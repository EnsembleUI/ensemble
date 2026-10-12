import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:ensemble_test_runner/application/application_test_types.dart';
import 'package:ensemble_test_runner/execution/artifact_transport.dart';
import 'package:ensemble_test_runner/execution/device_discovery.dart';
import 'package:ensemble_test_runner/execution/execution_backend.dart';
import 'package:ensemble_test_runner/execution/host_address.dart';
import 'package:ensemble_test_runner/cli/ensemble_test_doctor.dart';
import 'package:ensemble_test_runner/cli/cli_process_output.dart';
import 'package:ensemble_test_runner/cli/cli_report_coordinator.dart';
import 'package:ensemble_test_runner/cli/cli_service_overrides.dart';
import 'package:ensemble_test_runner/cli/cli_test_selection.dart';
import 'package:ensemble_test_runner/cli/cli_compiled_plan_batch.dart';
import 'package:ensemble_test_runner/cli/cli_argument_options.dart';
import 'package:ensemble_test_runner/cli/cli_test_output_presenter.dart';
import 'package:ensemble_test_runner/cli/cli_worker_progress_output.dart';
import 'package:ensemble_test_runner/cli/cli_run_artifact_lock.dart';
import 'package:ensemble_test_runner/cli/cli_worker_workspace.dart';
import 'package:ensemble_test_runner/cli/process_lifecycle.dart';
import 'package:ensemble_test_runner/cli/worker_process_failure.dart';
import 'package:ensemble_test_runner/cli/cli_app_console_log.dart';
import 'package:ensemble_test_runner/cli/ensemble_test_cli_output.dart';
import 'package:ensemble_test_runner/cli/flutter_test_command.dart'
    as flutter_test_command;
import 'package:ensemble_test_runner/cli/cli_shard_planner.dart'
    as shard_planner;
import 'package:ensemble_test_runner/cli/app_patcher.dart';
import 'package:ensemble_test_runner/cli/test_timer_rewriter.dart';
import 'package:ensemble_test_runner/cli/flutter_command_resolver.dart';
import 'package:ensemble_test_runner/cli/ensemble_test_scaffold.dart';
import 'package:ensemble_test_runner/discovery/test_suite_source.dart';
import 'package:ensemble_test_runner/inspect/ensemble_app_inspector.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/reporters/atomic_file.dart';
import 'package:ensemble_test_runner/reporters/console_test_case.dart';
import 'package:ensemble_test_runner/runner/test_artifacts.dart';
import 'package:ensemble_test_runner/runner/test_service_manager.dart';
import 'package:ensemble_test_runner/runner/host_screenshot_optimizer.dart';
import 'package:ensemble_test_runner/src/worker_capacity.dart';
import 'package:ensemble_test_runner/src/cli/process_interruption_watch.dart';
import 'package:ensemble_test_runner/src/core/async_cleanup_stack.dart';
import 'package:ensemble_test_runner/validation/ensemble_test_validator.dart';
import 'package:path/path.dart' as p;

part 'ensemble_test_cli_worker_support.dart';
part 'ensemble_test_cli_run.dart';
part 'ensemble_test_cli_workers.dart';
part 'ensemble_test_cli_process.dart';
part 'ensemble_test_cli_device_support.dart';

String? _cachedSuiteEncryptionKey;

String _suiteEncryptionKey() {
  final existing = _cachedSuiteEncryptionKey;
  if (existing != null) return existing;
  const alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  final random = Random.secure();
  final key = List.generate(
    32,
    (_) => alphabet[random.nextInt(alphabet.length)],
  ).join();
  return _cachedSuiteEncryptionKey = key;
}

