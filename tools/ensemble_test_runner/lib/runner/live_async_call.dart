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
  static final Set<Future<dynamic>> _inFlightLiveCalls = {};
  static Future<void> _liveCallQueue = Future<void>.value();

  static bool get hasPendingLiveCalls => _inFlightLiveCalls.isNotEmpty;
  static int get pendingLiveCallCount => _inFlightLiveCalls.length;
  static int get completedLiveCallCount => _completedLiveCalls;
  static DateTime? get lastLiveCallCompletedAt => _lastLiveCallCompletedAt;

  /// Captures the live calls already in flight at this boundary.
  ///
  /// The returned future does not include calls started after the snapshot.
  static Future<void>? pendingLiveCallsSnapshot() {
    if (_inFlightLiveCalls.isEmpty) return null;
    return Future.wait(_inFlightLiveCalls.toList());
  }

  static Future<void> waitForLiveCalls() async {
    if (_inFlightLiveCalls.isEmpty) {
      return;
    }
    await Future.wait(_inFlightLiveCalls.toList());
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
  static Future<T?> runUntracked<T>(Future<T> Function() call) =>
      _run(call, trackAsLiveCall: false);

  static Future<T?> _run<T>(
    Future<T> Function() call, {
    required bool trackAsLiveCall,
    Future<T?> Function<T>(Future<T> Function())? runnerOverride,
  }) {
    final liveRunner = runnerOverride ?? runner;
    if (liveRunner == null) {
      return call();
    }

    final completer = Completer<T?>();
    final trackedFuture = completer.future;
    if (trackAsLiveCall) {
      _inFlightLiveCalls.add(trackedFuture);
    }

    _liveCallQueue = _liveCallQueue.then((_) async {
      try {
        completer.complete(await liveRunner<T>(call));
      } catch (error, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      } finally {
        if (trackAsLiveCall) {
          _inFlightLiveCalls.remove(trackedFuture);
          _completedLiveCalls++;
          _lastLiveCallCompletedAt = DateTime.now().toUtc();
        }
      }
    });

    return trackedFuture;
  }

  static void reset() {
    runner = null;
    platformHttpRunner = null;
    _completedLiveCalls = 0;
    _lastLiveCallCompletedAt = null;
    _inFlightLiveCalls.clear();
    _liveCallQueue = Future<void>.value();
  }
}
