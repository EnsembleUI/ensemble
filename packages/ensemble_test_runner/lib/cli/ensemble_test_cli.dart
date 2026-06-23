import 'dart:io';

import 'package:ensemble_test_runner/cli/ensemble_test_cli_output.dart';
import 'package:ensemble_test_runner/cli/yaml_test_app_patcher.dart';

/// Runs declarative YAML tests in an Ensemble app.
///
/// The host app must list `ensemble_test_runner` in `dev_dependencies`.
///
/// Options:
///   --app-dir=<path>   App directory (default: current directory)
///   --verbose          Full `flutter pub get` / `flutter test` output
Future<void> runEnsembleYamlTestsCli(List<String> arguments) async {
  final verbose = isVerboseCli(arguments);
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
      'No Ensemble YAML tests found.\n'
      'Expected at least one *.test.yaml file under:\n'
      '  $testsDirRelative/\n\n'
      'Example:\n'
      '  $testsDirRelative/login_flow.test.yaml',
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
      '--reporter',
      verbose ? 'expanded' : 'silent',
      ...flutterTestArguments(arguments),
    ];

    final testRun = await _runProcess(
      'flutter',
      testArgs,
      workingDirectory: appDir,
    );

    if (verbose || testRun.exitCode != 0) {
      _writeProcessStreams(testRun);
    } else {
      final out = testRun.stdout?.toString() ?? '';
      final report = extractSuiteReport(out);
      if (report.isNotEmpty) {
        stdout.write(report);
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

void _writeProcessStreams(ProcessResult result) {
  final out = result.stdout?.toString() ?? '';
  final err = result.stderr?.toString() ?? '';
  if (out.isNotEmpty) stdout.write(out);
  if (err.isNotEmpty) stderr.write(err);
}