/// Runs declarative tests in an Ensemble app.
///
/// The host app must list `ensemble_test_runner` in `dev_dependencies`.
///
/// Options:
///   --app-dir=<path>   App directory (default: current directory)
///   --tests-dir=<path> YAML suite directory relative to the app root
///   --test-entry=<path> Application-owned Flutter test entry point
///   --doctor           Validate test setup without running Flutter tests
///   --fix             With --doctor, raise iOS deployment target permanently
///   --inspect-app      Print app metadata JSON for test generation
///   --validate-only    Validate declarative tests without running Flutter tests
///   --scaffold-test=<id> Create a starter test file
///   --report=json      Print JSON run results instead of the boxed report
///   --report-file=<path> Write JSON run results to a file
///   --id=<id>          Run matching test id(s); repeatable
///   --feature=<name>   Run matching feature(s); repeatable
///   --profile=<name>   Run matching profile(s); repeatable
///   --tag=<tag>        Run matching tag(s); repeatable
///   --path=<path>      Run matching test asset path(s); repeatable
///   --device=<id>      Run only these suite device id(s); repeatable (default: all)
///   --mode=<mode>      Execution mode: widget or integration
///   --device-id=<id>   Flutter target id for integration mode
///   --host-address=<ip> LAN address for physical iOS host services
///   --reset-device-storage  Wipe device storage before the suite (destructive)
///   --allow-device-storage-mutation  Acknowledge storage mutation on physical devices
///   --input key=value  Provide a test input for ${inputs.key}; repeatable
///   --jobs=<n|auto>    Concurrent jobs (default: adaptive CPU/memory; 1 disables)
///   --timeout=<duration> Test suite timeout, e.g. 30s, 5m, 1h (default: 10m)
///   --verbose          Full `flutter pub get` / `flutter test` output
///   --plan-batch-file=<path>  Opt-in compiled plan hand-off for workers
///   --help             Show this help without inspecting or changing an app
Future<void> runEnsembleTestsCli(List<String> arguments) async {
  if (arguments.contains('--help') || arguments.contains('-h')) {
    stdout.writeln(_cliHelp);
    return;
  }
  final verbose = isVerboseCli(arguments);
  final quiet = arguments.contains('--quiet');
  final reportMode = CliArgumentOptions.reportMode(arguments);
  final jsonReport = reportMode == 'json';
  final junitReport = reportMode == 'junit';
  final machineReport = jsonReport || junitReport;
  final streamLiveOutput = !quiet && !machineReport;
  final reportFile = CliArgumentOptions.reportFile(arguments);
  final appDir = CliArgumentOptions.appDirectory(arguments);
  final reportCoordinator = CliReportCoordinator(appDir);
  final workerWorkspace = CliWorkerWorkspace(appDir);
  final ownsFlutterKernelCache =
      flutter_test_command.isRunnerPackageRoot(Directory(appDir));
  try {
    flutter_test_command.validatePlanBatchFile(arguments);
  } on StateError catch (error) {
    stderr.writeln(error.message);
    exit(2);
  }
  final timeoutSeconds = CliArgumentOptions.timeoutSeconds(arguments);
  final jobs = CliArgumentOptions.jobsOverride(arguments);
  final testsDirOptions = CliTestSelection.values(arguments, '--tests-dir');
  final testEntryOptions = CliTestSelection.values(arguments, '--test-entry');
  if (testsDirOptions.length > 1 || testEntryOptions.length > 1) {
    stderr.writeln('--tests-dir and --test-entry may each be specified once.');
    exit(2);
  }
  final testEntry = testEntryOptions.isEmpty ? null : testEntryOptions.first;
  final explicitTestsDir =
      testsDirOptions.isEmpty ? null : testsDirOptions.first;
  if (explicitTestsDir != null &&
      testEntry == null &&
      !File(p.join(appDir, 'ensemble', 'ensemble-config.yaml')).existsSync()) {
    stderr.writeln(
      'Pure Flutter suites require --test-entry=<path> in addition to '
      '--tests-dir.',
    );
    exit(2);
  }
  late final TestAppPatcher patcher;
  try {
    patcher = TestAppPatcher(
      appDir,
      testsDirRelative:
          explicitTestsDir ?? (testEntry == null ? null : 'tests'),
      testEntryRelativePath: testEntry,
    );
  } on StateError catch (error) {
    stderr.writeln(error.message);
    exit(2);
  }

  if (!Directory(appDir).existsSync()) {
    stderr.writeln('App directory not found: $appDir');
    exit(2);
  }

  if (!File('${appDir}/pubspec.yaml').existsSync()) {
    stderr.writeln('No pubspec.yaml in $appDir');
    exit(2);
  }

  if (arguments.contains('--doctor')) {
    if (patcher.usesApplicationEntry) {
      final lines = <String>[
        'Ensemble test runner doctor (application-provided entry)',
        'App: $appDir',
        'Tests: ${patcher.testsDirRelative}',
        'Entry: ${patcher.activeEntryRelativePath}',
      ];
      var hasErrors = false;
      void error(String message) {
        hasErrors = true;
        lines.add('[ERROR] $message');
      }

      void ok(String message) => lines.add('[OK] $message');

      final testsRelative = patcher.testsDirRelative;
      if (testsRelative == null || testsRelative.isEmpty) {
        error('Missing --tests-dir for application-provided suites');
      } else {
        final testsDir = Directory(p.join(appDir, testsRelative));
        if (!testsDir.existsSync()) {
          error('Tests directory not found: $testsRelative');
        } else {
          ok('Found tests directory $testsRelative');
        }
      }

      final entryFile = File(p.join(appDir, patcher.activeEntryRelativePath));
      if (!entryFile.existsSync()) {
        error('test entry not found: ${patcher.activeEntryRelativePath}');
      } else {
        ok('test entry exists and will not be overwritten');
      }

      final result = EnsembleTestValidator(
        appDir,
        testsDirRelative: patcher.testsDirRelative,
        applicationProvided: true,
      ).validate();
      lines.addAll(result.formatText().split('\n'));
      stdout.writeln(lines.join('\n'));
      exit(hasErrors || result.hasErrors ? 1 : 0);
    }
    ExecutionMode? modeOverride;
    try {
      if (CliTestSelection.values(arguments, '--mode').isNotEmpty) {
        modeOverride = _resolveExecutionMode(
          arguments,
          ExecutionMode.widget,
        );
      }
    } catch (error) {
      stderr.writeln(error);
      exit(2);
    }
    final result = await EnsembleTestDoctor(
      appDir,
      modeOverride: modeOverride,
    ).run(fix: arguments.contains('--fix'));
    stdout.writeln(result.lines.join('\n'));
    exit(result.hasErrors ? 1 : 0);
  }

  if (arguments.contains('--inspect-app')) {
    if (patcher.usesApplicationEntry) {
      stdout.writeln(const JsonEncoder.withIndent('  ').convert({
        'launchKind': 'applicationProvided',
        'staticMetadataAvailable': false,
        'message':
            'Host widget and route metadata is available only at runtime.',
      }));
      exit(0);
    }
    try {
      stdout.writeln(EnsembleAppInspector(appDir).inspect().toPrettyJson());
      exit(0);
    } on StateError catch (error) {
      stderr.writeln(error.message);
      exit(2);
    }
  }

  if (arguments.contains('--validate-only')) {
    final result = EnsembleTestValidator(
      appDir,
      testsDirRelative: patcher.testsDirRelative,
      applicationProvided: patcher.usesApplicationEntry,
    ).validate();
    stdout.writeln(jsonReport ? result.toPrettyJson() : result.formatText());
    exit(result.hasErrors ? 2 : 0);
  }

  if (arguments.any((arg) =>
      arg == '--scaffold-test' || arg.startsWith('--scaffold-test='))) {
    try {
      final result = EnsembleTestScaffold(
        appDir,
        testsDirRelative: patcher.testsDirRelative,
        applicationProvided: patcher.usesApplicationEntry,
      ).create(arguments);
      stdout.writeln(
        result.created
            ? 'Created ${result.path}'
            : 'Test file already exists: ${result.path}',
      );
      exit(result.created ? 0 : 2);
    } on StateError catch (error) {
      stderr.writeln(error.message);
      exit(2);
    }
  }

  final testsDirRelative = patcher.testsDirRelative;
  if (testsDirRelative == null) {
    stderr.writeln(
      'Could not find definitions.local.path in ensemble/ensemble-config.yaml.\n'
      'Declarative tests must live under definitions.local.path/tests.',
    );
    exit(2);
  }
  final suiteSource = TestSuiteSource(
    appDirectory: appDir,
    testsDirectory: testsDirRelative,
    testsAssetPrefix: testsDirRelative.endsWith('/')
        ? testsDirRelative
        : '$testsDirRelative/',
    testEntryPath: patcher.activeEntryRelativePath,
    launchKind: patcher.usesApplicationEntry
        ? TestApplicationLaunchKind.applicationProvided
        : TestApplicationLaunchKind.standaloneEnsemble,
  );

  if (!patcher.hasTestsOnDisk) {
    stderr.writeln(
      'No declarative tests found. Add *.test.yaml files under '
      '$testsDirRelative/',
    );
    exit(2);
  }

  late final ExecutionMode executionMode;
  late EnsembleTestConfig suiteConfig;
  try {
    suiteConfig = shard_planner.readCliTestsConfigStrict(patcher.testsDirPath!);
    executionMode =
        CliArgumentOptions.executionMode(arguments, suiteConfig.mode);
    CliArgumentOptions.validateExecutionModeOptions(
      arguments,
      mode: executionMode,
      config: suiteConfig,
      jobs: jobs,
    );
  } catch (error) {
    stderr.writeln(error);
    exit(2);
  }

  final executionBackend = executionBackendFor(executionMode);

  FlutterDevice? integrationDevice;
  try {
    integrationDevice = await executionBackend.selectDevice(arguments);
    if (integrationDevice != null) {
      _validatePlatformProject(appDir, integrationDevice.platform);
      suiteConfig = shard_planner.applyCliIntegrationDeviceMatrix(
        suiteConfig,
        platform: integrationDevice.platform,
        arguments: arguments,
        quiet: quiet,
      );
      if (!integrationDevice.isVirtual &&
          !arguments.contains('--allow-device-storage-mutation') &&
          !arguments.contains('--reset-device-storage')) {
        throw StateError(
          'Physical device ${integrationDevice.display} will mutate app '
          'storage during the suite. Pass --allow-device-storage-mutation '
          'to acknowledge this, or --reset-device-storage to wipe storage '
          'first on a disposable device.',
        );
      }
    }
  } catch (error) {
    stderr.writeln(error);
    exit(2);
  }

  final artifactLock = CliRunArtifactLock(appDir);
  if (!artifactLock.acquire()) {
    stderr.writeln(
      'Another Ensemble test run is already using the app artifact directory. '
      'Wait for it to finish before starting another run.',
    );
    exit(3);
  }

  if (ownsFlutterKernelCache) {
    try {
      // Reclaim cache left by an interrupted runner invocation before creating
      // more build artifacts. App-owned build caches are never pruned here.
      flutter_test_command.pruneFlutterTestKernelCache(Directory(appDir));
    } catch (_) {
      // Cache maintenance is best effort and must not strand the run lock.
    }
  }
  await _executeCliRun(
    arguments: arguments,
    appDir: appDir,
    patcher: patcher,
    artifactLock: artifactLock,
    pruneKernelCache: ownsFlutterKernelCache,
    verbose: verbose,
    quiet: quiet,
    machineReport: machineReport,
    jsonReport: jsonReport,
    junitReport: junitReport,
    streamLiveOutput: streamLiveOutput,
    reportMode: reportMode,
    reportFile: reportFile,
    timeoutSeconds: timeoutSeconds,
    jobs: jobs,
    suiteConfig: suiteConfig,
    executionMode: executionMode,
    executionBackend: executionBackend,
    integrationDevice: integrationDevice,
    suiteSource: suiteSource,
    reportCoordinator: reportCoordinator,
    workerWorkspace: workerWorkspace,
  );
}

