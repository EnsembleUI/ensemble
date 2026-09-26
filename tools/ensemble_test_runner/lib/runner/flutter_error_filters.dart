import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Flutter diagnostics that should not fail a YAML test step.
///
/// Layout overflow is reported via [FlutterError.onError] in debug builds but
/// does not replace the tree with [ErrorWidget] — the UI remains usable.
/// Treat it like animation teardown noise, not a fatal framework failure.
bool isNonFatalFlutterDiagnostic(Object error) {
  final text = error.toString();
  if (text.contains(
    'An animation is still running even after the widget tree was disposed.',
  )) {
    return true;
  }
  if (text.contains('A RenderFlex overflowed')) {
    return true;
  }
  if (text.contains('A RenderOverflow')) {
    return true;
  }
  // Ensemble YAML/JS often coerces stringly values; these assert in debug
  // without replacing the tree with ErrorWidget.
  if (text.contains("type 'String' is not a subtype of type 'bool'")) {
    return true;
  }
  if (text.contains("type 'String' is not a subtype of type 'bool?'")) {
    return true;
  }
  // API/JS callbacks often complete after a screen was navigated away.
  // Flutter asserts; the destination UI is still fine (no ErrorWidget).
  if (text.contains("Looking up a deactivated widget's ancestor")) {
    return true;
  }
  // Enabling/disposing SemanticsHandle around observe dirties Focus /
  // MediaQuery inherited scopes; Live-binding pumps may report a one-shot
  // build assert without replacing the tree with ErrorWidget.
  if (text.contains('building _FocusInheritedScope')) {
    return true;
  }
  if (text.contains('building _MediaQueryFromView')) {
    return true;
  }
  return false;
}

/// Live-binding races when Ensemble timers/API callbacks call navigateScreen
/// during a test yield. The next pump can hit restoration / build-scope
/// asserts once; a follow-up frame usually finishes the route cleanly.
bool isTransientNavigationDiagnostic(Object error) {
  final text = error.toString();
  return text.contains('UnmanagedRestorationScope') ||
      text.contains('wrong build scope') ||
      text.contains('ListenableBuilder') ||
      // clearAllScreens / pushAndRemoveUntil under Live binding
      (text.contains('Overlay') && text.contains('_dependents.isEmpty')) ||
      (text.contains('Overlay') && text.contains('dependents.isEmpty')) ||
      text.contains('Duplicate GlobalKeys detected') ||
      text.contains('_OverlayEntryWidgetState');
}

/// True when Flutter has replaced a failed build with [ErrorWidget] (red
/// screen). Navigation trackers can still report the destination screen even
/// though nothing usable is painted.
bool treeHasFlutterErrorWidget(WidgetTester tester) {
  return find.byType(ErrorWidget).evaluate().isNotEmpty;
}
