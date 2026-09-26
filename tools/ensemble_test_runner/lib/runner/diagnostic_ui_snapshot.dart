import 'dart:convert';

import 'package:ensemble_test_runner/application/application_test_types.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/session/actions/test_action.dart';
import 'package:ensemble_test_runner/session/local/observed_element_tree.dart';
import 'package:ensemble_test_runner/session/observation/suggested_locator.dart';
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
  final locatorEntries = <String, List<(UiElement, List<String>)>>{};
  void collectLocators(List<UiElement> elements, List<String> ancestors) {
    for (final element in elements) {
      // Match observationElementsTreeForReport: hidden subtrees do not appear
      // in the report and therefore must not make a visible locator ambiguous.
      if (!_includeInObserverReport(element)) continue;
      final locator = element.suggestedLocator;
      if (locator != null) {
        locatorEntries
            .putIfAbsent(jsonEncode(locator.toJson()), () => [])
            .add((element, ancestors));
      }
      collectLocators(element.children, [...ancestors, element.elementId]);
    }
  }

  collectLocators(withLocators, const []);
  final ambiguousElementIds = <String>{};
  for (final entries in locatorEntries.values) {
    for (var i = 0; i < entries.length; i++) {
      for (var j = i + 1; j < entries.length; j++) {
        final a = entries[i];
        final b = entries[j];
        // Parent and child can legitimately share a locator when Flutter
        // merges semantics. Separate branches can resolve ambiguously.
        if (!a.$2.contains(b.$1.elementId) && !b.$2.contains(a.$1.elementId)) {
          ambiguousElementIds
            ..add(a.$1.elementId)
            ..add(b.$1.elementId);
        }
      }
    }
  }
  UiElement markAmbiguities(UiElement element) {
    final ambiguous = ambiguousElementIds.contains(element.elementId);
    return element.copyWith(
      children: [for (final child in element.children) markAmbiguities(child)],
      suggestedLocator: ambiguous ? null : element.suggestedLocator,
      clearSuggestedLocator: ambiguous,
      locatorWarning: ambiguous
          ? 'Suggested locator matches multiple observed elements'
          : element.locatorWarning,
      clearLocatorWarning: !ambiguous && element.locatorWarning == null,
    );
  }

  final verifiedTree = [
    for (final element in withLocators) markAmbiguities(element)
  ];
  final screen = _screenObservation(navigation);
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  return DiagnosticUiSnapshot(
    observation: UiObservation(
      observationId: 'diagnostic',
      revision: 0,
      timestamp: DateTime.now().toUtc(),
      screen: screen,
      elements: verifiedTree,
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

/// Owned ValueKey / Invokable id → `id=…`; otherwise agent caption / within
/// locators from [cheapSuggestedLocator] (shared ranking with live enrich).
///
/// Decorative media (`image` / `svg` / …) without an id get **no** selector —
/// there is no image wait/tap vocabulary.
///
/// No live finder verification (that path is for inspect-ui only).
UiElement _attachCheapSuggestedLocators(
  UiElement element, {
  ElementLocator? parentScope,
  int? iconOccurrenceAmongSiblings,
  int? iconSiblingCount,
  int? occurrenceAmongSiblings,
}) {
  final locator = cheapSuggestedLocator(
    element,
    parentScope: parentScope,
    iconOccurrenceAmongSiblings: iconOccurrenceAmongSiblings,
    iconSiblingCount: iconSiblingCount,
    occurrenceAmongSiblings: occurrenceAmongSiblings,
  );
  // Inert cards keep no sel, but still scope nested icons via caption+role.
  final scopeForChildren =
      locator ?? containerScopeLocator(element) ?? parentScope;

  final iconKids = [
    for (final child in element.children)
      if ((child.type ?? '').toLowerCase() == 'icon') child,
  ];
  final siblingLocators = [
    for (final child in element.children)
      cheapSuggestedLocator(
        child,
        parentScope: scopeForChildren,
      ),
  ];
  final siblingGroups = <String, List<int>>{};
  for (var i = 0; i < siblingLocators.length; i++) {
    final candidate = siblingLocators[i];
    if (candidate == null) continue;
    siblingGroups
        .putIfAbsent(candidate.toJson().toString(), () => <int>[])
        .add(i);
  }
  final occurrenceBySiblingIndex = <int, int>{};
  for (final indexes in siblingGroups.values) {
    if (indexes.length < 2) continue;
    for (var occurrence = 0; occurrence < indexes.length; occurrence++) {
      occurrenceBySiblingIndex[indexes[occurrence]] = occurrence;
    }
  }
  final children = <UiElement>[];
  var iconIndex = 0;
  for (var childIndex = 0; childIndex < element.children.length; childIndex++) {
    final child = element.children[childIndex];
    final isIcon = (child.type ?? '').toLowerCase() == 'icon';
    children.add(
      _attachCheapSuggestedLocators(
        child,
        parentScope: scopeForChildren,
        iconOccurrenceAmongSiblings:
            isIcon && iconKids.length > 1 ? iconIndex : null,
        iconSiblingCount: isIcon ? iconKids.length : null,
        occurrenceAmongSiblings: occurrenceBySiblingIndex[childIndex],
      ),
    );
    if (isIcon) iconIndex++;
  }

  return element.copyWith(
    children: children,
    suggestedLocator: locator,
    clearSuggestedLocator: true,
    clearLocatorWarning: false,
  );
}

bool _includeInObserverReport(UiElement element) =>
    element.state.visible != false || element.state.offscreen == true;
