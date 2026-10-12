import 'dart:io';

import 'package:ensemble_test_runner/parser/ensemble_test_parser.dart';
import 'package:ensemble_test_runner/src/runtime/compiled_plan.dart';
import 'package:ensemble_test_runner/src/core/plan.dart';

/// Parses and compiles every YAML test under a directory without running it.
/// Usage: dart run tool/audit_execution_plans.dart <test-directory>
Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln(
        'Usage: dart run tool/audit_execution_plans.dart <test-directory>');
    exitCode = 64;
    return;
  }

  final directory = Directory(arguments.single);
  if (!await directory.exists()) {
    stderr.writeln('Test directory does not exist: ${directory.path}');
    exitCode = 66;
    return;
  }

  final paths = await directory
      .list(recursive: true, followLinks: false)
      .where((entity) => entity is File && entity.path.endsWith('.test.yaml'))
      .map((entity) => entity.path)
      .toList();
  paths.sort();
  if (paths.isEmpty) {
    stderr.writeln('No *.test.yaml files found in ${directory.path}');
    exitCode = 66;
    return;
  }

  final compiler = CompiledPlanCompiler();
  var compiled = 0;
  var operations = 0;
  var commentOnly = 0;
  final errors = <String>[];
  for (final path in paths) {
    try {
      final content = await File(path).readAsString();
      if (!_hasDocumentContent(content)) {
        commentOnly++;
        continue;
      }
      final test = EnsembleTestParser.parseString(
        content,
        sourcePath: path,
      );
      final plan = compiler.compile(test);
      compiled++;
      operations += plan.nodes.values.whereType<OperationNode>().length;
    } catch (error) {
      errors.add('$path: $error');
    }
  }

  stdout.writeln('Compiled $compiled active test files; '
      '$operations operation nodes.'
      '${commentOnly == 0 ? '' : ' Skipped $commentOnly comment-only files.'}');
  for (final error in errors) {
    stderr.writeln(error);
  }
  if (errors.isNotEmpty) exitCode = 1;
}

bool _hasDocumentContent(String content) => content
    .split('\n')
    .map((line) => line.trimLeft())
    .any((line) => line.isNotEmpty && !line.startsWith('#'));
