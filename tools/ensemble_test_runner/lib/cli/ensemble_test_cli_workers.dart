part of 'ensemble_test_cli.dart';

Future<ProcessResult> _runParallelFlutterTests(
  List<String> arguments, {
  required String appDir,
  required String flutterExecutable,
  required TestAppPatcher patcher,
  required TestTimerRewritePlan timerRewritePlan,
  required int? jobs,
  required String? reportMode,
  required String? reportFile,
  required int? timeoutSeconds,
  required bool quiet,
  required bool machineReport,
  required EnsembleTestConfig suiteConfig,
}) async {
  final reportCoordinator = CliReportCoordinator(appDir);
  return await RunnerBenchmark.async('worker', 'runParallelFlutterTests',
      () async {
    final testFiles = await shard_planner.buildCliShardPlan(
      appDir,
      patcher.testsDirPath,
      arguments: arguments,
    );
    final allFiles = [
      ...testFiles.parallel.map((file) => file.id),
      ...testFiles.serial,
    ];
    Future<ProcessResult> runSingleAndPersistReport() async {
      final process = await _runSingleFlutterTestProcess(
        arguments,
        appDir: appDir,
        flutterExecutable: flutterExecutable,
        patcher: patcher,
        timerRewritePlan: timerRewritePlan,
        reportMode: reportMode,
        reportFile: reportFile,
        timeoutSeconds: timeoutSeconds,
      );
      final result = _runResultFromProcessOutput(
        process,
        artifactRoot: _artifactRootPath(appDir),
      );
      if (result != null) {
        await reportCoordinator.writeHtmlReport(result);
      } else {
        final output = '${process.stdout ?? ''}\n${process.stderr ?? ''}';
        final suiteOutput = extractSuiteReport(output);
        final failure = extractKnownFailure(output);
        final details = failure.isNotEmpty
            ? failure
            : suiteOutput.isNotEmpty
                ? suiteOutput.trim()
                : 'The test worker did not produce a machine-readable result.';
        await reportCoordinator.writeHtmlReport(
          EnsembleTestRunResult(
            results: [
              EnsembleSingleTestResult.failed(
                testId: 'test-process',
                durationMs: 0,
                message: details,
                logs: suiteOutput.isEmpty ? [details] : [suiteOutput],
                failure: TestFailureDetails(
                  kind: TestFailureKind.incompleteExecution,
                  message: details,
                  phase: 'worker',
                ),
              ),
            ],
          ),
        );
        if (process.exitCode == 0) {
          return ProcessResult(
            process.pid,
            3,
            process.stdout,
            process.stderr,
          );
        }
      }
      return process;
    }

    if (allFiles.length < 2) {
      return runSingleAndPersistReport();
    }

    final requestedJobs = jobs ?? _autoWorkerCount(allFiles.length);
    final hasParallelFiles = testFiles.parallel.isNotEmpty;
    final hasSerialFiles = testFiles.serial.isNotEmpty;
    final totalJobCount = requestedJobs.clamp(1, allFiles.length);
    final serialLaneCount = hasSerialFiles ? 1 : 0;
    final parallelLaneBudget = totalJobCount - serialLaneCount;
    final parallelWorkerCount = hasParallelFiles
        ? parallelLaneBudget.clamp(1, testFiles.parallel.length)
        : 0;
    if (parallelWorkerCount <= 1 && !hasSerialFiles) {
      return runSingleAndPersistReport();
    }
    final shards = shard_planner.balancedCliShards(
      testFiles.parallel,
      parallelWorkerCount,
    );
    final compiledPlans = await CliCompiledPlanBatch.build(
      appDirectory: appDir,
      testsDirectory: patcher.testsDirPath!,
      arguments: arguments,
      config: suiteConfig,
      assetContents: testFiles.assetContents,
      decodedDocuments: testFiles.decodedDocuments,
    );

    CliProcessOutput.writeStatus(
      'Running ${allFiles.length} test runs with $totalJobCount workers...',
      quiet: quiet,
      machineReport: machineReport,
    );

    final elapsed = Stopwatch()..start();
    final artifactRoot = _artifactRootPath(appDir);
    final workerStarts = <Future<_WorkerProcessResult> Function()>[];
    final workerReportFiles = <String>[];
    final expectedWorkerTestIds = <List<String>>[];
    final workerProgressFiles = <String>[];
    final showProgress = !quiet && !machineReport;
    final usedServicePorts = <int>{};
    for (var i = 0; i < parallelWorkerCount; i++) {
      final shard = shards[i];
      if (shard.isEmpty) continue;
      final shardPaths = shard.expand((file) => file.paths).toSet().toList();
      final shardIds = shard.map((file) => file.id).toList();
      final workerReportFile = _workerReportFile(appDir, i);
      final workerProgressFile = _workerProgressFile(appDir, i);
      _deleteIfExists(workerReportFile);
      _deleteIfExists(workerProgressFile);
      workerReportFiles.add(workerReportFile);
      expectedWorkerTestIds.add(shardIds);
      workerProgressFiles.add(workerProgressFile);
      final workerDirectory =
          CliWorkerWorkspace(appDir).prepare(i, timerRewritePlan);
      final planBatchFile = File(p.join(
        workerDirectory,
        '.ensemble_test_runner_plan_batch_${i + 1}.json',
      ));
      planBatchFile.writeAsStringSync(
        compiledPlans.encodeForWorker(testIds: shardIds),
      );
      final serviceOverrides = await resolveServiceOverrides(
        patcher: patcher,
        preferredOffset: i,
        usedPorts: usedServicePorts,
      );
      final workerArguments = _withPlanBatchFile(arguments, planBatchFile.path);
      final appLogPath = CliAppConsoleLog.filePath(appDir, workerIndex: i);
      final appLogDisplayPath = CliAppConsoleLog.relativePath(workerIndex: i);
      final progressPath = showProgress ? workerProgressFile : null;
      final runtimeEnvironment =
          flutter_test_command.buildFlutterTestWorkerEnvironment(
        suiteEncryptionKey: _suiteEncryptionKey(),
        artifactRoot: artifactRoot,
        workerIndex: i,
        reportMode: 'json',
        timeoutSeconds: timeoutSeconds,
        shardPaths: shardPaths,
        shardIds: shardIds,
        reportFile: workerReportFile,
        progressFile: progressPath,
        appLogPath: appLogPath,
        appLogDisplayPath: appLogDisplayPath,
        serviceOverrides: serviceOverrides,
        arguments: workerArguments,
      );
      workerStarts.add(
        () => _runFlutterTestProcess(
          flutterExecutable,
          flutter_test_command.buildFlutterTestArgs(
            workerArguments,
            suiteEncryptionKey: _suiteEncryptionKey(),
            reportMode: 'json',
            reportFile: workerReportFile,
            timeoutSeconds: timeoutSeconds,
            verbose: false,
            shardPaths: shardPaths,
            shardIds: shardIds,
            workerIndex: i,
            progressFile: progressPath,
            appLogPath: appLogPath,
            appLogDisplayPath: appLogDisplayPath,
            artifactRoot: artifactRoot,
            serviceOverrides: serviceOverrides,
            testEntryRelativePath: patcher.activeEntryRelativePath,
            testsAssetPrefix: patcher.testsDirRelative,
            useRuntimeWorkerConfig: true,
          ),
          workingDirectory: workerDirectory,
          streamOutput: false,
          verbose: false,
          appLogFile:
              CliAppConsoleLog.filePath(workerDirectory, workerIndex: i),
          timeout:
              timeoutSeconds == null ? null : Duration(seconds: timeoutSeconds),
          environment: runtimeEnvironment,
        ),
      );
    }

    if (hasSerialFiles) {
      final serialWorkerIndex = parallelWorkerCount;
      final workerReportFile = _workerReportFile(appDir, serialWorkerIndex);
      final workerProgressFile = _workerProgressFile(appDir, serialWorkerIndex);
      _deleteIfExists(workerReportFile);
      _deleteIfExists(workerProgressFile);
      workerReportFiles.add(workerReportFile);
      // The parsed suite definitions carry expanded IDs for serial assets too;
      // retain them so an interrupted worker with no report is attributable.
      expectedWorkerTestIds.add(
        compiledPlans.testIdsForAssetPaths(testFiles.serial),
      );
      workerProgressFiles.add(workerProgressFile);
      final workerDirectory = CliWorkerWorkspace(appDir).prepare(
        serialWorkerIndex,
        timerRewritePlan,
      );
      final planBatchFile = File(p.join(
        workerDirectory,
        '.ensemble_test_runner_plan_batch_${serialWorkerIndex + 1}.json',
      ));
      planBatchFile.writeAsStringSync(
        compiledPlans.encodeForWorker(assetPaths: testFiles.serial),
      );
      final serviceOverrides = await resolveServiceOverrides(
        patcher: patcher,
        preferredOffset: serialWorkerIndex,
        usedPorts: usedServicePorts,
      );
      final workerArguments = _withPlanBatchFile(arguments, planBatchFile.path);
      final appLogPath = CliAppConsoleLog.filePath(
        appDir,
        workerIndex: serialWorkerIndex,
      );
      final appLogDisplayPath =
          CliAppConsoleLog.relativePath(workerIndex: serialWorkerIndex);
      final progressPath = showProgress ? workerProgressFile : null;
      final runtimeEnvironment =
          flutter_test_command.buildFlutterTestWorkerEnvironment(
        suiteEncryptionKey: _suiteEncryptionKey(),
        artifactRoot: artifactRoot,
        workerIndex: serialWorkerIndex,
        reportMode: 'json',
        timeoutSeconds: timeoutSeconds,
        shardPaths: testFiles.serial,
        shardIds: const [],
        reportFile: workerReportFile,
        progressFile: progressPath,
        appLogPath: appLogPath,
        appLogDisplayPath: appLogDisplayPath,
        serviceOverrides: serviceOverrides,
        arguments: workerArguments,
      );
      workerStarts.add(
        () => _runFlutterTestProcess(
          flutterExecutable,
          flutter_test_command.buildFlutterTestArgs(
            workerArguments,
            suiteEncryptionKey: _suiteEncryptionKey(),
            reportMode: 'json',
            reportFile: workerReportFile,
            timeoutSeconds: timeoutSeconds,
            verbose: false,
            shardPaths: testFiles.serial,
            workerIndex: serialWorkerIndex,
            progressFile: progressPath,
            appLogPath: appLogPath,
            appLogDisplayPath: appLogDisplayPath,
            artifactRoot: artifactRoot,
            serviceOverrides: serviceOverrides,
            testEntryRelativePath: patcher.activeEntryRelativePath,
            testsAssetPrefix: patcher.testsDirRelative,
            useRuntimeWorkerConfig: true,
          ),
          workingDirectory: workerDirectory,
          streamOutput: false,
          verbose: false,
          appLogFile: CliAppConsoleLog.filePath(
            workerDirectory,
            workerIndex: serialWorkerIndex,
          ),
          timeout:
              timeoutSeconds == null ? null : Duration(seconds: timeoutSeconds),
          environment: runtimeEnvironment,
        ),
      );
    }

    var runDone = false;
    final progressPoller = showProgress
        ? _pollWorkerProgress(
            workerProgressFiles,
            isDone: () => runDone,
          )
        : Future<void>.value();
    // Keep collection in a finally block. Process.start can fail before a
    // worker produces a ProcessResult (for example when an SDK executable is
    // unavailable). In that case the old path skipped sandbox cleanup and
    // left linked worker trees behind for the next run.
    late final List<_WorkerProcessResult> workerExecutions;
    var workerResultsCollected = false;
    try {
      // Wait for every worker before cleaning sandboxes. A startup failure in
      // one worker must not let Future.wait return early while another worker
      // still owns files, ports, or a child process that cleanup is about to
      // remove. The first error is still rethrown after all workers settle.
      workerExecutions = await startManagedProcesses(workerStarts);
      workerResultsCollected = true;
    } finally {
      runDone = true;
      try {
        await progressPoller;
      } finally {
        try {
          if (!workerResultsCollected ||
              workerExecutions.any((result) => result.exitCode != 0) ||
              CliWorkerProgressOutput.hasMissingReports(workerReportFiles)) {
            CliWorkerProgressOutput.preserveIncompleteProgress(
              workerProgressFiles,
              Directory(p.join(
                appDir,
                'build',
                'ensemble_test_runner',
                'diagnostics',
                'worker_progress',
              )),
              timedOutWorkerIndexes: {
                if (workerResultsCollected)
                  for (var i = 0; i < workerExecutions.length; i++)
                    if (workerExecutions[i].timedOut) i,
              },
            );
          }
          // Live ✓/✗ streaming is done — progress files have finished their
          // job. A cleanup error must not prevent sandbox removal.
          _deleteArtifactSubdir(appDir, 'worker_progress');
          for (var i = 0; i < workerReportFiles.length; i++) {
            CliWorkerWorkspace(appDir).copyArtifacts(i);
          }
        } finally {
          // Worker sandboxes only exist to isolate Flutter build/ output and
          // timer rewrites. Artifacts are copied above; drop the trees so they
          // do not keep multi‑GB compile caches around after the run.
          CliWorkerWorkspace(appDir).clean();
        }
      }
    }
    final workerResults = workerExecutions
        .map((execution) => execution.result)
        .toList(growable: false);
    var merged = _mergeWorkerReports(
      workerResults,
      reportFiles: workerReportFiles,
      expectedWorkerTestIds: expectedWorkerTestIds,
      appDir: appDir,
      orderedOutputs: [
        for (final execution in workerExecutions) execution.orderedOutput,
      ],
    );
    // Shard JSONs are merged into memory — drop per-worker report files.
    _deleteArtifactSubdir(appDir, 'worker_reports');
    merged = _mergeParallelSuiteArtifacts(merged);
    merged = await reportCoordinator.writeHtmlReport(
      merged,
      wallTimeMs: elapsed.elapsedMilliseconds,
    );
    final output = StringBuffer();
    if (reportMode == 'json') {
      output.writeln(
        reportCoordinator.serializeMachineResult(merged, junit: false),
      );
    } else if (reportMode == 'junit') {
      output.writeln(
        reportCoordinator.serializeMachineResult(merged, junit: true),
      );
    } else {
      output.write(
        _formatCliSummary(
          merged,
          testFile: '${patcher.testsDirRelative}/*.test.yaml',
          wallTimeMs: elapsed.elapsedMilliseconds,
        ),
      );
    }
    if (reportFile != null) {
      reportCoordinator.writeMachineResult(
        merged,
        path: reportFile,
        junit: reportMode == 'junit',
      );
    }

    final stderr = StringBuffer();
    if (merged.failedCount > 0) {
      for (var i = 0; i < workerResults.length; i++) {
        final result = workerResults[i];
        if (result.exitCode != 0) {
          stderr.writeln(
            'A test process failed with exit code ${result.exitCode}.',
          );
          final known = extractKnownFailure(
            '${result.stdout ?? ''}\n${result.stderr ?? ''}',
          );
          if (known.isNotEmpty) stderr.writeln(known);
        }
        final err = result.stderr?.toString() ?? '';
        if (err.isNotEmpty && !isBenignFlutterTestStderr(err)) {
          stderr.writeln(err.trimRight());
        }
      }
    }

    final exitCode = merged.failedCount > 0 ? 1 : 0;
    return ProcessResult(
      0,
      exitCode,
      output.toString(),
      stderr.toString(),
    );
  });
}

