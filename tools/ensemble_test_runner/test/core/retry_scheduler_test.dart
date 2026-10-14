import 'package:ensemble_test_runner/src/core/retry_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stops after a first-attempt pass and keeps one-based numbering', () {
    final scheduler = RetryScheduler(retries: 3);
    final attempts = <int>[];

    for (final attempt in scheduler.attemptNumbers) {
      attempts.add(attempt);
      if (!scheduler.shouldRetry(
        attemptNumber: attempt,
        succeeded: true,
      )) {
        break;
      }
    }

    expect(attempts, [1]);
    expect(scheduler.maxAttempts, 4);
  });

  test('continues after failure and stops when a later attempt passes', () {
    final scheduler = RetryScheduler(retries: 2);
    final outcomes = [false, true, false];
    final attempts = <int>[];

    for (final attempt in scheduler.attemptNumbers) {
      attempts.add(attempt);
      if (!scheduler.shouldRetry(
        attemptNumber: attempt,
        succeeded: outcomes[attempt - 1],
      )) {
        break;
      }
    }

    expect(attempts, [1, 2]);
  });

  test('exhausts the configured attempts after repeated failures', () {
    final scheduler = RetryScheduler(retries: 2);
    final attempts = <int>[];

    for (final attempt in scheduler.attemptNumbers) {
      attempts.add(attempt);
      expect(
        scheduler.shouldRetry(attemptNumber: attempt, succeeded: false),
        attempt < scheduler.maxAttempts,
      );
    }

    expect(attempts, [1, 2, 3]);
  });
}
