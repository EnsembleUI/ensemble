import 'package:js/js.dart';
import 'package:flutter/widgets.dart';
import 'package:face_camera/face_camera.dart';

@JS()
@anonymous
class FaceDetectionResult {
  external bool get detected;
  external double? get left;
  external double? get top;
  external double? get width;
  external double? get height;
  external String? get message;
  external factory FaceDetectionResult(
      {bool detected,
      double? left,
      double? top,
      double? width,
      double? height,
      String? message});
}

/// Stub implementation for non-web platforms
class WebFaceDetection {
  static void dispose() {}
  static void setPerformanceMode(FaceDetectorMode mode) {}
  static Future<void> initialize() async {}
  static Future<FaceDetectionResult> detectFace() async =>
      FaceDetectionResult(detected: false);
  static Future<String?> captureImage() async => null;
}

/// Stub implementation of SmartFaceCameraWeb for non-web platforms
class SmartFaceCameraWeb extends StatelessWidget {
  const SmartFaceCameraWeb({
    Key? key,
    this.message = '',
    this.messageStyle = const TextStyle(),
    this.showControls = true,
    this.showCaptureControl = true,
    this.showFlashControl = true,
    this.showCameraLensControl = true,
    this.showStatusMessage = true,
    this.indicatorShape = IndicatorShape.defaultShape,
    this.autoDisableCaptureControl = false,
    this.autoCapture = false,
    this.onCapture,
    this.onError,
  }) : super(key: key);

  final String message;
  final TextStyle messageStyle;
  final bool showControls;
  final bool showCaptureControl;
  final bool showFlashControl;
  final bool showCameraLensControl;
  final bool showStatusMessage;
  final IndicatorShape indicatorShape;
  final bool autoDisableCaptureControl;
  final bool autoCapture;
  final Function(String)? onCapture;
  final Function(dynamic)? onError;

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
