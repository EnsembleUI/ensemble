// Dart 3.8 reports deprecated_member_use at RegExp construction sites even though
// the deprecation is specifically about implementing RegExp. Keep construction compatible
// with this SDK without suppressing diagnostics in unrelated files.
// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/reporters/junit_test_report.dart';
import 'package:ensemble_test_runner/reporters/result_projection.dart';
import 'package:ensemble_test_runner/reporters/test_report_document.dart';
import 'package:ensemble_test_runner/reporters/test_reporter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all reporter projections share legacy failure fallback policy', () {
    final failed = EnsembleSingleTestResult.failed(
      testId: 'missing-submit',
      durationMs: 17,
      message: 'submit was not found',
    );
    final result = EnsembleTestRunResult(results: [failed]);
    final projection = TestResultProjection(failed);

    expect(projection.status, 'failed');
    expect(projection.failureMessage, 'submit was not found');
    expect(projection.failureKind, 'elementNotFound');
    expect(projection.failureStackTrace, 'submit was not found');
    expect(failed.toJson()['failure'], isA<Map>());
    expect(
      TestReporter().formatSummary(result),
      allOf(contains('error: submit was not found'),
          contains('kind: elementNotFound')),
    );
    expect(
      JunitTestReport.build(result),
      contains('name="ensemble.failure.kind" value="elementNotFound"'),
    );

    final temp = Directory.systemTemp.createTempSync('runner-projection-');
    try {
      final html = TestReportDocument.buildComplete(
        EnsembleTestRunResult(
          results: [
            EnsembleSingleTestResult.failed(
              testId: 'empty-stack',
              durationMs: 1,
              message: 'missing target',
              stackTrace: '  ',
            ),
          ],
        ),
        artifactRoot: temp.path,
        displayRoot: 'build/report',
      );
      expect((html['tests'] as List).single['stackTrace'], 'missing target');
    } finally {
      temp.deleteSync(recursive: true);
    }
  });

  test('suite projection snapshots one stable execution order', () {
    final results = <EnsembleSingleTestResult>[
      EnsembleSingleTestResult.passed(testId: 'first', durationMs: 7),
    ];
    final projection = SuiteResultProjection(
      EnsembleTestRunResult(results: results),
    );

    results
      ..add(EnsembleSingleTestResult.failed(
        testId: 'mutated-later',
        durationMs: 99,
        message: 'late mutation',
      ));

    expect(projection.total, 1);
    expect(projection.passed, 1);
    expect(projection.failed, 0);
    expect(projection.totalDurationMs, 7);
    expect(projection.summary, '1 passed, 0 failed (1 total)');
    expect(projection.orderedResults.single.testId, 'first');
  });

  test('suite projection keeps aggregate totals and duration consistent', () {
    final result = EnsembleTestRunResult(
      results: [
        EnsembleSingleTestResult.passed(testId: 'pass', durationMs: 11),
        EnsembleSingleTestResult.failed(
          testId: 'fail',
          durationMs: 29,
          message: 'failed',
        ),
      ],
    );
    final projection = SuiteResultProjection(result);

    expect(projection.total, 2);
    expect(projection.passed, 1);
    expect(projection.failed, 1);
    expect(projection.totalDurationMs, 40);
    expect(projection.status, 'failed');
  });

  test('all report projections preserve machine result ordering', () {
    final result = EnsembleTestRunResult(
      results: [
        EnsembleSingleTestResult.passed(
          testId: 'pass-first',
          durationMs: 11,
        ),
        EnsembleSingleTestResult.failed(
          testId: 'fail-second',
          durationMs: 29,
          message: 'failed',
        ),
      ],
    );
    final expected = ['pass-first', 'fail-second'];
    final suite = SuiteResultProjection(result);
    expect(suite.orderedResults.map((test) => test.testId), expected);

    final jsonIds = (result.toJson()['results'] as List)
        .map((entry) => (entry as Map)['testId'].toString())
        .toList();
    expect(jsonIds, expected);

    final temp = Directory.systemTemp.createTempSync('runner-projection-');
    try {
      final html = TestReportDocument.buildComplete(
        result,
        artifactRoot: temp.path,
        displayRoot: 'build/report',
      );
      final htmlIds = (html['tests'] as List)
          .map((entry) => (entry as Map)['id'].toString())
          .toList();
      expect(htmlIds, expected);
    } finally {
      temp.deleteSync(recursive: true);
    }

    final junitIds = RegExp(r'<testcase name="([^"]+)"')
        .allMatches(JunitTestReport.build(result))
        .map((match) => match.group(1))
        .toList();
    expect(junitIds, expected);

    final console = TestReporter().formatSummary(result);
    final consoleIds = RegExp(r'│  [✓✗] ([^ ]+) \(')
        .allMatches(console)
        .map((match) => match.group(1))
        .toList();
    expect(consoleIds, expected);
  });

  test('console, machine JSON, JUnit, and HTML share completed result fields',
      () {
    final result = EnsembleTestRunResult(results: [
      EnsembleSingleTestResult.passed(testId: 'first', durationMs: 11),
      EnsembleSingleTestResult.failed(
        testId: 'second',
        durationMs: 29,
        attempts: 2,
        retry: 1,
        failedStepIndex: 2,
        failureOperation: 'tap',
        message: 'submit was not found',
        stackTrace: '  ',
      ),
    ]);
    final machine = result.toJson();
    final machineFailure = (machine['results'] as List).last as Map;
    final console = TestReporter().formatSummary(result);
    final junit = JunitTestReport.build(result);

    final temp = Directory.systemTemp.createTempSync('runner-projection-');
    addTearDown(() => temp.deleteSync(recursive: true));
    final html = TestReportDocument.buildComplete(
      result,
      artifactRoot: temp.path,
      displayRoot: 'build/report',
    );
    final htmlSummary = html['summary'] as Map;
    final htmlFailure = (html['tests'] as List).last as Map;

    expect(machine, containsPair('status', 'failed'));
    expect(machine, containsPair('total', 2));
    expect(machine, containsPair('passed', 1));
    expect(machine, containsPair('failed', 1));
    expect(htmlSummary, containsPair('status', machine['status']));
    expect(htmlSummary, containsPair('total', machine['total']));
    expect(htmlSummary, containsPair('passed', machine['passed']));
    expect(htmlSummary, containsPair('failed', machine['failed']));
    expect(htmlSummary, containsPair('totalMs', 40));
    expect(console, contains('1 passed, 1 failed (2 total) · 40ms total'));
    expect(junit, contains('tests="2" failures="1" time="0.040"'));

    for (final key in const [
      'status',
      'durationMs',
      'attempts',
      'retry',
      'failedStepIndex',
      'failureOperation',
      'message',
      'stackTrace',
      'failure',
    ]) {
      expect(htmlFailure[key], machineFailure[key], reason: key);
    }
    expect(console, contains('✗ second (29ms)'));
    expect(console, contains('attempts: 2/2'));
    expect(console, contains('operation: tap'));
    expect(console, contains('kind: elementNotFound'));
    expect(console, contains('at step: 3'));
    expect(junit, contains('<testcase name="second" time="0.029">'));
    expect(junit, contains('name="ensemble.attempts" value="2"'));
    expect(junit, contains('name="ensemble.retries" value="1"'));
    expect(junit, contains('name="ensemble.failed_step_index" value="2"'));
    expect(junit, contains('name="ensemble.failure.operation" value="tap"'));
    expect(junit,
        contains('name="ensemble.failure.kind" value="elementNotFound"'));
    expect(junit, contains('<failure message="submit was not found">'));
  });

  test('compact and boxed reporters share one test entry formatter', () {
    final failed = EnsembleSingleTestResult.failed(
      testId: 'compact-failure',
      durationMs: 23,
      attempts: 2,
      retry: 1,
      message: 'submit was not found',
    );

    final compact = StringBuffer();
    TestReporter.writeTestCase(
      compact,
      failed,
      includeFailureKind: false,
    );
    final boxed = StringBuffer();
    TestReporter.writeTestCase(boxed, failed);

    expect(compact.toString(), contains('attempts: 2/2'));
    expect(compact.toString(), contains('error: submit was not found'));
    expect(compact.toString(), isNot(contains('kind:')));
    expect(boxed.toString(), contains('kind: elementNotFound'));
    expect(boxed.toString(), contains('error: submit was not found'));
  });
}
