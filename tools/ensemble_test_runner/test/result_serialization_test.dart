import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('structured result fields round trip without requiring them', () {
    final original = EnsembleSingleTestResult.failed(
      testId: 'login',
      durationMs: 12,
      failedStepIndex: 0,
      failedStep: const TestStep(type: 'tap', args: {'id': 'continue'}),
      error: 'missing',
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
}
