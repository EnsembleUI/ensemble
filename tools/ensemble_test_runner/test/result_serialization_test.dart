import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/src/core/operation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('failure details read only the canonical message field', () {
    final canonical = TestFailureDetails.fromJson({
      'kind': 'assertion',
      'message': 'submit was rejected',
    });
    final oldShape = TestFailureDetails.fromJson({
      'kind': 'assertion',
      'actual': 'old failure text',
    });

    expect(canonical.message, 'submit was rejected');
    expect(oldShape.message, 'Test failed');
    expect(
      const TestFailureDetails(
        kind: TestFailureKind.assertion,
        message: 'submit was rejected',
      ).toJson(),
      containsPair('message', 'submit was rejected'),
    );
  });

  test('structured result fields round trip without requiring them', () {
    final original = EnsembleSingleTestResult.failed(
      testId: 'login',
      durationMs: 12,
      failedStepIndex: 0,
      failedStep: const TestStep(type: 'tap', args: {'id': 'continue'}),
      message: 'missing',
      failureOperation: 'tap',
      failureSource: const SourceLocation('tests/login.test.yaml', 'steps[0]'),
      failure: const TestFailureDetails(
        kind: TestFailureKind.elementNotFound,
        message: 'missing',
        target: {'id': 'continue'},
      ),
      secondaryFailures: const [
        TestFailureDetails(
          kind: TestFailureKind.cleanup,
          message: 'restore failed',
          phase: 'cleanup',
        ),
      ],
      capabilityStatus: const {'navigation': false},
      report: const EnsembleTestReportDetails(navigationKnown: false),
    );

    final decoded = EnsembleSingleTestResult.fromJson(original.toJson());
    expect(decoded.failure?.kind, TestFailureKind.elementNotFound);
    expect(decoded.failure?.target, {'id': 'continue'});
    expect(decoded.secondaryFailures.single.kind, TestFailureKind.cleanup);
    expect(decoded.capabilityStatus, {'navigation': false});
    expect(decoded.failedStep?.type, 'tap');
    expect(decoded.failureOperation, 'tap');
    expect(decoded.failureSource?.path, 'tests/login.test.yaml');
    expect(decoded.failureSource?.stepPath, 'steps[0]');
    expect(
      (decoded.toJson()['failure'] as Map)['operation'],
      'tap',
    );
    expect(decoded.report?.navigationKnown, isFalse);
    expect(decoded.report?.toJson(), isNot(contains('startScreen')));

    final legacy = EnsembleSingleTestResult.fromJson({
      'testId': 'legacy',
      'status': 'passed',
      'durationMs': 1,
      'logs': <String>[],
    });
    expect(legacy.status, TestStatus.passed);
    expect(legacy.failure, isNull);
  });

  test('legacy message and structured projections share failure fallbacks', () {
    final legacy = EnsembleSingleTestResult.failed(
      testId: 'legacy-failure',
      durationMs: 1,
      message: 'missing submit button',
    );

    expect(legacy.effectiveFailureMessage, 'missing submit button');
    expect(
        legacy.effectiveFailureDetails?.kind, TestFailureKind.elementNotFound);
    expect(legacy.toJson()['failure'], containsPair('kind', 'elementNotFound'));

    final blank = EnsembleSingleTestResult(
      testId: 'blank-failure',
      status: TestStatus.failed,
      durationMs: 1,
      message: '   ',
      failure: const TestFailureDetails(
        kind: TestFailureKind.cleanup,
        message: '',
      ),
    );
    expect(blank.effectiveFailureMessage, 'failed');
    expect(blank.effectiveFailureDetails?.kind, TestFailureKind.cleanup);
    expect(blank.effectiveFailureDetails?.message, 'failed');
    expect(
      (blank.toJson()['failure'] as Map)['message'],
      'failed',
    );
    expect(blank.toJson()['message'], 'failed');

    final decodedBlank = EnsembleSingleTestResult.fromJson(blank.toJson());
    expect(decodedBlank.message, 'failed');
    expect(decodedBlank.effectiveFailureMessage, 'failed');
  });

  test('ignores non-canonical error field when message is absent', () {
    final decoded = EnsembleSingleTestResult.fromJson({
      'testId': 'legacy-error-field',
      'status': 'failed',
      'durationMs': 4,
      'error': 'legacy failure',
      'logs': <String>[],
    });

    expect(decoded.message, isNull);
    expect(decoded.effectiveFailureMessage, 'failed');
    expect(decoded.toJson(), containsPair('message', 'failed'));
    expect(decoded.toJson(), isNot(contains('error')));
  });

  test('machine JSON publishes the same fallback stack as other reports', () {
    final result = EnsembleSingleTestResult.failed(
      testId: 'missing-target',
      durationMs: 1,
      message: 'submit was not found',
    );

    expect(result.effectiveFailureStackTrace, 'submit was not found');
    expect(result.toJson()['stackTrace'], 'submit was not found');
  });

  test('machine JSON derives aggregate counts with serialized case order', () {
    final result = EnsembleTestRunResult(
      results: [
        EnsembleSingleTestResult.passed(testId: 'first', durationMs: 1),
        EnsembleSingleTestResult.failed(
          testId: 'second',
          durationMs: 2,
          message: 'failed',
        ),
      ],
    );

    final json = result.toJson();
    expect(json, containsPair('total', 2));
    expect(json, containsPair('passed', 1));
    expect(json, containsPair('failed', 1));
    expect(
      (json['results'] as List)
          .map((entry) => (entry as Map)['testId'])
          .toList(),
      ['first', 'second'],
    );
  });
}
