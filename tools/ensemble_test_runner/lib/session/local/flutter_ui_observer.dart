import 'package:ensemble_test_runner/application/application_test_driver.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/session/local/element_semantics.dart';
import 'package:ensemble_test_runner/session/local/observable_fingerprint.dart';
import 'package:ensemble_test_runner/session/local/observation_registry.dart';
import 'package:ensemble_test_runner/session/local/widget_locator_id.dart';
import 'package:ensemble_test_runner/session/observation/observation_options.dart';
import 'package:ensemble_test_runner/session/observation/ui_element.dart';
import 'package:ensemble_test_runner/session/observation/ui_observation.dart';
import 'package:ensemble_test_runner/session/observation/ui_observer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Local [UiObserver] over [WidgetTester] + optional navigation metadata.
class FlutterUiObserver implements UiObserver {
  FlutterUiObserver({
    required this.tester,
    required this.assertions,
    required this.registry,
    required this.nextObservationId,
    required this.currentRevision,
    required this.lastFingerprint,
    required this.markRevision,
    this.navigation,
    this.settleTimeout = const Duration(seconds: 5),
  });

  final WidgetTester tester;
  final AssertionEngine assertions;
  final ObservationRegistry registry;
  final String Function() nextObservationId;
  final int Function() currentRevision;
  final String? Function() lastFingerprint;
  final void Function(int revision, String fingerprint) markRevision;
  final NavigationTestService? navigation;
  final Duration settleTimeout;

  @override
  Future<UiObservation> observe([
    ObservationOptions options = const ObservationOptions(),
  ]) async {
    var partial = false;
    switch (options.synchronization) {
      case ObservationSynchronization.immediate:
        break;
      case ObservationSynchronization.nextFrame:
        await tester.pump();
        break;
      case ObservationSynchronization.untilStable:
        final timeout = options.stableTimeout ?? settleTimeout;
        try {
          await tester.pumpAndSettle(timeout);
        } on FlutterError {
          partial = true;
        }
        break;
    }

    // Identity/freshness always includes bounds so presentation options
    // (includeBounds) cannot change stale-target validation.
    final built = _buildElements(
      includeBounds: true,
      keyedOnly: options.keyedOnly,
    );
    final screen = _screenObservation();
    final fingerprint = fingerprintForObservation(
      screen: screen,
      elements: built.elements,
    );

    final revision = _applyFingerprint(fingerprint);

    final observationId = nextObservationId();
    registry.registerObservation(
      observationId: observationId,
      handles: rebindHandles(observationId, built.handles),
    );

    final elements = options.includeBounds
        ? built.elements
        : built.elements.map(_withoutBounds).toList(growable: false);

    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    return UiObservation(
      observationId: observationId,
      revision: revision,
      timestamp: DateTime.now().toUtc(),
      screen: screen,
      elements: elements,
      viewport: UiViewport(
        width: size.width,
        height: size.height,
        devicePixelRatio: tester.view.devicePixelRatio,
      ),
      observableFingerprint: fingerprint,
      completeness: ObservationCompleteness(
        semanticTree: true,
        runtimeMetadata: true,
        navigationState: !screen.unknown,
        screenshot: false,
        partial: partial,
      ),
    );
  }

  /// Recomputes the session revision from the live tree after a mutation.
  ///
  /// Does not register a new observation — only refreshes revision tracking
  /// so [ActionResult.afterRevision] reflects UI changes.
  Future<void> syncRevisionAfterMutation() async {
    final built = _buildElements(includeBounds: true, keyedOnly: false);
    final fingerprint = fingerprintForObservation(
      screen: _screenObservation(),
      elements: built.elements,
    );
    _applyFingerprint(fingerprint);
  }

  int _applyFingerprint(String fingerprint) {
    var revision = currentRevision();
    final previous = lastFingerprint();
    if (previous == null || previous != fingerprint) {
      revision += 1;
      markRevision(revision, fingerprint);
    }
    return revision;
  }

  /// Live fingerprint for [ObservationRegistry.revalidate] — matches observe
  /// identity digests (always includes bounds).
  String liveFingerprintFor(Element element, String? testId) {
    final ui = describeElement(
      element: element,
      elementId: 'live',
      testId: testId,
      assertions: assertions,
      tester: tester,
      includeBounds: true,
    );
    return fingerprintForElement(ui);
  }

