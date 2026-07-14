import 'dart:convert';
import 'dart:io';

import 'package:ensemble_test_runner/actions/extended_step_handlers.dart';
import 'package:ensemble_test_runner/actions/screenshot_device.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/test_runtime_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

const _recordingFrameDurationMs = 800;
const _recordingFrameIntervalMs = 75;
const _recordingMaxFrames = 600;

Future<void> captureRecordingFrame(
  WidgetTester tester,
  EnsembleTestContext context, {
  required String label,
  bool force = false,
}) async {
  final config = context.config.record;
  if (!config.enabled) return;
  if (context.runtime.recordingFrames.length >= _recordingMaxFrames) return;

  final now = DateTime.now();
  final lastTime = context.runtime.lastRecordingFrameTime;
  if (!force &&
      lastTime != null &&
      now.difference(lastTime).inMilliseconds < _recordingFrameIntervalMs) {
    return;
  }

  final screenImage = ExtendedStepHandlers.captureScreenshotImage(tester);

  final durationMs = lastTime == null
      ? _recordingFrameDurationMs
      : now.difference(lastTime).inMilliseconds.clamp(
            _recordingFrameIntervalMs,
            _recordingFrameDurationMs * 4,
          );
  context.runtime
    ..lastRecordingFrameTime = now
    ..addRecordingFrame(
      RecordingFrame(
        testId: context.testCase.id,
        label: label,
        image: screenImage,
        timestamp: now,
        durationMs: durationMs,
      ),
    );
}

Future<String?> writeSessionRecording({
  required RecordConfig config,
  required List<RecordingFrame> frames,
}) async {
  if (!config.enabled || frames.isEmpty) return null;

  final directory = Directory('build/ensemble_test_runner/recordings');
  directory.createSync(recursive: true);

  final encoder = img.GifEncoder(repeat: 0);
  for (final frame in frames) {
    var image = await _decodeRecordingFrame(frame, config);
    if (image != null) {
      if (image.width > 480) {
        image = img.copyResize(
          image,
          width: 480,
          interpolation: img.Interpolation.average,
        );
      }
      final duration = (frame.durationMs / 10).round().clamp(1, 6000);
      encoder.addFrame(image, duration: duration);
    }
  }

  final bytes = encoder.finish();
  if (bytes == null) return null;

  final gifFile = File('${directory.path}/recording.gif');
  gifFile.writeAsBytesSync(bytes);

  final manifestFile = File('${directory.path}/recording.json');
  manifestFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'file': gifFile.path,
      'frames': [
        for (var i = 0; i < frames.length; i++)
          {
            'index': i + 1,
            'testId': frames[i].testId,
            'label': frames[i].label,
            'timestamp': frames[i].timestamp.toIso8601String(),
            'durationMs': frames[i].durationMs,
          },
      ],
    }),
  );

  return gifFile.path;
}

Future<img.Image?> _decodeRecordingFrame(
  RecordingFrame frame,
  RecordConfig config,
) async {
  final pngBytes = frame.pngBytes;
  if (pngBytes != null) {
    return img.decodePng(pngBytes);
  }

  final screenImage = frame.image;
  if (screenImage == null) return null;

  try {
    final device = resolveScreenshotDevice(config.toScreenshotArgs());
    final framedBytes = await ExtendedStepHandlers.encodeScreenshotImage(
      screenImage,
      device,
    );
    return img.decodePng(framedBytes);
  } finally {
    screenImage.dispose();
  }
}
