part of 'ensemble_test_cli.dart';

const _processOutputDrainTimeout = Duration(seconds: 3);
const _integrationStartupTimeout = Duration(minutes: 20);

final class _WorkerProcessResult {
  const _WorkerProcessResult({
    required this.result,
    required this.orderedOutput,
    required this.timedOut,
  });

  final ProcessResult result;
  final String orderedOutput;
  final bool timedOut;

  int get exitCode => result.exitCode;
  int get pid => result.pid;
  dynamic get stdout => result.stdout;
  dynamic get stderr => result.stderr;
}

EnsembleTestRunResult? _runResultFromProcessOutput(
  ProcessResult result, {
  String? artifactRoot,
}) {
  final fromFile =
      artifactRoot == null ? '' : _readTransportedMachineResult(artifactRoot);
  final fromStdout =
      extractJsonReport('${result.stdout ?? ''}\n${result.stderr ?? ''}');
  final rawJson = fromFile.isNotEmpty ? fromFile : fromStdout;
  if (rawJson.isEmpty) return null;
  try {
    final decoded = json.decode(rawJson);
    if (decoded is Map<String, dynamic>) {
      return _runResultFromJson(decoded);
    }
  } catch (_) {
    // Ignore malformed subprocess report and fall back to process exit code.
  }
  return null;
}

String _readTransportedMachineResult(String artifactRoot) {
  final file = File(
    p.join(artifactRoot, ensembleTestMachineResultRelativePath),
  );
  if (!file.existsSync()) return '';
  try {
    return file.readAsStringSync();
  } catch (_) {
    return '';
  }
}

EnsembleTestRunResult _runResultFromJson(Map<String, dynamic> json) {
  final results = (json['results'] as List<dynamic>? ?? const [])
      .whereType<Map<String, dynamic>>()
      .map(_singleResultFromJson)
      .toList();
  final suiteLogs = (json['suiteLogs'] as List<dynamic>? ?? const [])
      .map((value) => value.toString())
      .toList();
  final metadata = json['metadata'] is Map
      ? Map<String, dynamic>.from(json['metadata'] as Map)
      : const <String, dynamic>{};
  return EnsembleTestRunResult(
    results: results,
    suiteLogs: suiteLogs,
    metadata: metadata,
  );
}

EnsembleSingleTestResult _singleResultFromJson(Map<String, dynamic> json) {
  return EnsembleSingleTestResult.fromJson(json);
}