const _cliHelp = '''Ensemble Test Runner

Usage: ensemble test [options]

Options:
  --app-dir=<path>       App directory (default: current directory)
  --tests-dir=<path>     Test suite directory relative to the app root
  --test-entry=<path>    Application-owned Flutter test entry point
  --doctor               Validate test setup without running tests
  --fix                  With --doctor, raise iOS deployment target
  --inspect-app          Print app metadata JSON
  --validate-only        Validate tests without running Flutter tests
  --scaffold-test=<id>   Create a starter test file
  --report=json|junit    Print machine-readable results
  --report-file=<path>   Write JSON run results to a file
  --id=<id>              Run matching test id(s); repeatable
  --feature=<name>       Run matching feature(s); repeatable
  --profile=<name>       Run matching profile(s); repeatable
  --tag=<tag>            Run matching tag(s); repeatable
  --path=<path>          Run matching test asset path(s); repeatable
  --device=<id>          Run only these suite device id(s); repeatable
  --mode=widget|integration
  --device-id=<id>       Flutter target id for integration mode
  --host-address=<ip>    LAN address for physical iOS host services
  --input key=value      Provide a test input; repeatable
  --jobs=<n|auto>        Concurrent workers (default: adaptive; 1 disables)
  --timeout=<duration>   Suite timeout, e.g. 30s, 5m, 1h
  --verbose              Full Flutter command output
  --help, -h             Show this help
''';

