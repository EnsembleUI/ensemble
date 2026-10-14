/// Classification of failures raised while producing optional screenshot
/// evidence. Reporting policy remains owned by the execution adapter.
enum ScreenshotCaptureFailureKind {
  unpaintedRenderView,
  renderCapture,
  other,
}

ScreenshotCaptureFailureKind classifyScreenshotCaptureFailure(Object? error) {
  final text = error?.toString() ?? '';
  if (text.contains('screenshot requires a painted render view')) {
    return ScreenshotCaptureFailureKind.unpaintedRenderView;
  }
  if (text.contains('toImageSync') ||
      text.contains('RenderRepaintBoundary') ||
      text.contains('debugNeedsPaint') ||
      text.contains('Cannot capture screenshot')) {
    return ScreenshotCaptureFailureKind.renderCapture;
  }
  return ScreenshotCaptureFailureKind.other;
}

bool isKnownScreenshotCaptureFailure(Object? error) =>
    classifyScreenshotCaptureFailure(error) !=
    ScreenshotCaptureFailureKind.other;
