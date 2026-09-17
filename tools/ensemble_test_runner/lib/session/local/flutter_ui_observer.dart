import 'package:ensemble/framework/screen_tracker.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/runner/yaml_test_session.dart';
import 'package:ensemble_test_runner/session/local/element_semantics.dart';
import 'package:ensemble_test_runner/session/local/observable_fingerprint.dart';
import 'package:ensemble_test_runner/session/local/observation_registry.dart';
import 'package:ensemble_test_runner/session/observation/observation_options.dart';
import 'package:ensemble_test_runner/session/observation/ui_element.dart';
import 'package:ensemble_test_runner/session/observation/ui_observation.dart';
import 'package:ensemble_test_runner/session/observation/ui_observer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Local [UiObserver] over [WidgetTester] + Ensemble metadata.
class FlutterUiObserver implements UiObserver {
  FlutterUiObserver({
    required this.tester,
    required this.assertions,
    required this.registry,
    required this.nextObservationId,
    required this.currentRevision,
    required this.lastFingerprint,
    required this.markRevision,
    this.settleTimeout = const Duration(seconds: 5),
  });

  final WidgetTester tester;
  final AssertionEngine assertions;
  final ObservationRegistry registry;
  final String Function() nextObservationId;
  final int Function() currentRevision;
  final String? Function() lastFingerprint;
  final void Function(int revision, String fingerprint) markRevision;
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

    final built = _buildElements(includeBounds: options.includeBounds);
    final screen = _screenObservation();
    final fingerprint = fingerprintForObservation(
      screen: screen,
      elements: built.elements,
    );

    var revision = currentRevision();
    final previous = lastFingerprint();
    if (previous == null || previous != fingerprint) {
      revision += 1;
      markRevision(revision, fingerprint);
    }

    final observationId = nextObservationId();
    registry.registerObservation(
      observationId: observationId,
      handles: rebindHandles(observationId, built.handles),
    );

    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    return UiObservation(
      observationId: observationId,
      revision: revision,
      timestamp: DateTime.now().toUtc(),
      screen: screen,
      elements: built.elements,
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

  /// Live fingerprint for [ObservationRegistry.revalidate] — same fields as observe.
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

  ScreenObservation _screenObservation() {
    try {
      final tracker = ScreenTracker();
      final name = tracker.getCurrentScreenIdentifier();
      final current = tracker.currentScreen;
      final flow = List<String>.from(YamlTestSession.navigationFlow.flow);
      if ((name == null || name.trim().isEmpty) && flow.isEmpty) {
        return ScreenObservation.unknown();
      }
      return ScreenObservation(
        name: name?.trim().isEmpty == true ? null : name?.trim(),
        routeId: current?.screenId,
        navigationStack: flow,
        hasModal: current?.isModal,
        unknown: false,
      );
    } catch (_) {
      return ScreenObservation.unknown();
    }
  }

  ({List<UiElement> elements, Map<String, SnapshotElementHandle> handles})
      _buildElements({required bool includeBounds}) {
    final elements = <UiElement>[];
    final handles = <String, SnapshotElementHandle>{};
    var index = 0;

    final semantics = tester.ensureSemantics();
    try {
      for (final element in tester.allElements) {
        final key = element.widget.key;
        if (key is! ValueKey) continue;
        final value = key.value;
        if (value is! String) continue;
        final testId = _compactTestId(value);
        if (testId.isEmpty) continue;

        final elementId = 'el_${index++}';
        final uiElement = describeElement(
          element: element,
          elementId: elementId,
          testId: testId,
          assertions: assertions,
          tester: tester,
          includeBounds: includeBounds,
        );
        elements.add(uiElement);
        handles[elementId] = SnapshotElementHandle(
          observationId: '',
          elementId: elementId,
          testId: testId,
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
