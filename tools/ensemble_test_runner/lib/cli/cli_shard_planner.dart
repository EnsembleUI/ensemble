import 'dart:io';

import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/parser/ensemble_test_parser.dart';
import 'package:ensemble_test_runner/cli/cli_test_selection.dart';
import 'package:ensemble_test_runner/discovery/device_matrix.dart';
import 'package:ensemble_test_runner/reporters/ensemble_test_history_store.dart';
import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

Future<CliShardPlan> buildCliShardPlan(
  String appDir,
  String? testsDir, {
  List<String> arguments = const [],
}) async {
  if (testsDir == null) return CliShardPlan();
  final historicalDurations =
      await EnsembleTestHistoryStore.loadPlannerDurations(appDir);
  final parallel = <CliShardFile>[];
  final serial = <String>[];
  final config = _readTestsConfig(testsDir);
  final effectiveConfig = config == null
      ? null
      : applyDeviceFilter(
          config,
          CliTestSelection.valueSet(arguments, '--device'),
        );
  final files = Directory(testsDir)
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.test.yaml'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final docsByPath = <String, YamlMap?>{};
  final contentsByPath = <String, String>{};
  final pathById = <String, String>{};
  final referencedSessionIds = <String>{};
  final hasShardSelection = CliTestSelection.hasShardSelection(arguments);
  for (final file in files) {
    final relative = p.relative(file.path, from: appDir).replaceAll('\\', '/');
    final content = file.readAsStringSync();
    contentsByPath[relative] = content;
    final doc = _readShardDocumentContent(content);
    docsByPath[relative] = doc;
    final id = doc?['id']?.toString();
    if (id != null && id.isNotEmpty) {
      pathById[id] = relative;
    }
    final session = doc?['session']?.toString();
    if (session != null && session.isNotEmpty) {
      referencedSessionIds.add(session);
    }
  }

  final sessionProducerPaths = <String>{
    for (final id in referencedSessionIds)
      if (pathById[id] != null) pathById[id]!,
  };

  for (final file in files) {
    final relative = p.relative(file.path, from: appDir).replaceAll('\\', '/');
    final doc = docsByPath[relative];
    if (!CliTestSelection.matchesShardSelection(
      relative,
      doc,
      arguments,
      config: effectiveConfig,
    )) {
      continue;
    }
    if (_isParallelShardFile(doc: doc) &&
        (hasShardSelection || !sessionProducerPaths.contains(relative))) {
      final definitions = _expandedShardDefinitionsForFile(
        doc: doc,
        relativePath: relative,
        config: effectiveConfig,
        arguments: arguments,
      );
      final fileEstimate = _estimateShardFileDurationMs(
        file,
        relative,
        historicalDurations,
      );
      final fallbackEstimate =
          (fileEstimate / definitions.length.clamp(1, 1000000)).round();
      for (final definition in definitions) {
        parallel.add(
          CliShardFile(
            path: relative,
            paths: _shardPathsForDefinition(
              definition,
              relative,
              pathById,
            ),
            id: definition.id,
            estimatedDurationMs:
                historicalDurations.testDuration(definition.id) ??
                    fallbackEstimate,
          ),
        );
      }
    } else if (!hasShardSelection &&
        sessionProducerPaths.contains(relative) &&
        _isParallelShardFile(doc: doc)) {
      // Session producers are selected automatically by each shard that needs
      // them. Running them as standalone files would waste a worker lane.
      continue;
    } else {
      serial.add(relative);
    }
  }
  return CliShardPlan(
    parallel: parallel,
    serial: serial,
    assetContents: contentsByPath,
    decodedDocuments: docsByPath,
  );
}

List<String> _shardPathsForDefinition(
  ExpandedShardDefinition definition,
  String relativePath,
  Map<String, String> pathById,
) {
  final paths = <String>{relativePath};
  final session = definition.session;
  if (session != null && session.isNotEmpty) {
    final sessionPath = pathById[_rootExpandedId(session)];
    if (sessionPath != null) paths.add(sessionPath);
  }
  return paths.toList();
}

String _rootExpandedId(String id) {
  final bracket = id.indexOf('[');
  return bracket == -1 ? id : id.substring(0, bracket);
}

List<ExpandedShardDefinition> _expandedShardDefinitionsForFile({
  required YamlMap? doc,
  required String relativePath,
  required EnsembleTestConfig? config,
  required List<String> arguments,
}) {
  if (doc == null) return const [];
  final baseId = doc['id']?.toString();
  if (baseId == null || baseId.isEmpty) return const [];
  final effectiveConfig = config ?? const EnsembleTestConfig();
  final scenarios = CliTestSelection.scenarioIds(doc);
  final profileNames = CliTestSelection.profileNamesForShard(
    doc,
    config: effectiveConfig,
  );
  final multiProfile = profileNames.length > 1;
  final devices = effectiveConfig.devices;
  final multiDevice = devices.length > 1;
  final session = doc['session']?.toString();

  final definitions = <ExpandedShardDefinition>[];
  final scenarioIds = scenarios.isEmpty ? const [null] : scenarios;
  final profiles = profileNames.isEmpty ? const [null] : profileNames;
  final deviceIds = devices.isEmpty
      ? const [null]
      : devices.map((device) => device.id).toList(growable: false);

  for (final scenarioId in scenarioIds) {
    final scenarioRunId = scenarioId == null ? baseId : '$baseId[$scenarioId]';
    for (final profile in profiles) {
      final profileRunId = multiProfile && profile != null
          ? '$scenarioRunId[$profile]'
          : scenarioRunId;
      final profileSession = multiProfile && profile != null && session != null
          ? '$session[$profile]'
          : session;
      for (final deviceId in deviceIds) {
        definitions.add(
          ExpandedShardDefinition(
            id: multiDevice && deviceId != null
                ? '$profileRunId[$deviceId]'
                : profileRunId,
            assetPath: relativePath,
            feature: doc['feature']?.toString(),
            tags: CliTestSelection.stringList(doc['tags']),
            profile: profile,
            deviceId: deviceId,
            session: multiDevice && deviceId != null && profileSession != null
                ? '$profileSession[$deviceId]'
                : profileSession,
          ),
        );
      }
    }
  }

  return definitions
      .where(
        (definition) => CliTestSelection.matchesExpandedShardSelection(
          definition,
          arguments,
          config: config,
        ),
      )
      .toList();
}

