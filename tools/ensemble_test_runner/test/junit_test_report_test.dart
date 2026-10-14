import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/reporters/junit_test_report.dart';
import 'package:ensemble_test_runner/reporters/test_reporter.dart';
import 'package:ensemble_test_runner/src/core/operation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('projects suite totals and failing details into escaped JUnit XML', () {
    final report = JunitTestReport.build(
      EnsembleTestRunResult(
        results: [
          EnsembleSingleTestResult.passed(
            testId: 'happy & <safe>',
            durationMs: 1250,
          ),
          EnsembleSingleTestResult.failed(
            testId: 'bad "case"',
            durationMs: 250,
            message: "expected <ready> & wasn't",
            stackTrace: 'line <one> & line two',
          ),
        ],
      ),
    );

    expect(
      report,
      startsWith(
        '<testsuite name="ensemble_tests" tests="2" '
        'failures="1" time="1.500">',
      ),
    );
    expect(report, contains('name="happy &amp; &lt;safe&gt;" time="1.250"'));
    expect(report, contains('name="bad &quot;case&quot;" time="0.250"'));
    expect(
      report,
      contains('message="expected &lt;ready&gt; &amp; wasn&apos;t"'),
    );
    expect(report, contains('line &lt;one&gt; &amp; line two'));
    expect(report, endsWith('</testsuite>\n'));
  });

  test('uses the failure message when no stack trace is available', () {
    final report = JunitTestReport.build(
      EnsembleTestRunResult(
        results: [
          EnsembleSingleTestResult.failed(
            testId: 'failed',
            durationMs: 1,
            message: 'missing target',
          ),
        ],
      ),
    );

    expect(report, contains('<failure message="missing target">'));
    expect(report, contains('missing target\n    </failure>'));
  });

  test('uses the failure message when a legacy stack trace is empty', () {
    final result = EnsembleTestRunResult(
      results: [
        EnsembleSingleTestResult.failed(
          testId: 'empty-stack',
          durationMs: 1,
          message: 'missing target',
          stackTrace: '  ',
        ),
      ],
    );

    final report = JunitTestReport.build(result);
    expect(report, contains('message="missing target">\nmissing target\n'));
  });

  test(
      'uses structured failure text consistently when legacy message is absent',
      () {
    final failed = EnsembleSingleTestResult(
      testId: 'structured-only',
      status: TestStatus.failed,
      durationMs: 1,
      failure: const TestFailureDetails(
        kind: TestFailureKind.elementNotFound,
        message: 'submit was not found',
      ),
    );
    final result = EnsembleTestRunResult(results: [failed]);

    expect(failed.effectiveFailureMessage, 'submit was not found');
    expect(
      JunitTestReport.build(result),
      contains('message="submit was not found"'),
    );
    expect(
      TestReporter().formatFailureSummary(result),
      contains('- structured-only: submit was not found'),
    );
  });

  test('preserves retry metadata alongside console and JSON results', () {
    final retried = EnsembleSingleTestResult.passed(
      testId: 'retried-case',
      durationMs: 42,
      attempts: 2,
      retry: 1,
    );
    final result = EnsembleTestRunResult(results: [retried]);
    final junit = JunitTestReport.build(result);

    expect(junit, contains('<property name="ensemble.attempts" value="2"/>'));
    expect(junit, contains('<property name="ensemble.retries" value="1"/>'));
    expect(retried.toJson()['attempts'], 2);
    expect(retried.toJson()['retry'], 1);
    expect(TestReporter().formatSummary(result), contains('attempts: 2/2'));
  });

  test('preserves failure location metadata in JUnit properties', () {
    final report = JunitTestReport.build(
      EnsembleTestRunResult(
        results: [
          EnsembleSingleTestResult.failed(
            testId: 'submit',
            durationMs: 8,
            failedStepIndex: 2,
            failureOperation: 'tap',
            failureSource: const SourceLocation(
              'tests/submit.test.yaml',
              'steps[2]',
            ),
            message: 'missing submit',
          ),
        ],
      ),
    );

    expect(
      report,
      contains(
        '<property name="ensemble.failed_step_index" value="2"/>',
      ),
    );
    expect(
      report,
      contains(
        '<property name="ensemble.failure.operation" value="tap"/>',
      ),
    );
    expect(
      report,
      contains(
        '<property name="ensemble.failure.source.path" '
        'value="tests/submit.test.yaml"/>',
      ),
    );
    expect(
      report,
      contains(
        '<property name="ensemble.failure.source.step_path" '
        'value="steps[2]"/>',
      ),
    );
  });

  test('removes XML 1.0 forbidden control characters from report values', () {
    final report = JunitTestReport.build(
      EnsembleTestRunResult(
        results: [
          EnsembleSingleTestResult.failed(
            testId: 'bad\u0000case',
            durationMs: 1,
            message: 'bad\u0001value',
            stackTrace: 'line\u0002\nnext',
          ),
        ],
      ),
    );

    expect(report, contains('name="badcase"'));
    expect(report, contains('message="badvalue"'));
    expect(report, contains('line\nnext'));
    expect(report, isNot(contains('\u0000')));
    expect(report, isNot(contains('\u0001')));
    expect(report, isNot(contains('\u0002')));
  });
}
