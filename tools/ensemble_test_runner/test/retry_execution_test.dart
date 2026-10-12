import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/retry_execution.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preserves final attempt details while applying retry metadata', () {
    const failure = TestFailureDetails(
      kind: TestFailureKind.assertion,
      message: 'expected value',
    );
    final result = EnsembleSingleTestResult.failed(
      testId: 'retry',
      durationMs: 8,
      logs: const ['final attempt'],
      message: 'expected value',
      failure: failure,
      capabilityStatus: const {'assertions': true},
    );

    final updated = RetryExecutionCoordinator.withRetryMetadata(
      result,
      attempts: 2,
      retry: 1,
      durationMs: 20,
      logs: const ['all attempts'],
    );

    expect(updated.durationMs, 20);
    expect(updated.attempts, 2);
    expect(updated.retry, 1);
    expect(updated.logs, ['all attempts']);
    expect(updated.failure, same(failure));
    expect(updated.capabilityStatus, {'assertions': true});
  });

  test('collects adapter-specific attempts through the shared retry loop',
      () async {
    var executions = 0;
    final sequence = await RetryExecutionCoordinator.collect<int>(
      retries: 1,
      executeAttempt: (_) async => ++executions,
      succeeded: (value) => value == 2,
      durationMs: (_) => 3,
      logs: (value) => ['attempt $value'],
    );

    expect(sequence.outcome, 2);
    expect(sequence.attempts, 2);
    expect(sequence.durationMs, 6);
    expect(executions, 2);
  });

  test('assembles result attempts through the shared adapter boundary',
      () async {
    var executions = 0;
    final result = await RetryExecutionCoordinator.runResult(
      retries: 1,
      executeAttempt: (_) async {
        executions++;
        return executions == 1
            ? EnsembleSingleTestResult.failed(
                testId: 'hosted',
                durationMs: 2,
                logs: const ['appLogs: first'],
                message: 'transient',
              )
            : EnsembleSingleTestResult.passed(
                testId: 'hosted',
                durationMs: 3,
                logs: const ['appLogs: second'],
              );
      },
    );

    expect(result.status, TestStatus.passed);
    expect(result.attempts, 2);
    expect(result.retry, 1);
    expect(result.durationMs, 5);
    expect(
      result.logs,
      containsAll(<String>['appLogs: first', 'appLogs: second']),
    );
  });

  test('attempt cleanup preserves a failed step as primary', () {
    final failure = TestFailureDetails(
      kind: TestFailureKind.elementNotFound,
      message: 'target missing',
      phase: 'execution',
    );
    final original = EnsembleSingleTestResult.failed(
      testId: 'cleanup',
      durationMs: 12,
      failedStepIndex: 2,
      message: 'target missing',
      failure: failure,
      logs: const ['attempt evidence'],
    );

    final projected = RetryExecutionCoordinator.withAttemptCleanupFailure(
      original,
      error: StateError('navigation recorder cleanup'),
      stackTrace: StackTrace.current,
    );

    expect(projected.failure, same(failure));
    expect(projected.failedStepIndex, 2);
    expect(projected.secondaryFailures, hasLength(1));
    expect(projected.secondaryFailures.single.kind, TestFailureKind.cleanup);
    expect(projected.logs, ['attempt evidence']);
  });

  test('attempt cleanup fails a passing result with structured details', () {
    final original = EnsembleSingleTestResult.passed(
      testId: 'cleanup',
      durationMs: 12,
      logs: const ['attempt evidence'],
    );

    final projected = RetryExecutionCoordinator.withAttemptCleanupFailure(
      original,
      error: StateError('navigation recorder cleanup'),
      stackTrace: StackTrace.current,
    );

    expect(projected.status, TestStatus.failed);
    expect(projected.failure?.kind, TestFailureKind.cleanup);
    expect(projected.failure?.phase, 'attemptCleanup');
    expect(projected.message, contains('navigation recorder cleanup'));
    expect(projected.logs, ['attempt evidence']);
  });

  test('projects all teardown failures consistently after a passed attempt',
      () {
    final original = EnsembleSingleTestResult.passed(
      testId: 'cleanup',
      durationMs: 12,
    );

    final projected = RetryExecutionCoordinator.withAttemptCleanupFailures(
      original,
      failures: [
        (error: StateError('first cleanup'), stackTrace: StackTrace.current),
        (
          error: FormatException('second cleanup'),
          stackTrace: StackTrace.current
        ),
      ],
    );

    expect(projected.status, TestStatus.failed);
    expect(projected.failure?.message, contains('first cleanup'));
    expect(projected.secondaryFailures, hasLength(1));
    expect(
      projected.secondaryFailures.single.message,
      contains('second cleanup'),
    );
  });

  test('projects all teardown failures behind an existing test failure', () {
    final original = EnsembleSingleTestResult.failed(
      testId: 'cleanup',
      durationMs: 12,
      message: 'step failed',
      failure: const TestFailureDetails(
        kind: TestFailureKind.assertion,
        message: 'step failed',
      ),
    );

    final projected = RetryExecutionCoordinator.withAttemptCleanupFailures(
      original,
      failures: [
        (error: StateError('first cleanup'), stackTrace: StackTrace.current),
        (
          error: FormatException('second cleanup'),
          stackTrace: StackTrace.current
        ),
      ],
    );

    expect(projected.failure?.message, 'step failed');
    expect(projected.secondaryFailures, hasLength(2));
    expect(projected.secondaryFailures.map((failure) => failure.message), [
      'Bad state: first cleanup',
      'FormatException: second cleanup',
    ]);
  });

  test('cleanup detail projection excludes only the selected primary error',
      () {
    final selectedPrimary = StateError('selected');
    final sameMessage = StateError('selected');
    final projected = RetryExecutionCoordinator.attemptCleanupFailureDetails(
      [
        (error: selectedPrimary, stackTrace: StackTrace.current),
        (error: sameMessage, stackTrace: StackTrace.current),
        (
          error: FormatException('later'),
          stackTrace: StackTrace.current,
        ),
      ],
      excludeError: selectedPrimary,
      phase: 'cleanup',
    );

    expect(projected, hasLength(2));
    expect(projected.map((failure) => failure.message), [
      'Bad state: selected',
      'FormatException: later',
    ]);
    expect(projected.map((failure) => failure.phase), ['cleanup', 'cleanup']);
  });
}
