import 'dart:ui' as ui;

import 'package:ensemble_test_runner/actions/extended_step_handlers.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/screenshot_contact_sheet.dart';
import 'package:ensemble_test_runner/runner/test_runtime_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds the common report frame for orchestration-level failures.
///
/// Callers resolve device metadata according to their execution mode before
/// calling this helper. Hosted and standalone capture timing and fallback
/// policies therefore remain owned by their respective adapters.
ScreenshotSheetFrame emergencyFailureScreenshotFrame({
  required ui.Image image,
  String? deviceId,
  String? deviceLabel,
  String? platform,
  String? model,
}) =>
    ScreenshotSheetFrame(
      stepIndex: 0,
      label: 'Runner failure',
      image: image,
      deviceId: deviceId,
      deviceLabel: deviceLabel,
      platform: platform,
      model: model,
    );

/// Captures the common failure frame after the adapter has chosen its timing.
///
/// Hosted and standalone adapters intentionally retain different pump and
/// fallback policies, while sharing the pixel capture and report projection.
ScreenshotSheetFrame captureEmergencyFailureScreenshotFrame({
  required WidgetTester tester,
  String? deviceId,
  String? deviceLabel,
  String? platform,
  String? model,
}) =>
    emergencyFailureScreenshotFrame(
      image: ExtendedStepHandlers.captureScreenshotImage(tester),
      deviceId: deviceId,
      deviceLabel: deviceLabel,
      platform: platform,
      model: model,
    );

/// Captures a minimal screenshot when orchestration fails outside a test step.
///
/// Failure reporting should remain best effort: a problem while writing this
/// artifact must not hide the original runner error.
Future<List<String>> writeEmergencyFailureScreenshot({
  required WidgetTester tester,
  required EnsembleTestCase test,
  required EnsembleTestConfig config,
  required Object error,
}) async {
  if (!config.screenshots.enabled) return const [];
  try {
    final path = await writeScreenshotFrames(
      testId: test.resolvedScreenshotSheetId,
      config: config.screenshots,
      frames: [
        captureEmergencyFailureScreenshotFrame(
          tester: tester,
          deviceId: test.deviceTarget?.id,
          deviceLabel: test.deviceTarget?.displayLabel,
          platform: test.deviceTarget?.platform ??
              (config.devices.isNotEmpty
                  ? config.devices.first.platform
                  : 'ios'),
          model: test.deviceTarget?.model ??
              (config.devices.isNotEmpty
                  ? config.devices.first.model
                  : 'iPhone 15 Pro'),
        ),
      ],
      status: TestStatus.failed,
      failedStepIndex: 0,
      failedStepLabel: 'Runner failure',
      failureMessage: error.toString(),
      failedDeviceId: test.deviceTarget?.id,
    );
    return path == null ? const [] : ['screenshotFrames: $path'];
  } catch (_) {
    return const [];
  }
}
