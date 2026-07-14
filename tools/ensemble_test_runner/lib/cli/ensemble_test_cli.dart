import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ensemble_test_runner/cli/ensemble_test_doctor.dart';
import 'package:ensemble_test_runner/cli/ensemble_test_cli_output.dart';
import 'package:ensemble_test_runner/cli/yaml_test_app_patcher.dart';
import 'package:ensemble_test_runner/cli/ensemble_test_scaffold.dart';
import 'package:ensemble_test_runner/inspect/ensemble_app_inspector.dart';
import 'package:ensemble_test_runner/validation/ensemble_test_validator.dart';

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
///   --input key=value  Provide a test input for ${inputs.key}; repeatable
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

    final testArgs = [
      'test',
      YamlTestAppPatcher.testEntryRelativePath,
      '--no-pub',
      '--dart-define=testmode=true',
      if (reportMode != null) '--dart-define=ensembleTestReport=$reportMode',
      if (reportFile != null)
        '--dart-define=ensembleTestReportFile=$reportFile',
      if (timeoutSeconds != null)
        '--dart-define=ensembleTestTimeoutSeconds=$timeoutSeconds',
      ..._inputDartDefines(arguments),
      ..._selectionDartDefines(arguments),
      '--reporter',
      verbose ? 'expanded' : 'silent',
      ...flutterTestArguments(arguments),
    ];

    _writeStatus(
      'Running Ensemble YAML tests...',
      quiet: quiet,
      machineReport: machineReport,
    );
    final testRun = await _runFlutterTestProcess(
      'flutter',
      testArgs,
      workingDirectory: appDir,
      streamOutput: streamLiveOutput,
      verbose: verbose,
    );

    if (testRun.exitCode != 0 && !verbose) {
      final output = '${testRun.stdout ?? ''}\n${testRun.stderr ?? ''}';
      final json = jsonReport ? extractJsonReport(output) : '';
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
      final json = jsonReport ? extractJsonReport(out) : '';
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

    exitCode = testRun.exitCode == 0 ? 0 : 1;
  } on StateError catch (error) {
    stderr.writeln(error.message);
    exitCode = 3;
  } finally {
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
  };
  return [
    for (final entry in values.entries)
      if (entry.value.isNotEmpty)
        '--dart-define=${entry.key}=${entry.value.join(',')}',
  ];
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
