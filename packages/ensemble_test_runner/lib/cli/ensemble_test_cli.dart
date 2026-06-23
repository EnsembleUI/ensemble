import 'dart:io';

import 'package:ensemble_test_runner/cli/ensemble_test_doctor.dart';
import 'package:ensemble_test_runner/cli/ensemble_test_cli_output.dart';
import 'package:ensemble_test_runner/cli/yaml_test_app_patcher.dart';

/// Runs declarative YAML tests in an Ensemble app.
///
/// The host app must list `ensemble_test_runner` in `dev_dependencies`.
///
/// Options:
///   --app-dir=<path>   App directory (default: current directory)
///   --doctor           Validate test setup without running Flutter tests
///   --report=json      Print JSON run results instead of the boxed report
///   --report-file=<path> Write JSON run results to a file
///   --verbose          Full `flutter pub get` / `flutter test` output
Future<void> runEnsembleYamlTestsCli(List<String> arguments) async {
  final verbose = isVerboseCli(arguments);
  final jsonReport = _wantsJsonReport(arguments);
  final reportFile = _resolveReportFile(arguments);
  final appDir = _resolveAppDir(arguments);
  final patcher = YamlTestAppPatcher(appDir);

  if (!Directory(appDir).existsSync()) {
    stderr.writeln('App directory not found: $appDir');
    exit(1);
  }

  if (!File('${appDir}/pubspec.yaml').existsSync()) {
    stderr.writeln('No pubspec.yaml in $appDir');
    exit(1);
  }

  if (arguments.contains('--doctor')) {
    final result = await EnsembleTestDoctor(appDir).run();
    stdout.writeln(result.lines.join('\n'));
    exit(result.hasErrors ? 1 : 0);
  }

  final testsDirRelative = patcher.testsDirRelative;
  if (testsDirRelative == null) {
    stderr.writeln(
      'Could not find definitions.local.path in ensemble/ensemble-config.yaml.\n'
      'Declarative tests must live under definitions.local.path/tests.',
    );
    exit(1);
  }

  if (!patcher.hasTestYamlOnDisk) {
    stderr.writeln(
      'No declarative tests found. Add *.test.yaml files under '
      '$testsDirRelative/',
    );
    exit(1);
  }

  var exitCode = 0;
  try {
    patcher.enable();

    if (patcher.pubspecChanged) {
      final pubGet = await _runProcess(
        'flutter',
        ['pub', 'get', '--suppress-analytics'],
        workingDirectory: appDir,
      );
      if (pubGet.exitCode != 0 || verbose) {
        _writeProcessStreams(pubGet);
      }
      if (pubGet.exitCode != 0) {
        exitCode = pubGet.exitCode;
        return;
      }
    }

    final testArgs = [
      'test',
      YamlTestAppPatcher.testEntryRelativePath,
      '--no-pub',
      '--dart-define=testmode=true',
      if (jsonReport) '--dart-define=ensembleTestReport=json',
      if (reportFile != null)
        '--dart-define=ensembleTestReportFile=$reportFile',
      '--reporter',
      verbose ? 'expanded' : 'silent',
      ...flutterTestArguments(arguments),
    ];

    final testRun = await _runProcess(
      'flutter',
      testArgs,
      workingDirectory: appDir,
    );

    if (testRun.exitCode != 0 && !verbose) {
      final output = '${testRun.stdout ?? ''}\n${testRun.stderr ?? ''}';
      final json = jsonReport ? extractJsonReport(output) : '';
      final knownFailure = extractKnownFailure(output);
      if (json.isNotEmpty) {
        stdout.writeln(json);
      } else if (knownFailure.isNotEmpty) {
        stderr.writeln(knownFailure);
      } else {
        _writeProcessStreams(testRun);
      }
    } else if (verbose || testRun.exitCode != 0) {
      _writeProcessStreams(testRun);
    } else {
      final out = testRun.stdout?.toString() ?? '';
      final json = jsonReport ? extractJsonReport(out) : '';
      final report = json.isNotEmpty ? json : extractSuiteReport(out);
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

    exitCode = testRun.exitCode;
  } on StateError catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  } finally {
    patcher.restore();
  }
  exit(exitCode);
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

bool _wantsJsonReport(List<String> arguments) {
  return arguments.any((arg) => arg == '--report=json');
}

String? _resolveReportFile(List<String> arguments) {
  for (final arg in arguments) {
    if (arg.startsWith('--report-file=')) {
      return File(arg.substring('--report-file='.length)).absolute.path;
    }
  }
  return null;
}

void _writeProcessStreams(ProcessResult result) {
  final out = result.stdout?.toString() ?? '';
  final err = result.stderr?.toString() ?? '';
  if (out.isNotEmpty) stdout.write(out);
  if (err.isNotEmpty) stderr.write(err);
}
