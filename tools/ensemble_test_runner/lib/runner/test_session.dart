import 'dart:async';

import 'package:ensemble/framework/screen_tracker.dart';

/// Records screen visits for declarative tests (including back-navigation revisits).
class NavigationFlowRecorder {
  NavigationFlowRecorder({
    Stream<VisibleScreen?> Function()? screenChanges,
  }) : _screenChanges = screenChanges;

  final Stream<VisibleScreen?> Function()? _screenChanges;
  final List<String> _flow = [];
  final List<VisibleScreen> _pendingScreens = [];
  StreamSubscription<VisibleScreen?>? _subscription;
  Future<void>? _cancellationInFlight;

  /// Invoked when a screen name is appended to [flow] (after de-dupe).
  FutureOr<void> Function(String screenName)? onScreenAdded;

  List<String> get flow => List.unmodifiable(_flow);

  /// Whether this recorder currently owns a screen-change subscription.
  bool get isListening => _subscription != null;

  void _startListening() {
    // Attempt setup can be reached through more than one lifecycle adapter.
    // Keep repeated startup idempotent so one recorder never briefly owns two
    // subscriptions while the prior stream is still completing cancellation.
    // A previous teardown may still be awaiting stream cancellation. Do not
    // attach a new listener until that ownership transition is complete.
    if (_subscription != null || _cancellationInFlight != null) return;
    final changes = _screenChanges?.call() ?? ScreenTracker().onScreenChange;
    _subscription = changes.listen((screen) {
      _onScreenChange(screen);
      // Keep flow current without requiring an explicit flush from every caller.
      // A wait installs an awaited evidence callback on this recorder. Do not
      // start an unawaited flush in that window: the callback may capture a
      // screenshot and pump the guarded tester, which must remain serialized
      // with the wait's own frame advancement.
      if (onScreenAdded == null) unawaited(flushPending());
    });
  }

  /// Starts listening after a previous subscription has finished cancelling.
  ///
  /// Attempt boundaries use this before app preparation because dropping a
  /// start request while cancellation is still in flight would leave the next
  /// attempt without navigation history.
  Future<void> startListeningWhenReady() async {
    while (true) {
      final cancellation = _cancellationInFlight;
      if (cancellation == null) break;
      try {
        await cancellation;
      } catch (_) {
        // Cancellation errors must not prevent a fresh attempt from observing
        // navigation. The old subscription is already detached at this point.
      }
    }
    _startListening();
  }

  void clear() {
    _flow.clear();
    _pendingScreens.clear();
  }

  void beginTest(String? currentScreen) {
    clear();
    if (currentScreen != null && currentScreen.isNotEmpty) {
      _flow.add(currentScreen);
    }
  }

  /// Ends app-launch navigation and starts the authored test journey.
  ///
  /// Both lifecycle adapters use this transition so queued launch routes are
  /// recorded before the current screen becomes the journey's first screen.
  Future<void> beginTestAfterPending(String? Function() currentScreen) async {
    await flushPending();
    beginTest(currentScreen());
  }

  /// For unit tests only.
  void seed(Iterable<String> names) {
    _flow
      ..clear()
      ..addAll(names);
  }

  Future<void> dispose() async {
    await stopListening(clearHistory: true, awaitCancellation: true);
  }

  /// Stops collecting screens while keeping attempt history available for
  /// result projection after cleanup.
  Future<void> stopListening({
    bool clearHistory = false,
    bool awaitCancellation = false,
  }) async {
    final subscription = _subscription;
    _subscription = null;
    final inFlight = _cancellationInFlight;
    Object? cancellationError;
    StackTrace? cancellationStackTrace;
    try {
      if (inFlight != null) {
        if (awaitCancellation) await inFlight;
      } else if (subscription != null) {
        final cancellation = subscription.cancel();
        late final Future<void> trackedCancellation;
        trackedCancellation = cancellation.whenComplete(() {
          if (identical(_cancellationInFlight, trackedCancellation)) {
            _cancellationInFlight = null;
          }
        });
        _cancellationInFlight = trackedCancellation;
        if (awaitCancellation) {
          await trackedCancellation;
        } else {
          // StreamSubscription.cancel detaches the listener immediately.
          // Waiting for a broadcast stream's cleanup future can deadlock a
          // widget-test fake-async zone, so attempt teardown only initiates
          // cancellation.
          unawaited(trackedCancellation.catchError((Object _) {}));
        }
      }
    } catch (error, stackTrace) {
      cancellationError = error;
      cancellationStackTrace = stackTrace;
    }
    onScreenAdded = null;
    if (clearHistory) {
      _flow.clear();
      _pendingScreens.clear();
    }
    if (cancellationError != null) {
      Error.throwWithStackTrace(cancellationError, cancellationStackTrace!);
    }
  }

  /// Visible for unit tests; production receives changes from the subscription.
  void recordScreenChange(VisibleScreen? screen) => _onScreenChange(screen);

  void _onScreenChange(VisibleScreen? screen) {
    if (screen == null) return;
    // Queue every change — coalescing to the latest drops transient screens
    // (e.g. AutoSignIn_Device → Home in the same event loop turn).
    _pendingScreens.add(screen);
  }

  Future<void> flushPending() async {
    // Drain until empty so screens recorded during an onScreenAdded callback
    // are not lost.
    Object? firstError;
    StackTrace? firstStackTrace;
    while (_pendingScreens.isNotEmpty) {
      try {
        await _flushPendingScreen();
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace!);
    }
  }

  Future<void> _flushPendingScreen() async {
    if (_pendingScreens.isEmpty) return;
    final pending = List<VisibleScreen>.from(_pendingScreens);
    _pendingScreens.clear();
    final added = <String>[];
    for (final screen in pending) {
      final name = screen.screenName ?? screen.screenId;
      if (name == null) continue;
      if (_flow.isEmpty || _flow.last != name) {
        _flow.add(name);
        added.add(name);
      }
    }
    final callback = onScreenAdded;
    if (callback == null) return;
    Object? firstError;
    StackTrace? firstStackTrace;
    for (final name in added) {
      try {
        await callback(name);
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace!);
    }
  }
}
