import 'dart:convert';
import 'dart:io';

import 'package:ensemble_test_runner/cli/flutter_test_command.dart';
import 'package:ensemble_test_runner/entry/runner_runtime_configuration.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('passes a validated worker plan batch by file path', () {
    final arguments = buildFlutterTestArgs(
      const ['--plan-batch-file=build/worker-plans/worker-1.json'],
      suiteEncryptionKey: 'suite-key',
      reportMode: 'json',
      reportFile: null,
      timeoutSeconds: null,
      verbose: false,
    );

    expect(
      arguments,
      contains(
        '--dart-define=ensembleTestPlanBatchFile=${p.absolute('build/worker-plans/worker-1.json')}',
      ),
    );
    expect(arguments, isNot(contains('--plan-batch-file')));
    expect(arguments,
        isNot(contains('--plan-batch-file=build/worker-plans/worker-1.json')));
  });

  test('rejects repeated plan batch paths before launching Flutter', () {
    expect(
      () => buildFlutterTestArgs(
        const [
          '--plan-batch-file=one.json',
          '--plan-batch-file=two.json',
        ],
        suiteEncryptionKey: 'suite-key',
        reportMode: null,
        reportFile: null,
        timeoutSeconds: null,
        verbose: false,
      ),
      throwsStateError,
    );
  });

  test('prunes old generated kernel cache files to the configured budget', () {
    final project = Directory.systemTemp.createTempSync('runner-kernel-cache-');
    addTearDown(() => project.deleteSync(recursive: true));
    final cache = Directory(
      p.join(project.path, 'build', 'test_cache', 'build'),
    )..createSync(recursive: true);
    final old = File(p.join(cache.path, 'old.cache.dill.track.dill'))
      ..writeAsBytesSync(List.filled(7, 1))
      ..setLastModifiedSync(DateTime.utc(2020));
    final recent = File(p.join(cache.path, 'recent.cache.dill.track.dill'))
      ..writeAsBytesSync(List.filled(7, 2))
      ..setLastModifiedSync(DateTime.utc(2021));
    final unrelated = File(p.join(cache.path, 'keep.txt'))
      ..writeAsStringSync('unrelated');

    pruneFlutterTestKernelCache(project, maxBytes: 7);

    expect(old.existsSync(), isFalse);
    expect(recent.existsSync(), isTrue);
    expect(unrelated.existsSync(), isTrue);
  });

  test('keeps the default runner kernel cache near one warm compile', () {
    final project =
        Directory.systemTemp.createTempSync('runner-kernel-default-');
    addTearDown(() => project.deleteSync(recursive: true));
    final cache = Directory(
      p.join(project.path, 'build', 'test_cache', 'build'),
    )..createSync(recursive: true);
    final old = File(p.join(cache.path, 'old.cache.dill.track.dill'))
      ..writeAsBytesSync(List.filled(100 * 1024 * 1024, 1))
      ..setLastModifiedSync(DateTime.utc(2020));
    final recent = File(p.join(cache.path, 'recent.cache.dill.track.dill'))
      ..writeAsBytesSync(List.filled(100 * 1024 * 1024, 2))
      ..setLastModifiedSync(DateTime.utc(2021));

    pruneFlutterTestKernelCache(project);

    expect(old.existsSync(), isFalse);
    expect(recent.existsSync(), isTrue);
    expect(recent.lengthSync(), lessThanOrEqualTo(160 * 1024 * 1024));
  });

  test('deletes an oversized kernel cache entry instead of retaining it', () {
    final project =
        Directory.systemTemp.createTempSync('runner-kernel-budget-');
    addTearDown(() => project.deleteSync(recursive: true));
    final cache = Directory(
      p.join(project.path, 'build', 'test_cache', 'build'),
    )..createSync(recursive: true);
    final oversized = File(p.join(cache.path, 'large.cache.dill'))
      ..writeAsBytesSync(List.filled(8, 1));

    pruneFlutterTestKernelCache(project, maxBytes: 7);

    expect(oversized.existsSync(), isFalse);
  });

  test('identifies only the runner package as owning its build cache', () {
    final project = Directory.systemTemp.createTempSync('runner-cache-owner-');
    addTearDown(() => project.deleteSync(recursive: true));
    File(p.join(project.path, 'pubspec.yaml'))
        .writeAsStringSync('name: ensemble_test_runner\n');
    expect(isRunnerPackageRoot(project), isTrue);

    File(p.join(project.path, 'pubspec.yaml'))
        .writeAsStringSync('name: host_application\n');
    expect(isRunnerPackageRoot(project), isFalse);
  });

  test('moves shard-specific settings to runtime config for workers', () {
    const arguments = [
      '--plan-batch-file=build/worker-plans/worker-1.json',
      '--id=login',
      '--feature=accounts',
      '--device=iphone',
      '--input=region=uk',
    ];
    final flutterArguments = buildFlutterTestArgs(
      arguments,
      suiteEncryptionKey: 'suite-key',
      reportMode: 'json',
      reportFile: '/tmp/report-1.json',
      timeoutSeconds: 60,
      verbose: false,
      shardPaths: const ['tests/a.yaml'],
      shardIds: const ['case-a'],
      workerIndex: 0,
      progressFile: '/tmp/progress-1.jsonl',
      serviceOverrides: const {
        'api': {'url': 'http://127.0.0.1:9100'}
      },
      useRuntimeWorkerConfig: true,
    );
    final environment = buildFlutterTestWorkerEnvironment(
      suiteEncryptionKey: 'suite-key',
      workerIndex: 0,
      reportMode: 'json',
      timeoutSeconds: 60,
      shardPaths: const ['tests/a.yaml'],
      shardIds: const ['case-a'],
      reportFile: '/tmp/report-1.json',
      progressFile: '/tmp/progress-1.jsonl',
      appLogPath: null,
      appLogDisplayPath: null,
      serviceOverrides: const {
        'api': {'url': 'http://127.0.0.1:9100'}
      },
      arguments: arguments,
    );

    expect(
      flutterArguments.where((argument) =>
          argument.startsWith('--dart-define=ensembleTestEncryptionKey=') ||
          argument.startsWith('--dart-define=ensembleTestWorker') ||
          argument.startsWith('--dart-define=ensembleTestShard') ||
          argument.startsWith('--dart-define=ensembleTestReportFile=') ||
          argument.startsWith('--dart-define=ensembleTestId=') ||
          argument.startsWith('--dart-define=ensembleTestFeature=') ||
          argument.startsWith('--dart-define=ensembleTestDevice=') ||
          argument.startsWith('--dart-define=ensembleTestInputs=') ||
          argument.startsWith('--dart-define=ensembleTestReport=') ||
          argument.startsWith('--dart-define=ensembleTestTimeoutSeconds=') ||
          argument.startsWith('--dart-define=ensembleTestPlanBatchFile=') ||
          argument.startsWith('--dart-define=ensembleTestServiceOverrides=')),
      isEmpty,
    );
    final config = json.decode(
      environment['ENSEMBLE_TEST_RUNNER_CONFIG']!,
    ) as Map<String, dynamic>;
    expect(config['ensembleTestWorkerSuffix'], 'worker1');
    expect(config['ensembleTestEncryptionKey'], 'suite-key');
    expect(config['ensembleTestShardId'], ['case-a']);
    expect(config['ensembleTestShardPath'], ['tests/a.yaml']);
    expect(config['ensembleTestReportFile'], '/tmp/report-1.json');
    expect(config['ensembleTestId'], ['login']);
    expect(config['ensembleTestFeature'], ['accounts']);
    expect(config['ensembleTestDevice'], ['iphone']);
    expect(json.decode(config['ensembleTestInputs'] as String), {
      'region': 'uk',
    });
    expect(config['ensembleTestPlanBatchFile'],
        p.absolute('build/worker-plans/worker-1.json'));
    expect(
      json.decode(config['ensembleTestServiceOverrides'] as String),
      {
        'api': {'url': 'http://127.0.0.1:9100'}
      },
    );
  });

  test('decodes worker runtime settings without compile-time defines', () {
    final config = RunnerRuntimeConfiguration.fromEnvironment({
      'ENSEMBLE_TEST_RUNNER_CONFIG':
          '{"ensembleTestWorkerIndex":2,"ensembleTestShardId":["case-c"]}',
    });

    expect(config.integer('ensembleTestWorkerIndex'), 2);
    expect(config.strings('ensembleTestShardId'), ['case-c']);
  });

  test(
    'reads worker settings inherited by the Flutter test process',
    () {
      expect(
        RunnerRuntimeConfiguration.current.string('ensembleTestReportFile'),
        '/tmp/inherited-worker-report.json',
      );
      expect(
        RunnerRuntimeConfiguration.current.strings('ensembleTestShardId'),
        ['inherited-case'],
      );
    },
    skip: Platform.environment['ENSEMBLE_TEST_RUNNER_CONFIG'] == null,
  );
}
