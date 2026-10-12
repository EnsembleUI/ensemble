import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'dart:ui' as ui;

import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/screenshot_capture.dart';
import 'package:ensemble_test_runner/src/integrations/device_preview/device_preview_adapter.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Screenshot capture and encoding utilities used by runner diagnostics.
class ExtendedStepHandlers {
  static ui.Image captureScreenshotImage(WidgetTester tester) {
    return RunnerBenchmark.sync('screenshot', 'captureScreenshotImage', () {
      RunnerBenchmark.dimension('renderingIncluded', true);
      final renderView = tester.binding.renderViews.first;
      final layer = renderView.debugLayer;
      if (layer is! OffsetLayer) {
        throw EnsembleTestFailure(
          'screenshot requires a painted render view.',
        );
      }

      final view = renderView.flutterView;
      final image = layer.toImageSync(
        screenshotLayerBounds(
          physicalSize: view.physicalSize,
          paintBounds: renderView.paintBounds,
        ),
        pixelRatio: screenshotLayerPixelRatio,
      );
      RunnerBenchmark.count('framesCaptured', 1);
      RunnerBenchmark.count('pixels', image.width * image.height);
      return image;
    });
  }

  static Future<Uint8List> encodeScreenshotImage(
    ui.Image image,
    DeviceInfo device,
  ) async {
    return await RunnerBenchmark.async('screenshot', 'encodeScreenshotImage',
        () async {
      final byteData = await _addDeviceFrame(image, device);
      if (byteData == null) {
        throw EnsembleTestFailure('Failed to encode screenshot as PNG.');
      }
      return byteData.buffer.asUint8List();
    });
  }

  static Future<ByteData?> _addDeviceFrame(
    ui.Image screenImage,
    DeviceInfo device,
  ) async {
    return await RunnerBenchmark.async('screenshot', 'addDeviceFrame',
        () async {
      final padding = device.frameSize.shortestSide * 0.025;
      final outputWidth = (device.frameSize.width + padding * 2).ceil();
      final outputHeight = (device.frameSize.height + padding * 2).ceil();

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
        recorder,
        Rect.fromLTWH(0, 0, outputWidth.toDouble(), outputHeight.toDouble()),
      );

      canvas.drawColor(const Color(0x00000000), BlendMode.src);
      canvas.save();
      canvas.translate(padding, padding);
      device.framePainter.paint(canvas, device.frameSize);

      final screenPath = device.screenPath;
      final screenRect = screenPath.getBounds();
      canvas.save();
      canvas.clipPath(screenPath);
      canvas.drawRect(screenRect, Paint()..color = const Color(0xFFFFFFFF));
      final imageSize = Size(
        screenImage.width.toDouble(),
        screenImage.height.toDouble(),
      );
      canvas.drawImageRect(
        screenImage,
        Offset.zero & imageSize,
        screenshotFittedScreenRect(
          imageSize: imageSize,
          screenRect: screenRect,
        ),
        Paint()..filterQuality = FilterQuality.high,
      );
      canvas.restore();
      canvas.restore();

      final picture = recorder.endRecording();
      final image = await picture.toImage(outputWidth, outputHeight);
      picture.dispose();
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return byteData;
    });
  }
}
