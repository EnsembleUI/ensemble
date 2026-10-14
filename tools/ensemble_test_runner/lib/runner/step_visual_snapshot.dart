import 'dart:ui' as ui;

import 'package:ensemble_test_runner/actions/extended_step_handlers.dart';
import 'package:ensemble_test_runner/application/application_test_types.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/runner/diagnostic_ui_snapshot.dart';
import 'package:ensemble_test_runner/session/observation/observation_options.dart';
import 'package:flutter_test/flutter_test.dart';

/// Screenshot pixels and diagnostic tree captured from the same UI turn.
///
/// The tree is best-effort so a diagnostic walk cannot discard a valid image.
final class StepVisualSnapshot {
  const StepVisualSnapshot({required this.image, this.observerSnapshot});

  final ui.Image image;
  final DiagnosticUiSnapshot? observerSnapshot;
}

/// Captures image and Observer data before yielding to the event loop.
///
/// Hosted and standalone execution use this boundary to keep report evidence
/// aligned even when a route callback can advance the widget tree immediately
/// after rasterization.
StepVisualSnapshot captureStepVisualSnapshot({
  required WidgetTester tester,
  required AssertionEngine assertions,
  NavigationTestService? navigation,
  ObservationDetailLevel observationDetail = ObservationDetailLevel.standard,
}) {
  final image = ExtendedStepHandlers.captureScreenshotImage(tester);
  final observerSnapshot = captureDiagnosticUiSnapshotBestEffort(
    tester: tester,
    assertions: assertions,
    navigation: navigation,
    detail: observationDetail,
  );
  return StepVisualSnapshot(image: image, observerSnapshot: observerSnapshot);
}
