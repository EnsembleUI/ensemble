import 'dart:io';

import 'package:ensemble_test_runner/cli/cli_compiled_plan_batch.dart';
import 'package:ensemble_test_runner/cli/cli_worker_batch_wire_transport.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/src/runtime/compiled_plan.dart';
import 'package:path/path.dart' as p;

Future<void> main() async {
  final root = Directory.systemTemp.createTempSync('plain_dart_plan_batch_');
  try {
    final tests = Directory(p.join(root.path, 'tests'))
      ..createSync(recursive: true);
    File(p.join(tests.path, 'case.test.yaml')).writeAsStringSync('''
id: plain_dart_case
startScreen: Home
steps:
  - expectVisible:
      id: ready
''');
    var compileCount = 0;
    final batch = await CliCompiledPlanBatch.build(
      appDirectory: root.path,
      testsDirectory: tests.path,
      arguments: const [],
      config: const EnsembleTestConfig(),
      compile: (test) {
        compileCount++;
        return CompiledPlanCompiler().compile(test);
      },
    );
    final decoded = CliWorkerBatchWireTransport.decode(
      batch.encodeForWorker(testIds: const ['plain_dart_case']),
    );
    if (compileCount != 1 ||
        !decoded.serializedPlans.containsKey('plain_dart_case') ||
        decoded.plan.ordered.single.testCase.id != 'plain_dart_case') {
      throw StateError('Plan batch was not built exactly once.');
    }
    stdout.writeln('plain Dart compiled plan batch passed');
  } finally {
    root.deleteSync(recursive: true);
  }
}
