// Dart 3.8 reports deprecated_member_use at RegExp construction sites even though
// the deprecation is specifically about implementing RegExp. Keep construction compatible
// with this SDK without suppressing diagnostics in unrelated files.
// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:ensemble_test_runner/cli/process_lifecycle.dart';
import 'package:ensemble_test_runner/cli/worker_process_failure.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/dart_executable.dart';

void main() {
  test('joins every worker when one launch callback throws synchronously',
      () async {
    final secondWorker = Completer<int>();
    final startedWorkers = <int>[];
    final joined = startManagedProcesses<int>([
      () {
        startedWorkers.add(1);
        throw StateError('worker launch failed');
      },
      () {
        startedWorkers.add(2);
        return secondWorker.future;
      },
    ]);

    expect(startedWorkers, [1, 2]);
    var joinedCompleted = false;
    joined.then<void>((_) => joinedCompleted = true,
        onError: (Object _, StackTrace __) => joinedCompleted = true);
    await Future<void>.delayed(Duration.zero);
    expect(joinedCompleted, isFalse);

    secondWorker.complete(2);
    await expectLater(joined, throwsA(isA<StateError>()));
  });

  test('terminates a stuck child after the wall-time budget', () async {
    final directory = await Directory.systemTemp.createTemp('runner_process');
    final script = File('${directory.path}/stuck.dart');
    await script.writeAsString('''
Future<void> main() async {
  await Future<void>.delayed(const Duration(hours: 1));
}
''');
    final process = await Process.start(
      findDartExecutable(),
      ['run', script.path],
      runInShell: false,
    );

    final stopwatch = Stopwatch()..start();
    final result = await waitForManagedProcess(
      process,
      timeout: const Duration(milliseconds: 30),
      terminationGracePeriod: const Duration(milliseconds: 100),
    );

    try {
      expect(result.timedOut, isTrue);
      expect(result.exitCode, isNot(0));
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('integration execution timeout starts after workload readiness',
      () async {
    final directory = await Directory.systemTemp.createTemp('runner_startup');
    final script = File('${directory.path}/startup_then_work.dart');
    await script.writeAsString('''
import 'dart:async';
Future<void> main() async {
  await Future<void>.delayed(const Duration(milliseconds: 250));
  print('workload-ready');
  await Future<void>.delayed(const Duration(milliseconds: 30));
}
''');
    final process = await Process.start(
      findDartExecutable(),
      ['run', script.path],
      runInShell: false,
    );
    final workloadReady = Completer<void>();
    final outputSubscription =
        process.stdout.transform(utf8.decoder).listen((chunk) {
      if (chunk.contains('workload-ready') && !workloadReady.isCompleted) {
        workloadReady.complete();
      }
    });

    try {
      final result = await waitForManagedProcess(
        process,
        timeout: const Duration(milliseconds: 100),
        startupTimeout: const Duration(seconds: 2),
        timeoutStartsAfter: workloadReady.future,
        terminationGracePeriod: const Duration(milliseconds: 100),
      );
      expect(result.timedOut, isFalse);
      expect(result.exitCode, 0);
    } finally {
      await outputSubscription.cancel();
      await directory.delete(recursive: true);
    }
  });

  test('a timed out child leaves structured results for every assigned case',
      () async {
    final directory = await Directory.systemTemp.createTemp('runner_worker');
    final script = File('${directory.path}/stuck.dart');
    await script.writeAsString('''
Future<void> main() async {
  await Future<void>.delayed(const Duration(hours: 1));
}
''');
    final process = await Process.start(
      findDartExecutable(),
      ['run', script.path],
      runInShell: false,
    );

    try {
      final exit = await waitForManagedProcess(
        process,
        timeout: const Duration(milliseconds: 30),
        terminationGracePeriod: const Duration(milliseconds: 100),
      );
      expect(exit.timedOut, isTrue);

      final results = workerProcessFailureResults(
        ProcessResult(
          process.pid,
          exit.exitCode,
          '',
          'Ensemble test worker timed out after 30ms.',
        ),
        workerIndex: 0,
        expectedTestIds: const ['first_case[android]', 'second_case[android]'],
      );

      final suiteResult = EnsembleTestRunResult(results: results);
      expect(results.map((result) => result.testId),
          containsAll(['first_case[android]', 'second_case[android]']));
      expect(results, hasLength(2));
      expect(suiteResult.failedCount, 2);
      expect(
        results.every((result) =>
            result.status == TestStatus.failed &&
            result.failure?.kind == TestFailureKind.incompleteExecution &&
            result.failure?.phase == 'worker'),
        isTrue,
      );
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('terminates a child when descendant discovery stalls', () async {
    final directory = await Directory.systemTemp.createTemp('runner_process');
    final script = File('${directory.path}/stuck.dart');
    await script.writeAsString('''
Future<void> main() async {
  await Future<void>.delayed(const Duration(hours: 1));
}
''');
    final process = await Process.start(
      findDartExecutable(),
      ['run', script.path],
      runInShell: false,
    );
    final stalledSnapshot = Completer<List<int>>();
    final stopwatch = Stopwatch()..start();

    try {
      final result = await waitForManagedProcess(
        process,
        timeout: const Duration(milliseconds: 30),
        terminationGracePeriod: const Duration(milliseconds: 50),
        descendantResolver: (_) => stalledSnapshot.future,
      );

      expect(result.timedOut, isTrue);
      expect(result.exitCode, isNot(0));
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
    } finally {
      process.kill(ProcessSignal.sigkill);
      await directory.delete(recursive: true);
    }
  });

  test('terminates a child when descendant discovery throws', () async {
    if (Platform.isWindows) return;
    final directory = await Directory.systemTemp.createTemp('runner_process');
    final script = File('${directory.path}/ignores_term.dart');
    await script.writeAsString('''
import 'dart:async';
import 'dart:io';

Future<void> main() async {
  ProcessSignal.sigterm.watch().listen((_) {});
  await Future<void>.delayed(const Duration(hours: 1));
}
''');
    final process = await Process.start(
      findDartExecutable(),
      ['run', script.path],
      runInShell: false,
    );
    final stopwatch = Stopwatch()..start();

    try {
      final result = await waitForManagedProcess(
        process,
        timeout: const Duration(milliseconds: 30),
        terminationGracePeriod: const Duration(milliseconds: 100),
        descendantResolver: (_) async => throw StateError('process table'),
      );

      expect(result.timedOut, isTrue);
      expect(result.exitCode, isNot(0));
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
    } finally {
      process.kill(ProcessSignal.sigkill);
      await directory.delete(recursive: true);
    }
  });

  test(
    'bounds teardown when the child ignores graceful termination',
    () async {
      if (Platform.isWindows) return;
      final directory = await Directory.systemTemp.createTemp('runner_process');
      final script = File('${directory.path}/ignores_term.dart');
      await script.writeAsString('''
import 'dart:async';
import 'dart:io';

Future<void> main() async {
  ProcessSignal.sigterm.watch().listen((_) {});
  await Future<void>.delayed(const Duration(hours: 1));
}
''');
      final process = await Process.start(
        findDartExecutable(),
        ['run', script.path],
        runInShell: false,
      );

      try {
        final result = await waitForManagedProcess(
          process,
          timeout: const Duration(milliseconds: 30),
          terminationGracePeriod: const Duration(milliseconds: 100),
        );
        expect(result.timedOut, isTrue);
        expect(result.exitCode, isNot(0));
      } finally {
        // The test intentionally exercises the forced-kill path.  On a
        // platform with delayed process notifications, clean up defensively.
        process.kill(ProcessSignal.sigkill);
      }
    },
  );

  test('does not mark a normally completed child as timed out', () async {
    final process = await Process.start(
      Platform.isWindows ? 'cmd' : 'true',
      Platform.isWindows ? const ['/c'] : const [],
      runInShell: false,
    );

    final result = await waitForManagedProcess(
      process,
      timeout: const Duration(seconds: 1),
    );

    expect(result.timedOut, isFalse);
    expect(result.exitCode, 0);
  });

  test('keeps running when the interruption source fails', () async {
    final process = await Process.start(
      Platform.isWindows ? 'cmd' : 'true',
      Platform.isWindows ? const ['/c'] : const [],
      runInShell: false,
    );

    final result = await waitForManagedProcess(
      process,
      timeout: const Duration(seconds: 1),
      interruption: Future<ProcessSignal>.error(StateError('signal source')),
    );

    expect(result.exitCode, 0);
    expect(result.timedOut, isFalse);
    expect(result.interrupted, isFalse);
  });

  test('keeps the timeout cause when interruption arrives during teardown',
      () async {
    if (Platform.isWindows) return;
    final directory = await Directory.systemTemp.createTemp('runner_signal');
    final script = File('${directory.path}/ignores_term.dart');
    await script.writeAsString('''
import 'dart:async';
import 'dart:io';

Future<void> main() async {
  ProcessSignal.sigterm.watch().listen((_) {});
  await Future<void>.delayed(const Duration(hours: 1));
}
''');
    final process = await Process.start(
      findDartExecutable(),
      ['run', script.path],
      runInShell: false,
    );
    final interruption = Completer<ProcessSignal>();
    final resolverStarted = Completer<void>();
    final snapshot = Completer<List<int>>();

    try {
      final exit = waitForManagedProcess(
        process,
        timeout: const Duration(milliseconds: 100),
        terminationGracePeriod: const Duration(milliseconds: 150),
        interruption: interruption.future,
        descendantResolver: (_) {
          if (!resolverStarted.isCompleted) resolverStarted.complete();
          return snapshot.future;
        },
      );

      // The timeout has claimed termination and is waiting on its initial
      // descendant snapshot. A later parent interruption must not rewrite
      // the cause already selected for this process.
      await resolverStarted.future;
      interruption.complete(ProcessSignal.sigterm);
      snapshot.complete(const []);

      final result = await exit.timeout(const Duration(seconds: 2));
      expect(result.timedOut, isTrue);
      expect(result.interrupted, isFalse);
      expect(result.exitCode, isNot(0));
    } finally {
      process.kill(ProcessSignal.sigkill);
      await directory.delete(recursive: true);
    }
  });

  test('forwards a parent interruption and bounds child teardown', () async {
    if (Platform.isWindows) return;
    final directory = await Directory.systemTemp.createTemp('runner_signal');
    final script = File('${directory.path}/ignores_term.dart');
    await script.writeAsString('''
import 'dart:async';
import 'dart:io';

Future<void> main() async {
  ProcessSignal.sigterm.watch().listen((_) {});
  await Future<void>.delayed(const Duration(hours: 1));
}
''');
    final process = await Process.start(
      findDartExecutable(),
      ['run', script.path],
      runInShell: false,
    );
    final interruption = Completer<ProcessSignal>();
    final stopwatch = Stopwatch()..start();
    try {
      final exit = waitForManagedProcess(
        process,
        terminationGracePeriod: const Duration(milliseconds: 100),
        interruption: interruption.future,
      );
      interruption.complete(ProcessSignal.sigterm);
      final result = await exit;
      expect(result.interrupted, isTrue);
      expect(result.timedOut, isFalse);
      expect(result.exitCode, isNot(0));
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
    } finally {
      process.kill(ProcessSignal.sigkill);
      await directory.delete(recursive: true);
    }
  });

  test('reaps a stubborn descendant when its worker is interrupted', () async {
    if (Platform.isWindows) return;
    final directory =
        await Directory.systemTemp.createTemp('runner_process_tree');
    final grandchildScript = File('${directory.path}/grandchild.dart');
    await grandchildScript.writeAsString('''
import 'dart:async';
import 'dart:io';

Future<void> main() async {
  ProcessSignal.sigterm.watch().listen((_) {});
  await Future<void>.delayed(const Duration(hours: 1));
}
''');
    final workerScript = File('${directory.path}/worker.dart');
    await workerScript.writeAsString('''
import 'dart:async';
import 'dart:io';

Future<void> main() async {
  final child = await Process.start(
    Platform.resolvedExecutable,
    ['run', ${jsonEncode(grandchildScript.path)}],
    runInShell: false,
  );
  stdout.writeln('grandchildPid=\${child.pid}');
  await stdout.flush();
  await Future<void>.delayed(const Duration(hours: 1));
}
''');
    final process = await Process.start(
      findDartExecutable(),
      ['run', workerScript.path],
      runInShell: false,
    );
    final grandchildPid = Completer<int>();
    final stdoutDone = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      final match = RegExp(r'^grandchildPid=(\d+)$').firstMatch(line);
      if (match != null && !grandchildPid.isCompleted) {
        grandchildPid.complete(int.parse(match.group(1)!));
      }
    }).asFuture<void>();
    final interruption = Completer<ProcessSignal>();

    try {
      final childPid = await grandchildPid.future.timeout(
        const Duration(seconds: 5),
      );
      final exit = waitForManagedProcess(
        process,
        interruption: interruption.future,
        terminationGracePeriod: const Duration(milliseconds: 100),
      );
      interruption.complete(ProcessSignal.sigterm);

      final result = await exit.timeout(const Duration(seconds: 5));
      await stdoutDone;
      expect(result.interrupted, isTrue);
      expect(result.timedOut, isFalse);
      expect(result.exitCode, isNot(0));
      final liveness =
          await Process.run('ps', ['-p', '$childPid', '-o', 'pid=']);
      expect((liveness.stdout as String).trim(), isEmpty);
    } finally {
      process.kill(ProcessSignal.sigkill);
      await directory.delete(recursive: true);
    }
  });

  test('reaps a descendant spawned by the worker termination handler',
      () async {
    if (Platform.isWindows) return;
    final directory =
        await Directory.systemTemp.createTemp('runner_late_process_tree');
    final grandchildScript = File('${directory.path}/grandchild.dart');
    await grandchildScript.writeAsString('''
import 'dart:async';
import 'dart:io';

Future<void> main() async {
  ProcessSignal.sigterm.watch().listen((_) {});
  await Future<void>.delayed(const Duration(hours: 1));
}
''');
    final workerScript = File('${directory.path}/worker.dart');
    await workerScript.writeAsString('''
import 'dart:async';
import 'dart:io';

Future<void> main() async {
  ProcessSignal.sigterm.watch().listen((_) async {
    final child = await Process.start(
      Platform.resolvedExecutable,
      ['run', ${jsonEncode(grandchildScript.path)}],
      runInShell: false,
    );
    stdout.writeln('lateGrandchildPid=\${child.pid}');
    await stdout.flush();
  });
  stdout.writeln('workerReady');
  await stdout.flush();
  await Future<void>.delayed(const Duration(hours: 1));
}
''');
    final process = await Process.start(
      findDartExecutable(),
      ['run', workerScript.path],
      runInShell: false,
    );
    final lateGrandchildPid = Completer<int>();
    final workerReady = Completer<void>();
    final stdoutSubscription = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (line == 'workerReady' && !workerReady.isCompleted) {
        workerReady.complete();
      }
      final match = RegExp(r'^lateGrandchildPid=(\d+)$').firstMatch(line);
      if (match != null && !lateGrandchildPid.isCompleted) {
        lateGrandchildPid.complete(int.parse(match.group(1)!));
      }
    });
    final interruption = Completer<ProcessSignal>();
    var childPid = -1;
    var workerExited = false;

    try {
      await workerReady.future.timeout(const Duration(seconds: 3));
      final exit = waitForManagedProcess(
        process,
        interruption: interruption.future,
        terminationGracePeriod: const Duration(milliseconds: 400),
      );
      interruption.complete(ProcessSignal.sigterm);
      childPid = await lateGrandchildPid.future.timeout(
        const Duration(seconds: 3),
      );
      final result = await exit.timeout(const Duration(seconds: 4));
      workerExited = true;
      expect(result.interrupted, isTrue);
      expect(result.timedOut, isFalse);
      expect(result.exitCode, isNot(0));
      final liveness =
          await Process.run('ps', ['-p', '$childPid', '-o', 'pid=']);
      expect((liveness.stdout as String).trim(), isEmpty);
    } finally {
      await stdoutSubscription.cancel();
      if (!workerExited) process.kill(ProcessSignal.sigkill);
      if (childPid > 0) Process.killPid(childPid, ProcessSignal.sigkill);
      await directory.delete(recursive: true);
    }
  });

  test('reaps a nested descendant created during worker interruption',
      () async {
    if (Platform.isWindows) return;
    final directory =
        await Directory.systemTemp.createTemp('runner_nested_process_tree');
    final workerScript = File('${directory.path}/worker.dart');
    const shellCommand = r'sleep 600 & echo nestedPid=$!; wait';
    await workerScript.writeAsString('''
import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  ProcessSignal.sigterm.watch().listen((_) async {
    final child = await Process.start(
      '/bin/sh',
      ['-c', r${jsonEncode(shellCommand)}],
      runInShell: false,
    );
    child.stdout.transform(utf8.decoder).listen(stdout.write);
    await Future<void>.delayed(const Duration(seconds: 2));
  });
  stdout.writeln('workerReady');
  await stdout.flush();
  await Future<void>.delayed(const Duration(hours: 1));
}
''');
    final process = await Process.start(
      findDartExecutable(),
      ['run', workerScript.path],
      runInShell: false,
    );
    final workerReady = Completer<void>();
    final nestedPid = Completer<int>();
    final output = StringBuffer();
    final stderr = StringBuffer();
    final stderrSubscription =
        process.stderr.transform(utf8.decoder).listen(stderr.write);
    final stdoutSubscription = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      output.writeln(line);
      if (line == 'workerReady' && !workerReady.isCompleted) {
        workerReady.complete();
      }
      final match = RegExp(r'^nestedPid=(\d+)$').firstMatch(line);
      if (match != null && !nestedPid.isCompleted) {
        nestedPid.complete(int.parse(match.group(1)!));
      }
    });
    final interruption = Completer<ProcessSignal>();
    var trackedNestedPid = -1;
    var workerExited = false;

    try {
      await workerReady.future.timeout(const Duration(seconds: 3));
      final exit = waitForManagedProcess(
        process,
        interruption: interruption.future,
        terminationGracePeriod: const Duration(milliseconds: 500),
      );
      interruption.complete(ProcessSignal.sigterm);
      try {
        trackedNestedPid =
            await nestedPid.future.timeout(const Duration(seconds: 4));
      } on TimeoutException {
        fail('Nested process PID was not reported. stdout: $output');
      }
      final result = await exit.timeout(const Duration(seconds: 5));
      workerExited = true;

      expect(result.interrupted, isTrue);
      expect(result.timedOut, isFalse);
      expect(result.exitCode, isNot(0));
      final liveness =
          await Process.run('ps', ['-p', '$trackedNestedPid', '-o', 'pid=']);
      expect((liveness.stdout as String).trim(), isEmpty);
    } finally {
      await stdoutSubscription.cancel();
      await stderrSubscription.cancel();
      if (!workerExited) process.kill(ProcessSignal.sigkill);
      if (trackedNestedPid > 0) {
        Process.killPid(trackedNestedPid, ProcessSignal.sigkill);
      }
      await directory.delete(recursive: true);
    }
  });

  test('reaps a nested descendant created during worker timeout', () async {
    if (Platform.isWindows) return;
    final directory =
        await Directory.systemTemp.createTemp('runner_timeout_process_tree');
    final workerScript = File('${directory.path}/worker.dart');
    const shellCommand = r'sleep 600 & echo nestedPid=$!; wait';
    await workerScript.writeAsString('''
import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  ProcessSignal.sigterm.watch().listen((_) async {
    final child = await Process.start(
      '/bin/sh',
      ['-c', r${jsonEncode(shellCommand)}],
      runInShell: false,
    );
    child.stdout.transform(utf8.decoder).listen(stdout.write);
    await Future<void>.delayed(const Duration(seconds: 2));
  });
  stdout.writeln('workerReady');
  await stdout.flush();
  await Future<void>.delayed(const Duration(hours: 1));
}
''');
    final process = await Process.start(
      findDartExecutable(),
      ['run', workerScript.path],
      runInShell: false,
    );
    final workerReady = Completer<void>();
    final nestedPid = Completer<int>();
    final output = StringBuffer();
    final stderr = StringBuffer();
    final stderrSubscription =
        process.stderr.transform(utf8.decoder).listen(stderr.write);
    final stdoutSubscription = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      output.writeln(line);
      if (line == 'workerReady' && !workerReady.isCompleted) {
        workerReady.complete();
      }
      final match = RegExp(r'^nestedPid=(\d+)$').firstMatch(line);
      if (match != null && !nestedPid.isCompleted) {
        nestedPid.complete(int.parse(match.group(1)!));
      }
    });
    var trackedNestedPid = -1;
    var workerExited = false;

    try {
      try {
        await workerReady.future.timeout(const Duration(seconds: 3));
      } on TimeoutException {
        fail('Worker did not become ready. stderr: $stderr');
      }
      final result = await waitForManagedProcess(
        process,
        timeout: const Duration(milliseconds: 30),
        terminationGracePeriod: const Duration(milliseconds: 500),
      ).timeout(const Duration(seconds: 5));
      workerExited = true;
      trackedNestedPid =
          await nestedPid.future.timeout(const Duration(seconds: 1));

      expect(result.timedOut, isTrue);
      expect(result.interrupted, isFalse);
      expect(result.exitCode, isNot(0));
      final liveness =
          await Process.run('ps', ['-p', '$trackedNestedPid', '-o', 'pid=']);
      expect((liveness.stdout as String).trim(), isEmpty);
    } finally {
      await stdoutSubscription.cancel();
      await stderrSubscription.cancel();
      if (!workerExited) process.kill(ProcessSignal.sigkill);
      if (trackedNestedPid > 0) {
        Process.killPid(trackedNestedPid, ProcessSignal.sigkill);
      }
      await directory.delete(recursive: true);
    }
  });

  test('reaps descendants spawned by a child termination handler', () async {
    if (Platform.isWindows) return;
    final directory = await Directory.systemTemp
        .createTemp('runner_descendant_termination_tree');
    final workerScript = File('${directory.path}/worker.dart');
    final nestedPidFile = File('${directory.path}/nested.pid');
    final shellCommand =
        "trap 'sleep 600 & echo \$! > ${nestedPidFile.path}; wait' TERM; echo childReady; sleep 600 & wait";
    await workerScript.writeAsString('''
import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final child = await Process.start(
    '/bin/sh',
    ['-c', r${jsonEncode(shellCommand)}],
    runInShell: false,
  );
  child.stdout.transform(utf8.decoder).listen(stdout.write);
  child.stderr.transform(utf8.decoder).listen(stderr.write);
  stdout.writeln('workerReady');
  await stdout.flush();
  await Future<void>.delayed(const Duration(hours: 1));
}
''');
    final process = await Process.start(
      findDartExecutable(),
      ['run', workerScript.path],
      runInShell: false,
    );
    final output = StringBuffer();
    final stderr = StringBuffer();
    final workerReady = Completer<void>();
    final childReady = Completer<void>();
    final stdoutSubscription = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      output.writeln(line);
      if (line == 'workerReady' && !workerReady.isCompleted) {
        workerReady.complete();
      }
      if (line == 'childReady' && !childReady.isCompleted) {
        childReady.complete();
      }
    });
    final stderrSubscription =
        process.stderr.transform(utf8.decoder).listen(stderr.write);
    var trackedNestedPid = -1;
    var workerExited = false;

    try {
      try {
        await Future.wait([workerReady.future, childReady.future])
            .timeout(const Duration(seconds: 5));
      } on TimeoutException {
        fail('Worker not ready: $output; stderr: $stderr');
      }
      final result = await waitForManagedProcess(
        process,
        timeout: const Duration(milliseconds: 30),
        terminationGracePeriod: const Duration(milliseconds: 500),
      ).timeout(const Duration(seconds: 5));
      workerExited = true;
      for (var attempt = 0; attempt < 40; attempt++) {
        if (await nestedPidFile.exists()) {
          trackedNestedPid = int.tryParse(
                (await nestedPidFile.readAsString()).trim(),
              ) ??
              -1;
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }

      expect(result.timedOut, isTrue, reason: output.toString());
      expect(
        trackedNestedPid,
        greaterThan(0),
        reason: 'stdout: $output\nstderr: $stderr',
      );
      final liveness = await Process.run(
        'ps',
        ['-p', '$trackedNestedPid', '-o', 'pid='],
      );
      expect((liveness.stdout as String).trim(), isEmpty);
    } finally {
      await stdoutSubscription.cancel();
      await stderrSubscription.cancel();
      if (!workerExited) process.kill(ProcessSignal.sigkill);
      if (trackedNestedPid > 0) {
        Process.killPid(trackedNestedPid, ProcessSignal.sigkill);
      }
      await directory.delete(recursive: true);
    }
  });

  test('actual parent SIGTERM is forwarded through the worker lifecycle',
      () async {
    if (Platform.isWindows) return;
    final script = File(
      '${Directory.current.path}/test/support/cli_process_interruption_child.dart',
    );
    final process = await Process.start(
      findDartExecutable(),
      ['run', script.absolute.path],
      workingDirectory: Directory.current.path,
      runInShell: false,
    );
    final output = StringBuffer();
    final workerPid = Completer<int>();
    final stdoutDone = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      output.writeln(line);
      final match = RegExp(r'^workerPid=(\d+)$').firstMatch(line);
      if (match != null && !workerPid.isCompleted) {
        workerPid.complete(int.parse(match.group(1)!));
      }
    }).asFuture<void>();
    final stderr = StringBuffer();
    final stderrDone = process.stderr
        .transform(utf8.decoder)
        .listen(stderr.write)
        .asFuture<void>();
    var innerWorkerPid = -1;
    var wrapperExited = false;
    var workerExitReported = false;

    try {
      try {
        innerWorkerPid =
            await workerPid.future.timeout(const Duration(seconds: 5));
      } on TimeoutException {
        fail('Worker PID was not reported. stderr: $stderr');
      }
      expect(process.kill(ProcessSignal.sigterm), isTrue);
      final exitCode = await process.exitCode.timeout(
        const Duration(seconds: 3),
      );
      wrapperExited = true;
      await Future.wait([stdoutDone, stderrDone]);

      expect(exitCode, 0);
      expect(output.toString(), contains('interrupted=true'));
      final workerExit =
          RegExp(r'workerExitCode=(-?\d+)').firstMatch(output.toString());
      expect(workerExit, isNotNull);
      workerExitReported = true;
      expect(int.parse(workerExit!.group(1)!), isNot(0));
    } finally {
      if (!wrapperExited) process.kill(ProcessSignal.sigkill);
      if (!workerExitReported && innerWorkerPid > 0) {
        Process.killPid(innerWorkerPid, ProcessSignal.sigkill);
      }
    }
  });

  test('resolves bounded teardown when sending a termination signal throws',
      () async {
    if (Platform.isWindows) return;
    final directory = await Directory.systemTemp.createTemp('runner_signal');
    final script = File('${directory.path}/ignores_term.dart');
    await script.writeAsString('''
import 'dart:async';
import 'dart:io';

Future<void> main() async {
  ProcessSignal.sigterm.watch().listen((_) {});
  await Future<void>.delayed(const Duration(hours: 1));
}
''');
    final process = await Process.start(
      findDartExecutable(),
      ['run', script.path],
      runInShell: false,
    );
    final sentSignals = <ProcessSignal>[];

    try {
      final result = await waitForManagedProcess(
        process,
        timeout: const Duration(milliseconds: 30),
        terminationGracePeriod: const Duration(milliseconds: 50),
        signalSender: (signal) {
          sentSignals.add(signal);
          if (signal == ProcessSignal.sigterm) {
            throw const ProcessException('test', [], 'signal unavailable');
          }
          return process.kill(signal);
        },
      );

      expect(result.timedOut, isTrue);
      expect(result.exitCode, isNot(0));
      expect(sentSignals, [ProcessSignal.sigterm, ProcessSignal.sigkill]);
    } finally {
      process.kill(ProcessSignal.sigkill);
      await directory.delete(recursive: true);
    }
  });

  test('returns after the hard bound when all termination signals throw',
      () async {
    if (Platform.isWindows) return;
    final directory = await Directory.systemTemp.createTemp('runner_signal');
    final script = File('${directory.path}/stuck.dart');
    await script.writeAsString('''
Future<void> main() async {
  await Future<void>.delayed(const Duration(hours: 1));
}
''');
    final process = await Process.start(
      findDartExecutable(),
      ['run', script.path],
      runInShell: false,
    );
    final stopwatch = Stopwatch()..start();

    try {
      final result = await waitForManagedProcess(
        process,
        timeout: const Duration(milliseconds: 20),
        terminationGracePeriod: const Duration(milliseconds: 40),
        signalSender: (_) => throw const ProcessException(
          'test',
          [],
          'signal unavailable',
        ),
      );

      expect(result.timedOut, isTrue);
      expect(result.exitCode, -1);
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
    } finally {
      process.kill(ProcessSignal.sigkill);
      await directory.delete(recursive: true);
    }
  });
}
