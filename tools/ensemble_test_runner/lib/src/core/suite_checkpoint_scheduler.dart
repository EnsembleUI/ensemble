/// Tracks completed suite tests and checkpoints used by dependent tests.
///
/// An unknown dependency does not block execution. A known failed dependency
/// does; completed dependencies may provide a checkpoint to restore.
final class SuiteCheckpointScheduler<T> {
  final Map<String, bool> _failedTests = {};
  final Map<String, T> _checkpoints = {};

  bool dependencyFailed(String testId) => _failedTests[testId] == true;

  /// Returns a checkpoint only while its producer is successful.
  ///
  /// The producer can capture a checkpoint before its final result is known.
  /// A failed result therefore invalidates any checkpoint captured during that
  /// attempt; this guard also keeps callers safe if a failure is recorded by a
  /// different orchestration path.
  T? checkpointFor(String testId) {
    if (dependencyFailed(testId)) return null;
    return _checkpoints[testId];
  }

  void recordResult(String testId, {required bool failed}) {
    _failedTests[testId] = failed;
    if (failed) {
      // A producer may capture evidence before its test returns. Never let a
      // failed producer expose that partial state to a later dependent test.
      _checkpoints.remove(testId);
    }
  }

  void recordCheckpoint(String testId, T checkpoint) {
    if (dependencyFailed(testId)) {
      throw StateError(
        'Cannot record a checkpoint for failed test "$testId".',
      );
    }
    _checkpoints[testId] = checkpoint;
  }
}
