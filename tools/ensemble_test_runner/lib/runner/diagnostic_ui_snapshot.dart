import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'package:ensemble_test_runner/application/application_test_types.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/session/local/element_semantics.dart';
import 'package:ensemble_test_runner/session/local/observed_element_tree.dart';
import 'package:ensemble_test_runner/session/observation/observation_options.dart';
import 'package:ensemble_test_runner/session/observation/diagnostic_locators.dart';
import 'package:ensemble_test_runner/session/observation/ui_observation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Side-effect-free UI dump for HTML Observer tabs.
///
/// Never enables [SemanticsHandle], never pumps, never enters the leaf queue,
/// and never runs live [enrichSuggestedLocators] finder walks.
class DiagnosticUiSnapshot {
  const DiagnosticUiSnapshot({
    required this.observation,
    this.detail = ObservationDetailLevel.diagnostic,
  });

  final UiObservation observation;
  final ObservationDetailLevel detail;

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
  ObservationDetailLevel detail = ObservationDetailLevel.diagnostic,
}) {
  return RunnerBenchmark.sync('observer', 'captureDiagnosticUiSnapshot', () {
    RunnerBenchmark.dimension('synchronizationPolicy', 'immediate');
    RunnerBenchmark.dimension('semanticsEnabled', false);
    RunnerBenchmark.dimension('observationDetail', detail.name);
    final built = buildObservedElementTree(
      tester: tester,
      assertions: assertions,
      navigation: navigation,
      includeBounds: true,
      enableSemantics: false,
      useSemantics: false,
      registerRouteDependency: false,
    );
    final verifiedTree = annotateDiagnosticLocators(built.elements);
    final screen = _screenObservation(navigation, tester);
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    return DiagnosticUiSnapshot(
      detail: detail,
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

/// Captures report observation for a frozen screenshot without making the
/// screenshot itself depend on the diagnostic tree walk succeeding.
DiagnosticUiSnapshot? captureDiagnosticUiSnapshotBestEffort({
  required WidgetTester tester,
  required AssertionEngine assertions,
  NavigationTestService? navigation,
  ObservationDetailLevel detail = ObservationDetailLevel.diagnostic,
}) {
  try {
    return captureDiagnosticUiSnapshot(
      tester: tester,
      assertions: assertions,
      navigation: navigation,
      detail: detail,
    );
  } catch (_) {
    return null;
  }
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