List<String> _withPlanBatchFile(List<String> arguments, String path) => [
      for (final argument in arguments)
        if (!argument.startsWith('--plan-batch-file=')) argument,
      '--plan-batch-file=$path',
    ];

Future<ProcessResult> _runSingleFlutterTestProcess(
  List<String> arguments, {
  required String appDir,
  required String flutterExecutable,
  required TestAppPatcher patcher,
  required TestTimerRewritePlan timerRewritePlan,
  required String? reportMode,
  required String? reportFile,
  required int? timeoutSeconds,
}) async {
  final useWorker = timerRewritePlan.enabled;
  final workingDirectory = useWorker
      ? CliWorkerWorkspace(appDir).prepare(0, timerRewritePlan)
      : appDir;
  final serviceOverrides = await resolveServiceOverrides(
    patcher: patcher,
    usedPorts: <int>{},
  );
  final appLogPath = useWorker
      ? CliAppConsoleLog.filePath(appDir)
      : CliAppConsoleLog.relativePath();
  final appLogDisplayPath = useWorker ? CliAppConsoleLog.relativePath() : null;
  final artifactRoot = useWorker ? _artifactRootPath(appDir) : null;
  final internalReportFile = reportFile ??
      (reportMode == null
          ? p.join(
              _artifactRootPath(appDir),
              ensembleTestMachineResultRelativePath,
            )
          : null);
  final runtimeEnvironment =
      flutter_test_command.buildFlutterTestWorkerEnvironment(
    suiteEncryptionKey: _suiteEncryptionKey(),
    artifactRoot: artifactRoot,
    workerIndex: 0,
    reportMode: reportMode,
    timeoutSeconds: timeoutSeconds,
    shardPaths: const [],
    shardIds: const [],
    reportFile: internalReportFile,
    progressFile: null,
    appLogPath: appLogPath,
    appLogDisplayPath: appLogDisplayPath,
    serviceOverrides: serviceOverrides,
    arguments: arguments,
  );
  return (await _runFlutterTestProcess(
    flutterExecutable,
    flutter_test_command.buildFlutterTestArgs(
      arguments,
      suiteEncryptionKey: _suiteEncryptionKey(),
      reportMode: reportMode,
      reportFile: internalReportFile,
      timeoutSeconds: timeoutSeconds,
      verbose: false,
      appLogPath: appLogPath,
      appLogDisplayPath: appLogDisplayPath,
      artifactRoot: artifactRoot,
      serviceOverrides: serviceOverrides,
      testEntryRelativePath: patcher.activeEntryRelativePath,
      testsAssetPrefix: patcher.testsDirRelative,
      useRuntimeWorkerConfig: true,
    ),
    workingDirectory: workingDirectory,
    streamOutput: false,
    verbose: false,
    appLogFile: CliAppConsoleLog.filePath(appDir),
    timeout: timeoutSeconds == null ? null : Duration(seconds: timeoutSeconds),
    environment: runtimeEnvironment,
  ))
      .result;
}

