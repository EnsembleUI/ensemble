import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ensemble_device_preview/ensemble_device_preview.dart';
import 'package:ensemble_test_runner/actions/extended_step_handlers.dart';
import 'package:ensemble_test_runner/actions/screenshot_device.dart';
import 'package:ensemble_test_runner/runner/screenshot_capture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('layer bounds keep the physical RenderView paintBounds', () {
    const physical = Size(1179, 2556);
    final bounds = screenshotLayerBounds(
      physicalSize: physical,
      paintBounds: Offset.zero & physical,
    );

    expect(bounds, Offset.zero & physical);
    expect(screenshotLayerPixelRatio, 1.0);
  });

  test('layer bounds fall back to physicalSize when paintBounds are empty', () {
    const physical = Size(1179, 2556);
    final bounds = screenshotLayerBounds(
      physicalSize: physical,
      paintBounds: Rect.zero,
    );

    expect(bounds, Offset.zero & physical);
  });

  test('logical widget rects scale onto a physical screenshot', () {
    final rect = screenshotLogicalRectToImagePixels(
      logicalRect: const Rect.fromLTWH(24, 48, 200, 20),
      logicalSize: const Size(393, 852),
      imageSize: const Size(1179, 2556),
    );

    expect(rect.left, closeTo(72, 0.01));
    expect(rect.top, closeTo(144, 0.01));
    expect(rect.width, closeTo(600, 0.01));
    expect(rect.height, closeTo(60, 0.01));
  });

  test('raw highlight percentages match the capture image', () {
    final rect = screenshotHighlightPercentRect(
      rectInImagePixels: const Rect.fromLTWH(24, 48, 200, 20),
      imageSize: const Size(400, 800),
      frameDevice: null,
    );

    expect(rect.left, closeTo(6, 0.01));
    expect(rect.top, closeTo(6, 0.01));
    expect(rect.width, closeTo(50, 0.01));
    expect(rect.height, closeTo(2.5, 0.01));
  });

  test('framed highlight percentages sit inside the device screen hole', () {
    final device = resolveScreenshotDevice(const {});
    expect(device.name, Devices.ios.iPhone15Pro.name);

    final rect = screenshotHighlightPercentRect(
      rectInImagePixels: const Rect.fromLTWH(0, 0, 393, 40),
      imageSize: const Size(393, 852),
      frameDevice: device,
    );

    expect(rect.left, greaterThan(4));
    expect(rect.top, greaterThan(2));
    expect(rect.right, lessThan(96));
    expect(rect.width, greaterThan(70));
    expect(rect.height, lessThan(10));
  });

  testWidgets(
    'root-layer capture is the full view, not a DPR-zoomed crop',
    (tester) async {
      tester.view.physicalSize = const Size(300, 600);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      const marker = Color(0xFF0000FF);
      const background = Color(0xFFFF0000);
      await tester.pumpWidget(
        const ColoredBox(
          color: background,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 24,
              height: 24,
              child: ColoredBox(color: marker),
            ),
          ),
        ),
      );

      final image = await tester.runAsync(
        () async => ExtendedStepHandlers.captureScreenshotImage(tester),
      );
      expect(image, isNotNull);
      addTearDown(image!.dispose);

      expect(image.width, 300);
      expect(image.height, 600);

      final bytes = await tester.runAsync(() => _rgba(image));
      expect(bytes, isNotNull);
      // 24 logical px × 3 DPR = 72 physical px. A second DPR scale would
      // keep the marker blue out to x=216.
      expect(_rgbaAt(bytes!, image.width, 36, 36), marker);
      expect(_rgbaAt(bytes, image.width, 90, 36), background);
      expect(_rgbaAt(bytes, image.width, 280, 36), background);
    },
  );

  testWidgets(
    'highlight percentages follow the logical widget, not a zoomed crop',
    (tester) async {
      tester.view.physicalSize = const Size(300, 600);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: EdgeInsets.only(left: 20, top: 40),
            child: SizedBox(
              key: ValueKey('target'),
              width: 30,
              height: 20,
              child: ColoredBox(color: Color(0xFF00FF00)),
            ),
          ),
        ),
      );

      final image = await tester.runAsync(
        () async => ExtendedStepHandlers.captureScreenshotImage(tester),
      );
      expect(image, isNotNull);
      addTearDown(image!.dispose);
      final renderView = tester.binding.renderViews.first;
      final logical = tester.getRect(find.byKey(const ValueKey('target')));

      final imageRect = screenshotLogicalRectToImagePixels(
        logicalRect: logical,
        logicalSize: renderView.size,
        imageSize: Size(image.width.toDouble(), image.height.toDouble()),
      );
      final percent = screenshotHighlightPercentRect(
        rectInImagePixels: imageRect,
        imageSize: Size(image.width.toDouble(), image.height.toDouble()),
      );

      expect(percent.left, closeTo(20 / 100 * 100, 0.5));
      expect(percent.top, closeTo(40 / 200 * 100, 0.5));
      expect(percent.width, closeTo(30 / 100 * 100, 0.5));
      expect(percent.height, closeTo(20 / 200 * 100, 0.5));
    },
  );
}

Future<Uint8List> _rgba(ui.Image image) async {
  final data = await image.toByteData();
  return data!.buffer.asUint8List();
}

Color _rgbaAt(Uint8List bytes, int width, int x, int y) {
  final i = (y * width + x) * 4;
  return Color.fromARGB(bytes[i + 3], bytes[i], bytes[i + 1], bytes[i + 2]);
}
