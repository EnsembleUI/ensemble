import 'dart:convert';
import 'dart:io';

import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/reporters/ensemble_test_history_store.dart';
import 'package:ensemble_test_runner/reporters/junit_test_report.dart';
import 'package:ensemble_test_runner/reporters/test_report_document.dart';
import 'package:ensemble_test_runner/reporters/test_reporter.dart';
import 'package:ensemble_test_runner/src/core/operation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('result-projection-matrix-');
    sqfliteFfiInit();
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('report formats preserve their documented result-field contract',
      () async {
    final suiteLog = File(p.join(tempDir.path, 'logs', 'suite.txt'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('suite diagnostic');
    const testId = 'checkout[retry][iphone] (tests/checkout.test.yaml)';
    const message = 'Could not find widget pay_now';
    final failedStep = const TestStep(type: 'tap', args: {'id': 'pay_now'});
    final result = EnsembleTestRunResult(
      metadata: const {'mode': 'widget', 'platform': 'ios'},
      suiteLogs: ['suiteNotes: ${suiteLog.path}'],
      results: [
        EnsembleSingleTestResult.failed(
          testId: testId,
          metadata: const {
            'feature': 'payments',
            'profile': 'smoke',
            'scenarioId': 'retry',
            'scenarioDescription': 'retry after one transient failure',
            'description': 'Complete a card checkout',
            'customTag': 'full-metadata',
            'device': {'id': 'iphone'},
          },
          durationMs: 42,
          attempts: 2,
          retry: 1,
          failedStepIndex: 3,
          failedStep: failedStep,
          failureOperation: 'tap',
          message: message,
          stackTrace: 'CheckoutTest.run:42',
          failure: const TestFailureDetails(
            kind: TestFailureKind.elementNotFound,
            message: message,
            target: {'id': 'pay_now'},
            phase: 'action',
          ),
          secondaryFailures: const [
            TestFailureDetails(
              kind: TestFailureKind.cleanup,
              message: 'close failed',
            ),
          ],
          capabilityStatus: const {'screenshots': true, 'network': false},
          logs: const ['appLogs: logs/checkout.log'],
          report: const EnsembleTestReportDetails(
            startScreen: 'Checkout',
            endScreen: 'Checkout',
            navigationKnown: false,
            session: 'checkout-session',
            screensVisited: ['Checkout'],
            stepsOutline: ['tap(pay_now)'],
            stepDurationsMs: [31],
            stepStartTimes: ['2026-10-03T12:00:00.000Z'],
            screens: {
              'Checkout': {'dumpTree': 'screens/checkout.json'},
            },
          ),
        ),
      ],
    );

    final machine = result.toJson();
    final machineTest = (machine['results'] as List).single as Map;
    final console = TestReporter().formatSummary(result);
    final junit = JunitTestReport.build(result);
    final html = TestReportDocument.buildComplete(
      result,
      artifactRoot: tempDir.path,
      displayRoot: 'build/report',
    );
    final htmlTest = (html['tests'] as List).single as Map;

    // Canonical machine JSON carries the full result model.
    expect(machineTest['testId'], testId);
    expect(machineTest['metadata'], result.results.single.metadata);
    expect(machineTest['status'], 'failed');
    expect(machineTest['durationMs'], 42);
    expect(machineTest['attempts'], 2);
    expect(machineTest['retry'], 1);
    expect(machineTest['failedStepIndex'], 3);
    expect(machineTest['failedStep'], {
      'tap': {'id': 'pay_now'}
    });
    expect(machineTest['message'], message);
    expect(machineTest['failureOperation'], 'tap');
    expect(machineTest['failure'], isA<Map>());
    expect((machineTest['failure'] as Map)['phase'], 'action');
    expect(machineTest['secondaryFailures'], hasLength(1));
    expect(machineTest['capabilities'], result.results.single.capabilityStatus);
    expect(machineTest['logs'], result.results.single.logs);
    expect(machineTest['report'], isA<Map>());
    expect(machine['metadata'], result.metadata);
    expect(machine['suiteLogs'], result.suiteLogs);

    // Audit every report detail field: JSON and HTML retain the complete
    // navigation, timing, and screen-artifact context.
    final reportJson = machineTest['report'] as Map;
    expect(reportJson, {
      'startScreen': 'Checkout',
      'endScreen': 'Checkout',
      'navigationKnown': false,
      'session': 'checkout-session',
      'screensVisited': ['Checkout'],
      'stepsOutline': ['tap(pay_now)'],
      'stepDurationsMs': [31],
      'stepStartTimes': ['2026-10-03T12:00:00.000Z'],
      'screens': {
        'Checkout': {'dumpTree': 'screens/checkout.json'},
      },
    });

    // HTML preserves canonical diagnostics and adds viewer-oriented fields.
    expect(htmlTest['id'], testId);
    expect(htmlTest['metadata'], result.results.single.metadata);
    expect(
        htmlTest['scenarioDescription'], 'retry after one transient failure');
    expect(htmlTest['description'], 'Complete a card checkout');
    expect(htmlTest['status'], machineTest['status']);
    expect(htmlTest['durationMs'], machineTest['durationMs']);
    expect(htmlTest['attempts'], machineTest['attempts']);
    expect(htmlTest['retry'], machineTest['retry']);
    expect(htmlTest['message'], machineTest['message']);
    expect(htmlTest['failure'], machineTest['failure']);
    expect(htmlTest['secondaryFailures'], machineTest['secondaryFailures']);
    expect(htmlTest['capabilities'], machineTest['capabilities']);
    expect(htmlTest['stackTrace'], machineTest['stackTrace']);
    expect(htmlTest['failedStep'], machineTest['failedStep']);
    expect(htmlTest['failedStepIndex'], machineTest['failedStepIndex']);
    expect(htmlTest['failureOperation'], machineTest['failureOperation']);
    expect(htmlTest['logs'], isNull,
        reason: 'HTML resolves artifact references into viewer fields.');
    expect(htmlTest['report'], machineTest['report']);
    expect(htmlTest['steps'], isA<List>());
    expect(html['metadata'], result.metadata);
    expect((html['suiteArtifacts'] as List).single['label'], 'suiteNotes');

    // JUnit carries execution identity, timing, retry/failure properties and
    // useful failure text. Rich runner-only metadata is intentionally omitted.
    expect(junit, contains('<testcase name="$testId" time="0.042">'));
    expect(junit, contains('name="ensemble.attempts" value="2"'));
    expect(junit, contains('name="ensemble.retries" value="1"'));
    expect(junit, contains('name="ensemble.failed_step_index" value="3"'));
    expect(junit, contains('name="ensemble.failure.operation" value="tap"'));
    expect(junit,
        contains('name="ensemble.failure.kind" value="elementNotFound"'));
    expect(junit, contains('<failure message="$message">'));
    expect(junit, contains('CheckoutTest.run:42'));
    expect(junit, isNot(contains('payments')));
    expect(junit, isNot(contains('secondaryFailures')));
    expect(junit, isNot(contains('screenshots')));
    expect(junit, isNot(contains('suiteNotes')));
    expect(junit, isNot(contains('checkout-session')));
    expect(junit, isNot(contains('navigationKnown')));
    expect(junit, isNot(contains('action')),
        reason: 'JUnit publishes failure kind, not phase/context details.');

    // Console is a concise human summary. Its omissions are intentional: it
    // does not serialize arbitrary metadata, logs, report payloads or traces.
    expect(console, contains('checkout[retry][iphone]'));
    expect(console, contains('42ms'));
    expect(console, contains('attempts: 2/2'));
    expect(console, contains('operation: tap'));
    expect(console, contains('failed: tap(pay_now)'));
    expect(console, contains(message));
    expect(console, contains('suiteNotes:'));
    expect(console, isNot(contains('CheckoutTest.run')));
    expect(console, isNot(contains('appLogs:')));
    expect(console, isNot(contains('payments')));
    expect(console, contains('session: checkout-session'));
    expect(console, contains('start: Checkout'));
    expect(console, contains('tap(pay_now) (31ms)'));
    expect(console, isNot(contains('2026-10-03T12:00:00.000Z')));
    expect(console, isNot(contains('navigationKnown')));
  });

  test('history retains compact trend fields and omits rich diagnostics',
      () async {
    const testId = 'checkout[retry][iphone] (tests/checkout.test.yaml)';
    const message = 'Could not find widget pay_now';
    await EnsembleTestHistoryStore.recordCompletedRun(
      appDir: tempDir.path,
      artifactRoot: tempDir.path,
      wallTimeMs: 51,
      result: EnsembleTestRunResult(
        metadata: const {'mode': 'widget', 'platform': 'ios'},
        results: [
          EnsembleSingleTestResult.failed(
            testId: testId,
            metadata: const {
              'feature': 'payments',
              'profile': 'smoke',
              'scenarioId': 'retry',
              'scenarioDescription': 'retry after one transient failure',
              'description': 'Complete a card checkout',
              'customTag': 'full-metadata',
              'device': {'id': 'iphone'},
            },
            durationMs: 42,
            attempts: 2,
            retry: 1,
            failedStepIndex: 3,
            failedStep: const TestStep(type: 'tap', args: {'id': 'pay_now'}),
            failureOperation: 'tap',
            failureSource: const SourceLocation(
              'tests/checkout.test.yaml',
              'steps[3]',
            ),
            message: message,
            stackTrace: 'CheckoutTest.run:42',
            failure: const TestFailureDetails(
              kind: TestFailureKind.elementNotFound,
              message: message,
              target: {'id': 'pay_now'},
              phase: 'action',
            ),
            secondaryFailures: const [
              TestFailureDetails(
                kind: TestFailureKind.cleanup,
                message: 'close failed',
              ),
            ],
            capabilityStatus: const {'screenshots': true, 'network': false},
            logs: const ['appLogs: logs/checkout.log'],
            report: const EnsembleTestReportDetails(
              startScreen: 'Checkout',
              endScreen: 'Checkout',
            ),
          ),
        ],
      ),
    );

    final db = await databaseFactoryFfi.openDatabase(
      p.join(tempDir.path, 'report', EnsembleTestHistoryStore.fileName),
    );
    addTearDown(db.close);
    final run =
        (await db.query('test_results', where: "record_type = 'run'")).single;
    final runSummary = jsonDecode(run['summary_data'] as String);
    final stored = (await db.rawQuery('''
SELECT r.*, c.test_id, c.file_name, c.device, c.scenario, c.profile
FROM test_results r JOIN test_catalog c ON c.id = r.test_ref
WHERE r.record_type = 'test'
''')).single;

    expect(run['status'], 'failed');
    expect(run['duration_ms'], 51);
    expect(runSummary['total_tests'], 1);
    expect(stored['status'], 'failed');
    expect(stored['duration_ms'], 42);
    expect(stored['attempts'], 2);
    expect(stored.keys, isNot(contains('retry')));
    expect(stored['failed_step_index'], 3);
    expect(stored['failed_step'], 'tap(pay_now)');
    expect(stored.keys, isNot(contains('failure_operation')));
    expect(stored.keys, isNot(contains('failure_source_path')));
    expect(stored['error_kind'], 'elementNotFound');
    expect(stored['error_summary'], message);
    expect(stored['scenario'], 'retry');
    expect(stored['profile'], 'smoke');
    expect(stored.keys, isNot(contains('feature')));
    expect(stored['device'], 'iphone');
    expect(runSummary['mode'], 'widget');
    expect(runSummary['platform'], 'ios');

    // History keeps only fields consumed by the trends and run detail views.
    final columns = (await db.rawQuery('PRAGMA table_info(test_results)'))
        .map((row) => row['name'].toString())
        .toSet();
    expect(
        columns,
        containsAll([
          'test_ref',
          'status',
          'duration_ms',
          'attempts',
          'failed_step_index',
          'failed_step',
          'error_kind',
          'error_summary',
        ]));
    final catalogColumns =
        (await db.rawQuery('PRAGMA table_info(test_catalog)'))
            .map((row) => row['name'].toString())
            .toSet();
    expect(catalogColumns,
        containsAll(['test_id', 'file_name', 'device', 'scenario', 'profile']));
    expect(columns, isNot(contains('feature')));
    expect(columns, isNot(contains('retry')));
    expect(columns, isNot(contains('failure_source_path')));
    expect(columns, isNot(contains('stack_trace')));
    expect(columns, isNot(contains('secondary_failures')));
    expect(columns, isNot(contains('capabilities')));
    expect(columns, isNot(contains('logs')));
    expect(columns, isNot(contains('report')));
    expect(columns, isNot(contains('metadata')));
    expect(columns, isNot(contains('failure_phase')));
    expect(columns, isNot(contains('failure_operation')));
    expect(columns, isNot(contains('failure_source_step_path')));
    expect(columns, isNot(contains('scenario_description')));
    expect(columns, isNot(contains('description')));
    expect(columns, isNot(contains('custom_tag')));
    expect(jsonEncode(stored), isNot(contains('CheckoutTest.run')));
  });

  test('passed result fields and suite totals agree across formats', () async {
    final result = EnsembleTestRunResult(
      results: [
        EnsembleSingleTestResult.passed(
          testId: 'profile-settings',
          durationMs: 37,
          attempts: 2,
          retry: 1,
        ),
        EnsembleSingleTestResult.failed(
          testId: 'checkout-failure',
          durationMs: 13,
          message: 'payment declined',
        ),
      ],
    );

    final machine = result.toJson();
    final machinePassed = (machine['results'] as List).first as Map;
    final console = TestReporter().formatSummary(result);
    final junit = JunitTestReport.build(result);
    final html = TestReportDocument.buildComplete(
      result,
      artifactRoot: tempDir.path,
      displayRoot: 'build/report',
    );
    final htmlSummary = html['summary'] as Map;
    final htmlPassed = (html['tests'] as List).first as Map;

    expect(machinePassed['status'], 'passed');
    expect(machinePassed['durationMs'], 37);
    expect(machinePassed['attempts'], 2);
    expect(machinePassed['retry'], 1);
    expect(machine['total'], 2);
    expect(machine['passed'], 1);
    expect(machine['failed'], 1);
    expect(machine['status'], 'failed');

    expect(htmlPassed['status'], machinePassed['status']);
    expect(htmlPassed['durationMs'], machinePassed['durationMs']);
    expect(htmlPassed['attempts'], machinePassed['attempts']);
    expect(htmlPassed['retry'], machinePassed['retry']);
    expect(htmlSummary['total'], machine['total']);
    expect(htmlSummary['passed'], machine['passed']);
    expect(htmlSummary['failed'], machine['failed']);
    expect(htmlSummary['status'], machine['status']);

    expect(junit,
        contains('<testsuite name="ensemble_tests" tests="2" failures="1"'));
    expect(junit, contains('<testcase name="profile-settings" time="0.037">'));
    expect(junit, contains('name="ensemble.attempts" value="2"'));
    expect(junit, contains('name="ensemble.retries" value="1"'));

    expect(console, contains('profile-settings (37ms)'));
    expect(console, contains('attempts: 2/2'));
    expect(console, contains('1 passed, 1 failed (2 total) · 50ms total'));

    await EnsembleTestHistoryStore.recordCompletedRun(
      appDir: tempDir.path,
      artifactRoot: tempDir.path,
      wallTimeMs: 50,
      result: result,
    );
    final db = await databaseFactoryFfi.openDatabase(
      p.join(tempDir.path, 'report', EnsembleTestHistoryStore.fileName),
    );
    addTearDown(db.close);
    final historyRun =
        (await db.query('test_results', where: "record_type = 'run'")).single;
    final historySummary = jsonDecode(historyRun['summary_data'] as String);
    expect(historyRun['status'], machine['status']);
    expect(historySummary['total_tests'], machine['total']);
    expect(historySummary['passed_tests'], machine['passed']);
    expect(historySummary['failed_tests'], machine['failed']);
    final historyPassed = (await db.rawQuery('''
SELECT r.* FROM test_results r
JOIN test_catalog c ON c.id = r.test_ref
WHERE r.record_type = 'test' AND c.test_id = ?
''', ['profile-settings'])).single;
    expect(historyPassed['status'], 'passed');
    expect(historyPassed['duration_ms'], 37);
    expect(historyPassed['attempts'], 2);
  });
}