EnsembleTestRunResult _mergeWorkerReports(
  List<ProcessResult> results, {
  required List<String> reportFiles,
  List<List<String>> expectedWorkerTestIds = const [],
  required String appDir,
  List<String> orderedOutputs = const [],
}) {
  return RunnerBenchmark.sync('worker', 'mergeWorkerReports', () {
    final mergedResults = <EnsembleSingleTestResult>[];
    final suiteLogs = <String>[];
    final metadata = <String, dynamic>{};
    final seenPassedTestIds = <String>{};

    for (var i = 0; i < results.length; i++) {
      final result = results[i];
      final processOutput = '${result.stdout ?? ''}\n${result.stderr ?? ''}';
      final output =
          i < orderedOutputs.length ? orderedOutputs[i] : processOutput;
      final reportFile = i < reportFiles.length ? File(reportFiles[i]) : null;
      final rawJson = reportFile != null && reportFile.existsSync()
          ? reportFile.readAsStringSync()
          : extractJsonReport(processOutput);
      if (rawJson.isEmpty) {
        final workerOutputFile = _writeWorkerOutputLog(appDir, i, output);
        final workerFailures = workerProcessFailureResults(
          result,
          workerIndex: i,
          outputFile: workerOutputFile,
          expectedTestIds: i < expectedWorkerTestIds.length
              ? expectedWorkerTestIds[i]
              : const [],
        );
        mergedResults.addAll(workerFailures.isNotEmpty
            ? workerFailures
            : [
                EnsembleSingleTestResult.failed(
                  testId: 'test-process-${result.pid}',
                  durationMs: 0,
                  message: 'A test process did not emit an Ensemble JSON report'
                      '${workerOutputFile == null ? '' : '. See $workerOutputFile'}',
                  failure: TestFailureDetails(
                    kind: TestFailureKind.incompleteExecution,
                    message:
                        'A test process did not emit an Ensemble JSON report',
                    phase: 'worker',
                  ),
                )
              ]);
        continue;
      }

      late final EnsembleTestRunResult workerRun;
      try {
        final decoded = json.decode(rawJson) as Map<String, dynamic>;
        workerRun = _runResultFromJson(decoded);
      } catch (error) {
        final workerOutputFile = _writeWorkerOutputLog(appDir, i, output);
        mergedResults.addAll(
          workerReportDecodeFailureResults(
            workerIndex: i,
            error: error,
            expectedTestIds: i < expectedWorkerTestIds.length
                ? expectedWorkerTestIds[i]
                : const [],
            outputFile: workerOutputFile,
          ),
        );
        continue;
      }
      metadata.addAll(workerRun.metadata);
      suiteLogs.addAll(workerRun.suiteLogs);
      for (final test in workerRun.results) {
        final baseId = _baseTestId(test.testId);
        if (test.status == TestStatus.passed &&
            !seenPassedTestIds.add(baseId)) {
          continue;
        }
        mergedResults.add(test);
      }
      final workerFailures = workerProcessFailureResults(
        result,
        workerIndex: i,
        reportHasFailures: workerRun.failedCount > 0,
        reportHasResults: workerRun.results.isNotEmpty,
        expectedTestIds: i < expectedWorkerTestIds.length
            ? expectedWorkerTestIds[i]
            : const [],
        reportedTestIds: workerRun.results.map((test) => test.testId),
      );
      mergedResults.addAll(workerFailures);
    }

    return EnsembleTestRunResult(
      results: mergedResults,
      suiteLogs: suiteLogs,
      metadata: metadata,
    );
  });
}

