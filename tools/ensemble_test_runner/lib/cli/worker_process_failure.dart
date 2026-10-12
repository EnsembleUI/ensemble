import 'dart:io';

import 'package:ensemble_test_runner/models/ensemble_test_models.dart';

/// Creates the suite-visible result for a worker that failed outside a test
/// case. A worker that already reported failed test cases does not need an
/// additional synthetic result; those cases already preserve the failure. A
/// nonzero process status after a nonempty, all-passing report is also not
/// promoted to a synthetic failure: the report is the completed execution
/// contract and avoids turning a wrapper shutdown status into a test failure.
List<EnsembleSingleTestResult> workerProcessFailureResults(
  ProcessResult process, {
  required int workerIndex,
  String? outputFile,
  bool reportHasFailures = false,
  bool reportHasResults = false,
  Iterable<String> expectedTestIds = const [],
  Iterable<String> reportedTestIds = const [],
}) {
  // Shard planning uses the stable expanded id, while JSON reports carry the
  // same id followed by a human-readable source-file suffix. Compare the
  // stable portion so report decoration cannot create a false incomplete
  // worker failure.
  final expected = expectedTestIds.map(_stableTestId).toSet();
  final reported = reportedTestIds.map(_stableTestId).toSet();
  final missing = expected.difference(reported);
  final reportIsComplete = expected.isEmpty || missing.isEmpty;
  if (process.exitCode == 0 && reportIsComplete) return const [];
  if (reportHasFailures && reportIsComplete) return const [];
  if (process.exitCode != 0 && reportHasResults && reportIsComplete) {
    return const [];
  }

  final processOutput =
      '${process.stderr ?? ''}\n${process.stdout ?? ''}'.toLowerCase();
  final timedOut = processOutput.contains('timed out');
  final interrupted = processOutput.contains('interrupted by parent');
  final message = missing.isNotEmpty
      ? 'Test worker ${workerIndex + 1} did not report ${missing.length} '
          'expected test${missing.length == 1 ? '' : 's'}'
      : timedOut
          ? 'Test worker ${workerIndex + 1} timed out'
          : interrupted
              ? 'Test worker ${workerIndex + 1} was interrupted'
              : 'Test worker ${workerIndex + 1} exited with code ${process.exitCode}';
  final detail = outputFile == null ? '' : '. See $outputFile';
  final failureKind = timedOut || interrupted || missing.isNotEmpty
      ? TestFailureKind.incompleteExecution
      : TestFailureKind.crash;
  final failedTestIds =
      missing.isEmpty ? ['test-worker-${workerIndex + 1}'] : missing.toList()
        ..sort();
  return [
    for (final testId in failedTestIds)
      EnsembleSingleTestResult.failed(
        testId: testId,
        durationMs: 0,
        message: missing.isEmpty
            ? '$message$detail'
            : 'Test worker ${workerIndex + 1} did not report assigned test '
                '"$testId" before it stopped$detail',
        failure: TestFailureDetails(
          kind: failureKind,
          message: missing.isEmpty
              ? '$message$detail'
              : 'Test worker ${workerIndex + 1} did not report assigned test '
                  '"$testId" before it stopped$detail',
          phase: 'worker',
        ),
      ),
  ];
}

String _stableTestId(String value) {
  final suffix = value.indexOf('  (');
  return suffix == -1 ? value : value.substring(0, suffix);
}

/// Preserves a worker-level result when a report exists but cannot be decoded.
/// The malformed artifact must not discard results already merged from other
/// workers or turn the entire suite into an uncaught CLI exception.
List<EnsembleSingleTestResult> workerReportDecodeFailureResults({
  required int workerIndex,
  required Object error,
  Iterable<String> expectedTestIds = const [],
  String? outputFile,
}) {
  final message = 'Test worker ${workerIndex + 1} produced an invalid '
      'results report';
  final detail = outputFile == null ? '' : '. See $outputFile';
  final testIds = expectedTestIds.toSet().toList()..sort();
  final failedTestIds =
      testIds.isEmpty ? ['test-worker-${workerIndex + 1}'] : testIds;
  return [
    for (final testId in failedTestIds)
      EnsembleSingleTestResult.failed(
        testId: testId,
        durationMs: 0,
        message: testIds.isEmpty
            ? '$message$detail'
            : 'Test worker ${workerIndex + 1} could not report assigned test '
                '"$testId" because its results report is invalid$detail',
        failure: TestFailureDetails(
          kind: TestFailureKind.incompleteExecution,
          message: testIds.isEmpty
              ? '$message$detail'
              : 'Test worker ${workerIndex + 1} could not report assigned test '
                  '"$testId" because its results report is invalid$detail',
          phase: 'worker',
        ),
      ),
  ];
}
