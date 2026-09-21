import 'package:ensemble_test_runner/application/application_test_driver.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/session/local/element_semantics.dart';
import 'package:ensemble_test_runner/session/local/observable_fingerprint.dart';
import 'package:ensemble_test_runner/session/local/observation_registry.dart';
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
    final elements = <UiElement>[];
    final handles = <String, SnapshotElementHandle>{};
    var index = 0;
    final seenRenderObjects = <Object>{};

    final semantics = tester.ensureSemantics();
    try {
      for (final element in tester.allElements) {
        final key = element.widget.key;
        final value = key is ValueKey ? key.value : null;
        final testId = value is String ? _compactTestId(value) : '';
        if (keyedOnly && testId.isEmpty) continue;

        final actionable = testId.isEmpty &&
            (isSemanticLocatorCandidate(element) ||
                isTextLocatorCandidate(element));
        if (testId.isEmpty && !actionable && !keyedOnly) {
          final type = inferWidgetType(element);
          if (type == 'widget') continue;
        }

        final type = inferWidgetType(element);
        final label = keyedOnly || testId.isNotEmpty
            ? null
            : readSemanticsLabel(tester, element);
        final text = keyedOnly || testId.isNotEmpty ? null : readText(element);
        final relevant = testId.isNotEmpty ||
            label != null ||
            text != null ||
            actionable ||
            type != 'widget';
        if (!relevant) continue;
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
        elements.add(uiElement);
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

    return (elements: elements, handles: handles);
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

  String _compactTestId(String value) {
    final singleLine = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (singleLine.isEmpty || singleLine.length > 120) return '';
    if (singleLine.startsWith('_')) return '';
    if (RegExp(r'\s').hasMatch(singleLine)) return '';
    if (!RegExp(r'^[A-Za-z][A-Za-z0-9_:.:-]*$').hasMatch(singleLine)) {
      return '';
    }
    return singleLine;
  }
}