/// Returns the expanded run ids assigned to each parallel worker.
///
/// This is intentionally a small test hook for the CLI sharding planner. The
/// production runner uses the same private `_testFilesForSharding` and
/// `_balancedShards` path before launching Flutter worker processes.
Future<List<List<String>>> planShardRunIdsForTest({
  required String appDir,
  List<String> arguments = const [],
  int? jobs,
}) async {
  return await RunnerBenchmark.async('worker', 'planShardRunIdsForTest',
      () async {
    final testFiles = await shard_planner.buildCliShardPlan(
      appDir,
      TestAppPatcher(appDir).testsDirPath,
      arguments: arguments,
    );
    final allRuns = [
      ...testFiles.parallel.map((file) => file.id),
      ...testFiles.serial,
    ];
    if (allRuns.isEmpty) return const [];
    if (allRuns.length < 2) return [allRuns];

    final requestedJobs = jobs ?? _autoWorkerCount(allRuns.length);
    final totalJobCount = requestedJobs.clamp(1, allRuns.length);
    final serialLaneCount = testFiles.serial.isNotEmpty ? 1 : 0;
    final parallelLaneBudget = totalJobCount - serialLaneCount;
    final parallelWorkerCount = testFiles.parallel.isNotEmpty
        ? parallelLaneBudget.clamp(1, testFiles.parallel.length)
        : 0;

    final result = <List<String>>[
      for (final shard in shard_planner.balancedCliShards(
        testFiles.parallel,
        parallelWorkerCount,
      ))
        [for (final file in shard) file.id],
    ];
    if (testFiles.serial.isNotEmpty) {
      result.add(testFiles.serial);
    }
    return result.where((shard) => shard.isNotEmpty).toList();
  });
}
