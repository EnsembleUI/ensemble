import 'dart:async';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/screen_tracker.dart';

/// Records screen visits for YAML tests (including back-navigation revisits).
class NavigationFlowRecorder {
  final List<String> _flow = [];
  StreamSubscription<VisibleScreen?>? _subscription;

  List<String> get flow => List.unmodifiable(_flow);

  void startListening() {
    _subscription?.cancel();
    _subscription = ScreenTracker().onScreenChange.listen(_onScreenChange);
  }

  void clear() => _flow.clear();

  /// For unit tests only.
  void seed(Iterable<String> names) {
    _flow
      ..clear()
      ..addAll(names);
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _flow.clear();
  }

  /// Visible for unit tests; production uses [startListening].
  void recordScreenChange(VisibleScreen? screen) => _onScreenChange(screen);

  void _onScreenChange(VisibleScreen? screen) {
    if (screen == null) return;
    final name = screen.screenName ?? screen.screenId;
    if (name == null) return;
    if (_flow.isEmpty || _flow.last != name) {
      _flow.add(name);
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
    Ensemble.resetInitManagersForTest();
  }

  /// End of the widget test (cancels listeners).
  static void dispose() {
    navigationFlow.dispose();
  }
}
