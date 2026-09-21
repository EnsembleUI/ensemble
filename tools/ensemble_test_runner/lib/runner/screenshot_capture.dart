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
