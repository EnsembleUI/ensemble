import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ensemble_test_runner/cli/ensemble_test_doctor.dart';
import 'package:ensemble_test_runner/cli/ensemble_test_cli_output.dart';
import 'package:ensemble_test_runner/cli/yaml_test_app_patcher.dart';
import 'package:ensemble_test_runner/cli/ensemble_test_scaffold.dart';
import 'package:ensemble_test_runner/inspect/ensemble_app_inspector.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/parser/ensemble_test_parser.dart';
import 'package:ensemble_test_runner/reporters/html_test_reporter.dart';
import 'package:ensemble_test_runner/reporters/step_outline_format.dart';
import 'package:ensemble_test_runner/validation/ensemble_test_validator.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

const _maxAppConsoleLogBytes = 5 * 1024 * 1024;
final _appConsoleLogBytes = <String, int>{};
final _disabledAppConsoleLogs = <String>{};

/// Runs declarative YAML tests in an Ensemble app.
///
/// The host app must list `ensemble_test_runner` in `dev_dependencies`.
///
/// Options:
///   --app-dir=<path>   App directory (default: current directory)
///   --doctor           Validate test setup without running Flutter tests
///   --inspect-app      Print app metadata JSON for test generation
///   --validate-only    Validate YAML tests without running Flutter tests
///   --scaffold-test=<id> Create a starter test file
///   --report=json      Print JSON run results instead of the boxed report
///   --report-file=<path> Write JSON run results to a file
///   --id=<id>          Run matching test id(s); repeatable
///   --feature=<name>   Run matching feature(s); repeatable
///   --tag=<tag>        Run matching tag(s); repeatable
///   --path=<path>      Run matching test asset path(s); repeatable
///   --device=<id>      Run only these suite device id(s); repeatable (default: all)
///   --input key=value  Provide a test input for ${inputs.key}; repeatable
///   --jobs=<n|auto>    Concurrent job count (default: auto for full suites; 1 disables)
///   --timeout=<duration> Test suite timeout, e.g. 30s, 5m, 1h (default: 10m)
///   --verbose          Full `flutter pub get` / `flutter test` output
Future<void> runEnsembleYamlTestsCli(List<String> arguments) async {
  final verbose = isVerboseCli(arguments);
  final quiet = arguments.contains('--quiet');
  final reportMode = _resolveReportMode(arguments);
  final jsonReport = reportMode == 'json';
  final junitReport = reportMode == 'junit';
  final machineReport = jsonReport || junitReport;
  final streamLiveOutput = !quiet && !machineReport;
  final reportFile = _resolveReportFile(arguments);
  final appDir = _resolveAppDir(arguments);
  final timeoutSeconds = _resolveTimeoutSeconds(arguments);
  final jobs = _resolveJobsOverride(arguments);
  final patcher = YamlTestAppPatcher(appDir);

  if (!Directory(appDir).existsSync()) {
    stderr.writeln('App directory not found: $appDir');
    exit(2);
  }

  if (!File('${appDir}/pubspec.yaml').existsSync()) {
    stderr.writeln('No pubspec.yaml in $appDir');
    exit(2);
  }

  if (arguments.contains('--doctor')) {
    final result = await EnsembleTestDoctor(appDir).run();
    stdout.writeln(result.lines.join('\n'));
    exit(result.hasErrors ? 1 : 0);
  }

  if (arguments.contains('--inspect-app')) {
    try {
      stdout.writeln(EnsembleAppInspector(appDir).inspect().toPrettyJson());
      exit(0);
    } on StateError catch (error) {
      stderr.writeln(error.message);
      exit(2);
    }
  }

  if (arguments.contains('--validate-only')) {
    final result = EnsembleTestValidator(appDir).validate();
    stdout.writeln(jsonReport ? result.toPrettyJson() : result.formatText());
    exit(result.hasErrors ? 2 : 0);
  }

  if (arguments.any((arg) =>
      arg == '--scaffold-test' || arg.startsWith('--scaffold-test='))) {
    try {
      final result = EnsembleTestScaffold(appDir).create(arguments);
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

  if (!patcher.hasTestYamlOnDisk) {
    stderr.writeln(
      'No declarative tests found. Add *.test.yaml files under '
      '$testsDirRelative/',
    );
    exit(2);
  }

  var exitCode = 0;
  try {
    _writeStatus(
      'Preparing Ensemble YAML tests...',
      quiet: quiet,
      machineReport: machineReport,
    );
    patcher.enable();

    if (patcher.pubspecChanged) {
      _writeStatus(
        'Resolving Flutter dependencies...',
        quiet: quiet,
        machineReport: machineReport,
      );
      final pubGet = await _runProcess(
        'flutter',
        ['pub', 'get', '--suppress-analytics'],
        workingDirectory: appDir,
      );
      if (pubGet.exitCode != 0 || verbose) {
        _writeProcessStreams(pubGet);
      }
      if (pubGet.exitCode != 0) {
        exitCode = 2;
        return;
      }
    }

    _writeStatus(
      'Running Ensemble YAML tests...',
      quiet: quiet,
      machineReport: machineReport,
    );

    if (!machineReport) {
      try {
        final discovered = _discoverAllTestRuns(appDir, patcher);
        if (discovered.isNotEmpty) {
          _withHtmlReport(
            appDir,
            EnsembleTestRunResult(results: discovered),
            wallTimeMs: 0,
            isSuiteRunning: true,
          );
        }
      } catch (_) {}
    }
    if (_hasSelection(arguments) && jobs != null && jobs > 1) {
      throw StateError(
        '--jobs currently runs full suites only. Remove --id/--feature/--tag/--path '
        'or run the selected tests serially.',
      );
    }
    final runSerial = jobs == 1 || _hasSelection(arguments);
    final serialWorkingDirectory = runSerial && patcher.hasTimerRewrites
        ? _prepareWorkerDirectory(appDir, 0, patcher)
        : appDir;
    final serialServiceOverrides = runSerial
        ? await _resolveServiceOverrides(
            patcher: patcher,
            usedPorts: <int>{},
          )
        : null;
    final testRun = runSerial
        ? await _runFlutterTestProcess(
            'flutter',
            _buildFlutterTestArgs(
              arguments,
              reportMode: reportMode,
              reportFile: reportFile,
              timeoutSeconds: timeoutSeconds,
              verbose: verbose,
              appLogPath: patcher.hasTimerRewrites
                  ? _appConsoleLogFile(appDir)
                  : _appConsoleLogPath(),
              appLogDisplayPath:
                  patcher.hasTimerRewrites ? _appConsoleLogPath() : null,
              artifactRoot:
                  patcher.hasTimerRewrites ? _artifactRootPath(appDir) : null,
              serviceOverrides: serialServiceOverrides,
            ),
            workingDirectory: serialWorkingDirectory,
            streamOutput: streamLiveOutput,
            verbose: verbose,
            appLogFile: _appConsoleLogFile(appDir),
          )
        : await _runParallelFlutterTests(
            arguments,
            appDir: appDir,
            patcher: patcher,
            jobs: jobs,
            reportMode: reportMode,
            reportFile: reportFile,
            timeoutSeconds: timeoutSeconds,
            quiet: quiet,
            machineReport: machineReport,
          );

    if (testRun.exitCode != 0 && !verbose) {
      final output = '${testRun.stdout ?? ''}\n${testRun.stderr ?? ''}';
      final rawJson = extractJsonReport(output);
      final json = jsonReport ? rawJson : '';
      final junit = junitReport ? extractJunitReport(output) : '';
      final report = machineReport
          ? ''
          : extractSuiteReport(
              output,
              includeScreenTracker: !streamLiveOutput,
            );
      final knownFailure = extractKnownFailure(output);
      if (junit.isNotEmpty) {
        stdout.writeln(junit);
      } else if (json.isNotEmpty) {
        stdout.writeln(json);
      } else if (report.isNotEmpty) {
        stdout.write(report);
        if (!report.endsWith('\n')) stdout.writeln();
      } else if (knownFailure.isNotEmpty) {
        stderr.writeln(knownFailure);
      } else {
        _writeProcessStreams(testRun);
      }
    } else if (!verbose && testRun.exitCode != 0) {
      _writeProcessStreams(testRun);
    } else if (verbose) {
      // Output was already streamed live.
    } else {
      final out = testRun.stdout?.toString() ?? '';
      final rawJson = extractJsonReport(out);
      final json = jsonReport ? rawJson : '';
      final junit = junitReport ? extractJunitReport(out) : '';
      final report = junit.isNotEmpty
          ? junit
          : json.isNotEmpty
              ? json
              : extractSuiteReport(
                  out,
                  includeScreenTracker: !streamLiveOutput,
                );
      if (report.isNotEmpty) {
        stdout.write(report);
        if (!report.endsWith('\n')) stdout.writeln();
      } else {
        _writeProcessStreams(testRun);
      }
      final err = testRun.stderr?.toString() ?? '';
      if (err.isNotEmpty && !isBenignFlutterTestStderr(err)) {
        stderr.write(err);
      }
    }

    final machineResult = _runResultFromProcessOutput(testRun);
    exitCode = machineResult == null
        ? (testRun.exitCode == 0 ? 0 : 1)
        : (machineResult.failedCount == 0 ? 0 : 1);
  } on StateError catch (error) {
    stderr.writeln(error.message);
    exitCode = 3;
  } finally {
    // Serial timer-rewrite runs also use a worker sandbox; always drop leftovers.
    _cleanWorkerDirectories(appDir);
    patcher.restore();
  }
  exit(exitCode);
}

List<String> _selectionDartDefines(List<String> arguments) {
  final values = {
    'ensembleTestId': _optionValues(arguments, '--id'),
    'ensembleTestFeature': _optionValues(arguments, '--feature'),
    'ensembleTestTag': _optionValues(arguments, '--tag'),
    'ensembleTestPath': _optionValues(arguments, '--path'),
    'ensembleTestDevice': _optionValues(arguments, '--device'),
  };
  return [
    for (final entry in values.entries)
      if (entry.value.isNotEmpty)
        '--dart-define=${entry.key}=${entry.value.join(',')}',
  ];
}

List<String> _buildFlutterTestArgs(
  List<String> arguments, {
  required String? reportMode,
  required String? reportFile,
  required int? timeoutSeconds,
  required bool verbose,
  List<String> shardPaths = const [],
  int? workerIndex,
  String? progressFile,
  String? appLogPath,
  String? appLogDisplayPath,
  String? artifactRoot,
  Map<String, dynamic>? serviceOverrides,
  String artifactDisplayRoot = 'build/ensemble_test_runner',
}) {
  return [
    'test',
    YamlTestAppPatcher.testEntryRelativePath,
    '--no-pub',
    if (reportMode != null) '--dart-define=ensembleTestReport=$reportMode',
    '--dart-define=ensembleTestEmitJsonReport=true',
    if (reportFile != null) '--dart-define=ensembleTestReportFile=$reportFile',
    if (timeoutSeconds != null)
      '--dart-define=ensembleTestTimeoutSeconds=$timeoutSeconds',
    if (workerIndex != null) ...[
      '--dart-define=ensembleTestWorkerIndex=$workerIndex',
      '--dart-define=ensembleTestWorkerSuffix=worker${workerIndex + 1}',
    ],
    if (progressFile != null)
      '--dart-define=ensembleTestProgressFile=$progressFile',
    if (appLogPath != null) '--dart-define=ensembleTestAppLogFile=$appLogPath',
    if (appLogDisplayPath != null)
      '--dart-define=ensembleTestAppLogDisplayFile=$appLogDisplayPath',
    if (artifactRoot != null)
      '--dart-define=ensembleTestArtifactRoot=$artifactRoot',
    if (serviceOverrides != null && serviceOverrides.isNotEmpty)
      '--dart-define=ensembleTestServiceOverrides=${json.encode(serviceOverrides)}',
    '--dart-define=ensembleTestArtifactDisplayRoot=$artifactDisplayRoot',
    ..._inputDartDefines(arguments),
    ..._selectionDartDefines(arguments),
    if (shardPaths.isNotEmpty)
      '--dart-define=ensembleTestPath=${shardPaths.join(',')}',
    '--reporter',
    verbose ? 'expanded' : 'silent',
    ...flutterTestArguments(arguments),
  ];
}

Future<Map<String, dynamic>> _resolveServiceOverrides({
  required YamlTestAppPatcher patcher,
  required Set<int> usedPorts,
  int preferredOffset = 0,
}) async {
  final testsDir = patcher.testsDirPath;
  if (testsDir == null) return const {};
  final configFile = File(p.join(testsDir, 'config.yaml'));
  if (!configFile.existsSync()) return const {};

  final config = EnsembleTestParser.parseConfigString(
    configFile.readAsStringSync(),
    sourcePath: configFile.path,
  );
  if (config.services.isEmpty) return const {};

  final overrides = <String, dynamic>{};
  for (final service in config.services) {
    final resolvedUrl = await _allocateServiceUrl(
      service.url,
      usedPorts: usedPorts,
      preferredOffset: preferredOffset,
    );
    if (resolvedUrl == null) continue;
    final uri = Uri.parse(resolvedUrl);
    overrides[service.name] = {
      'url': resolvedUrl,
      'environment': {
        'PORT': '${uri.port}',
      },
    };
  }
  return overrides;
}

Future<String?> _allocateServiceUrl(
  String? configuredUrl, {
  required Set<int> usedPorts,
  required int preferredOffset,
}) async {
  final baseUri = _serviceBaseUri(configuredUrl);
  if (baseUri == null) return null;
  final configuredPort = baseUri.hasPort ? baseUri.port : null;
  final preferredPort =
      configuredPort == null ? null : configuredPort + preferredOffset;
  final port = await _allocateTcpPort(
    preferredPort: preferredPort,
    usedPorts: usedPorts,
  );
  return baseUri.replace(port: port).toString();
}

Uri? _serviceBaseUri(String? configuredUrl) {
  if (configuredUrl == null || configuredUrl.trim().isEmpty) {
    return Uri.parse('http://127.0.0.1');
  }
  final uri = Uri.tryParse(configuredUrl.trim());
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
  return uri;
}

Future<int> _allocateTcpPort({
  required int? preferredPort,
  required Set<int> usedPorts,
}) async {
  if (preferredPort != null &&
      preferredPort > 0 &&
      !usedPorts.contains(preferredPort) &&
      await _isTcpPortAvailable(preferredPort)) {
    usedPorts.add(preferredPort);
    return preferredPort;
  }

  while (true) {
    final socket = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    final port = socket.port;
    await socket.close();
    if (usedPorts.add(port)) return port;
  }
}

Future<bool> _isTcpPortAvailable(int port) async {
  try {
    final socket = await ServerSocket.bind(InternetAddress.anyIPv4, port);
    await socket.close();
    return true;
  } on SocketException {
    return false;
  }
}

Future<ProcessResult> _runParallelFlutterTests(
  List<String> arguments, {
  required String appDir,
  required YamlTestAppPatcher patcher,
  required int? jobs,
  required String? reportMode,
  required String? reportFile,
  required int? timeoutSeconds,
  required bool quiet,
  required bool machineReport,
}) async {
  final testFiles = _testFilesForSharding(appDir, patcher);
  final allFiles = [
    ...testFiles.parallel.map((file) => file.path),
    ...testFiles.serial,
  ];
  if (allFiles.length < 2) {
    return _runFlutterTestProcess(
      'flutter',
      _buildFlutterTestArgs(
        arguments,
        reportMode: reportMode,
        reportFile: reportFile,
        timeoutSeconds: timeoutSeconds,
        verbose: false,
        appLogPath: _appConsoleLogPath(),
      ),
      workingDirectory: appDir,
      streamOutput: false,
      verbose: false,
      appLogFile: _appConsoleLogFile(appDir),
    );
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
    return _runFlutterTestProcess(
      'flutter',
      _buildFlutterTestArgs(
        arguments,
        reportMode: reportMode,
        reportFile: reportFile,
        timeoutSeconds: timeoutSeconds,
        verbose: false,
        appLogPath: _appConsoleLogPath(),
      ),
      workingDirectory: appDir,
      streamOutput: false,
      verbose: false,
      appLogFile: _appConsoleLogFile(appDir),
    );
  }
  final shards = _balancedShards(testFiles.parallel, parallelWorkerCount);

  _cleanParallelRunArtifacts(appDir);
  _writeStatus(
    'Running ${allFiles.length} test files...',
    quiet: quiet,
    machineReport: machineReport,
  );

  final elapsed = Stopwatch()..start();
  final artifactRoot = _artifactRootPath(appDir);
  final futures = <Future<ProcessResult>>[];
  final workerReportFiles = <String>[];
  final workerProgressFiles = <String>[];
  final showProgress = !quiet && !machineReport;
  final usedServicePorts = <int>{};
  for (var i = 0; i < parallelWorkerCount; i++) {
    final shard = shards[i].map((file) => file.path).toList();
    if (shard.isEmpty) continue;
    final workerReportFile = _workerReportFile(appDir, i);
    final workerProgressFile = _workerProgressFile(appDir, i);
    _deleteIfExists(workerReportFile);
    _deleteIfExists(workerProgressFile);
    workerReportFiles.add(workerReportFile);
    workerProgressFiles.add(workerProgressFile);
    final workerDirectory = _prepareWorkerDirectory(appDir, i, patcher);
    final serviceOverrides = await _resolveServiceOverrides(
      patcher: patcher,
      preferredOffset: i,
      usedPorts: usedServicePorts,
    );
    futures.add(
      _runTimedFlutterTestProcess(
        reportFile: workerReportFile,
        run: () => _runFlutterTestProcess(
          'flutter',
          _buildFlutterTestArgs(
            arguments,
            reportMode: 'json',
            reportFile: workerReportFile,
            timeoutSeconds: timeoutSeconds,
            verbose: false,
            shardPaths: shard,
            workerIndex: i,
            progressFile: showProgress ? workerProgressFile : null,
            appLogPath: _appConsoleLogFile(appDir, workerIndex: i),
            appLogDisplayPath: _appConsoleLogPath(workerIndex: i),
            artifactRoot: artifactRoot,
            serviceOverrides: serviceOverrides,
          ),
          workingDirectory: workerDirectory,
          streamOutput: false,
          verbose: false,
          appLogFile: _appConsoleLogFile(workerDirectory, workerIndex: i),
        ),
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
    workerProgressFiles.add(workerProgressFile);
    final workerDirectory =
        _prepareWorkerDirectory(appDir, serialWorkerIndex, patcher);
    final serviceOverrides = await _resolveServiceOverrides(
      patcher: patcher,
      preferredOffset: serialWorkerIndex,
      usedPorts: usedServicePorts,
    );
    futures.add(
      _runTimedFlutterTestProcess(
        reportFile: workerReportFile,
        run: () => _runFlutterTestProcess(
          'flutter',
          _buildFlutterTestArgs(
            arguments,
            reportMode: 'json',
            reportFile: workerReportFile,
            timeoutSeconds: timeoutSeconds,
            verbose: false,
            shardPaths: testFiles.serial,
            workerIndex: serialWorkerIndex,
            progressFile: showProgress ? workerProgressFile : null,
            appLogPath: _appConsoleLogFile(
              appDir,
              workerIndex: serialWorkerIndex,
            ),
            appLogDisplayPath: _appConsoleLogPath(
              workerIndex: serialWorkerIndex,
            ),
            artifactRoot: artifactRoot,
            serviceOverrides: serviceOverrides,
          ),
          workingDirectory: workerDirectory,
          streamOutput: false,
          verbose: false,
          appLogFile: _appConsoleLogFile(
            workerDirectory,
            workerIndex: serialWorkerIndex,
          ),
        ),
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
  final workerResults = await Future.wait(futures);
  runDone = true;
  await progressPoller;

  try {
    for (var i = 0; i < workerReportFiles.length; i++) {
      _copyWorkerArtifacts(appDir, i);
    }
  } finally {
    // Worker sandboxes only exist to isolate Flutter build/ output and timer
    // rewrites. Artifacts are copied above; drop the trees so they do not keep
    // multi‑GB compile caches around after the run.
    _cleanWorkerDirectories(appDir);
  }
  var merged = _mergeWorkerReports(
    workerResults,
    reportFiles: workerReportFiles,
    appDir: appDir,
  );
  merged = _mergeParallelSuiteArtifacts(merged);
  merged = _withHtmlReport(
    appDir,
    merged,
    wallTimeMs: elapsed.elapsedMilliseconds,
  );
  _writeHistoricalDurations(appDir, merged);
  final output = StringBuffer();
  if (reportMode == 'json') {
    output.writeln(json.encode(merged.toJson()));
  } else if (reportMode == 'junit') {
    output.writeln(_junitReportForCli(merged));
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
    File(reportFile).writeAsStringSync(
      reportMode == 'junit'
          ? _junitReportForCli(merged)
          : json.encode(merged.toJson()),
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
}

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
  );
}

Future<ProcessResult> _runTimedFlutterTestProcess({
  required String reportFile,
  required Future<ProcessResult> Function() run,
}) async {
  final stopwatch = Stopwatch()..start();
  final result = await run();
  stopwatch.stop();
  _annotateWorkerReportDuration(reportFile, stopwatch.elapsedMilliseconds);
  return result;
}

void _annotateWorkerReportDuration(String reportFile, int durationMs) {
  final file = File(reportFile);
  if (!file.existsSync()) return;
  try {
    final decoded = json.decode(file.readAsStringSync());
    if (decoded is! Map) return;
    final updated = Map<String, dynamic>.from(decoded)
      ..['durationMs'] = durationMs;
    file.writeAsStringSync(json.encode(updated));
  } catch (_) {
    // Keep the original report if it cannot be decoded.
  }
}

void _cleanParallelRunArtifacts(String appDir) {
  final root = Directory(p.join(appDir, 'build', 'ensemble_test_runner'));
  for (final name in const [
    'logs',
    'screenshots',
    'worker_progress',
    'worker_reports',
  ]) {
    final directory = Directory(p.join(root.path, name));
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  }
}

/// Deletes `build/ensemble_test_runner/workers/` after a run.
///
/// Worker directories are disposable sandboxes (symlinked sources + per-worker
/// Flutter `build/` caches). Suite artifacts are copied out first; keeping the
/// trees only wastes disk.
void _cleanWorkerDirectories(String appDir) {
  final directory = Directory(
    p.join(appDir, 'build', 'ensemble_test_runner', 'workers'),
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

String _appConsoleLogPath({int? workerIndex}) {
  final name = workerIndex == null
      ? 'app_console.log'
      : 'app_console_${workerIndex + 1}.log';
  return p.join('build', 'ensemble_test_runner', 'logs', name);
}

String _appConsoleLogFile(String appDir, {int? workerIndex}) {
  return p.join(appDir, _appConsoleLogPath(workerIndex: workerIndex));
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
  for (var i = 0; i < progressFiles.length; i++) {
    final path = progressFiles[i];
    final file = File(path);
    if (!file.existsSync()) continue;
    final lines =
        file.readAsLinesSync().where((line) => line.trim().isNotEmpty).toList();
    final seen = seenLines[path] ?? 0;
    if (seen >= lines.length) continue;
    for (final line in lines.skip(seen)) {
      final event = _decodeProgressEvent(line);
      if (event == null) continue;
      stderr.writeln(_formatProgressEvent(event));
    }
    seenLines[path] = lines.length;
  }
}

Map<String, dynamic>? _decodeProgressEvent(String line) {
  try {
    final decoded = json.decode(line);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
  } catch (_) {
    return null;
  }
}

String _formatProgressEvent(Map<String, dynamic> event) {
  final status = event['status'] == 'passed' ? '✓' : '✗';
  final testId = event['testId']?.toString() ?? '(unknown)';
  final durationMs =
      event['durationMs'] is int ? event['durationMs'] as int : 0;
  final message = event['message']?.toString();
  final attempts = event['attempts'] is int ? event['attempts'] as int : 1;
  final retry = event['retry'] is int ? event['retry'] as int : 0;
  final retryText = attempts > 1 ? ' · attempt $attempts/${retry + 1}' : '';
  final suffix = message == null || message.isEmpty
      ? ''
      : ': ${_singleLine(message, maxLength: 120)}';
  return '$status ${_baseTestId(testId)} (${_formatDuration(durationMs)})$retryText$suffix';
}

String _formatDuration(int durationMs) {
  if (durationMs < 1000) return '${durationMs}ms';
  return '${(durationMs / 1000).toStringAsFixed(1)}s';
}

String _singleLine(String value, {required int maxLength}) {
  final single = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (single.length <= maxLength) return single;
  return '${single.substring(0, maxLength - 1)}…';
}

void _deleteIfExists(String path) {
  final file = File(path);
  if (file.existsSync()) file.deleteSync();
}

String _prepareWorkerDirectory(
  String appDir,
  int workerIndex,
  YamlTestAppPatcher patcher,
) {
  final workerDir = Directory(_workerDirectory(appDir, workerIndex));
  workerDir.createSync(recursive: true);

  final sourceNames = <String>{};
  for (final entity in Directory(appDir).listSync(followLinks: false)) {
    final name = p.basename(entity.path);
    if (name == 'build' || name == '.git' || name == '.dart_tool') continue;
    sourceNames.add(name);
    _replaceWithLink(
      p.join(workerDir.path, name),
      entity.absolute.path,
    );
  }

  for (final entity in workerDir.listSync(followLinks: false)) {
    final name = p.basename(entity.path);
    if (name == 'build' || name == '.dart_tool' || sourceNames.contains(name)) {
      continue;
    }
    entity.deleteSync(recursive: true);
  }

  final sourceDartTool = Directory(p.join(appDir, '.dart_tool'));
  final workerDartTool = Directory(p.join(workerDir.path, '.dart_tool'))
    ..createSync();
  for (final fileName in const [
    'package_config.json',
    'package_graph.json',
    'version',
  ]) {
    final source = File(p.join(sourceDartTool.path, fileName));
    if (source.existsSync()) {
      source.copySync(p.join(workerDartTool.path, fileName));
    }
  }
  _materializeTimerRewriteScreens(workerDir.path, appDir, patcher);
  patcher.rewriteTimersIn(workerDir.path);
  return workerDir.path;
}

void _materializeTimerRewriteScreens(
  String workerDir,
  String appDir,
  YamlTestAppPatcher patcher,
) {
  if (!patcher.hasTimerRewrites) return;
  final testsDir = patcher.testsDirRelative;
  if (testsDir == null) return;
  final appRootRelative = p.dirname(_withoutTrailingSlash(testsDir));
  final screensRelative = p.join(appRootRelative, 'screens');
  final sourceScreens = Directory(p.join(appDir, screensRelative));
  if (!sourceScreens.existsSync()) return;
  _materializeCopiedSubtree(
    workerDir: workerDir,
    sourceRoot: appDir,
    relativePath: screensRelative,
  );
}

String _withoutTrailingSlash(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.endsWith('/')
      ? normalized.substring(0, normalized.length - 1)
      : normalized;
}

void _materializeCopiedSubtree({
  required String workerDir,
  required String sourceRoot,
  required String relativePath,
}) {
  final segments = p.split(relativePath.replaceAll('\\', '/'));
  var sourceParent = Directory(sourceRoot);
  var targetParent = Directory(workerDir);
  for (var i = 0; i < segments.length; i++) {
    final segment = segments[i];
    final source = Directory(p.join(sourceParent.path, segment));
    final targetPath = p.join(targetParent.path, segment);
    final isLeaf = i == segments.length - 1;
    if (isLeaf) {
      _replaceWithDirectoryCopy(targetPath, source);
      return;
    }
    _replaceWithOverlayDirectory(
      targetPath,
      source,
      skipChildName: segments[i + 1],
    );
    sourceParent = source;
    targetParent = Directory(targetPath);
  }
}

void _replaceWithOverlayDirectory(
  String path,
  Directory source, {
  required String skipChildName,
}) {
  _deleteEntityIfExists(path);
  final target = Directory(path)..createSync(recursive: true);
  for (final entity in source.listSync(followLinks: false)) {
    final name = p.basename(entity.path);
    if (name == skipChildName) continue;
    _replaceWithLink(p.join(target.path, name), entity.absolute.path);
  }
}

void _replaceWithDirectoryCopy(String path, Directory source) {
  _deleteEntityIfExists(path);
  final target = Directory(path)..createSync(recursive: true);
  _copyDirectoryContents(source, target);
}

void _replaceWithLink(String path, String target) {
  _deleteEntityIfExists(path);
  Link(path).createSync(target);
}

void _deleteEntityIfExists(String path) {
  final existing = FileSystemEntity.typeSync(path, followLinks: false);
  if (existing != FileSystemEntityType.notFound) {
    FileSystemEntity entity;
    if (existing == FileSystemEntityType.directory) {
      entity = Directory(path);
    } else if (existing == FileSystemEntityType.link) {
      entity = Link(path);
    } else {
      entity = File(path);
    }
    entity.deleteSync(recursive: true);
  }
}

String _workerDirectory(String appDir, int workerIndex) {
  return p.join(
    appDir,
    'build',
    'ensemble_test_runner',
    'workers',
    'worker${workerIndex + 1}',
  );
}

void _copyWorkerArtifacts(String appDir, int workerIndex) {
  final source = Directory(
    p.join(
      _workerDirectory(appDir, workerIndex),
      'build',
      'ensemble_test_runner',
    ),
  );
  if (!source.existsSync()) return;
  final target = Directory(p.join(appDir, 'build', 'ensemble_test_runner'));
  target.createSync(recursive: true);
  _copyDirectoryContents(source, target);
}

void _copyDirectoryContents(Directory source, Directory target) {
  for (final entity in source.listSync(recursive: false, followLinks: false)) {
    final destination = p.join(target.path, p.basename(entity.path));
    if (entity is Directory) {
      final destinationDir = Directory(destination)
        ..createSync(recursive: true);
      _copyDirectoryContents(entity, destinationDir);
    } else if (entity is File) {
      entity.copySync(destination);
    }
  }
}

_ShardedTestFiles _testFilesForSharding(
  String appDir,
  YamlTestAppPatcher patcher,
) {
  final testsDir = patcher.testsDirPath;
  if (testsDir == null) return const _ShardedTestFiles();
  final historicalDurations = _loadHistoricalDurations(appDir);
  final parallel = <_ShardableTestFile>[];
  final serial = <String>[];
  final files = Directory(testsDir)
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.test.yaml'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final docsByPath = <String, YamlMap?>{};
  final pathById = <String, String>{};
  final referencedSessionIds = <String>{};
  for (final file in files) {
    final relative = p.relative(file.path, from: appDir).replaceAll('\\', '/');
    final doc = _readTestYamlMap(file);
    docsByPath[relative] = doc;
    final id = doc?['id']?.toString();
    if (id != null && id.isNotEmpty) {
      pathById[id] = relative;
    }
    final session = doc?['session']?.toString();
    if (session != null && session.isNotEmpty) {
      referencedSessionIds.add(session);
    }
  }

  final sessionProducerPaths = <String>{
    for (final id in referencedSessionIds)
      if (pathById[id] != null) pathById[id]!,
  };

  for (final file in files) {
    final relative = p.relative(file.path, from: appDir).replaceAll('\\', '/');
    if (_isParallelTestFile(file, doc: docsByPath[relative]) &&
        !sessionProducerPaths.contains(relative)) {
      parallel.add(
        _ShardableTestFile(
          path: relative,
          estimatedDurationMs: _estimateTestFileDurationMs(
            file,
            relative,
            historicalDurations,
          ),
        ),
      );
    } else if (sessionProducerPaths.contains(relative) &&
        _isParallelTestFile(file, doc: docsByPath[relative])) {
      // Session producers are selected automatically by each shard that needs
      // them. Running them as standalone files would waste a worker lane.
      continue;
    } else {
      serial.add(relative);
    }
  }
  return _ShardedTestFiles(parallel: parallel, serial: serial);
}

YamlMap? _readTestYamlMap(File file) {
  try {
    final doc = loadYaml(file.readAsStringSync());
    return doc is YamlMap ? doc : null;
  } catch (_) {
    // Let the real parser report invalid YAML with source context.
  }
  return null;
}

bool _isParallelTestFile(File file, {YamlMap? doc}) {
  doc ??= _readTestYamlMap(file);
  if (doc != null && doc['parallel'] == false) return false;
  return true;
}

class _ShardedTestFiles {
  final List<_ShardableTestFile> parallel;
  final List<String> serial;

  const _ShardedTestFiles({
    this.parallel = const [],
    this.serial = const [],
  });
}

class _ShardableTestFile {
  final String path;
  final int estimatedDurationMs;

  const _ShardableTestFile({
    required this.path,
    required this.estimatedDurationMs,
  });
}

List<List<_ShardableTestFile>> _balancedShards(
  List<_ShardableTestFile> files,
  int workerCount,
) {
  if (workerCount <= 0) return const [];
  final shards = List.generate(workerCount, (_) => <_ShardableTestFile>[]);
  final shardDurations = List.filled(workerCount, 0);
  final sorted = [...files]..sort((a, b) {
      final byDuration = b.estimatedDurationMs.compareTo(a.estimatedDurationMs);
      return byDuration != 0 ? byDuration : a.path.compareTo(b.path);
    });

  for (final file in sorted) {
    var target = 0;
    for (var i = 1; i < shardDurations.length; i++) {
      if (shardDurations[i] < shardDurations[target]) target = i;
    }
    shards[target].add(file);
    shardDurations[target] += file.estimatedDurationMs;
  }
  return shards;
}

int _autoWorkerCount(int fileCount) {
  if (fileCount < 2) return 1;
  final halfCpu = (Platform.numberOfProcessors / 2).floor();
  final cpuBased = (halfCpu - 1).clamp(1, fileCount);
  return cpuBased.clamp(1, fileCount);
}

int _estimateTestFileDurationMs(
  File file,
  String relativePath,
  Map<String, int> historicalDurations,
) {
  final historical = historicalDurations[relativePath];
  if (historical != null && historical > 0) return historical;

  try {
    final doc = loadYaml(file.readAsStringSync());
    if (doc is! YamlMap) return 30000;
    final steps = doc['steps'];
    var estimate = doc['startScreen'] == 'Login' ? 18000 : 6000;
    if (doc['session'] != null) estimate += 4000;
    if (steps is YamlList) {
      for (final step in steps) {
        estimate += _estimateStepDurationMs(step);
      }
    }
    return estimate.clamp(10000, 180000);
  } catch (_) {
    return 30000;
  }
}

int _estimateStepDurationMs(dynamic step) {
  if (step is! YamlMap || step.isEmpty) return 1000;
  final type = step.keys.first.toString();
  return switch (type) {
    'waitForNavigation' => 7000,
    'waitForApi' => 6000,
    'waitFor' => 4000,
    'settle' => 2500,
    'tap' || 'toggle' || 'enterText' || 'goBack' => 1200,
    'expectVisible' || 'expectText' || 'expectNotVisible' => 700,
    _ => 1500,
  };
}

Map<String, int> _loadHistoricalDurations(String appDir) {
  final file = File(_durationCachePath(appDir));
  if (!file.existsSync()) return const {};
  try {
    final decoded = json.decode(file.readAsStringSync());
    if (decoded is! Map) return const {};
    final files = decoded['files'];
    if (files is! Map) return const {};
    return {
      for (final entry in files.entries)
        if (entry.value is int) entry.key.toString(): entry.value as int,
    };
  } catch (_) {
    return const {};
  }
}

void _writeHistoricalDurations(
  String appDir,
  EnsembleTestRunResult result,
) {
  final previousDurations = _loadHistoricalDurations(appDir);
  final currentDurations = <String, int>{};
  for (final test in result.results) {
    if (test.durationMs <= 0) continue;
    final path = _assetPathFromTestId(test.testId);
    if (path == null) continue;
    currentDurations[path] = (currentDurations[path] ?? 0) + test.durationMs;
  }
  final durations = {
    ...previousDurations,
    ...currentDurations,
  };

  final file = File(_durationCachePath(appDir));
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'updatedAt': DateTime.now().toIso8601String(),
      'files': durations,
    }),
  );
}

String _durationCachePath(String appDir) {
  return p.join(appDir, 'build', 'ensemble_test_runner', 'test_durations.json');
}

String? _assetPathFromTestId(String testId) {
  final start = testId.lastIndexOf('  (');
  if (start == -1 || !testId.endsWith(')')) return null;
  return testId.substring(start + 3, testId.length - 1);
}

bool _hasSelection(List<String> arguments) {
  return arguments.any(
    (arg) =>
        arg.startsWith('--id=') ||
        arg.startsWith('--feature=') ||
        arg.startsWith('--tag=') ||
        arg.startsWith('--path='),
  );
}

EnsembleTestRunResult _mergeWorkerReports(
  List<ProcessResult> results, {
  required List<String> reportFiles,
  required String appDir,
}) {
  final mergedResults = <EnsembleSingleTestResult>[];
  final suiteLogs = <String>[];
  final seenPassedDependencies = <String>{};

  for (var i = 0; i < results.length; i++) {
    final result = results[i];
    final output = '${result.stdout ?? ''}\n${result.stderr ?? ''}';
    final reportFile = i < reportFiles.length ? File(reportFiles[i]) : null;
    final rawJson = reportFile != null && reportFile.existsSync()
        ? reportFile.readAsStringSync()
        : extractJsonReport(output);
    if (rawJson.isEmpty) {
      final workerOutputFile = _writeWorkerOutputLog(appDir, i, output);
      mergedResults.add(
        EnsembleSingleTestResult.failed(
          testId: 'test-process-${result.pid}',
          durationMs: 0,
          error: 'A test process did not emit an Ensemble JSON report'
              '${workerOutputFile == null ? '' : '. See $workerOutputFile'}',
        ),
      );
      continue;
    }

    final decoded = json.decode(rawJson) as Map<String, dynamic>;
    final workerRun = _runResultFromJson(decoded);
    suiteLogs.addAll(workerRun.suiteLogs);
    for (final test in workerRun.results) {
      final baseId = _baseTestId(test.testId);
      final isPassedDependency =
          test.status == TestStatus.passed && _isRepeatedDependency(baseId);
      if (isPassedDependency && !seenPassedDependencies.add(baseId)) {
        continue;
      }
      mergedResults.add(test);
    }
  }

  return EnsembleTestRunResult(
    results: mergedResults,
    suiteLogs: suiteLogs,
  );
}

String? _writeWorkerOutputLog(String appDir, int workerIndex, String output) {
  if (output.trim().isEmpty) return null;
  final file = File(
    p.join(
      appDir,
      'build',
      'ensemble_test_runner',
      'logs',
      'test_process_${workerIndex + 1}_output.log',
    ),
  );
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(output);
  return p.relative(file.path, from: appDir).replaceAll('\\', '/');
}

EnsembleTestRunResult _withHtmlReport(
  String appDir,
  EnsembleTestRunResult result, {
  int? wallTimeMs,
  bool isSuiteRunning = false,
}) {
  final reporter = HtmlTestReporter();
  final artifactRoot = _artifactRootPath(appDir);
  final displayRoot = p
      .join('build', 'ensemble_test_runner')
      .replaceAll('\\', '/');
  final htmlPath = p
      .join(displayRoot, 'report', 'index.html')
      .replaceAll('\\', '/');
  final resultsPath = p
      .join(displayRoot, 'report', 'results.json')
      .replaceAll('\\', '/');

  if (isSuiteRunning) {
    reporter.write(
      result,
      artifactRoot: artifactRoot,
      displayRoot: displayRoot,
      wallTimeMs: wallTimeMs,
      isSuiteRunning: true,
    );
  } else {
    // Shell was written at suite start; only refresh the results DB.
    reporter.writeResultsOnly(
      result,
      artifactRoot: artifactRoot,
      displayRoot: displayRoot,
      wallTimeMs: wallTimeMs,
    );
  }

  var suiteLogs = result.suiteLogs;
  if (!suiteLogs.any((log) => log.startsWith('htmlReport:'))) {
    suiteLogs = [...suiteLogs, 'htmlReport: $htmlPath'];
  }
  if (!suiteLogs.any((log) => log.startsWith('results:'))) {
    suiteLogs = [...suiteLogs, 'results: $resultsPath'];
  }
  if (identical(suiteLogs, result.suiteLogs)) {
    return result;
  }
  return EnsembleTestRunResult(
    results: result.results,
    suiteLogs: suiteLogs,
  );
}

String _formatCliSummary(
  EnsembleTestRunResult result, {
  String? testFile,
  int? wallTimeMs,
}) {
  final buffer = StringBuffer();
  buffer.writeln('┌─ Ensemble YAML tests ─────────────────────────────');
  if (testFile != null) {
    buffer.writeln('│  $testFile');
    buffer.writeln('│');
  }

  for (var i = 0; i < result.results.length; i++) {
    if (i > 0) buffer.writeln('│');
    _writeCliTestCase(buffer, result.results[i]);
  }

  if (result.suiteLogs.isNotEmpty) {
    buffer.writeln('│');
    buffer.writeln('│  suite artifacts:');
    for (final log in result.suiteLogs) {
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

void _writeCliTestCase(StringBuffer buffer, EnsembleSingleTestResult r) {
  final icon = r.status == TestStatus.passed ? '✓' : '✗';
  buffer.writeln('│  $icon ${r.testId} (${r.durationMs}ms)');
  if (r.attempts > 1) {
    buffer.writeln('│     attempts: ${r.attempts}/${r.retry + 1}');
  }

  final report = r.report;
  if (report != null) {
    if (report.session != null) {
      buffer.writeln('│     session: ${report.session}');
    }
    buffer.writeln('│     start: ${report.startScreen}');
    if (report.endScreen != null && report.endScreen != report.startScreen) {
      buffer.writeln('│     end:   ${report.endScreen}');
    }
    if (report.screensVisited.length > 1) {
      buffer.writeln('│     flow:  ${report.screensVisited.join(' → ')}');
    }
    if (report.stepsOutline.isNotEmpty) {
      buffer.writeln('│     steps (${report.stepsOutline.length}):');
      var i = 0;
      for (final line in stepOutlineDisplayLines(
        stepsOutline: report.stepsOutline,
        stepDurationsMs: report.stepDurationsMs,
        failedStepIndex:
            r.status == TestStatus.failed ? r.failedStepIndex : null,
      )) {
        final prefix = line.failed ? '>>' : '  ';
        buffer.writeln('│       $prefix ${i + 1}. ${line.text}');
        i++;
      }
    }
  }

  if (r.status == TestStatus.failed && r.message != null) {
    buffer.writeln('│     error: ${r.message}');
  }

  if (r.logs.isNotEmpty) {
    buffer.writeln('│     artifacts:');
    for (final log in r.logs) {
      buffer.writeln('│          $log');
    }
  }
}

bool _isRepeatedDependency(String testId) => testId == 'signin_to_gateway';

String _baseTestId(String value) {
  final index = value.indexOf('  (');
  return index == -1 ? value : value.substring(0, index);
}

EnsembleTestRunResult? _runResultFromProcessOutput(ProcessResult result) {
  final rawJson =
      extractJsonReport('${result.stdout ?? ''}\n${result.stderr ?? ''}');
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

EnsembleTestRunResult _runResultFromJson(Map<String, dynamic> json) {
  final results = (json['results'] as List<dynamic>? ?? const [])
      .whereType<Map<String, dynamic>>()
      .map(_singleResultFromJson)
      .toList();
  final suiteLogs = (json['suiteLogs'] as List<dynamic>? ?? const [])
      .map((value) => value.toString())
      .toList();
  return EnsembleTestRunResult(results: results, suiteLogs: suiteLogs);
}

EnsembleSingleTestResult _singleResultFromJson(Map<String, dynamic> json) {
  return EnsembleSingleTestResult(
    testId: json['testId']?.toString() ?? '(unknown)',
    metadata: json['metadata'] is Map
        ? Map<String, dynamic>.from(json['metadata'] as Map)
        : const {},
    status: json['status'] == 'passed' ? TestStatus.passed : TestStatus.failed,
    durationMs: json['durationMs'] is int ? json['durationMs'] as int : 0,
    attempts: json['attempts'] is int ? json['attempts'] as int : 1,
    retry: json['retry'] is int ? json['retry'] as int : 0,
    failedStepIndex:
        json['failedStepIndex'] is int ? json['failedStepIndex'] as int : null,
    message: json['message']?.toString(),
    stackTrace: json['stackTrace']?.toString(),
    logs: (json['logs'] as List<dynamic>? ?? const [])
        .map((value) => value.toString())
        .toList(),
    report: json['report'] is Map
        ? EnsembleTestReportDetails.fromJson(
            Map<String, dynamic>.from(json['report'] as Map))
        : null,
  );
}

String _junitReportForCli(EnsembleTestRunResult result) {
  final totalMs = result.results.fold<int>(0, (sum, r) => sum + r.durationMs);
  final buffer = StringBuffer()
    ..writeln(
      '<testsuite name="ensemble_yaml_tests" tests="${result.results.length}" '
      'failures="${result.failedCount}" time="${(totalMs / 1000).toStringAsFixed(3)}">',
    );
  for (final r in result.results) {
    buffer.writeln(
      '  <testcase name="${_xmlEscape(r.testId)}" '
      'time="${(r.durationMs / 1000).toStringAsFixed(3)}">',
    );
    if (r.status == TestStatus.failed) {
      buffer
        ..writeln(
          '    <failure message="${_xmlEscape(r.message ?? 'failed')}">',
        )
        ..writeln(_xmlEscape(r.stackTrace ?? r.message ?? 'failed'))
        ..writeln('    </failure>');
    }
    buffer.writeln('  </testcase>');
  }
  buffer.writeln('</testsuite>');
  return buffer.toString();
}

String _xmlEscape(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

List<String> _inputDartDefines(List<String> arguments) {
  final inputs = _inputValues(arguments);
  if (inputs.isEmpty) return const [];
  final encoded = base64Url.encode(utf8.encode(jsonEncode(inputs)));
  return ['--dart-define=ensembleTestInputs=$encoded'];
}

Map<String, dynamic> _inputValues(List<String> arguments) {
  final inputs = <String, dynamic>{};
  for (var i = 0; i < arguments.length; i++) {
    final arg = arguments[i];
    String? raw;
    if (arg == '--input') {
      if (i + 1 >= arguments.length) {
        throw StateError('--input requires key=value');
      }
      raw = arguments[++i];
    } else if (arg.startsWith('--input=')) {
      raw = arg.substring('--input='.length);
    }
    if (raw == null) continue;

    final separator = raw.indexOf('=');
    if (separator <= 0) {
      throw StateError('Invalid --input "$raw". Use --input key=value.');
    }
    final key = raw.substring(0, separator).trim();
    if (key.isEmpty) {
      throw StateError('Invalid --input "$raw". Input key cannot be empty.');
    }
    inputs[key] = _parseInputValue(raw.substring(separator + 1));
  }
  return inputs;
}

dynamic _parseInputValue(String value) {
  final trimmed = value.trim();
  if (trimmed == 'true') return true;
  if (trimmed == 'false') return false;
  final intValue = int.tryParse(trimmed);
  if (intValue != null) return intValue;
  final doubleValue = double.tryParse(trimmed);
  if (doubleValue != null) return doubleValue;
  return value;
}

List<String> _optionValues(List<String> arguments, String name) {
  return arguments
      .where((arg) => arg.startsWith('$name='))
      .map((arg) => arg.substring(name.length + 1))
      .where((value) => value.isNotEmpty)
      .toList();
}

Future<ProcessResult> _runFlutterTestProcess(
  String executable,
  List<String> arguments, {
  required String workingDirectory,
  required bool streamOutput,
  required bool verbose,
  String? appLogFile,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    runInShell: false,
  );
  final stdoutBuffer = StringBuffer();
  final stderrBuffer = StringBuffer();
  final liveFilter = LiveFlutterTestOutputFilter();
  final elapsed = Stopwatch()..start();
  var lastLiveOutput = DateTime.now();
  Timer? heartbeat;
  final appLog = _openAppConsoleLog(appLogFile);

  if (streamOutput && !verbose) {
    heartbeat = Timer.periodic(const Duration(seconds: 10), (_) {
      final idleFor = DateTime.now().difference(lastLiveOutput);
      if (idleFor.inSeconds >= 10) {
        stderr.writeln(
          'Still running Flutter tests (${elapsed.elapsed.inSeconds}s)...',
        );
      }
    });
  }

  try {
    final stdoutDone = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      stdoutBuffer.writeln(line);
      _appendAppConsoleLogLine(appLog, 'stdout', line);
      if (verbose) {
        stdout.writeln(line);
      } else if (streamOutput && liveFilter.shouldEmit(line)) {
        lastLiveOutput = DateTime.now();
        stderr.writeln(line);
      }
    }).asFuture<void>();

    final stderrDone = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      stderrBuffer.writeln(line);
      _appendAppConsoleLogLine(appLog, 'stderr', line);
      if (verbose) {
        stderr.writeln(line);
      }
    }).asFuture<void>();

    final exitCode = await process.exitCode;
    await Future.wait([stdoutDone, stderrDone]);
    return ProcessResult(
      process.pid,
      exitCode,
      stdoutBuffer.toString(),
      stderrBuffer.toString(),
    );
  } finally {
    heartbeat?.cancel();
  }
}

File? _openAppConsoleLog(String? path) {
  if (path == null) return null;
  final file = File(path);
  try {
    file.parent.createSync(recursive: true);
    final header = 'createdAt: ${DateTime.now().toIso8601String()}\n';
    file.writeAsStringSync(header);
    _appConsoleLogBytes[file.path] = utf8.encode(header).length;
    _disabledAppConsoleLogs.remove(file.path);
    return file;
  } on FileSystemException {
    return null;
  }
}

void _appendAppConsoleLogLine(File? file, String stream, String line) {
  if (file == null || !_isAppConsoleLogLine(line)) return;
  final path = file.path;
  if (_disabledAppConsoleLogs.contains(path)) return;

  final entry = '[$stream] $line\n';
  final bytes = utf8.encode(entry).length;
  final currentBytes = _appConsoleLogBytes[path] ?? file.lengthSync();
  if (currentBytes + bytes > _maxAppConsoleLogBytes) {
    _writeFinalAppConsoleLogLine(
      file,
      '[runner] app console log truncated at '
      '${(_maxAppConsoleLogBytes / (1024 * 1024)).toStringAsFixed(0)} MB\n',
    );
    _disabledAppConsoleLogs.add(path);
    return;
  }

  try {
    file.writeAsStringSync(entry, mode: FileMode.append);
    _appConsoleLogBytes[path] = currentBytes + bytes;
  } on FileSystemException {
    _disabledAppConsoleLogs.add(path);
  }
}

void _writeFinalAppConsoleLogLine(File file, String line) {
  try {
    file.writeAsStringSync(line, mode: FileMode.append);
    _appConsoleLogBytes[file.path] =
        (_appConsoleLogBytes[file.path] ?? 0) + utf8.encode(line).length;
  } on FileSystemException {
    // Log files are diagnostic artifacts. They must not crash the test run.
  }
}

bool _isAppConsoleLogLine(String line) {
  return !line.startsWith(jsonReportPrefix) &&
      !line.startsWith(junitReportPrefix);
}

Future<ProcessResult> _runProcess(
  String executable,
  List<String> arguments, {
  required String workingDirectory,
}) {
  return Process.run(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    runInShell: false,
  );
}

String _resolveAppDir(List<String> arguments) {
  for (final arg in arguments) {
    if (arg.startsWith('--app-dir=')) {
      return arg.substring('--app-dir='.length);
    }
  }
  return Directory.current.path;
}

String? _resolveReportMode(List<String> arguments) {
  for (final arg in arguments) {
    if (arg == '--report=json') return 'json';
    if (arg == '--report=junit') return 'junit';
  }
  return null;
}

String? _resolveReportFile(List<String> arguments) {
  for (final arg in arguments) {
    if (arg.startsWith('--report-file=')) {
      return File(arg.substring('--report-file='.length)).absolute.path;
    }
  }
  return null;
}

int? _resolveTimeoutSeconds(List<String> arguments) {
  String? value;
  for (final arg in arguments) {
    if (arg.startsWith('--timeout=')) {
      value = arg.substring('--timeout='.length);
    }
  }
  if (value == null || value.isEmpty) return null;

  final match = RegExp(r'^(\d+)(ms|s|m|h)?$').firstMatch(value);
  if (match == null) {
    stderr.writeln(
      'Invalid --timeout value "$value". Use a duration like 30s, 5m, or 1h.',
    );
    exit(2);
  }

  final amount = int.parse(match.group(1)!);
  final unit = match.group(2) ?? 's';
  final seconds = switch (unit) {
    'ms' => (amount / 1000).ceil(),
    's' => amount,
    'm' => amount * 60,
    'h' => amount * 60 * 60,
    _ => amount,
  };
  if (seconds <= 0) {
    stderr.writeln('--timeout must be greater than zero.');
    exit(2);
  }
  return seconds;
}

int? _resolveJobsOverride(List<String> arguments) {
  String? value;
  for (final arg in arguments) {
    if (arg.startsWith('--jobs=')) {
      value = arg.substring('--jobs='.length);
    }
  }
  if (value == null || value.isEmpty || value == 'auto') return null;
  final jobs = int.tryParse(value);
  if (jobs == null || jobs <= 0) {
    stderr.writeln(
      'Invalid --jobs value "$value". Use a positive integer, auto, or 1 to disable parallelism.',
    );
    exit(2);
  }
  return jobs;
}

void _writeStatus(
  String message, {
  required bool quiet,
  required bool machineReport,
}) {
  if (quiet || machineReport) return;
  stderr.writeln(message);
}

void _writeProcessStreams(ProcessResult result) {
  final out = result.stdout?.toString() ?? '';
  final err = result.stderr?.toString() ?? '';
  if (out.isNotEmpty) stdout.write(out);
  if (err.isNotEmpty) stderr.write(err);
}

List<EnsembleSingleTestResult> _discoverAllTestRuns(
  String appDir,
  YamlTestAppPatcher patcher,
) {
  final testsDir = patcher.testsDirPath;
  if (testsDir == null) return [];
  final configFile = File(p.join(testsDir, 'config.yaml'));
  final devices = <String>[];
  if (configFile.existsSync()) {
    try {
      final config = EnsembleTestParser.parseConfigString(
        configFile.readAsStringSync(),
        sourcePath: configFile.path,
      );
      for (final dev in config.devices) {
        devices.add(dev.id);
      }
    } catch (_) {}
  }

  final files = Directory(testsDir)
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.test.yaml'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final results = <EnsembleSingleTestResult>[];
  for (final file in files) {
    final relative = p.relative(file.path, from: appDir).replaceAll('\\', '/');
    final doc = _readTestYamlMap(file);
    final id = doc?['id']?.toString();
    if (id == null || id.isEmpty) continue;

    if (devices.isEmpty) {
      results.add(EnsembleSingleTestResult(
        testId: '$id  ($relative)',
        status: TestStatus.pending,
        durationMs: 0,
      ));
    } else {
      for (final devId in devices) {
        results.add(EnsembleSingleTestResult(
          testId: '$id [$devId]  ($relative)',
          status: TestStatus.pending,
          durationMs: 0,
        ));
      }
    }
  }
  return results;
}
