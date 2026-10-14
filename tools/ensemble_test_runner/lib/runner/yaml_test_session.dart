import 'dart:async';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/screen_tracker.dart';
import 'package:ensemble_test_runner/runner/live_async_call.dart';

/// Records screen visits for YAML tests (including back-navigation revisits).
class NavigationFlowRecorder {
  final List<String> _flow = [];
  final List<VisibleScreen> _pendingScreens = [];
  StreamSubscription<VisibleScreen?>? _subscription;

  /// Invoked when a screen name is appended to [flow] (after de-dupe).
  FutureOr<void> Function(String screenName)? onScreenAdded;

  List<String> get flow => List.unmodifiable(_flow);

  void startListening() {
    _subscription?.cancel();
    _subscription = ScreenTracker().onScreenChange.listen((screen) {
      _onScreenChange(screen);
      // Keep flow current without requiring an explicit flush from every caller.
      unawaited(flushPending());
    });
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

  /// For unit tests only.
  void seed(Iterable<String> names) {
    _flow
      ..clear()
      ..addAll(names);
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    onScreenAdded = null;
    _flow.clear();
    _pendingScreens.clear();
  }

  /// Visible for unit tests; production uses [startListening].
  void recordScreenChange(VisibleScreen? screen) => _onScreenChange(screen);

  void _onScreenChange(VisibleScreen? screen) {
    if (screen == null) return;
    // Queue every change — coalescing to the latest drops transient screens
    // (e.g. AutoSignIn_Gateway → Home in the same event loop turn).
    _pendingScreens.add(screen);
  }

  Future<void> flushPending() async {
    // Drain until empty so screens recorded during an onScreenAdded callback
    // are not lost.
    while (_pendingScreens.isNotEmpty) {
      await _flushPendingScreen();
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
    for (final name in added) {
      await callback(name);
    }
  }
}

/// Per–widget-test session state for declarative YAML tests.
class YamlTestSession {
  YamlTestSession._();

  static final NavigationFlowRecorder navigationFlow = NavigationFlowRecorder();

  static bool runtimeBootstrapped = false;

  static void markRuntimeBootstrapped() {
    runtimeBootstrapped = true;
  }

  /// Between cold starts within a suite (keeps the screen-change listener).
  static void reset() {
    runtimeBootstrapped = false;
    navigationFlow.clear();
    navigationFlow.onScreenAdded = null;
    LiveAsyncCallSupport.reset();
    Ensemble.resetInitManagersForTest();
  }

  /// End of the widget test (cancels listeners).
  static void dispose() {
    navigationFlow.dispose();
  }
}
