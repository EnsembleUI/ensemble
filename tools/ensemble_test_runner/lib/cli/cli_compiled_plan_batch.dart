import 'dart:io';

import 'package:ensemble_test_runner/cli/cli_test_selection.dart';
import 'package:ensemble_test_runner/discovery/asset_string_loader.dart';
import 'package:ensemble_test_runner/discovery/device_matrix.dart';
import 'package:ensemble_test_runner/discovery/ensemble_test_execution_planner.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/src/core/plan.dart';
import 'package:ensemble_test_runner/cli/cli_worker_batch_wire_transport.dart';
import 'package:ensemble_test_runner/src/runtime/compiled_plan.dart';
import 'package:path/path.dart' as p;

/// Compiles selected suite plans in the CLI process before worker dispatch.
///
/// Workers receive selected parsed definitions, suite configuration and
/// immutable execution plans before their test entry points start.
final class CliCompiledPlanBatch {
  CliCompiledPlanBatch._({
    required this.definitionsById,
    required this.plansById,
    required this.config,
  });

  final Map<String, EnsembleTestDefinition> definitionsById;
  final Map<String, ExecutionPlan> plansById;
  final EnsembleTestConfig config;

  /// Returns selected case IDs whose source assets are assigned to a worker.
  /// Session definitions are included only when their source path is assigned.
  List<String> testIdsForAssetPaths(Iterable<String> assetPaths) {
    final paths = assetPaths.toSet();
    return definitionsById.values
        .where((definition) => paths.contains(definition.assetPath))
        .map((definition) => definition.testCase.id)
        .toList(growable: false);
  }

  static Future<CliCompiledPlanBatch> build({
    required String appDirectory,
    required String testsDirectory,
    required List<String> arguments,
    required EnsembleTestConfig config,
    Map<String, String>? assetContents,
    Map<String, dynamic>? decodedDocuments,
    ExecutionPlan Function(EnsembleTestCase test)? compile,
  }) async {
    // Sharding applies --device before deriving expanded IDs. The parent CLI
    // does not narrow widget-mode config before calling this builder, so do
    // the same filtering here or the worker IDs (for example, a scenario ID
    // without a device suffix) will not match the compiled definitions.
    final selectedConfig = applyDeviceFilter(
      config,
      CliTestSelection.valueSet(arguments, '--device'),
    );
    // The shard planner has already enumerated and read the complete suite.
    // Treat that snapshot as authoritative so the plan handoff does not repeat
    // the same recursive filesystem walk (or reopen the source files).
    final paths = assetContents == null
        ? Directory(testsDirectory)
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.test.yaml'))
            .map((file) =>
                p.relative(file.path, from: appDirectory).replaceAll('\\', '/'))
            .toList()
        : assetContents.keys.toList();
    paths.sort();
    final assets = assetContents ??
        {
          for (final path in paths)
            path: File(p.join(appDirectory, path)).readAsStringSync(),
        };
    final selection = EnsembleTestSelection(
      ids: CliTestSelection.valueSet(arguments, '--id'),
      features: CliTestSelection.valueSet(arguments, '--feature'),
      profiles: CliTestSelection.valueSet(arguments, '--profile'),
      tags: CliTestSelection.valueSet(arguments, '--tag'),
      paths: CliTestSelection.valueSet(arguments, '--path'),
    );
    final plan = await EnsembleTestExecutionPlanner.buildFromAssets(
      assetContents: assets,
      config: selectedConfig,
      selection: selection,
      inputs: inputValuesFromArguments(arguments),
      decodedDocuments: decodedDocuments,
      assetLoader: (assetPath) async {
        final file = File(p.join(appDirectory, assetPath));
        if (!file.existsSync()) {
          throw AssetLoadException(
              assetPath,
              FileSystemException(
                'Test asset not found',
                file.path,
              ));
        }
        return file.readAsString();
      },
    );
    final definitions = <String, EnsembleTestDefinition>{
      for (final definition in plan.ordered) definition.testCase.id: definition,
    };
    final compileTest =
        compile ?? (test) => CompiledPlanCompiler().compile(test);
    final compiled = <String, ExecutionPlan>{};
    for (final definition in plan.ordered) {
      try {
        compiled[definition.testCase.id] = compileTest(definition.testCase);
      } on Object {
        // Keep invalid plans on the worker's normal case-level error path.
        // Successfully compiled plans are still handed off without a second
        // compilation in each worker process.
      }
    }
    return CliCompiledPlanBatch._(
      definitionsById: Map.unmodifiable(definitions),
      plansById: Map.unmodifiable(compiled),
      config: selectedConfig,
    );
  }

  /// Encodes only the plans assigned to one worker, including session setup
  /// definitions required by those plans.
  String encodeForWorker({
    Iterable<String> testIds = const [],
    Iterable<String> assetPaths = const [],
  }) {
    final selectedIds = <String>{...testIds};
    final paths = assetPaths.toSet();
    for (final definition in definitionsById.values) {
      if (paths.contains(definition.assetPath)) {
        selectedIds.add(definition.testCase.id);
      }
    }

    void includeSession(String id) {
      final definition = definitionsById[id];
      if (definition == null) {
        throw StateError('No compiled test definition for worker test "$id".');
      }
      final session = definition.testCase.session;
      if (session != null && selectedIds.add(session)) includeSession(session);
    }

    for (final id in selectedIds.toList(growable: false)) {
      includeSession(id);
    }
    final plans = <String, ExecutionPlan>{};
    final definitions = definitionsById.values
        .where((definition) => selectedIds.contains(definition.testCase.id))
        .toList(growable: false);
    for (final id in selectedIds) {
      final plan = plansById[id];
      if (plan == null) continue;
      plans[id] = plan;
    }
    return CliWorkerBatchWireTransport.encode(
      definitions: definitions,
      config: config,
      plans: plans,
    );
  }
}

/// Converts the CLI's repeatable `--input key=value` options to runtime values.
Map<String, dynamic> inputValuesFromArguments(List<String> arguments) {
  final inputs = <String, dynamic>{};
  for (var i = 0; i < arguments.length; i++) {
    final argument = arguments[i];
    String? raw;
    if (argument == '--input') {
      if (i + 1 >= arguments.length) {
        throw StateError('--input requires key=value');
      }
      raw = arguments[++i];
    } else if (argument.startsWith('--input=')) {
      raw = argument.substring('--input='.length);
    }
    if (raw == null) continue;
    final separator = raw.indexOf('=');
    if (separator <= 0) {
      throw StateError('Invalid --input "$raw". Use --input key=value.');
    }
    final key = raw.substring(0, separator).trim();
    if (key.isEmpty) {
      throw StateError('Invalid --input "$raw". Input key cannot be empty.');
    }
    final value = raw.substring(separator + 1);
    final trimmed = value.trim();
    inputs[key] = trimmed == 'true'
        ? true
        : trimmed == 'false'
            ? false
            : int.tryParse(trimmed) ?? double.tryParse(trimmed) ?? value;
  }
  return inputs;
}
