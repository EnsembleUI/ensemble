part of 'ensemble_test_cli.dart';

Future<void> _executeCliRun({
  required List<String> arguments,
  required String appDir,
  required TestAppPatcher patcher,
  required CliRunArtifactLock artifactLock,
  bool pruneKernelCache = false,
  required bool verbose,
  required bool quiet,
  required bool machineReport,
  required bool jsonReport,
  required bool junitReport,
  required bool streamLiveOutput,
  required String? reportMode,
  required String? reportFile,
  required int? timeoutSeconds,
  required int? jobs,
  required EnsembleTestConfig suiteConfig,
  required ExecutionMode executionMode,
  required ExecutionBackend executionBackend,
  required FlutterDevice? integrationDevice,
  required TestSuiteSource suiteSource,
  required CliReportCoordinator reportCoordinator,
  required CliWorkerWorkspace workerWorkspace,
}) async {
  var exitCode = 0;
  final flutter = resolveFlutterExecutable(appDir);
  TestServiceManager? hostServices;
  final reversedPorts = <int>[];
  try {
    CliProcessOutput.writeStatus(
      'Preparing Ensemble tests...',
      quiet: quiet,
      machineReport: machineReport,
    );
    patcher.enable(
      mode: executionBackend.mode,
      targetPlatform: integrationDevice?.platform,
    );
    final timerRewritePlan = TestTimerRewritePlan.forApp(
      appDir: appDir,
      testsDirRelative: patcher.testsDirRelative,
    );

    if (patcher.pubspecChanged) {
      CliProcessOutput.writeStatus(
        'Resolving Flutter dependencies...',
        quiet: quiet,
        machineReport: machineReport,
      );
      final pubGet = await _runProcess(
        flutter,
        ['pub', 'get', '--suppress-analytics'],
        workingDirectory: appDir,
      );
      if (pubGet.exitCode != 0 || verbose) {
        CliProcessOutput.writeProcessStreams(pubGet);
      }
      if (pubGet.exitCode != 0) {
        exitCode = 2;
        return;
      }
    }

    CliProcessOutput.writeStatus(
      'Running Ensemble tests...',
      quiet: quiet,
      machineReport: machineReport,
    );

    _cleanParallelRunArtifacts(appDir);

    if (!machineReport) {
      try {
        await reportCoordinator.writeHtmlReport(
          const EnsembleTestRunResult(results: []),
          wallTimeMs: 0,
          isSuiteRunning: true,
        );
      } catch (_) {}
    }
    final runSerial = !executionBackend.supportsParallel || jobs == 1;
    final serialWorkingDirectory = runSerial && timerRewritePlan.enabled
        ? workerWorkspace.prepare(0, timerRewritePlan)
        : appDir;
    final serialServiceOverrides = runSerial
        ? await resolveServiceOverrides(
            patcher: patcher,
            usedPorts: <int>{},
          )
        : null;
    var effectiveServiceOverrides =
        serialServiceOverrides ?? const <String, dynamic>{};
    if (executionBackend.hostOwnsServices) {
      final hostAddress = await resolveIntegrationHostAddress(
        platform: integrationDevice!.platform,
        emulator: integrationDevice.isVirtual,
        explicitHostAddress: () {
          final hosts = CliTestSelection.values(arguments, '--host-address');
          return hosts.isEmpty ? null : hosts.single;
        }(),
      );
      if (hostAddress != null) {
        effectiveServiceOverrides = rewriteServiceOverridesForHost(
          effectiveServiceOverrides,
          suiteConfig.services,
          hostAddress,
        );
      }
      final resolvedServices = _resolvedHostServices(
        suiteConfig.services,
        effectiveServiceOverrides,
        appDir: appDir,
      );
      hostServices = TestServiceManager(
        resolvedServices,
        artifactRoot: _artifactRootPath(appDir),
      );
      await hostServices.startAll();
      if (integrationDevice.platform == 'android') {
        for (final service in resolvedServices) {
          final uri = service.url == null ? null : Uri.tryParse(service.url!);
          if (uri == null || !uri.hasPort) continue;
          await _addAdbReverse(integrationDevice.id, uri.port);
          reversedPorts.add(uri.port);
        }
        await _clearAdbLogcat(integrationDevice.id);
      }
    }
    final testRun = runSerial
        ? (await _runFlutterTestProcess(
            flutter,
            flutter_test_command.buildFlutterTestArgs(
              arguments,
              suiteEncryptionKey: _suiteEncryptionKey(),
              reportMode: reportMode,
              reportFile: executionMode == ExecutionMode.integration
                  ? null
                  : reportFile,
              timeoutSeconds: timeoutSeconds,
              verbose: verbose,
              testEntryRelativePath: patcher.activeEntryRelativePath,
              testsAssetPrefix: suiteSource.testsAssetPrefix,
              physicalDevice: integrationDevice,
              hostOwnsServices: executionBackend.hostOwnsServices,
              appLogPath: timerRewritePlan.enabled
                  ? CliAppConsoleLog.filePath(appDir)
                  : CliAppConsoleLog.relativePath(),
              appLogDisplayPath: timerRewritePlan.enabled
                  ? CliAppConsoleLog.relativePath()
                  : null,
              artifactRoot:
                  timerRewritePlan.enabled ? _artifactRootPath(appDir) : null,
              serviceOverrides: effectiveServiceOverrides.isEmpty
                  ? null
                  : effectiveServiceOverrides,
            ),
            workingDirectory: serialWorkingDirectory,
            streamOutput: streamLiveOutput,
            verbose: verbose,
            appLogFile: CliAppConsoleLog.filePath(appDir),
            timeout: timeoutSeconds == null
                ? null
                : Duration(seconds: timeoutSeconds),
          ))
            .result
        : await _runParallelFlutterTests(
            arguments,
            appDir: appDir,
            flutterExecutable: flutter,
            patcher: patcher,
            timerRewritePlan: timerRewritePlan,
            jobs: jobs,
            reportMode: reportMode,
            reportFile: reportFile,
            timeoutSeconds: timeoutSeconds,
            quiet: quiet,
            machineReport: machineReport,
            suiteConfig: suiteConfig,
          );

    if (executionMode == ExecutionMode.integration) {
      var transport = await materializeTransportedArtifacts(
        artifactRoot: _artifactRootPath(appDir),
        output: '${testRun.stdout ?? ''}\n${testRun.stderr ?? ''}',
      );
      if (!transport.complete && integrationDevice?.platform == 'android') {
        final logcat = await _readAdbLogcat(integrationDevice!.id);
        if (logcat.contains(ensembleTestArtifactProtocolPrefix)) {
          transport = await materializeTransportedArtifacts(
            artifactRoot: _artifactRootPath(appDir),
            output: logcat,
          );
        }
      }
      if (!transport.complete) {
        stderr.writeln(
          transport.error ?? 'Integration artifact transport was incomplete.',
        );
        if (transport.receivedPaths.isNotEmpty) {
          stderr.writeln(
            'Kept ${transport.receivedPaths.length} valid artifact(s) that '
            'arrived before the failure.',
          );
        }
        if (!verbose) {
          CliProcessOutput.writeProcessStreams(testRun);
        }
        exitCode = 3;
        return;
      }
      await optimizeTransportedScreenshotsForHost(_artifactRootPath(appDir));
    }

    CliTestOutputPresenter.present(
      testRun,
      jsonReport: jsonReport,
      junitReport: junitReport,
      machineReport: machineReport,
      streamLiveOutput: streamLiveOutput,
      verbose: verbose,
    );

    final machineResult = _runResultFromProcessOutput(
      testRun,
      artifactRoot: _artifactRootPath(appDir),
    );
    if (runSerial && machineResult != null) {
      if (machineReport) {
        await reportCoordinator.recordHistory(machineResult);
      } else {
        await reportCoordinator.writeHtmlReport(machineResult);
      }
      if (executionMode == ExecutionMode.integration && reportFile != null) {
        reportCoordinator.writeMachineResult(
          machineResult,
          path: reportFile,
          junit: junitReport,
        );
      }
    }
    exitCode = machineResult == null
        ? (executionMode == ExecutionMode.integration
            ? 3
            : (testRun.exitCode == 0 ? 0 : 1))
        : (machineResult.failedCount == 0 ? 0 : 1);
  } on StateError catch (error) {
    stderr.writeln(error.message);
    exitCode = 3;
  } catch (error, stackTrace) {
    stderr.writeln('Ensemble test runner infrastructure failure: $error');
    if (verbose) stderr.writeln(stackTrace);
    exitCode = 3;
  } finally {
    // Teardown must continue through every owner.  Service shutdown can fail
    // when a child process ignores termination; that must not strand worker
    // sandboxes, leave patched entry points in the app, or hold the artifact
    // lock for the next run.  AsyncCleanupStack preserves the first cleanup
    // error while still attempting each callback in reverse ownership order.
    final cleanup = AsyncCleanupStack();
    cleanup.add(artifactLock.release);
    if (pruneKernelCache) {
      cleanup.add(() =>
          flutter_test_command.pruneFlutterTestKernelCache(Directory(appDir)));
    }
    cleanup.add(patcher.restore);
    // Serial timer-rewrite runs also use a worker sandbox; always drop leftovers.
    cleanup.add(workerWorkspace.clean);
    cleanup.add(() async {
      if (executionMode == ExecutionMode.integration &&
          integrationDevice?.platform == 'android') {
        for (final port in reversedPorts.reversed) {
          await _removeAdbReverse(integrationDevice!.id, port);
        }
      }
    });
    cleanup.add(() async {
      await hostServices?.stopAll();
    });
    try {
      await cleanup.close();
    } catch (error, stackTrace) {
      // Preserve an existing run failure.  If the run otherwise succeeded,
      // make cleanup failure visible through the CLI status without skipping
      // the remaining cleanup callbacks.
      if (exitCode == 0) exitCode = 3;
      if (verbose) {
        stderr.writeln('Ensemble test runner cleanup failure: $error');
        stderr.writeln(stackTrace);
      }
    }
    exit(exitCode);
  }
}
