part of 'ensemble_test_cli.dart';

String _workerReportFile(String appDir, int workerIndex) {
  return p.join(
    appDir,
    'build',
    'ensemble_test_runner',
    'worker_reports',
    'worker${workerIndex + 1}.json',
  );
}

/// Drops legacy suite-level apiCalls/storage/appLogs links; those artifacts are
/// now attached per test (and copied from workers as `{testId}_*.json/.log`).
EnsembleTestRunResult _mergeParallelSuiteArtifacts(
  EnsembleTestRunResult result,
) {
  final logs = result.suiteLogs
      .where(
        (log) =>
            !log.startsWith('apiCalls:') &&
            !log.startsWith('storage:') &&
            !log.startsWith('storage[') &&
            !log.startsWith('appLogs:'),
      )
      .toList();

  return EnsembleTestRunResult(
    results: result.results,
    suiteLogs: logs,
    metadata: result.metadata,
  );
}

void _cleanParallelRunArtifacts(String appDir) {
  final root = Directory(p.join(appDir, 'build', 'ensemble_test_runner'));
  for (final name in const [
    'logs',
    'diagnostics',
    'frames',
    // Legacy pre-rename location for `*_frames.json` manifests.
    'screenshots',
    'worker_progress',
    'worker_reports',
    'plan_batches',
  ]) {
    final directory = Directory(p.join(root.path, name));
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  }
  final reportScreenshots =
      Directory(p.join(root.path, 'report', 'screenshots'));
  if (reportScreenshots.existsSync()) {
    reportScreenshots.deleteSync(recursive: true);
  }
}

/// Deletes one subdirectory under `build/ensemble_test_runner/` when its job
/// is finished (progress after live polling, reports after merge).
void _deleteArtifactSubdir(String appDir, String name) {
  final directory = Directory(
    p.join(appDir, 'build', 'ensemble_test_runner', name),
  );
  if (directory.existsSync()) {
    directory.deleteSync(recursive: true);
  }
}

String _workerProgressFile(String appDir, int workerIndex) {
  return p.join(
    appDir,
    'build',
    'ensemble_test_runner',
    'worker_progress',
    'worker${workerIndex + 1}.jsonl',
  );
}

String _artifactRootPath(String appDir) {
  return p.join(appDir, 'build', 'ensemble_test_runner');
}

Future<void> _pollWorkerProgress(
  List<String> progressFiles, {
  required bool Function() isDone,
}) async {
  final seenLines = <String, int>{
    for (final file in progressFiles) file: 0,
  };

  while (!isDone()) {
    _drainWorkerProgress(progressFiles, seenLines);
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  _drainWorkerProgress(progressFiles, seenLines);
}

void _drainWorkerProgress(
  List<String> progressFiles,
  Map<String, int> seenLines,
) {
  CliWorkerProgressOutput.drainFiles(progressFiles, seenLines);
}

void _deleteIfExists(String path) {
  final file = File(path);
  if (file.existsSync()) file.deleteSync();
}

int _autoWorkerCount(int fileCount) {
  return calculateAutomaticWorkerCount(
    testCount: fileCount,
    logicalProcessorCount: Platform.numberOfProcessors,
    totalMemoryBytes: detectTotalMemoryBytes(),
  );
}
