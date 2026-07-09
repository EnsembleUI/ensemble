import 'dart:async';

/// Serializes real async work (HTTP, etc.) through [WidgetTester.runAsync].
///
/// Flutter rejects reentrant [WidgetTester.runAsync] calls, so live network
/// requests from the app must be queued when multiple actions run in parallel.
class LiveAsyncCallSupport {
  static Future<T?> Function<T>(Future<T> Function())? runner;

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

  static Future<T?> run<T>(Future<T> Function() call) {
    final liveRunner = runner;
    if (liveRunner == null) {
      return call();
    }

    _pendingLiveCalls++;
    final completer = Completer<T?>();
    final tracked = completer.future;
    _inFlightLiveCalls.add(tracked);

    _liveCallQueue = _liveCallQueue.then((_) async {
      try {
        completer.complete(await liveRunner<T>(call));
      } catch (error, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      } finally {
        _pendingLiveCalls--;
        _inFlightLiveCalls.remove(tracked);
      }
    });

    return tracked;
  }

  static void reset() {
    runner = null;
    _pendingLiveCalls = 0;
    _inFlightLiveCalls.clear();
    _liveCallQueue = Future<void>.value();
  }
}
