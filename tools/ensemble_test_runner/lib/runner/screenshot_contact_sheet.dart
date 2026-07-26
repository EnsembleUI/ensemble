import 'dart:convert';
import 'dart:typed_data';

import 'package:ensemble_device_preview/ensemble_device_preview.dart';
import 'package:ensemble_test_runner/actions/extended_step_handlers.dart';
import 'package:ensemble_test_runner/actions/screenshot_device.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/live_async_call.dart';
import 'package:ensemble_test_runner/runner/test_artifacts.dart';
import 'package:ensemble_test_runner/runner/test_runtime_state.dart';

/// Encodes each frame to a device-framed PNG and writes a [frames.json] manifest.
///
/// Returns the display path of the frames manifest (not a composite sheet PNG).
/// The HTML report builds the contact-sheet gallery from these per-step files.
Future<String?> writeScreenshotFrames({
  required String testId,
  required ScreenshotConfig config,
  required List<ScreenshotSheetFrame> frames,
  required TestStatus status,
  int? failedStepIndex,
  String? failedStepLabel,
  String? failureMessage,
  String? failedDeviceId,
}) async {
  if (frames.isEmpty) return null;

  final defaultDevice = resolveScreenshotDevice(const {});
  final directory = ensembleTestArtifactDirectory('screenshots');
  directory.createSync(recursive: true);
  final safeTestId = _safeFileName(testId);
  final frameEntries = <Map<String, dynamic>>[];
  final stepOrdinal = <int, int>{};

  try {
    for (final frame in frames) {
      final failedFrame = status == TestStatus.failed &&
          frame.stepIndex == failedStepIndex &&
          (failedDeviceId == null || frame.deviceId == failedDeviceId);
      final frameDevice = _deviceForFrame(frame, defaultDevice);
      final pngBytes = frame.encodedPngBytes ??
          await _encodeFrameImage(frame, frameDevice);
      frame.encodedPngBytes ??= pngBytes;

      final ordinal = stepOrdinal[frame.stepIndex] ?? 0;
      stepOrdinal[frame.stepIndex] = ordinal + 1;
      final frameFileName = '${safeTestId}_step${frame.stepIndex}_$ordinal.png';
      ensembleTestArtifactFile('screenshots', frameFileName)
          .writeAsBytesSync(pngBytes);
      frameEntries.add({
        'stepIndex': frame.stepIndex,
        'label': frame.label,
        'file': frameFileName,
        if (failedFrame) 'failed': true,
        if (frame.deviceId != null) 'deviceId': frame.deviceId,
        if (frame.deviceLabel != null) 'deviceLabel': frame.deviceLabel,
      });
    }
  } finally {
    if (status != TestStatus.pending) {
      for (final frame in frames) {
        try {
          frame.image.dispose();
        } catch (_) {}
      }
    }
  }

  if (frameEntries.isEmpty) return null;

  // Drop legacy composite sheet artifacts from older runner versions.
  for (final legacyName in [
    '$safeTestId.png',
    '${safeTestId}_sheet.png',
  ]) {
    final legacy = ensembleTestArtifactFile('screenshots', legacyName);
    if (legacy.existsSync()) {
      legacy.deleteSync();
    }
  }

  final framesFileName = '${safeTestId}_frames.json';
  final framesFile = ensembleTestArtifactFile('screenshots', framesFileName);
  framesFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'status': status.name,
      if (failedStepIndex != null) 'failedStepIndex': failedStepIndex,
      if (failedStepLabel != null) 'failedStepLabel': failedStepLabel,
      if (failureMessage != null) 'failureMessage': failureMessage,
      'frames': frameEntries,
    }),
  );

  return ensembleTestArtifactDisplayPath('screenshots', framesFileName);
}

/// @Deprecated Use [writeScreenshotFrames]. Kept as a thin alias for call sites.
Future<String?> writeScreenshotContactSheet({
  required String testId,
  required ScreenshotConfig config,
  required List<ScreenshotSheetFrame> frames,
  required TestStatus status,
  required int durationMs,
  int? failedStepIndex,
  String? failedStepLabel,
  String? failureMessage,
  String? failedDeviceId,
}) {
  return writeScreenshotFrames(
    testId: testId,
    config: config,
    frames: frames,
    status: status,
    failedStepIndex: failedStepIndex,
    failedStepLabel: failedStepLabel,
    failureMessage: failureMessage,
    failedDeviceId: failedDeviceId,
  );
}

DeviceInfo _deviceForFrame(
  ScreenshotSheetFrame frame,
  DeviceInfo fallback,
) {
  final platform = frame.platform;
  final model = frame.model;
  if ((platform == null || platform.isEmpty) &&
      (model == null || model.isEmpty)) {
    return fallback;
  }
  return resolveScreenshotDevice({
    if (platform != null && platform.isNotEmpty) 'platform': platform,
    if (model != null && model.isNotEmpty) 'model': model,
  });
}

Future<Uint8List> _encodeFrameImage(
  ScreenshotSheetFrame frame,
  DeviceInfo device,
) async {
  final bytes = await LiveAsyncCallSupport.runUntracked(
    () => ExtendedStepHandlers.encodeScreenshotImage(frame.image, device),
  );
  if (bytes == null) {
    throw EnsembleTestFailure('Failed to encode screenshot as PNG.');
  }
  return bytes;
}

String _safeFileName(String value) =>
    value.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
