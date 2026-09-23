import 'package:ensemble_test_runner/application/application_test_types.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/session/actions/test_action.dart';
import 'package:ensemble_test_runner/session/local/observed_element_tree.dart';
import 'package:ensemble_test_runner/session/observation/ui_element.dart';
import 'package:ensemble_test_runner/session/observation/ui_observation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Side-effect-free UI dump for HTML Observer tabs.
///
/// Never enables [SemanticsHandle], never pumps, never enters the leaf queue,
/// and never runs live [enrichSuggestedLocators] finder walks.
class DiagnosticUiSnapshot {
  const DiagnosticUiSnapshot({
    required this.observation,
  });

  final UiObservation observation;

  String get screenLabel {
    final screen = observation.screen;
    if (screen.unknown) return 'Unknown';
    final name = screen.name?.trim();
    if (name != null && name.isNotEmpty) return name;
    final route = screen.routeId?.trim();
    if (route != null && route.isNotEmpty) return route;
    return 'Unknown';
  }
}

/// Sync element walk for a step screenshot (no semantics / pump / queue).
///
/// Safe during mid-wait while the leaf queue is held — diagnostic capture never
/// enters the queue. Pair with the mid-wait PNG via [captureStepReportArtifacts]
/// so report overlays do not drift to the next screen after `execute` returns.
DiagnosticUiSnapshot captureDiagnosticUiSnapshot({
  required WidgetTester tester,
  required AssertionEngine assertions,
  NavigationTestService? navigation,
}) {
  final built = buildObservedElementTree(
    tester: tester,
    assertions: assertions,
    navigation: navigation,
    includeBounds: true,
    enableSemantics: false,
    useSemantics: false,
    registerRouteDependency: false,
  );
  final withLocators = [
    for (final root in built.elements) _attachCheapSuggestedLocators(root),
  ];
  final screen = _screenObservation(navigation);
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  return DiagnosticUiSnapshot(
    observation: UiObservation(
      observationId: 'diagnostic',
      revision: 0,
      timestamp: DateTime.now().toUtc(),
      screen: screen,
      elements: withLocators,
      viewport: UiViewport(
        width: size.width,
        height: size.height,
        devicePixelRatio: tester.view.devicePixelRatio,
      ),
      observableFingerprint: '',
      completeness: ObservationCompleteness(
        semanticTree: false,
        runtimeMetadata: true,
        navigationState: !screen.unknown,
        screenshot: false,
      ),
    ),
  );
}

ScreenObservation _screenObservation(NavigationTestService? navigation) {
  final nav = navigation;
  if (nav == null) return ScreenObservation.unknown();
  final route = nav.currentRoute;
  final history = List<String>.from(nav.routeHistory);
  if ((route == null || route.trim().isEmpty) && history.isEmpty) {
    return ScreenObservation.unknown();
  }
  return ScreenObservation(
    name: route?.trim().isEmpty == true ? null : route?.trim(),
    routeId: route,
    navigationStack: history,
    unknown: false,
  );
}

/// Owned ValueKey / Invokable id → `id=…`; plain text from Text / fields.
///
/// No live finder verification (that path is for inspect-ui only).
UiElement _attachCheapSuggestedLocators(UiElement element) {
  final children = [
    for (final child in element.children) _attachCheapSuggestedLocators(child),
  ];
  return element.copyWith(
    children: children,
    suggestedLocator: _cheapSuggestedLocator(element),
    clearSuggestedLocator: true,
    clearLocatorWarning: true,
  );
}

ElementLocator? _cheapSuggestedLocator(UiElement element) {
  final tid = element.testId?.trim();
  if (tid != null && tid.isNotEmpty) {
    return ElementLocator(id: tid);
  }
  final type = (element.type ?? '').toLowerCase();
  final text = element.text?.trim();
  if (text == null || text.isEmpty) return null;
  switch (type) {
    case 'text':
    case 'textinput':
    case 'textfield':
    case 'button':
      return ElementLocator(text: text);
    default:
      return null;
  }
}