String? _writeWorkerOutputLog(String appDir, int workerIndex, String output) {
  if (output.trim().isEmpty) return null;
  final file = File(
    p.join(
      appDir,
      'build',
      'ensemble_test_runner',
      'diagnostics',
      'test_process_${workerIndex + 1}_output.log',
    ),
  );
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(output);
  return p.relative(file.path, from: appDir).replaceAll('\\', '/');
}

String _formatCliSummary(
  EnsembleTestRunResult result, {
  String? testFile,
  int? wallTimeMs,
}) {
  final buffer = StringBuffer();
  buffer.writeln('┌─ Ensemble tests ─────────────────────────────');
  if (testFile != null) {
    buffer.writeln('│  $testFile');
  }
  final mode = result.metadata['mode']?.toString();
  final device = result.metadata['deviceName']?.toString() ??
      result.metadata['deviceId']?.toString();
  if (mode != null) {
    buffer.writeln('│  mode: $mode${device == null ? '' : ' · $device'}');
  }
  if (testFile != null || mode != null) buffer.writeln('│');

  for (var i = 0; i < result.results.length; i++) {
    if (i > 0) buffer.writeln('│');
    writeConsoleTestCase(
      buffer,
      result.results[i],
      includeFailureKind: false,
    );
  }

  final suiteArtifacts = durableArtifactLogs(result.suiteLogs).toList();
  if (suiteArtifacts.isNotEmpty) {
    buffer.writeln('│');
    buffer.writeln('│  suite artifacts:');
    for (final log in suiteArtifacts) {
      buffer.writeln('│       $log');
    }
  }

  buffer.writeln('│');
  final durationText = wallTimeMs == null
      ? '${result.results.fold<int>(0, (sum, r) => sum + r.durationMs)}ms total'
      : '${wallTimeMs}ms';
  buffer.writeln('└─ ${result.summary} · $durationText');
  return buffer.toString();
}

