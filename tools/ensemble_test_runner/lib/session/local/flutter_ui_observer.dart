import 'package:ensemble/page_model.dart';
import 'package:ensemble/framework/widget/screen.dart';
import 'package:ensemble_test_runner/application/application_test_driver.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/session/local/element_semantics.dart';
import 'package:ensemble_test_runner/session/local/modal_route_lookup.dart';
import 'package:ensemble_test_runner/session/local/observable_fingerprint.dart';
import 'package:ensemble_test_runner/session/local/observation_registry.dart';
import 'package:ensemble_test_runner/session/local/observed_element_tree.dart';
import 'package:ensemble_test_runner/session/observation/observation_options.dart';
import 'package:ensemble_test_runner/session/observation/ui_element.dart';
import 'package:ensemble_test_runner/session/observation/ui_observation.dart';
import 'package:ensemble_test_runner/session/observation/ui_observer.dart';
import 'package:flutter/widgets.dart';
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

  /// Recomputes the session revision after a mutation without semantics churn.
  ///
  /// Uses a lightweight widget-field fingerprint (keyed ids + text) so every
  /// `act` does not toggle [SemanticsHandle] via a full observe walk.
  Future<void> syncRevisionAfterMutation() async {
    final fingerprint = lightweightMutationFingerprint(
      tester: tester,
      routeName: navigation?.currentRoute,
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
    final route = _visibleRouteIdentifier() ?? nav.currentRoute;
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

  /// Prefer the route that actually owns the visible widget tree. The
  /// app-level screen tracker can briefly lag route pops while a lazy history
  /// route is materialized; reporting that stale identifier makes otherwise
  /// current elements look like content from another screen.
  String? _visibleRouteIdentifier() {
    String? visibleScreenIdentifier;
    var visibleScreenDepth = -1;
    for (final element in tester.allElements) {
      if (!isUnderCurrentModalRoute(element)) continue;
      if (isUnderOffstageAncestor(element)) continue;
      final widget = element.widget;
      if (widget is Screen) {
        final payload = widget.screenPayload;
        final name = payload?.screenName?.trim();
        final id = payload?.screenId?.trim();
        final identifier = name != null && name.isNotEmpty
            ? name
            : id != null && id.isNotEmpty
                ? id
                : null;
        if (identifier != null) {
          var depth = 0;
          element.visitAncestorElements((_) {
            depth++;
            return true;
          });
          // A nested screen is the most specific identifier for the visible
          // content (for example, a page inside a navigator hosted by a
          // parent screen).
          if (depth > visibleScreenDepth) {
            visibleScreenIdentifier = identifier;
            visibleScreenDepth = depth;
          }
        }
      }
    }
    if (visibleScreenIdentifier != null) return visibleScreenIdentifier;

    for (final element in tester.allElements) {
      if (!isUnderCurrentModalRoute(element)) continue;
      final route = modalRouteForElement(element);
      if (route == null || !route.isCurrent) continue;
      final settings = route.settings;
      final arguments = settings.arguments;
      if (arguments is ScreenPayload) {
        final name = arguments.screenName?.trim();
        if (name != null && name.isNotEmpty) return name;
        final id = arguments.screenId?.trim();
        if (id != null && id.isNotEmpty) return id;
      }
      final name = settings.name?.trim();
      if (name != null && name.isNotEmpty && name != '/') return name;
    }
    return null;
  }

  ({List<UiElement> elements, Map<String, SnapshotElementHandle> handles})
      _buildElements({required bool includeBounds, bool keyedOnly = false}) {
    // Brief enable only for this snapshot — keeping semantics on for the whole
    // session changes hit-testing / focus and flakes YAML waits.
    return buildObservedElementTree(
      tester: tester,
      assertions: assertions,
      navigation: navigation,
      includeBounds: includeBounds,
      keyedOnly: keyedOnly,
      enableSemantics: true,
    );
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
