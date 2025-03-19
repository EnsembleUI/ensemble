import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:face_camera/face_camera.dart';

// ignore: must_be_immutable
class FaceDetectionCamera extends StatefulWidget
    with
        Invokable,
        HasController<FaceDetectionController, FaceDetectionCameraState> {
  FaceDetectionCamera({Key? key, this.onCapture, this.onError})
      : super(key: key);

  final void Function(String)? onCapture;
  final void Function(dynamic)? onError;

  @override
  final FaceDetectionController controller = FaceDetectionController();

  @override
  State<StatefulWidget> createState() => FaceDetectionCameraState();

  @override
  Map<String, Function> getters() => {};

  @override
  Map<String, Function> methods() => {};

  @override
  Map<String, Function> setters() => {
        'initialCamera': (value) => controller
            .setInitialCamera(Utils.getString(value, fallback: 'front')),
        'faceDetection': (value) =>
            controller.setFaceDetection(Utils.getMap(value)),
      };
}

class FaceDetectionCameraState extends State<FaceDetectionCamera>
    with WidgetsBindingObserver, WidgetStateMixin {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.init(context, widget.onCapture, widget.onError);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.controller.faceDetectionConfig;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SmartFaceCamera(
          controller: widget.controller.faceCameraController,
          message: config.message,
          messageStyle: config.messageStyle,
          showControls: config.showControls,
          showCaptureControl: config.showCaptureControl,
          showFlashControl: config.showFlashControl,
          showCameraLensControl: config.showCameraLensControl,
          indicatorShape: config.indicatorShape,
          autoDisableCaptureControl: config.autoDisableCaptureControl,
        ),
      ),
    );
  }
}

class FaceDetectionController extends Controller {
  FaceDetectionController();

  CameraLens initialCamera = CameraLens.front;
  late final FaceCameraController faceCameraController;
  FaceDetectionConfig faceDetectionConfig = FaceDetectionConfig();

  void setInitialCamera(String? cameraLens) {
    initialCamera = cameraLens == 'back' ? CameraLens.back : CameraLens.front;
  }

  void setFaceDetection(Map<String, dynamic>? configMap) {
    faceDetectionConfig = FaceDetectionConfig.fromMap(configMap);
  }

  void init(BuildContext context, Function(String)? onCapture,
      Function(dynamic)? onError) {
    faceCameraController = FaceCameraController(
        defaultCameraLens: initialCamera,
        autoCapture: faceDetectionConfig.autoCapture,
        imageResolution: faceDetectionConfig.imageResolution,
        defaultFlashMode: faceDetectionConfig.defaultFlashMode,
        orientation: faceDetectionConfig.orientation,
        performanceMode: faceDetectionConfig.performanceMode,
        onCapture: (File? image) async {
          if (image != null) {
            try {
              notifyListeners();
              onCapture?.call(image.path);
            } catch (e) {
              onError?.call(e);
            }
          }
        });
  }

  @override
  void dispose() {
    faceCameraController.dispose();
    super.dispose();
  }
}

class FaceDetectionConfig {
  final String message;
  final TextStyle messageStyle;
  final bool showControls;
  final bool showCaptureControl;
  final bool showFlashControl;
  final bool showCameraLensControl;
  final IndicatorShape indicatorShape;
  final bool autoDisableCaptureControl;
  final bool autoCapture;
  final ImageResolution imageResolution;
  final CameraFlashMode defaultFlashMode;
  final CameraOrientation orientation;
  final FaceDetectorMode performanceMode;

  FaceDetectionConfig({
    this.message = '',
    this.messageStyle = const TextStyle(color: Colors.white),
    this.showControls = true,
    this.showCaptureControl = true,
    this.showFlashControl = true,
    this.showCameraLensControl = true,
    this.indicatorShape = IndicatorShape.defaultShape,
    this.autoDisableCaptureControl = false,
    this.autoCapture = false,
    this.imageResolution = ImageResolution.high,
    this.defaultFlashMode = CameraFlashMode.off,
    this.orientation = CameraOrientation.portraitUp,
    this.performanceMode = FaceDetectorMode.fast,
  });

  factory FaceDetectionConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return FaceDetectionConfig();

    return FaceDetectionConfig(
      message: map['message'] ?? '',
      messageStyle: Utils.getTextStyle(map['messageStyle']) ??
          const TextStyle(color: Colors.white),
      showControls: map['showControls'] ?? true,
      showCaptureControl: map['showCaptureControl'] ?? true,
      showFlashControl: map['showFlashControl'] ?? true,
      showCameraLensControl: map['showCameraLensControl'] ?? true,
      indicatorShape: map['indicatorShape'] ?? IndicatorShape.defaultShape,
      autoDisableCaptureControl: map['autoDisableCaptureControl'] ?? false,
      autoCapture: map['autoCapture'] ?? false,
      imageResolution: map['imageResolution'] ?? ImageResolution.high,
      defaultFlashMode: map['defaultFlashMode'] ?? CameraFlashMode.off,
    );
  }
}
