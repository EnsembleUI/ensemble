import 'dart:async';

/// Serializes real async work (HTTP, etc.) through [WidgetTester.runAsync].
///
/// Flutter rejects reentrant [WidgetTester.runAsync] calls, so live network
/// requests from the app must be queued when multiple actions run in parallel.
class LiveAsyncCallSupport {
  static Future<T?> Function<T>(Future<T> Function())? runner;
  static void Function()? drainPendingExceptions;

  static int _pendingLiveCalls = 0;
  static final Set<Future<dynamic>> _inFlightLiveCalls = {};
  static Future<void> _liveCallQueue = Future<void>.value();

  static bool get hasPendingLiveCalls => _pendingLiveCalls > 0;

  static Future<void> waitForLiveCalls() async {
    if (_inFlightLiveCalls.isEmpty) {
      return;
    }
    await Future.wait(_inFlightLiveCalls.toList());
  }

  /// Backwards-compatible alias for callers that need real async work.
  static Future<T?> runWithPlatformHttp<T>(Future<T> Function() call) =>
      run(call);

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
  }) {
    final liveRunner = runner;
    if (liveRunner == null) {
      return call();
    }

    final completer = Completer<T?>();
    final trackedFuture = completer.future;
    if (trackAsLiveCall) {
      _pendingLiveCalls++;
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
        drainPendingExceptions?.call();
        if (trackAsLiveCall) {
          _pendingLiveCalls--;
          _inFlightLiveCalls.remove(trackedFuture);
        }
      }
    });

    return trackedFuture;
  }

  static void reset() {
    runner = null;
    drainPendingExceptions = null;
    _pendingLiveCalls = 0;
    _inFlightLiveCalls.clear();
    _liveCallQueue = Future<void>.value();
  }
}
