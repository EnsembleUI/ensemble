import 'dart:ui' as ui;

import 'package:ensemble_test_runner/actions/screenshot_device.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/screenshot_capture.dart';
import 'package:ensemble_test_runner/runner/test_artifacts.dart';
import 'package:ensemble_test_runner/runner/step_policy.dart';
import 'package:ensemble_test_runner/runner/test_runtime_state.dart';

/// Resolves the report marker kind consistently across screenshot adapters.
/// Host captures also treat coordinate taps as actions; other action kinds
/// come from the operation registry used by standalone execution.
String screenshotHighlightKind(
  TestStep step, {
  bool forFailure = false,
  bool tapAtIsAction = false,
}) {
  if (forFailure) return 'failure';
  if ((tapAtIsAction && step.type == 'tapAt') || isUserActionStep(step)) {
    return 'action';
  }
  return 'assertion';
}

/// Converts a logical target rectangle into the report's screenshot space.
///
/// The host and standalone runtimes choose targets differently, but should
/// encode the selected target with identical scaling, bezel, and payload rules.
ScreenshotHighlight? buildScreenshotHighlight({
  required ui.Rect logicalRect,
  required ui.Size logicalSize,
  required ui.Size imageSize,
  required String kind,
  TestDeviceTarget? device,
}) {
  final scaled = screenshotLogicalRectToImagePixels(
    logicalRect: logicalRect,
    logicalSize: logicalSize,
    imageSize: imageSize,
  );
  if (scaled.isEmpty) return null;

  final frameDevice = !framesScreenshotsWithDeviceBezel || device == null
      ? null
      : resolveScreenshotDevice({
          'platform': device.platform,
          'model': device.model,
        });
  final framed = screenshotHighlightPercentRect(
    rectInImagePixels: scaled,
    imageSize: imageSize,
    frameDevice: frameDevice,
  );
  if (framed.isEmpty) return null;

  return ScreenshotHighlight(
    kind: kind,
    left: framed.left,
    top: framed.top,
    width: framed.width,
    height: framed.height,
  );
}
