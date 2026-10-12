/// Defines retry numbering and stop conditions independently of execution.
///
/// Attempt numbers are one-based. Callers that expose zero-based attempt
/// indexes can translate at the boundary while keeping result metadata
/// one-based.
final class RetryScheduler {
  RetryScheduler({required int retries}) : _retries = _validate(retries);

  final int _retries;

  static int _validate(int retries) {
    if (retries < 0) {
      throw ArgumentError.value(retries, 'retries', 'must be non-negative');
    }
    return retries;
  }

  int get maxAttempts => _retries + 1;

  Iterable<int> get attemptNumbers sync* {
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      yield attempt;
    }
  }

  /// Returns true only when the current failed attempt has a retry remaining.
  bool shouldRetry({required int attemptNumber, required bool succeeded}) {
    if (attemptNumber < 1 || attemptNumber > maxAttempts) {
      throw RangeError.range(attemptNumber, 1, maxAttempts, 'attemptNumber');
    }
    return !succeeded && attemptNumber < maxAttempts;
  }
}
