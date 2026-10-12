import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:ensemble_test_runner/actions/extended_step_handlers.dart';
import 'package:ensemble_test_runner/actions/screenshot_device.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/live_async_call.dart';
import 'package:ensemble_test_runner/runner/webp_encoder.dart';
import 'package:ensemble_test_runner/runner/test_artifacts.dart';
import 'package:ensemble_test_runner/runner/test_runtime_state.dart';
import 'package:ensemble_test_runner/src/integrations/device_preview/device_preview_adapter.dart';
import 'package:path/path.dart' as p;

const _maxReportScreenshotWidth = 360;

/// Encodes each frame for the HTML report and writes a `frames.json` manifest.
///
/// Widget mode dresses frames in a device bezel. Integration mode keeps the
/// raw simulator/emulator capture so highlights match the pixels.
///
/// Returns the display path of the frames manifest.
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
  List<StepObserverArtifact> stepObservers = const [],
}) async {
  return await RunnerBenchmark.async('screenshot', 'writeScreenshotFrames',
      () async {
    if (frames.isEmpty && stepObservers.isEmpty) return null;

    final defaultDevice = resolveScreenshotDevice(const {});
    final manifestDirectory = ensembleTestArtifactDirectory('frames');
    final imageDirectory = ensembleTestArtifactDirectory(
      p.join('report', 'screenshots'),
    );
    if (!usesDeviceArtifactTransport) {
      manifestDirectory.createSync(recursive: true);
      imageDirectory.createSync(recursive: true);
    }
    final safeTestId = _safeFileName(testId);
    final frameEntries = <Map<String, dynamic>>[];

    try {
      for (final frame in frames) {
        final failedFrame = status == TestStatus.failed &&
            frame.stepIndex == failedStepIndex &&
            (failedDeviceId == null || frame.deviceId == failedDeviceId);
        final frameDevice = _deviceForFrame(frame, defaultDevice);
        final encoded = frame.encodedReportImage ??
            await _encodeFrameImage(frame, frameDevice);
        frame.encodedReportImage ??= encoded;
        RunnerBenchmark.count('framesEncoded', 1);
        RunnerBenchmark.count('encodedBytes', encoded.bytes.length);
        RunnerBenchmark.dimension('codec', encoded.extension);

        // Byte-exact dedup only: any real pixel difference keeps its own file.
        // Perceptual hashing previously collapsed small UI changes (day-button
        // selection, success toasts) into stale frames and broke report highlights.
        final frameFileName = _dedupedImageFileName(encoded);
        final frameFile = File(p.join(imageDirectory.path, frameFileName));
        if (usesDeviceArtifactTransport || !frameFile.existsSync()) {
          RunnerBenchmark.count('filesWritten', 1);
          await writeEnsembleTestArtifactBytes(
            p.join('report', 'screenshots'),
            frameFileName,
            encoded.bytes,
            mimeType: _mimeTypeForExtension(encoded.extension),
          );
        }
        frameEntries.add({
          'stepIndex': frame.stepIndex,
          'label': frame.label,
          'file': frameFileName,
          if (failedFrame) 'failed': true,
          if (frame.deviceId != null) 'deviceId': frame.deviceId,
          if (frame.deviceLabel != null) 'deviceLabel': frame.deviceLabel,
          if (frame.highlight != null) 'highlight': frame.highlight!.toJson(),
        });
      }

      for (final observer in stepObservers) {
        // Metadata only — no second PNG. HTML draws overlays on the step shot.
        frameEntries.add({
          'stepIndex': observer.stepIndex,
          'role': 'observer',
          'observationJson': observer.observationJson,
          if (observer.overlays.isNotEmpty) 'overlays': observer.overlays,
        });
      }
    } finally {
      for (final frame in frames) {
        try {
          frame.image.dispose();
        } catch (_) {}
      }
      for (final observer in stepObservers) {
        observer.dispose();
      }
    }

    if (frameEntries.isEmpty) return null;

    // Drop legacy composite sheet artifacts from older runner versions.
    if (!usesDeviceArtifactTransport) {
      for (final legacyDir in [
        manifestDirectory,
        ensembleTestArtifactDirectory('screenshots'),
      ]) {
        for (final legacyName in [
          '$safeTestId.png',
          '${safeTestId}_sheet.png',
        ]) {
          final legacy = File(p.join(legacyDir.path, legacyName));
          if (legacy.existsSync()) {
            legacy.deleteSync();
          }
        }
      }
    }

    final framesFileName = '${safeTestId}_frames.json';
    await writeEnsembleTestArtifactString(
      'frames',
      framesFileName,
      const JsonEncoder.withIndent(' ').convert({
        'status': status.name,
        if (failedStepIndex != null) 'failedStepIndex': failedStepIndex,
        if (failedStepLabel != null) 'failedStepLabel': failedStepLabel,
        if (failureMessage != null) 'failureMessage': failureMessage,
        'frames': frameEntries,
      }),
      mimeType: 'application/json',
    );

    return ensembleTestArtifactDisplayPath('frames', framesFileName);
  });
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

Future<EncodedScreenshotImage> _encodeFrameImage(
  ScreenshotSheetFrame frame,
  DeviceInfo device,
) async {
  return await RunnerBenchmark.async('screenshot', 'encodeFrameImage',
      () async {
    if (!framesScreenshotsWithDeviceBezel) {
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw EnsembleTestFailure('Failed to encode integration screenshot.');
      }
      return EncodedScreenshotImage(
        bytes: data.buffer.asUint8List(),
        extension: 'png',
      );
    }
    final bytes = await LiveAsyncCallSupport.runUntracked(
      () => ExtendedStepHandlers.encodeScreenshotImage(frame.image, device),
    );
    if (bytes == null) {
      throw EnsembleTestFailure('Failed to encode screenshot.');
    }
    return encodePngAsWebp(
      bytes,
      benchmarkOperation: 'encodeWebP',
      resizeWidth: _maxReportScreenshotWidth,
      blendAlpha: '0x0a111f',
    ).then((webPBytes) {
      if (webPBytes == null) {
        throw EnsembleTestFailure(
          'Could not encode screenshot as WebP. Ensure the runner WebP encoder is available.',
        );
      }
      return EncodedScreenshotImage(bytes: webPBytes, extension: 'webp');
    });
  });
}

String _mimeTypeForExtension(String extension) => switch (extension) {
      'webp' => 'image/webp',
      _ => 'application/octet-stream',
    };

String _safeFileName(String value) =>
    value.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');

String _dedupedImageFileName(EncodedScreenshotImage image) {
  return RunnerBenchmark.sync('screenshot', 'dedupedImageFileName', () {
    final digest = sha256.convert(image.bytes).toString();
    return 'shot_${image.bytes.length}_$digest.${image.extension}';
  });
}
