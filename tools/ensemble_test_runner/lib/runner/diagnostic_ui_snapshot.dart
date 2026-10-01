import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'dart:convert';

import 'package:ensemble_test_runner/application/application_test_types.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/session/local/element_semantics.dart';
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
  return RunnerBenchmark.sync('observer', 'captureDiagnosticUiSnapshot', () {
    RunnerBenchmark.dimension('synchronizationPolicy', 'immediate');
    RunnerBenchmark.dimension('semanticsEnabled', false);
    final built = buildObservedElementTree(
      tester: tester,
      assertions: assertions,
      navigation: navigation,
      includeBounds: true,
      enableSemantics: false,
      useSemantics: false,
      registerRouteDependency: false,
    );
    final withLocators = mapObservationLocatorTree(
      elements: built.elements,
      resolve: ({
        required element,
        parentScope,
        iconOccurrenceAmongSiblings,
        iconSiblingCount,
        occurrenceAmongSiblings,
      }) =>
          (
        locator: cheapSuggestedLocator(
          element,
          parentScope: parentScope,
          iconOccurrenceAmongSiblings: iconOccurrenceAmongSiblings,
          iconSiblingCount: iconSiblingCount,
          occurrenceAmongSiblings: occurrenceAmongSiblings,
        ),
        warning: null,
      ),
    );
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
          if (!a.$2.contains(b.$1.elementId) &&
              !b.$2.contains(a.$1.elementId)) {
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
        children: [
          for (final child in element.children) markAmbiguities(child)
        ],
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
    final screen = _screenObservation(navigation, tester);
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
  });
}

ScreenObservation _screenObservation(
  NavigationTestService? navigation,
  WidgetTester tester,
) {
  final nav = navigation;
  final route = visibleScreenIdentifier(tester) ?? nav?.currentRoute;
  final history = List<String>.from(nav?.routeHistory ?? const <String>[]);
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

bool _includeInObserverReport(UiElement element) =>
    element.state.visible != false || element.state.offscreen == true;
