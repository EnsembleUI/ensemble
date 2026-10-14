import 'dart:ui' as ui;

import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/diagnostic_ui_snapshot.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/failure_observer_capture.dart';
import 'package:ensemble_test_runner/runner/test_runtime_state.dart';
import 'package:ensemble_test_runner/reporters/step_outline_format.dart';
import 'package:flutter_test/flutter_test.dart';

/// Publishes screenshot and Observer data as one same-turn report artifact.
///
/// Call immediately after rasterizing the frame and taking [observerSnapshot].
/// Keeping publication synchronous ensures Observer overlays are drawn against
/// the image captured from the same UI state.
void writeStepScreenshotArtifacts({
  required WidgetTester tester,
  required EnsembleTestContext context,
  required TestStep step,
  required int stepIndex,
  required ui.Image image,
  TestStep? labelStep,
  TestDeviceTarget? device,
  ScreenshotHighlight? highlight,
  DiagnosticUiSnapshot? observerSnapshot,
}) {
  final labelSource = labelStep ?? step;
  context.runtime.addScreenshotSheetFrame(
    ScreenshotSheetFrame(
      stepIndex: stepIndex,
      label: '${stepIndex + 1}. ${formatStepBrief(labelSource)}',
      image: image,
      deviceId: device?.id,
      deviceLabel: device?.displayLabel,
      platform: device?.platform,
      model: device?.model,
      highlight: highlight,
    ),
  );
  if (observerSnapshot != null) {
    upsertStepObserverFromSnapshot(
      ctx: context,
      tester: tester,
      stepIndex: stepIndex,
      snap: observerSnapshot,
    );
  }
}