EnsembleTestConfig? _readTestsConfig(String testsDir) {
  final configFile = File(p.join(testsDir, 'config.yaml'));
  if (!configFile.existsSync()) return null;
  try {
    return EnsembleTestParser.parseConfigString(
      configFile.readAsStringSync(),
      sourcePath: configFile.path,
    );
  } catch (_) {
    return null;
  }
}

EnsembleTestConfig readCliTestsConfigStrict(String testsDir) {
  final configFile = File(p.join(testsDir, 'config.yaml'));
  if (!configFile.existsSync()) return const EnsembleTestConfig();
  return EnsembleTestParser.parseConfigString(
    configFile.readAsStringSync(),
    sourcePath: configFile.path,
  );
}

EnsembleTestConfig applyCliIntegrationDeviceMatrix(
  EnsembleTestConfig config, {
  required String platform,
  required List<String> arguments,
  required bool quiet,
}) {
  if (config.devices.isEmpty &&
      CliTestSelection.values(arguments, '--device').isEmpty) {
    return config;
  }
  final matrix = resolveIntegrationDeviceMatrix(
    config,
    platform: platform,
    selectedIds: CliTestSelection.valueSet(arguments, '--device'),
  );
  for (final warning in matrix.warnings) {
    if (!quiet) stderr.writeln(warning);
  }
  return matrix.config;
}

YamlMap? _readShardDocumentContent(String content) {
  try {
    final doc = loadYaml(content);
    RunnerBenchmark.count('documentsDecoded', 1);
    return doc is YamlMap ? doc : null;
  } catch (_) {
    // Let the real parser report invalid YAML with source context.
  }
  return null;
}

bool _isParallelShardFile({YamlMap? doc}) {
  if (doc != null && doc['parallel'] == false) return false;
  return true;
}

class CliShardPlan {
  final List<CliShardFile> parallel;
  final List<String> serial;
  final Map<String, String> assetContents;
  final Map<String, dynamic> decodedDocuments;

  CliShardPlan({
    this.parallel = const [],
    this.serial = const [],
    Map<String, String> assetContents = const {},
    Map<String, dynamic> decodedDocuments = const {},
  })  : assetContents = Map.unmodifiable(assetContents),
        decodedDocuments = Map.unmodifiable(decodedDocuments);
}

class CliShardFile {
  final String path;
  final List<String> paths;
  final String id;
  final int estimatedDurationMs;

  const CliShardFile({
    required this.path,
    required this.paths,
    required this.id,
    required this.estimatedDurationMs,
  });
}

List<List<CliShardFile>> balancedCliShards(
  List<CliShardFile> files,
  int workerCount,
) {
  return RunnerBenchmark.sync('worker', 'balancedShards', () {
    if (workerCount <= 0) return const [];
    final shards = List.generate(workerCount, (_) => <CliShardFile>[]);
    final shardDurations = List.filled(workerCount, 0);
    final sorted = [...files]..sort((a, b) {
        final byDuration =
            b.estimatedDurationMs.compareTo(a.estimatedDurationMs);
        if (byDuration != 0) return byDuration;
        final byPath = a.path.compareTo(b.path);
        return byPath != 0 ? byPath : a.id.compareTo(b.id);
      });

    for (final file in sorted) {
      var target = 0;
      for (var i = 1; i < shardDurations.length; i++) {
        if (shardDurations[i] < shardDurations[target]) target = i;
      }
      shards[target].add(file);
      shardDurations[target] += file.estimatedDurationMs;
    }
    return shards;
  });
}

int _estimateShardFileDurationMs(
  File file,
  String relativePath,
  HistoricalTestDurations historicalDurations,
) {
  final historical = historicalDurations.fileDuration(relativePath);
  if (historical != null && historical > 0) return historical;

  try {
    final doc = loadYaml(file.readAsStringSync());
    if (doc is! YamlMap) return 30000;
    final steps = doc['steps'];
    var estimate = doc['startScreen'] == 'Login' ? 18000 : 6000;
    if (doc['session'] != null) estimate += 4000;
    if (steps is YamlList) {
      for (final step in steps) estimate += _estimateShardStepDurationMs(step);
    }
    return estimate.clamp(10000, 180000);
  } catch (_) {
    return 30000;
  }
}

int _estimateShardStepDurationMs(dynamic step) {
  if (step is! YamlMap || step.isEmpty) return 1000;
  final type = step.keys.first.toString();
  return switch (type) {
    'waitForNavigation' => 7000,
    'waitForApi' => 6000,
    'waitFor' => 4000,
    'settle' => 2500,
    'tap' || 'toggle' || 'enterText' || 'goBack' => 1200,
    'expectVisible' || 'expectText' || 'expectNotVisible' => 700,
    _ => 1500,
  };
}