  static UiElement _withoutBounds(UiElement element) => UiElement(
        elementId: element.elementId,
        testId: element.testId,
        type: element.type,
        role: element.role,
        label: element.label,
        text: element.text,
        hint: element.hint,
        options: element.options,
        suggestedLocator: element.suggestedLocator,
        locatorWarning: element.locatorWarning,
        state: element.state,
        bounds: null,
        supportedActions: element.supportedActions,
        children: element.children.map(_withoutBounds).toList(growable: false),
        metadata: element.metadata,
      );

  ScreenObservation _screenObservation() {
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

  ({List<UiElement> elements, Map<String, SnapshotElementHandle> handles})
      _buildElements({required bool includeBounds, bool keyedOnly = false}) {
    final kept = <({Element element, UiElement ui})>[];
    final handles = <String, SnapshotElementHandle>{};
    var index = 0;
    final seenRenderObjects = <Object>{};

    final claimedOwnedIds = <String>{};
    final semantics = tester.ensureSemantics();
    try {
      for (final element in tester.allElements) {
        // Inherited Invokable.id must NOT force-keep every descendant — that
        // exploded inspect-ui into dozens of duplicate rows per control.
        final ownedKey = hasCompactValueKey(element);
        final ownedId = readOwnedWidgetLocatorId(element);
        if (keyedOnly && ownedKey == false && ownedId == null) continue;

        final underKeyed = _hasCompactKeyedAncestor(element);
        final ancestorOwnedId = nearestOwnedLocatorIdAncestor(element);

        var keep = false;
        if (ownedKey) {
          keep = true;
          if (ownedId != null) claimedOwnedIds.add(ownedId);
        } else if (underKeyed) {
          keep = false;
        } else if (isPrimaryControlElement(element) &&
            !hasPrimaryControlAncestor(element)) {
          // testId (KeyedSubtree under Invokable) owns the locator — skip host.
          if (readInvokableLocatorId(element) != null &&
              nearestDescendantValueKeyLocatorId(element) != null) {
            keep = false;
          } else if (ancestorOwnedId != null) {
            // One primary per Invokable/YAML id owner (e.g. Dropdown, Switch).
            keep = claimedOwnedIds.add(ancestorOwnedId);
          } else if (ownedId != null) {
            keep = claimedOwnedIds.add(ownedId);
          } else {
            keep = true;
          }
        } else if (isStandaloneTextElement(element) &&
            ancestorOwnedId == null) {
          // Skip label Text under id'd Ensemble controls; absorbFormFieldLabels
          // covers the rest when labels sit beside fields.
          keep = true;
        }
        if (!keep) continue;

        final testId = readWidgetLocatorId(element) ?? '';

        final renderObject = element.renderObject;
        if (testId.isEmpty &&
            renderObject != null &&
            !seenRenderObjects.add(renderObject)) {
          continue;
        }

        final elementId = 'el_${index++}';
        final uiElement = describeElement(
          element: element,
          elementId: elementId,
          testId: testId.isEmpty ? null : testId,
          assertions: assertions,
          tester: tester,
          includeBounds: includeBounds,
        );
        kept.add((element: element, ui: uiElement));
        handles[elementId] = SnapshotElementHandle(
          observationId: '',
          elementId: elementId,
          testId: testId.isEmpty ? null : testId,
          element: element,
          observableFingerprint: fingerprintForElement(uiElement),
        );
      }
    } finally {
      semantics.dispose();
    }

    final absorbed = _absorbFormFieldLabels(kept);
    final remainingIds = <String>{
      for (final item in absorbed) item.ui.elementId,
    };
    handles.removeWhere((id, _) => !remainingIds.contains(id));
    for (final item in absorbed) {
      handles[item.ui.elementId] = SnapshotElementHandle(
        observationId: '',
        elementId: item.ui.elementId,
        testId: item.ui.testId,
        element: item.element,
        observableFingerprint: fingerprintForElement(item.ui),
      );
    }
    return (elements: _nestKeptElements(absorbed), handles: handles);
  }

  /// Fold nearby standalone label [Text] into form controls and drop duplicates.
  ///
  /// Ensemble often renders `Text('Label')` above/beside a field instead of
  /// [InputDecoration.labelText].
  static List<({Element element, UiElement ui})> _absorbFormFieldLabels(
    List<({Element element, UiElement ui})> kept,
  ) {
    const formTypes = {'textInput', 'switch', 'toggle', 'dropdown'};
    final claimed = <int>{};
    final updated = List<({Element element, UiElement ui})>.of(kept);

    for (var i = 0; i < kept.length; i++) {
      final control = kept[i].ui;
      if (!formTypes.contains(control.type)) continue;
      final controlBounds = control.bounds;
      if (controlBounds == null) continue;

      int? bestTextIndex;
      var bestScore = double.infinity;
      for (var j = 0; j < kept.length; j++) {
        if (i == j || claimed.contains(j)) continue;
        final textUi = kept[j].ui;
        if (textUi.type != 'text') continue;
        if (textUi.testId != null && textUi.testId!.isNotEmpty) continue;
        final textBounds = textUi.bounds;
        if (textBounds == null) continue;
        final label = (textUi.text ?? textUi.label)?.trim();
        if (label == null || label.isEmpty) continue;
        final score = _labelAssociationScore(textBounds, controlBounds);
        if (score != null && score < bestScore) {
          bestScore = score;
          bestTextIndex = j;
        }
      }

      if (bestTextIndex == null) continue;
      claimed.add(bestTextIndex);
      final labelText =
          (kept[bestTextIndex].ui.text ?? kept[bestTextIndex].ui.label)!
              .trim();
      // Prefer the nearby Text label over semantics (often concatenates hint).
      updated[i] = (
        element: kept[i].element,
        ui: control.copyWith(label: labelText),
      );
    }

    return [
      for (var i = 0; i < updated.length; i++)
        if (!claimed.contains(i)) updated[i],
    ];
  }

  /// Lower is better; null when the text is not a plausible label for [control].
  static double? _labelAssociationScore(UiBounds text, UiBounds control) {
    final textRect = Rect.fromLTWH(text.left, text.top, text.width, text.height);
    final controlRect =
        Rect.fromLTWH(control.left, control.top, control.width, control.height);

    // Same-row label to the left of the control (switch / compact fields).
    final verticalOverlap = textRect.bottom > controlRect.top &&
        textRect.top < controlRect.bottom;
    final leftOfControl = textRect.right <= controlRect.left + 8;
    if (verticalOverlap && leftOfControl) {
      final gap = controlRect.left - textRect.right;
      if (gap >= -8 && gap <= 48) return gap.abs();
    }

    // Label stacked above the control (common Ensemble form layout).
    final above = textRect.bottom <= controlRect.top + 12;
    if (!above) return null;
    final gap = controlRect.top - textRect.bottom;
    if (gap < -12 || gap > 40) return null;
    final horizontalOverlap = textRect.left < controlRect.right &&
        textRect.right > controlRect.left;
    final leftAligned = (textRect.left - controlRect.left).abs() <= 24;
    if (!horizontalOverlap && !leftAligned) return null;
    return 100 + gap;
  }

  /// Nests kept nodes under their nearest kept Flutter ancestor.
  static List<UiElement> _nestKeptElements(
    List<({Element element, UiElement ui})> kept,
  ) {
    if (kept.isEmpty) return const [];

    final elementToIndex = <Element, int>{
      for (var i = 0; i < kept.length; i++) kept[i].element: i,
    };
    final childIndexes = List.generate(kept.length, (_) => <int>[]);
    final isRoot = List<bool>.filled(kept.length, true);

    for (var i = 0; i < kept.length; i++) {
      kept[i].element.visitAncestorElements((ancestor) {
        final parentIndex = elementToIndex[ancestor];
        if (parentIndex == null) return true;
        childIndexes[parentIndex].add(i);
        isRoot[i] = false;
        return false;
      });
    }

    UiElement build(int i) {
      final children = [
        for (final childIndex in childIndexes[i]) build(childIndex),
      ];
      final ui = kept[i].ui;
      if (children.isEmpty) return ui;
      return ui.copyWith(children: children);
    }

    return [
      for (var i = 0; i < kept.length; i++)
        if (isRoot[i]) build(i),
    ];
  }

  /// True when an ancestor already carries a compact string [ValueKey] (EDL id).
  ///
  /// Invokable-only YAML `id`s are not treated as keyed ancestors — those ids
  /// are attached onto the primary control via [readWidgetLocatorId] instead.
  bool _hasCompactKeyedAncestor(Element element) {
    var found = false;
    element.visitAncestorElements((ancestor) {
      if (hasCompactValueKey(ancestor)) {
        found = true;
        return false;
      }
      return true;
    });
    return found;
  }

  Map<String, SnapshotElementHandle> rebindHandles(
    String observationId,
    Map<String, SnapshotElementHandle> handles,
  ) {
    return {
      for (final e in handles.entries)
        e.key: SnapshotElementHandle(
          observationId: observationId,
          elementId: e.value.elementId,
          testId: e.value.testId,
          element: e.value.element,
          observableFingerprint: e.value.observableFingerprint,
        ),
    };
  }
}
