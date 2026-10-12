import 'package:ensemble/ensemble.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/test_artifacts.dart';
import 'package:ensemble_test_runner/src/core/attempt_coordinator.dart';

/// The value returned by one complete test execution, including its runtime
/// context.  Keeping this record next to retry aggregation makes the retry
/// boundary independent from the runner's orchestration implementation.
typedef EnsembleTestRunOutput = ({
  EnsembleSingleTestResult result,
  EnsembleConfig config,
  EnsembleTestContext context,
});

/// Executes attempts and applies the aggregate retry metadata to the final
/// result.  The callback owns setup, cleanup, and attempt execution; this
/// class only owns retry policy and result assembly.
final class RetryExecutionCoordinator {
  const RetryExecutionCoordinator({required this.retries});

  final int retries;

  /// Shared attempt loop for adapters whose final value is not a complete
  /// [EnsembleTestRunOutput], such as application-host executions.
  static Future<AttemptSequence<T>> collect<T>({
    required int retries,
    required Future<T> Function(AttemptDescriptor attempt) executeAttempt,
    required bool Function(T outcome) succeeded,
    required int Function(T outcome) durationMs,
    required List<String> Function(T outcome) logs,
  }) {
    return AttemptCoordinator<T>(retries: retries).run(
      executeAttempt: executeAttempt,
      succeeded: succeeded,
      durationMs: durationMs,
      logs: logs,
    );
  }

  /// Runs a result-producing attempt loop and applies shared aggregate
  /// metadata, keeping hosted and standalone retry behavior identical.
  static Future<EnsembleSingleTestResult> runResult({
    required int retries,
    required Future<EnsembleSingleTestResult> Function(
      AttemptDescriptor attempt,
    ) executeAttempt,
  }) async {
    final sequence = await collect<EnsembleSingleTestResult>(
      retries: retries,
      executeAttempt: executeAttempt,
      succeeded: (outcome) => outcome.status == TestStatus.passed,
      durationMs: (outcome) => outcome.durationMs,
      logs: (outcome) => outcome.logs,
    );
    final last = sequence.outcome;
    return applySequence(last, sequence);
  }

  Future<EnsembleTestRunOutput> run({
    required Future<EnsembleTestRunOutput> Function(AttemptDescriptor attempt)
        executeAttempt,
  }) async {
    final sequence = await collect<EnsembleTestRunOutput>(
      retries: retries,
      executeAttempt: executeAttempt,
      succeeded: (out) => out.result.status == TestStatus.passed,
      durationMs: (out) => out.result.durationMs,
      logs: (out) => out.result.logs,
    );
    final out = sequence.outcome;
    return (
      result: applySequence(out.result, sequence),
      config: out.config,
      context: out.context,
    );
  }

  /// Applies the sequence's aggregate fields identically to every adapter.
  /// The last result remains the source of all case-specific report details.
  static EnsembleSingleTestResult applySequence(
    EnsembleSingleTestResult result,
    AttemptSequence<Object?> sequence,
  ) {
    return withRetryMetadata(
      result,
      attempts: sequence.attempts,
      retry: sequence.retry,
      durationMs: sequence.durationMs,
      logs: combineAttemptDiagnosticLogs(result.logs, sequence.logsByAttempt),
    );
  }

  /// Rebuilds a result with attempt-level aggregate fields while preserving
  /// all execution and reporting details from the final attempt.
  static EnsembleSingleTestResult withRetryMetadata(
    EnsembleSingleTestResult result, {
    required int attempts,
    required int retry,
    required int durationMs,
    List<String>? logs,
  }) {
    return EnsembleSingleTestResult(
      testId: result.testId,
      metadata: result.metadata,
      status: result.status,
      durationMs: durationMs,
      attempts: attempts,
      retry: retry,
      failedStepIndex: result.failedStepIndex,
      failedStep: result.failedStep,
      message: result.message,
      stackTrace: result.stackTrace,
      failureOperation: result.failureOperation,
      failureSource: result.failureSource,
      logs: logs ?? result.logs,
      report: result.report,
      failure: result.failure,
      secondaryFailures: result.secondaryFailures,
      capabilityStatus: result.capabilityStatus,
    );
  }

