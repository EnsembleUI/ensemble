import 'dart:io';

import 'package:ensemble_test_runner/cli/cli_compiled_plan_batch.dart';
import 'package:ensemble_test_runner/cli/cli_shard_planner.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'package:ensemble_test_runner/cli/cli_worker_batch_wire_transport.dart';
import 'package:ensemble_test_runner/src/runtime/compiled_plan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('compiles each selected suite plan once before worker dispatch',
      () async {
    final root = Directory.systemTemp.createTempSync('compiled_plan_batch_');
    addTearDown(() => root.deleteSync(recursive: true));
    final tests = Directory(p.join(root.path, 'tests'))
      ..createSync(recursive: true);
    File(p.join(tests.path, 'session.test.yaml')).writeAsStringSync('''
id: session_base
startScreen: Home
steps:
  - expectVisible:
      id: open_button
''');
    File(p.join(tests.path, 'selected.test.yaml')).writeAsStringSync('''
id: selected
feature: worker transport
description: Preserve parsed definition metadata.
tags: [fast, smoke]
session: session_base
startScreen: Home
steps:
  - expectVisible:
      id: open_button
''');
    File(p.join(tests.path, 'unselected.test.yaml')).writeAsStringSync('''
id: unselected
startScreen: Home
steps:
  - expectVisible:
      id: open_button
''');

    final compileCounts = <String, int>{};
    const config = EnsembleTestConfig(
      logApiCalls: LogApiCallsConfig(enabled: false),
      initialState: {'transport': true},
      devices: [
        TestDeviceTarget(id: 'ios', platform: 'ios', model: 'iPhone'),
      ],
    );
    final batch = await CliCompiledPlanBatch.build(
      appDirectory: root.path,
      testsDirectory: tests.path,
      arguments: const ['--id=selected'],
      config: config,
      compile: (test) {
        compileCounts.update(test.id, (count) => count + 1, ifAbsent: () => 1);
        return CompiledPlanCompiler().compile(test);
      },
    );

    expect(compileCounts, {'session_base': 1, 'selected': 1});
    final workerPlans = CliWorkerBatchWireTransport.decode(
      batch.encodeForWorker(testIds: const ['selected']),
    );
    expect(
      workerPlans.serializedPlans.keys.toSet(),
      {'session_base', 'selected'},
    );
    expect(
      workerPlans.plan.ordered.map((definition) => definition.testCase.id),
      ['session_base', 'selected'],
    );
    final transportedTest = workerPlans.plan.ordered
        .singleWhere((definition) => definition.testCase.id == 'selected')
        .testCase;
    expect(transportedTest.feature, 'worker transport');
    expect(transportedTest.description, 'Preserve parsed definition metadata.');
    expect(transportedTest.tags, ['fast', 'smoke']);
    expect(workerPlans.plan.config.logApiCalls.enabled, isFalse);
    expect(workerPlans.plan.config.initialState, {'transport': true});
    expect(workerPlans.plan.config.devices.single.model, 'iPhone');
  });

  test('worker batch can select assigned asset paths and their session chain',
      () async {
    final root = Directory.systemTemp.createTempSync('compiled_plan_paths_');
    addTearDown(() => root.deleteSync(recursive: true));
    final tests = Directory(p.join(root.path, 'ensemble', 'tests'))
      ..createSync(recursive: true);
    File(p.join(tests.path, 'session.test.yaml')).writeAsStringSync('''
id: session_base
startScreen: Home
steps:
  - expectVisible:
      id: open_button
''');
    File(p.join(tests.path, 'serial.test.yaml')).writeAsStringSync('''
id: serial_case
session: session_base
startScreen: Home
steps:
  - expectVisible:
      id: open_button
''');

    final batch = await CliCompiledPlanBatch.build(
      appDirectory: root.path,
      testsDirectory: tests.path,
      arguments: const [],
      config: const EnsembleTestConfig(),
    );
    final plans = CliWorkerBatchWireTransport.decode(
      batch.encodeForWorker(
          assetPaths: const ['ensemble/tests/serial.test.yaml']),
    );

    expect(plans.serializedPlans.keys.toSet(), {'session_base', 'serial_case'});
    expect(
      batch.testIdsForAssetPaths(const ['ensemble/tests/serial.test.yaml']),
      ['serial_case'],
    );
  });

  test('uses shard planner decoded documents instead of decoding assets again',
      () async {
    final root = Directory.systemTemp.createTempSync('compiled_plan_cached_');
    addTearDown(() => root.deleteSync(recursive: true));
    final tests = Directory(p.join(root.path, 'tests'))
      ..createSync(recursive: true);
    const source = '''
id: cached
startScreen: Home
steps:
  - expectVisible:
      id: ready
''';
    File(p.join(tests.path, 'cached.test.yaml')).writeAsStringSync(source);

    final shardPlan = await buildCliShardPlan(root.path, tests.path);
    final staleText = Map<String, String>.of(shardPlan.assetContents)
      ..['tests/cached.test.yaml'] = 'intentionally invalid';
    final batch = await CliCompiledPlanBatch.build(
      appDirectory: root.path,
      testsDirectory: tests.path,
      arguments: const [],
      config: const EnsembleTestConfig(),
      assetContents: staleText,
      decodedDocuments: shardPlan.decodedDocuments,
    );

    expect(batch.definitionsById.keys, contains('cached'));
    expect(batch.plansById.keys, contains('cached'));
  });

  test('compiles a suite asset once before worker handoff', () async {
    final root = Directory.systemTemp.createTempSync('compiled_plan_once_');
    addTearDown(() => root.deleteSync(recursive: true));
    final tests = Directory(p.join(root.path, 'tests'))
      ..createSync(recursive: true);
    File(p.join(tests.path, 'selected.test.yaml')).writeAsStringSync('''
id: selected
startScreen: Home
steps:
  - expectVisible:
      id: ready
''');

    var compileCount = 0;
    late CliCompiledPlanBatch batch;
    final shards = await buildCliShardPlan(root.path, tests.path);
    batch = await CliCompiledPlanBatch.build(
      appDirectory: root.path,
      testsDirectory: tests.path,
      arguments: const [],
      config: const EnsembleTestConfig(),
      assetContents: shards.assetContents,
      decodedDocuments: shards.decodedDocuments,
      compile: (test) {
        compileCount++;
        return CompiledPlanCompiler().compile(test);
      },
    );

    expect(compileCount, 1);

    // Worker handoff serializes the already compiled representation, so a
    // worker does not need to compile this selected plan again.
    expect(
      CliWorkerBatchWireTransport.decode(
        batch.encodeForWorker(testIds: const ['selected']),
      ).serializedPlans.keys,
      {'selected'},
    );
  });

  test('decodes a selected suite once and compiles each scenario once',
      () async {
    final root = Directory.systemTemp.createTempSync('compiled_scenarios_');
    addTearDown(() => root.deleteSync(recursive: true));
    final tests = Directory(p.join(root.path, 'tests'))
      ..createSync(recursive: true);
    File(p.join(tests.path, 'selected.test.yaml')).writeAsStringSync(r'''
id: selected
startScreen: Home
scenarios:
  - id: first
    vars:
      button: first_button
  - id: second
    vars:
      button: second_button
steps:
  - expectVisible:
      id: ${scenario.button}
''');
    File(p.join(tests.path, 'unselected.test.yaml')).writeAsStringSync('''
id: unselected
startScreen: Other
steps:
  - expectVisible:
      id: other_button
''');

    final collector = BenchmarkCollector(
      caseId: 'cli-selected-scenario-compile-once',
      sample: 0,
      processId: 'test',
    );
    final compileCounts = <String, int>{};
    late CliShardPlan shardPlan;
    late CliCompiledPlanBatch batch;
    await RunnerBenchmark.collect(collector, () async {
      await RunnerBenchmark.async('test', 'suiteBatch', () async {
        const arguments = ['--id=selected'];
        shardPlan = await buildCliShardPlan(
          root.path,
          tests.path,
          arguments: arguments,
        );
        batch = await CliCompiledPlanBatch.build(
          appDirectory: root.path,
          testsDirectory: tests.path,
          arguments: arguments,
          config: const EnsembleTestConfig(),
          assetContents: shardPlan.assetContents,
          decodedDocuments: shardPlan.decodedDocuments,
          compile: (test) {
            compileCounts.update(
              test.id,
              (count) => count + 1,
              ifAbsent: () => 1,
            );
            return CompiledPlanCompiler().compile(test);
          },
        );

        final assignedIds = shardPlan.parallel.map((file) => file.id).toList();
        for (var attempt = 0; attempt < 3; attempt++) {
          final workerBatch = CliWorkerBatchWireTransport.decode(
            batch.encodeForWorker(testIds: assignedIds),
          );
          expect(workerBatch.serializedPlans.keys.toSet(), {
            'selected[first]',
            'selected[second]',
          });
          expect(
            workerBatch.plan.ordered
                .map((definition) => definition.testCase.id)
                .toSet(),
            {'selected[first]', 'selected[second]'},
          );
        }
      });
    });

    expect(shardPlan.decodedDocuments.keys.toSet(), {
      'tests/selected.test.yaml',
      'tests/unselected.test.yaml',
    });
    expect(compileCounts, {
      'selected[first]': 1,
      'selected[second]': 1,
    });
    expect(batch.plansById.keys.toSet(), compileCounts.keys.toSet());

    final suiteBatchSpan = collector.spans.singleWhere(
      (span) => span.service == 'test' && span.operation == 'suiteBatch',
    );
    expect(suiteBatchSpan.counters['documentsDecoded'], 2);
    expect(
      collector.spans
          .where((span) =>
              span.service == 'planner' &&
              span.operation == 'parseDefinitionsFromAsset')
          .length,
      1,
    );
  });

  test('uses the supplied suite snapshot without scanning the test directory',
      () async {
    final root = Directory.systemTemp.createTempSync('compiled_plan_snapshot_');
    addTearDown(() => root.deleteSync(recursive: true));
    final tests = Directory(p.join(root.path, 'tests'))..createSync();

    final batch = await CliCompiledPlanBatch.build(
      appDirectory: root.path,
      testsDirectory: tests.path,
      arguments: const [],
      config: const EnsembleTestConfig(),
      assetContents: const {
        'tests/snapshot.test.yaml': '''
id: snapshot
startScreen: Home
steps:
  - expectVisible:
      id: ready
''',
      },
    );

    expect(batch.definitionsById.keys, ['snapshot']);
    expect(batch.plansById.keys, ['snapshot']);
  });

  test('applies device selection before compiling worker test IDs', () async {
    final root = Directory.systemTemp.createTempSync('compiled_plan_device_');
    addTearDown(() => root.deleteSync(recursive: true));
    final tests = Directory(p.join(root.path, 'tests'))
      ..createSync(recursive: true);
    File(p.join(tests.path, 'matrix.test.yaml')).writeAsStringSync('''
id: matrix_case
startScreen: Home
scenarios:
  - id: no_disconnect
    vars: {}
steps:
  - expectVisible:
      id: ready
''');
    const config = EnsembleTestConfig(devices: [
      TestDeviceTarget(id: 'iphone', platform: 'ios', model: 'iPhone'),
      TestDeviceTarget(id: 'android', platform: 'android', model: 'Pixel'),
    ]);

    final batch = await CliCompiledPlanBatch.build(
      appDirectory: root.path,
      testsDirectory: tests.path,
      arguments: const ['--id=matrix_case', '--device=android'],
      config: config,
    );

    expect(batch.definitionsById.keys, ['matrix_case[no_disconnect]']);
    final plans = CliWorkerBatchWireTransport.decode(
      batch.encodeForWorker(testIds: const ['matrix_case[no_disconnect]']),
    );
    expect(plans.serializedPlans.keys, {'matrix_case[no_disconnect]'});
  });
}
