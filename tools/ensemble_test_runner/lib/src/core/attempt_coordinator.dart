import 'package:ensemble_test_runner/src/core/retry_scheduler.dart';

/// Identifies one execution attempt without making adapters translate between
/// one-based report numbers and zero-based driver indexes.
final class AttemptDescriptor {
  const AttemptDescriptor({
    required this.number,
    required this.index,
    required this.total,
  });

  /// One-based number used in reports and user-facing diagnostics.
  final int number;

  /// Zero-based index used by application drivers and artifact names.
  final int index;

  /// Total number of attempts allowed for this test.
  final int total;
}

/// Runs attempts and collects the values that both suite adapters report.
///
/// Attempt execution and cleanup remain owned by [executeAttempt]. This
/// coordinator only owns retry order and aggregate metadata.
final class AttemptCoordinator<T> {
  AttemptCoordinator({required int retries})
      : _scheduler = RetryScheduler(retries: retries),
        retries = retries;

  final RetryScheduler _scheduler;
  final int retries;

  Future<AttemptSequence<T>> run({
    required Future<T> Function(AttemptDescriptor attempt) executeAttempt,
    required bool Function(T outcome) succeeded,
    required int Function(T outcome) durationMs,
    required List<String> Function(T outcome) logs,
  }) async {
    var totalDurationMs = 0;
    final logsByAttempt = <List<String>>[];
    T? lastOutcome;
    var attempts = 0;
    final maxAttempts = _scheduler.maxAttempts;

    // Keep the hot retry loop allocation-free. The public scheduler iterator
    // is useful to callers that need attempt numbers, but creating its sync*
    // iterator here adds a generator and iterator object to every test run.
    for (var attemptNumber = 1; attemptNumber <= maxAttempts; attemptNumber++) {
      final attempt = AttemptDescriptor(
        number: attemptNumber,
        index: attemptNumber - 1,
        total: maxAttempts,
      );
      final outcome = await executeAttempt(attempt);
      attempts = attempt.number;
      lastOutcome = outcome;
      totalDurationMs += durationMs(outcome);
      logsByAttempt.add(logs(outcome));
      final attemptSucceeded = succeeded(outcome);
      if (_scheduler.shouldRetry(
        attemptNumber: attemptNumber,
        succeeded: attemptSucceeded,
      )) {
        continue;
      }
      break;
    }

    return AttemptSequence<T>(
      outcome: lastOutcome as T,
      attempts: attempts,
      retry: retries,
      durationMs: totalDurationMs,
      logsByAttempt: List.unmodifiable(logsByAttempt),
    );
  }
}

/// Shared retry aggregate; caller-specific reporting maps this to its result.
final class AttemptSequence<T> {
  const AttemptSequence({
    required this.outcome,
    required this.attempts,
    required this.retry,
    required this.durationMs,
    required this.logsByAttempt,
  });

  final T outcome;
  final int attempts;
  final int retry;
  final int durationMs;
  final List<List<String>> logsByAttempt;
}