Future<_WorkerProcessResult> _runFlutterTestProcess(
  String executable,
  List<String> arguments, {
  required String workingDirectory,
  required bool streamOutput,
  required bool verbose,
  String? appLogFile,
  Duration? timeout,
  bool timeoutAfterIntegrationStartup = false,
  Map<String, String>? environment,
}) async {
  return await RunnerBenchmark.async('worker', 'runFlutterTestProcess',
      () async {
    final resolvedExecutable = executable == 'flutter'
        ? resolveFlutterExecutable(workingDirectory)
        : executable;
    final interruptionWatch = ProcessInterruptionWatch();
    late final Process process;
    try {
      process = await Process.start(
        RunnerBenchmark.collector?.executables[executable] ??
            resolvedExecutable,
        arguments,
        workingDirectory: workingDirectory,
        environment: environment == null
            ? null
            : {...Platform.environment, ...environment},
        runInShell: false,
      );
    } on Object {
      await interruptionWatch.close();
      rethrow;
    }
    final benchmarkBootstrap = RunnerBenchmark.pending(
        'process_bootstrap', 'flutterUntilWorkloadReady');
    RunnerBenchmark.dimension('childProcessId', process.pid);
    RunnerBenchmark.dimension('workingDirectory', workingDirectory);
    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();
    final transcript = CliProcessTranscript();
    final liveFilter = LiveFlutterTestOutputFilter();
    final integrationWorkloadReady = Completer<void>();
    var integrationWorkloadStarted = !timeoutAfterIntegrationStartup;
    final elapsed = Stopwatch()..start();
    final integrationExecutionElapsed = Stopwatch();
    var lastLiveOutput = DateTime.now();
    Timer? heartbeat;
    final appLog = CliAppConsoleLog.open(appLogFile);

    if (streamOutput && !verbose) {
      heartbeat = Timer.periodic(const Duration(seconds: 10), (_) {
        final idleFor = DateTime.now().difference(lastLiveOutput);
        if (idleFor.inSeconds >= 10) {
          if (timeoutAfterIntegrationStartup && !integrationWorkloadStarted) {
            stderr.writeln(
              'Still building/starting integration app '
              '(${elapsed.elapsed.inSeconds}s)...',
            );
          } else {
            final runningFor = timeoutAfterIntegrationStartup
                ? integrationExecutionElapsed.elapsed
                : elapsed.elapsed;
            stderr.writeln(
              'Still running Flutter tests (${runningFor.inSeconds}s)...',
            );
          }
        }
      });
    }

    try {
      final stdoutSubscription = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        stdoutBuffer.writeln(line);
        transcript.add('stdout', line);
        if (timeoutAfterIntegrationStartup &&
            CliProcessOutput.isIntegrationWorkloadStarted(line)) {
          if (!integrationWorkloadStarted) {
            integrationWorkloadStarted = true;
            integrationExecutionElapsed.start();
          }
          if (!integrationWorkloadReady.isCompleted) {
            integrationWorkloadReady.complete();
          }
        }
        if (line.contains('ENSEMBLE_BENCHMARK_WORKLOAD_READY')) {
          benchmarkBootstrap?.finish();
          RunnerBenchmark.dimension(
              'bootstrapToReadyUs', elapsed.elapsedMicroseconds);
        }
        if (!CliProcessOutput.isArtifactProtocolLine(line)) {
          CliAppConsoleLog.append(appLog, 'stdout', line);
        }
        if (CliProcessOutput.isArtifactProtocolLine(line)) {
          return;
        }
        if (verbose) {
          stdout.writeln(line);
        } else if (streamOutput &&
            CliProcessOutput.isIntegrationProgressLine(line)) {
          final progressLine =
              CliProcessOutput.formatIntegrationProgressLine(line);
          if (progressLine != null) {
            lastLiveOutput = DateTime.now();
            stderr.writeln(progressLine);
          }
        } else if (streamOutput && liveFilter.shouldEmit(line)) {
          lastLiveOutput = DateTime.now();
          stderr.writeln(line);
        }
      });

      final stderrSubscription = process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        stderrBuffer.writeln(line);
        transcript.add('stderr', line);
        CliAppConsoleLog.append(appLog, 'stderr', line);
        if (verbose) {
          stderr.writeln(line);
        }
      });

      final stdoutDone = stdoutSubscription.asFuture<void>();
      final stderrDone = stderrSubscription.asFuture<void>();

      final managedExit = await waitForManagedProcess(
        process,
        timeout: timeout,
        startupTimeout:
            timeoutAfterIntegrationStartup ? _integrationStartupTimeout : null,
        timeoutStartsAfter: timeoutAfterIntegrationStartup
            ? integrationWorkloadReady.future
            : null,
        interruption: interruptionWatch.future,
      );
      if (managedExit.timedOut) {
        final message = integrationWorkloadStarted
            ? 'Ensemble test worker timed out after '
                '${timeout?.inSeconds ?? 0}s of test execution.'
            : 'Flutter integration build/startup did not reach the first test within '
                '${_integrationStartupTimeout.inMinutes}m.';
        stderrBuffer.writeln(message);
        transcript.add('stderr', message);
      }
      if (managedExit.interrupted) {
        const message = 'Ensemble test worker interrupted by parent.';
        stderrBuffer.writeln(message);
        transcript.add('stderr', message);
      }
      try {
        await Future.wait([stdoutDone, stderrDone]).timeout(
          _processOutputDrainTimeout,
        );
      } on TimeoutException {
        // A descendant can inherit the worker's pipes and keep them open
        // after the worker itself was killed. Do not let that block report
        // generation forever; close both subscriptions and retain the
        // process result already obtained above.
        await Future.wait([
          stdoutSubscription.cancel(),
          stderrSubscription.cancel(),
        ]);
        stderrBuffer.writeln(
          'Timed out draining Flutter test worker output after '
          '${_processOutputDrainTimeout.inSeconds}s.',
        );
      }
      return _WorkerProcessResult(
        result: ProcessResult(
          process.pid,
          managedExit.exitCode,
          stdoutBuffer.toString(),
          stderrBuffer.toString(),
        ),
        orderedOutput: transcript.text,
        timedOut: managedExit.timedOut,
      );
    } finally {
      if (benchmarkBootstrap?.span.endUs == null) {
        benchmarkBootstrap?.span.outcome = 'workload-not-ready';
        benchmarkBootstrap?.finish();
      }
      heartbeat?.cancel();
      await interruptionWatch.close();
    }
  });
}

/// Test hook for the device-to-host artifact protocol.
Future<void> materializeTransportedArtifactsForTest(
  String appDir,
  String output,
) async {
  final result = await materializeTransportedArtifacts(
    artifactRoot: _artifactRootPath(appDir),
    output: output,
  );
  if (!result.complete) {
    throw StateError(result.error ?? 'Incomplete artifact transport.');
  }
}

Future<ProcessResult> _runProcess(
  String executable,
  List<String> arguments, {
  required String workingDirectory,
}) {
  final resolvedExecutable = executable == 'flutter'
      ? resolveFlutterExecutable(workingDirectory)
      : executable;
  return Process.run(
    resolvedExecutable,
    arguments,
    workingDirectory: workingDirectory,
    runInShell: false,
  );
}
