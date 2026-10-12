import 'dart:io';

import 'package:ensemble_test_runner/cli/process_lifecycle.dart';
import 'package:ensemble_test_runner/src/cli/process_interruption_watch.dart';
import 'dart_executable.dart';

Future<void> main() async {
  final interruptionWatch = ProcessInterruptionWatch();
  final workerPath =
      Platform.script.resolve('cli_process_stuck_child.dart').toFilePath();
  final worker = await Process.start(
    findDartExecutable(),
    ['run', workerPath],
    runInShell: false,
  );
  stdout.writeln('workerPid=${worker.pid}');
  await stdout.flush();

  try {
    final result = await waitForManagedProcess(
      worker,
      interruption: interruptionWatch.future,
      terminationGracePeriod: const Duration(milliseconds: 250),
    );
    stdout.writeln(
      'interrupted=${result.interrupted} workerExitCode=${result.exitCode}',
    );
    await stdout.flush();
  } finally {
    await interruptionWatch.close();
  }
}
