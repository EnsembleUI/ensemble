import 'dart:async';
import 'dart:io';

/// The result of waiting for a child process, including why the runner
/// interrupted it.
final class ManagedProcessExit {
  const ManagedProcessExit({
    required this.exitCode,
    required this.timedOut,
    this.interrupted = false,
  });

  final int exitCode;
  final bool timedOut;
  final bool interrupted;
}

/// Starts every prepared worker and waits for all of them, even when one
/// start callback throws synchronously or one worker fails immediately.
///
/// The callbacks are invoked before awaiting any result so a single launch
/// error cannot leave later workers unstarted and outside the caller's join.
Future<List<T>> startManagedProcesses<T>(
  Iterable<Future<T> Function()> start,
) {
  final running = <Future<T>>[];
  for (final startProcess in start) {
    running.add(Future<T>.sync(startProcess));
  }
  return Future.wait(running, eagerError: false);
}

/// Waits for [process], terminating it on timeout, interruption, or request.
///
/// A stuck child is force-killed after [terminationGracePeriod]. Both
/// termination paths share the process exit future and are bounded even when
/// the operating system does not report the final exit code.
Future<ManagedProcessExit> waitForManagedProcess(
  Process process, {
  Duration? timeout,
  Duration terminationGracePeriod = const Duration(seconds: 3),
  Future<ProcessSignal>? interruption,

  /// Sends this signal immediately after installing the exit and interruption
  /// handlers. This lets owners request teardown while still snapshotting and
  /// cleaning descendants before the root exits.
  ProcessSignal? terminateOnStart,
  bool Function(ProcessSignal signal)? signalSender,
  Future<List<int>> Function(int rootPid)? descendantResolver,
}) {
  final result = Completer<ManagedProcessExit>();
  final processExit = process.exitCode;
  Timer? timer;
  var timedOut = false;
  var interrupted = false;
  var terminating = false;
  int? observedExitCode;
  final sendSignal = signalSender ?? process.kill;

  void complete(int exitCode) {
    timer?.cancel();
    if (!result.isCompleted) {
      result.complete(ManagedProcessExit(
        exitCode: exitCode,
        timedOut: timedOut,
        interrupted: interrupted,
      ));
    }
  }

  Future<void> terminate(
    ProcessSignal signal, {
    required bool timeout,
    bool interruption = false,
  }) async {
    if (result.isCompleted || terminating) return;
    // The first termination trigger owns the outcome classification. A later
    // timeout or parent interruption can arrive while cleanup awaits process
    // discovery, but must not rewrite the cause selected by this invocation.
    terminating = true;
    timedOut = timeout;
    interrupted = interruption;
    final resolveDescendants = descendantResolver ?? _processDescendants;
    final descendants = <int>{};
    Future<List<int>> descendantsSnapshot(int rootPid, Duration budget) async {
      try {
        final resolution = Future<List<int>>.sync(
          () => resolveDescendants(rootPid),
        ).then<List<int>>(
          (descendants) => descendants,
          onError: (Object _, StackTrace __) => const [],
        );
        return await resolution.timeout(
          budget,
          onTimeout: () => const [],
        );
      } on Object {
        // Descendant discovery is best-effort. A process-table failure must
        // never prevent signaling the managed root or completing its wait.
        return const [];
      }
    }

    descendants.addAll(
      await descendantsSnapshot(process.pid, terminationGracePeriod),
    );
    try {
      sendSignal(signal);
    } catch (_) {
      // A failed graceful signal must not strand the caller. Continue to the
      // forced-kill path and retain the same bounded exit wait.
    }
    // A worker can spawn a subprocess from its SIGTERM handler. Keep sampling
    // while the root is alive so those late descendants are not orphaned when
    // the root is force-killed at the end of the grace period.
    final graceDeadline = DateTime.now().add(terminationGracePeriod);
    while (observedExitCode == null && DateTime.now().isBefore(graceDeadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
      if (observedExitCode != null) break;
      final remaining = graceDeadline.difference(DateTime.now());
      if (remaining <= Duration.zero) break;
      descendants.addAll(await descendantsSnapshot(process.pid, remaining));
    }

    var exitCode = observedExitCode;
    if (exitCode == null) {
      // A child that survives SIGKILL, or whose exit notification is lost,
      // must not block suite teardown indefinitely. A platform-level kill
      // error is equivalent to a missing exit notification at this point.
      try {
        sendSignal(ProcessSignal.sigkill);
      } catch (_) {
        exitCode = -1;
      }
      exitCode ??= await processExit.timeout(
        terminationGracePeriod,
        onTimeout: () => -1,
      );
    }
    await _terminateDescendants(
        descendants.toList(growable: false), signal, terminationGracePeriod);
    complete(exitCode);
  }

  processExit.then((exitCode) {
    observedExitCode = exitCode;
    if (!terminating) complete(exitCode);
  });
  interruption?.then(
    (signal) => terminate(signal, timeout: false, interruption: true),
    onError: (Object _, StackTrace __) {
      // Signal delivery is best-effort. A failed signal source must not
      // surface as an unhandled asynchronous error while the managed child
      // continues to its normal exit or configured timeout.
    },
  );
  if (timeout != null) {
    timer =
        Timer(timeout, () => terminate(ProcessSignal.sigterm, timeout: true));
  }
  if (terminateOnStart != null) {
    unawaited(terminate(terminateOnStart, timeout: false));
  }
  return result.future;
}

/// Finds descendants before the root exits and reparents them to the OS.
///
/// Flutter's test command owns subprocesses that may outlive its CLI process.
/// This is only used on cancellation/timeout, so a process-table snapshot does
/// not affect successful run cost.
Future<List<int>> _processDescendants(int rootPid) async {
  return _processDescendantsOf([rootPid]);
}

Future<List<int>> _processDescendantsOf(Iterable<int> roots) async {
  final rootPids = roots.toSet();
  if (rootPids.isEmpty) return const [];
  if (Platform.isWindows) return const [];
  try {
    final result = await Process.run('ps', ['-axo', 'pid=,ppid=']);
    if (result.exitCode != 0) return const [];
    final children = <int, List<int>>{};
    for (final line in (result.stdout as String).split('\n')) {
      final fields = line.trim().split(RegExp(r'\s+'));
      if (fields.length != 2) continue;
      final pid = int.tryParse(fields[0]);
      final parent = int.tryParse(fields[1]);
      if (pid == null || parent == null) continue;
      children.putIfAbsent(parent, () => []).add(pid);
    }
    final descendants = <int>[];
    final pending = <int>[];
    for (final rootPid in rootPids) {
      pending.addAll(children[rootPid] ?? const []);
    }
    final seen = rootPids;
    while (pending.isNotEmpty) {
      final pid = pending.removeLast();
      if (!seen.add(pid)) continue;
      descendants.add(pid);
      pending.addAll(children[pid] ?? const []);
    }
    return descendants;
  } on Object {
    return const [];
  }
}

Future<void> _terminateDescendants(
  List<int> descendants,
  ProcessSignal signal,
  Duration gracePeriod,
) async {
  if (descendants.isEmpty || Platform.isWindows) return;
  // Signal parents first so their termination handlers can run. A child may
  // create another helper during that handler, so keep observing surviving
  // descendants throughout the grace period and include new processes.
  final known = descendants.toSet();
  for (final pid in descendants) {
    try {
      Process.killPid(pid, signal);
    } on Object {
      // A descendant may have exited with the parent. Continue through the
      // captured tree and force-kill only processes that remain alive.
    }
  }

  final stopwatch = Stopwatch()..start();
  var active = await _activeProcesses(known.toList(growable: false));
  while (active.isNotEmpty && stopwatch.elapsed < gracePeriod) {
    final remaining = gracePeriod - stopwatch.elapsed;
    final spawned = await _processDescendantsOf(active).timeout(
      remaining,
      onTimeout: () => const [],
    );
    final newlyObserved = spawned.where(known.add).toList(growable: false);
    for (final pid in newlyObserved) {
      try {
        Process.killPid(pid, signal);
      } on Object {
        // The process can exit between the process-table read and the signal.
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 25));
    active = await _activeProcesses(known.toList(growable: false));
  }
  for (final pid in active) {
    try {
      Process.killPid(pid, ProcessSignal.sigkill);
    } on Object {
      // The process can exit between the liveness check and signal delivery.
    }
  }
  final killDeadline = DateTime.now().add(gracePeriod);
  while (active.isNotEmpty && DateTime.now().isBefore(killDeadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 25));
    active = await _activeProcesses(active);
  }
}

Future<List<int>> _activeProcesses(List<int> processIds) async {
  if (processIds.isEmpty) return const [];
  try {
    final result =
        await Process.run('ps', ['-p', processIds.join(','), '-o', 'pid=']);
    if (result.exitCode != 0) return const [];
    return (result.stdout as String)
        .split('\n')
        .map((line) => int.tryParse(line.trim()))
        .whereType<int>()
        .toList(growable: false);
  } on Object {
    return const [];
  }
}
