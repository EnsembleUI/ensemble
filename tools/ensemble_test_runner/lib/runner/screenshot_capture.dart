import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ensemble_device_preview/ensemble_device_preview.dart';
import 'package:flutter/painting.dart';

/// Layer-local rectangle to pass to [OffsetLayer.toImageSync] for a RenderView.
///
/// [RenderView.paintBounds] is already `size × devicePixelRatio`. The root
/// TransformLayer applies DPR when compositing, so this must be captured at
/// [screenshotLayerPixelRatio] (1.0). Passing the view DPR again zooms into
/// the top-left of the screen and clips the right/bottom of the UI.
Rect screenshotLayerBounds({
  required Size physicalSize,
  required Rect paintBounds,
}) {
  if (paintBounds.isFinite && !paintBounds.isEmpty) {
    return paintBounds;
  }
  if (physicalSize.isFinite && !physicalSize.isEmpty) {
    return Offset.zero & physicalSize;
  }
  return Rect.zero;
}

/// Pixel ratio for [OffsetLayer.toImageSync] on a RenderView layer.
///
/// Always 1. The root transform already maps logical layout to physical pixels.
const double screenshotLayerPixelRatio = 1.0;

/// Maps a widget rect in logical pixels onto the rasterized screenshot.
Rect screenshotLogicalRectToImagePixels({
  required Rect logicalRect,
  required Size logicalSize,
  required Size imageSize,
}) {
  if (logicalSize.width <= 0 || logicalSize.height <= 0) {
    return Rect.zero;
  }
  final scaleX = imageSize.width / logicalSize.width;
  final scaleY = imageSize.height / logicalSize.height;
  return Rect.fromLTRB(
    logicalRect.left * scaleX,
    logicalRect.top * scaleY,
    logicalRect.right * scaleX,
    logicalRect.bottom * scaleY,
  );
}

/// Destination rect for a capture inside the device-frame screen hole.
///
/// [BoxFit.contain] keeps the capture's aspect ratio. Mapping a default
/// 800×600 widget-test surface into an iPhone hole with [BoxFit.fill]
/// stretches the UI.
Rect screenshotFittedScreenRect({
  required Size imageSize,
  required Rect screenRect,
}) {
  if (imageSize.isEmpty || screenRect.isEmpty) return screenRect;
  final fitted = applyBoxFit(BoxFit.contain, imageSize, screenRect.size);
  return Alignment.center.inscribe(fitted.destination, screenRect);
}

/// Converts a rect in capture-image pixels into HTML overlay percentages.
///
/// When [frameDevice] is set, percentages are relative to the framed output
/// produced by the device-frame encoder. Otherwise they are relative to the
/// raw capture.
Rect screenshotHighlightPercentRect({
  required Rect rectInImagePixels,
  required Size imageSize,
  DeviceInfo? frameDevice,
}) {
  if (frameDevice == null) {
    return Rect.fromLTRB(
      _percent(rectInImagePixels.left, imageSize.width),
      _percent(rectInImagePixels.top, imageSize.height),
      _percent(rectInImagePixels.right, imageSize.width),
      _percent(rectInImagePixels.bottom, imageSize.height),
    );
  }

  final padding = frameDevice.frameSize.shortestSide * 0.025;
  final outputWidth = frameDevice.frameSize.width + padding * 2;
  final outputHeight = frameDevice.frameSize.height + padding * 2;
  final screenRect = frameDevice.screenPath.getBounds().shift(
        Offset(padding, padding),
      );
  final dest = screenshotFittedScreenRect(
    imageSize: imageSize,
    screenRect: screenRect,
  );
  final left =
      dest.left + (rectInImagePixels.left / imageSize.width) * dest.width;
  final top =
      dest.top + (rectInImagePixels.top / imageSize.height) * dest.height;
  final right =
      dest.left + (rectInImagePixels.right / imageSize.width) * dest.width;
  final bottom =
      dest.top + (rectInImagePixels.bottom / imageSize.height) * dest.height;
  return Rect.fromLTRB(
    _percent(left, outputWidth),
    _percent(top, outputHeight),
    _percent(right, outputWidth),
    _percent(bottom, outputHeight),
  );
}

double _percent(double value, double total) =>
    total <= 0 ? 0 : (value / total * 100).clamp(0, 100).toDouble();

class _RgbMean {
  const _RgbMean(this.r, this.g, this.b);
  final double r;
  final double g;
  final double b;

  double distanceTo(_RgbMean other) {
    final dr = r - other.r;
    final dg = g - other.g;
    final db = b - other.b;
    return math.sqrt(dr * dr + dg * dg + db * db);
  }
}

_RgbMean? _sampleRgbMean({
  required Uint8List bytes,
  required int imageWidth,
  required int imageHeight,
  required int left,
  required int top,
  required int right,
  required int bottom,
}) {
  final width = right - left;
  final height = bottom - top;
  if (width <= 0 || height <= 0) return null;
  final stepX = math.max(1, width ~/ 12);
  final stepY = math.max(1, height ~/ 8);
  var sumR = 0, sumG = 0, sumB = 0, count = 0;
  for (var y = top; y < bottom; y += stepY) {
    for (var x = left; x < right; x += stepX) {
      final i = (y * imageWidth + x) * 4;
      sumR += bytes[i];
      sumG += bytes[i + 1];
      sumB += bytes[i + 2];
      count++;
    }
  }
  if (count == 0) return null;
  return _RgbMean(sumR / count, sumG / count, sumB / count);
}

/// Whether [region] looks painted relative to nearby background pixels.
///
/// Solid-colored buttons are flat inside the rect, so we compare the region
/// mean to a strip just above it (or a screen corner). Used to drop optional
/// tap highlights that land on empty loading frames.
Future<bool> screenshotImageRegionHasContrast({
  required ui.Image image,
  required Rect region,
  double minDistance = 18,
}) async {
  if (region.isEmpty || !region.isFinite) return false;
  final left = region.left.floor().clamp(0, image.width - 1);
  final top = region.top.floor().clamp(0, image.height - 1);
  final right = region.right.ceil().clamp(left + 1, image.width);
  final bottom = region.bottom.ceil().clamp(top + 1, image.height);
  if (right <= left || bottom <= top) return false;

  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (byteData == null) return false;
  final bytes = byteData.buffer.asUint8List();

  final regionMean = _sampleRgbMean(
    bytes: bytes,
    imageWidth: image.width,
    imageHeight: image.height,
    left: left,
    top: top,
    right: right,
    bottom: bottom,
  );
  if (regionMean == null) return false;

  // Prefer a strip just above the control (typical loading-frame emptiness).
  final stripHeight = math.max(4, (bottom - top) ~/ 2);
  var bgTop = top - stripHeight - 2;
  var bgBottom = top - 2;
  if (bgTop < 0 || bgBottom <= bgTop) {
    // Fall back to top-left corner of the capture.
    bgTop = 0;
    bgBottom = math.min(stripHeight, image.height);
  }
  final bgMean = _sampleRgbMean(
    bytes: bytes,
    imageWidth: image.width,
    imageHeight: image.height,
    left: left,
    top: bgTop,
    right: right,
    bottom: bgBottom,
  );
  if (bgMean == null) return false;
  return regionMean.distanceTo(bgMean) >= minDistance;
}
