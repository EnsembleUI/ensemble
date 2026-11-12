import 'dart:async';

/// Serializes real async work (HTTP, etc.) through [WidgetTester.runAsync].
///
/// Flutter rejects reentrant [WidgetTester.runAsync] calls, so live network
/// requests from the app must be queued when multiple actions run in parallel.
class LiveAsyncCallSupport {
  static Future<T?> Function<T>(Future<T> Function())? runner;
  static Future<T?> Function<T>(Future<T> Function())? platformHttpRunner;

  static int _completedLiveCalls = 0;
  static DateTime? _lastLiveCallCompletedAt;
  static final Map<Future<dynamic>, int> _inFlightLiveCalls = {};
  static int _attemptGeneration = 0;
  static final List<_QueuedLiveAsyncCall<dynamic>> _priorityQueue = [];
  static final List<_QueuedLiveAsyncCall<dynamic>> _liveCallQueue = [];
  static bool _isDrainingQueue = false;
  static bool _drainScheduled = false;

  static Iterable<Future<dynamic>> get _currentAttemptCalls =>
      _inFlightLiveCalls.entries
          .where((entry) => entry.value == _attemptGeneration)
          .map((entry) => entry.key);

  static bool get hasPendingLiveCalls => _currentAttemptCalls.isNotEmpty;
  static int get pendingLiveCallCount => _currentAttemptCalls.length;
  static int get completedLiveCallCount => _completedLiveCalls;
  static DateTime? get lastLiveCallCompletedAt => _lastLiveCallCompletedAt;

  /// Captures the live calls already in flight at this boundary.
  ///
  /// The returned future does not include calls started after the snapshot.
  static Future<void>? pendingLiveCallsSnapshot() {
    final calls = _currentAttemptCalls.toList();
    if (calls.isEmpty) return null;
    return Future.wait(calls);
  }

  static Future<void> waitForLiveCalls() async {
    final calls = _currentAttemptCalls.toList();
    if (calls.isEmpty) {
      return;
    }
    await Future.wait(calls);
  }

  /// Runs platform HTTP outside the runner's console-capture zone.
  ///
  /// Some platform HTTP clients depend on the test binding's native
  /// `runAsync` zone. Keep this route on the binding directly while ordinary
  /// app async work uses [runner] for console capture.
  static Future<T?> runWithPlatformHttp<T>(Future<T> Function() call) =>
      _run(call, trackAsLiveCall: true, runnerOverride: platformHttpRunner);

  static Future<T?> run<T>(Future<T> Function() call) =>
      _run(call, trackAsLiveCall: true);

  /// Queues work through the same runAsync lane without counting it as live
  /// app work. Use this for best-effort artifact generation so API settling
  /// does not wait for screenshots.
  static Future<T?> runUntracked<T>(
    Future<T> Function() call, {
    Future<T?> Function<T>(Future<T> Function())? runnerOverride,
  }) =>
      _run(
        call,
        trackAsLiveCall: false,
        runnerOverride: runnerOverride,
      );

  /// Runs artifact work after the currently executing live call, ahead of
  /// background app calls that are still queued. Widget screenshot encoding
  /// uses the same non-reentrant `WidgetTester.runAsync` lane as live APIs, but
  /// should not have to wait for the app's entire background request backlog.
  static Future<T?> runPriorityUntracked<T>(Future<T> Function() call) =>
      _run(call, trackAsLiveCall: false, priority: true);

  static Future<T?> _run<T>(
    Future<T> Function() call, {
    required bool trackAsLiveCall,
    Future<T?> Function<T>(Future<T> Function())? runnerOverride,
    bool priority = false,
  }) {
    final liveRunner = runnerOverride ?? runner;
    if (liveRunner == null &&
        !_isDrainingQueue &&
        _priorityQueue.isEmpty &&
        _liveCallQueue.isEmpty) {
      return call();
    }

    final completer = Completer<T?>();
    final trackedFuture = completer.future;
    final generation = _attemptGeneration;
    if (trackAsLiveCall) {
      _inFlightLiveCalls[trackedFuture] = generation;
    }

    final queuedCall = _QueuedLiveAsyncCall<T>(
      call: call,
      runner: liveRunner,
      completer: completer,
      onSettled: trackAsLiveCall
          ? () {
              _inFlightLiveCalls.remove(trackedFuture);
              // Keep calls from a previous attempt serialized, but exclude
              // their completion from the current attempt's diagnostics.
              if (generation == _attemptGeneration) {
                _completedLiveCalls++;
                _lastLiveCallCompletedAt = DateTime.now().toUtc();
              }
            }
          : null,
    );
    (priority ? _priorityQueue : _liveCallQueue).add(queuedCall);
    _drainQueue();

    return trackedFuture;
  }

  static void reset() {
    runner = null;
    platformHttpRunner = null;
    _attemptGeneration++;
    _completedLiveCalls = 0;
    _lastLiveCallCompletedAt = null;
    // Calls can be outstanding when one app case is torn down. Clearing or
    // replacing this queue would allow the next case to enter
    // WidgetTester.runAsync concurrently and Flutter will reject it as
    // reentrant. Old calls remain serialized, while generation filtering
    // keeps them out of the new attempt's pending/completion counts.
  }

  /// Uses one runAsync lane and prioritizes diagnostic writes after the active
  /// callback, before queued background app requests.
  static void _drainQueue() {
    if (_isDrainingQueue || _drainScheduled) return;
    // App action groups commonly launch several independent APIs in the same
    // synchronous turn. Let those calls join one batch before entering
    // WidgetTester.runAsync; invoking runAsync once per request serializes all
    // network latency and delays the app's callbacks/UI updates.
    _drainScheduled = true;
    scheduleMicrotask(() {
      _drainScheduled = false;
      _startQueueDrain();
    });
  }

  static void _startQueueDrain() {
    if (_isDrainingQueue) return;
    _isDrainingQueue = true;
    unawaited(() async {
      try {
        while (_priorityQueue.isNotEmpty || _liveCallQueue.isNotEmpty) {
          final queue =
              _priorityQueue.isNotEmpty ? _priorityQueue : _liveCallQueue;
          final runner = queue.first.runner;
          final batch = <_QueuedLiveAsyncCall<dynamic>>[];
          while (queue.isNotEmpty && identical(queue.first.runner, runner)) {
            batch.add(queue.removeAt(0));
          }

          Future<void> runBatch() async {
            await Future.wait(batch.map((call) => call.runInCurrentZone()));
          }

          if (runner == null) {
            await runBatch();
          } else {
            // All requests in the batch start concurrently inside one real
            // async zone. The lane itself remains single-entry, so calls
            // across attempts and priority artifact work stay non-reentrant.
            await runner<void>(runBatch);
          }
        }
      } finally {
        _isDrainingQueue = false;
        if (_priorityQueue.isNotEmpty || _liveCallQueue.isNotEmpty) {
          _drainQueue();
        }
      }
    }());
  }
}

class _QueuedLiveAsyncCall<T> {
  _QueuedLiveAsyncCall({
    required this.call,
    required this.runner,
    required this.completer,
    this.onSettled,
  });

  final Future<T> Function() call;
  final Future<R?> Function<R>(Future<R> Function())? runner;
  final Completer<T?> completer;
  final void Function()? onSettled;

  Future<void> runInCurrentZone() async {
    try {
      completer.complete(await call());
    } catch (error, stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    } finally {
      onSettled?.call();
    }
  }
}