String _baseTestId(String value) {
  final index = value.indexOf('  (');
  return index == -1 ? value : value.substring(0, index);
}

ExecutionMode _resolveExecutionMode(
  List<String> arguments,
  ExecutionMode configured,
) =>
    CliArgumentOptions.executionMode(arguments, configured);

/// Test hook for CLI precedence without launching a subprocess.
ExecutionMode resolveExecutionModeForTest(
  List<String> arguments,
  ExecutionMode configured,
) =>
    CliArgumentOptions.executionMode(arguments, configured);

/// Test hook for validating worker report recovery without launching Flutter.
EnsembleTestRunResult mergeWorkerReportsForTest({
  required List<ProcessResult> results,
  required List<String> reportFiles,
  required List<List<String>> expectedWorkerTestIds,
  required String appDir,
}) =>
    _mergeWorkerReports(
      results,
      reportFiles: reportFiles,
      expectedWorkerTestIds: expectedWorkerTestIds,
      appDir: appDir,
    );

/// Test hook for execution-mode option compatibility.
void validateExecutionModeOptionsForTest(
  List<String> arguments, {
  required ExecutionMode mode,
  required EnsembleTestConfig config,
  int? jobs,
}) =>
    CliArgumentOptions.validateExecutionModeOptions(
      arguments,
      mode: mode,
      config: config,
      jobs: jobs,
    );

/// Test hook for deterministic device filtering and non-interactive selection.
String selectIntegrationDeviceIdForTest(
  String machineJson, {
  String? requestedId,
}) =>
    CliArgumentOptions.selectIntegrationDeviceId(
      machineJson,
      requestedId: requestedId,
    );

/// Internal benchmark adapter to the actual CLI worker launch/merge pipeline.
/// It cannot be used without an active standalone benchmark collector.
Future<ProcessResult> runRunnerWorkersForBenchmark({
  required String appDir,
  required int workers,
  required String testsDir,
  required String testEntry,
}) {
  if (RunnerBenchmark.collector == null) {
    throw StateError('Worker benchmarks require the standalone benchmark tool');
  }
  return _runParallelFlutterTests(
    const [],
    appDir: appDir,
    flutterExecutable: resolveFlutterExecutable(appDir),
    patcher: TestAppPatcher(appDir,
        testsDirRelative: testsDir, testEntryRelativePath: testEntry),
    timerRewritePlan: TestTimerRewritePlan.forApp(
      appDir: appDir,
      testsDirRelative: testsDir,
    ),
    jobs: workers,
    reportMode: 'json',
    reportFile: p.join(appDir, 'merged.json'),
    timeoutSeconds: 120,
    quiet: true,
    machineReport: true,
    suiteConfig: const EnsembleTestConfig(),
  );
}