  /// Adds a failure from attempt teardown without replacing a failure already
  /// reported by the test body. Standalone execution returns failed test
  /// results as values, while hosted execution throws them through the attempt
  /// boundary; this keeps teardown reporting consistent across both paths.
  static EnsembleSingleTestResult withAttemptCleanupFailure(
    EnsembleSingleTestResult result, {
    required Object error,
    required StackTrace stackTrace,
    String phase = 'attemptCleanup',
  }) {
    final cleanupFailure = attemptCleanupFailureDetails([
      (error: error, stackTrace: stackTrace),
    ], phase: phase)
        .single;
    if (result.status == TestStatus.failed) {
      return EnsembleSingleTestResult(
        testId: result.testId,
        metadata: result.metadata,
        status: result.status,
        durationMs: result.durationMs,
        attempts: result.attempts,
        retry: result.retry,
        failedStepIndex: result.failedStepIndex,
        failedStep: result.failedStep,
        message: _appendCleanupFailure(result.message, error),
        stackTrace: result.stackTrace,
        failureOperation: result.failureOperation,
        failureSource: result.failureSource,
        logs: result.logs,
        report: result.report,
        failure: result.failure,
        secondaryFailures: [...result.secondaryFailures, cleanupFailure],
        capabilityStatus: result.capabilityStatus,
      );
    }
    return EnsembleSingleTestResult(
      testId: result.testId,
      metadata: result.metadata,
      status: TestStatus.failed,
      durationMs: result.durationMs,
      attempts: result.attempts,
      retry: result.retry,
      failedStepIndex: result.failedStepIndex,
      failedStep: result.failedStep,
      message: 'Cleanup failed: $error',
      stackTrace: stackTrace.toString(),
      failureOperation: result.failureOperation,
      failureSource: result.failureSource,
      logs: result.logs,
      report: result.report,
      failure: cleanupFailure,
      secondaryFailures: result.secondaryFailures,
      capabilityStatus: result.capabilityStatus,
    );
  }

  /// Projects all attempt teardown failures through the same precedence rule.
  /// The first teardown failure becomes primary only after a passing body;
  /// every teardown failure remains secondary when the body already failed.
  static EnsembleSingleTestResult withAttemptCleanupFailures(
    EnsembleSingleTestResult result, {
    required Iterable<({Object error, StackTrace stackTrace})> failures,
    String phase = 'attemptCleanup',
    Object? excludeError,
  }) {
    var projected = result;
    for (final failure in failures) {
      if (excludeError != null && identical(failure.error, excludeError)) {
        continue;
      }
      projected = withAttemptCleanupFailure(
        projected,
        error: failure.error,
        stackTrace: failure.stackTrace,
        phase: phase,
      );
    }
    return projected;
  }

  static String _appendCleanupFailure(String? message, Object error) {
    final cleanupMessage = 'Cleanup failed: $error';
    if (message == null || message.isEmpty) return cleanupMessage;
    return '$message\n$cleanupMessage';
  }

  /// Converts teardown failures into report details for either adapter.
  ///
  /// [excludeError] is used when the selected primary failure is already
  /// represented by the result's top-level failure field. Identity matching
  /// preserves separate failures that happen to have the same message.
  static List<TestFailureDetails> attemptCleanupFailureDetails(
    Iterable<({Object error, StackTrace stackTrace})> failures, {
    Object? excludeError,
    String phase = 'attemptCleanup',
  }) =>
      [
        for (final failure in failures)
          if (excludeError == null || !identical(failure.error, excludeError))
            TestFailureDetails(
              kind: TestFailureKind.cleanup,
              message: failure.error.toString(),
              phase: phase,
            ),
      ];
}
