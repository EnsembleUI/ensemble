import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:face_camera/face_camera.dart';
import 'accuracy_config.dart';
import 'package:ensemble/framework/data_context.dart';

class FaceDetectionResult {
  final bool detected;
  final double? left;
  final double? top;
  final double? width;
  final double? height;
  final String? message;

  FaceDetectionResult({
    this.detected = false,
    this.left,
    this.top,
    this.width,
    this.height,
    this.message,
  });
}

class WebFaceDetection {
  static final ValueNotifier<bool> faceDetected = ValueNotifier<bool>(false);
  static final ValueNotifier<String> statusMessage = ValueNotifier<String>('');
  static final ValueNotifier<double?> faceLeft = ValueNotifier<double?>(null);
  static final ValueNotifier<double?> faceTop = ValueNotifier<double?>(null);
  static final ValueNotifier<double?> faceWidth = ValueNotifier<double?>(null);
  static final ValueNotifier<double?> faceHeight = ValueNotifier<double?>(null);

  static Future<void> initializeCamera({
    required CameraLens initialLens,
    required Function(dynamic) onError,
    ImageResolution imageResolution = ImageResolution.high,
    CameraFlashMode defaultFlashMode = CameraFlashMode.off,
    IndicatorShape indicatorShape = IndicatorShape.defaultShape,
    AccuracyConfig? accuracyConfig,
  }) async {
    // No-op for non-web platforms
  }

  static void setPerformanceMode(FaceDetectorMode mode) {
    // No-op for non-web platforms
  }

  static void dispose() {
    // No-op for non-web platforms
  }

  static CameraController? getCameraController() {
    return null;
  }

  static List<CameraDescription> getCameras() {
    return [];
  }

  static Future<void> switchCamera() async {
    // No-op for non-web platforms
  }

  static bool isFlashSupported() {
    return false;
  }

  static FlashMode getFlashMode() {
    return FlashMode.off;
  }

  static Future<bool> setFlashMode(FlashMode mode) async {
    return false;
  }

  static double? getAspectRatio() {
    return null;
  }

  static bool shouldAutoCapture(bool autoCapture) {
    return false;
  }

  static void markAutoCaptured() {
    // No-op for non-web platforms
  }

  static Future<String?> takePicture() async {
    return null;
  }
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
  final Function(File?)? onCapture;
  final Function(dynamic)? onError;

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
