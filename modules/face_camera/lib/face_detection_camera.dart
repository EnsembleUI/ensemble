import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:face_camera/face_camera.dart';
import 'package:flutter/foundation.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'web/face_detection_stub.dart'
    if (dart.library.html) 'web/face_detection_web.dart' as face_detection;
import 'web/face_detection_stub.dart'
    if (dart.library.html) 'web/smart_face_camera_web.dart'
    show SmartFaceCameraWeb;
import 'web/accuracy_config.dart' show AccuracyConfig;
import 'package:ensemble/framework/data_context.dart';

// ignore: must_be_immutable
class FaceDetectionCamera extends StatefulWidget
    with
        Invokable,
        HasController<FaceDetectionController, FaceDetectionCameraState> {
  FaceDetectionCamera({Key? key, this.onCapture, this.onError})
      : super(key: key);

  final void Function(File?)? onCapture;
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
        'message': (value) =>
            controller.updateConfig({'message': Utils.optionalString(value)}),
        'messageStyle': (value) =>
            controller.updateConfig({'messageStyle': value}),
        'showControls': (value) => controller.updateConfig(
            {'showControls': Utils.getBool(value, fallback: true)}),
        'showCaptureControl': (value) => controller.updateConfig(
            {'showCaptureControl': Utils.getBool(value, fallback: true)}),
        'showFlashControl': (value) => controller.updateConfig(
            {'showFlashControl': Utils.getBool(value, fallback: true)}),
        'showCameraLensControl': (value) => controller.updateConfig(
            {'showCameraLensControl': Utils.getBool(value, fallback: true)}),
        'showStatusMessage': (value) => controller.updateConfig(
            {'showStatusMessage': Utils.getBool(value, fallback: true)}),
        'indicatorShape': (value) =>
            controller.updateConfig({'indicatorShape': value}),
        'autoDisableCaptureControl': (value) => controller.updateConfig({
              'autoDisableCaptureControl': Utils.getBool(value, fallback: false)
            }),
        'autoCapture': (value) => controller.updateConfig(
            {'autoCapture': Utils.getBool(value, fallback: false)}),
        'imageResolution': (value) =>
            controller.updateConfig({'imageResolution': value}),
        'defaultFlashMode': (value) =>
            controller.updateConfig({'defaultFlashMode': value}),
        'orientation': (value) =>
            controller.updateConfig({'orientation': value}),
        'performanceMode': (value) =>
            controller.updateConfig({'performanceMode': value}),
        'accuracyConfig': (value) =>
            controller.updateConfig({'accuracyConfig': value}),
      };
}

class FaceDetectionCameraState extends State<FaceDetectionCamera>
    with WidgetsBindingObserver, WidgetStateMixin {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (kIsWeb) {
      try {
        // Initialize camera with web implementation and all configuration properties
        face_detection.WebFaceDetection.setPerformanceMode(
            widget.controller.faceDetectionConfig.performanceMode);
        await face_detection.WebFaceDetection.initializeCamera(
          initialLens: widget.controller.initialCamera,
          onError: widget.onError ?? (e) => print('Error: $e'),
          imageResolution:
              widget.controller.faceDetectionConfig.imageResolution,
          defaultFlashMode:
              widget.controller.faceDetectionConfig.defaultFlashMode,
          indicatorShape: widget.controller.faceDetectionConfig.indicatorShape,
          accuracyConfig: widget.controller.faceDetectionConfig.accuracyConfig,
        );

        setState(() {});
      } catch (e) {
        print('Camera initialization error: $e');
        widget.onError?.call(e);
      }
    } else {
      widget.controller.init(context, widget.onCapture, widget.onError);
    }
  }

  @override
  void didUpdateWidget(FaceDetectionCamera oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update performance mode if config changed
    if (kIsWeb &&
        widget.controller.faceDetectionConfig.performanceMode !=
            oldWidget.controller.faceDetectionConfig.performanceMode) {
      face_detection.WebFaceDetection.setPerformanceMode(
          widget.controller.faceDetectionConfig.performanceMode);
    }
  }

  @override
  void dispose() {
    if (kIsWeb) {
      face_detection.WebFaceDetection.dispose();
    }
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.controller.faceDetectionConfig;

    if (kIsWeb) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: SmartFaceCameraWeb(
            message: config.message,
            messageStyle: config.messageStyle,
            showControls: config.showControls,
            showCaptureControl: config.showCaptureControl,
            showFlashControl: config.showFlashControl,
            showCameraLensControl: config.showCameraLensControl,
            showStatusMessage: config.showStatusMessage,
            indicatorShape: config.indicatorShape,
            autoDisableCaptureControl: config.autoDisableCaptureControl,
            autoCapture: config.autoCapture,
            onCapture: widget.onCapture,
            onError: widget.onError,
          ),
        ),
      );
    }

    // mobile implementation
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: widget.controller.faceCameraController == null
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : SmartFaceCamera(
                controller: widget.controller.faceCameraController!,
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
  FaceCameraController? faceCameraController;
  FaceDetectionConfig faceDetectionConfig = FaceDetectionConfig();

  void setInitialCamera(String? cameraLens) {
    initialCamera = cameraLens == 'back' ? CameraLens.back : CameraLens.front;
  }

  void setFaceDetection(Map<String, dynamic>? configMap) {
    faceDetectionConfig = FaceDetectionConfig.fromMap(configMap);

    // Update face detection mode for web implementation
    if (kIsWeb) {
      face_detection.WebFaceDetection.setPerformanceMode(
          faceDetectionConfig.performanceMode);
    }
  }

  void updateConfig(Map<String, dynamic> partialConfig) {
    faceDetectionConfig = faceDetectionConfig.copyWith(
      message: partialConfig['message'],
      messageStyle: Utils.getTextStyle(partialConfig['messageStyle']),
      showControls: partialConfig['showControls'],
      showCaptureControl: partialConfig['showCaptureControl'],
      showFlashControl: partialConfig['showFlashControl'],
      showCameraLensControl: partialConfig['showCameraLensControl'],
      showStatusMessage: partialConfig['showStatusMessage'],
      indicatorShape: partialConfig['indicatorShape'] is IndicatorShape
          ? partialConfig['indicatorShape']
          : null,
      autoDisableCaptureControl: partialConfig['autoDisableCaptureControl'],
      autoCapture: partialConfig['autoCapture'],
      imageResolution: partialConfig['imageResolution'] is ImageResolution
          ? partialConfig['imageResolution']
          : null,
      defaultFlashMode: partialConfig['defaultFlashMode'] is CameraFlashMode
          ? partialConfig['defaultFlashMode']
          : null,
      orientation: partialConfig['orientation'] is CameraOrientation
          ? partialConfig['orientation']
          : null,
      performanceMode: partialConfig['performanceMode'] != null
          ? FaceDetectionConfig._parsePerformanceMode(
              partialConfig['performanceMode'])
          : null,
      accuracyConfig: partialConfig['accuracyConfig'] != null
          ? (partialConfig['accuracyConfig'] is AccuracyConfig
              ? partialConfig['accuracyConfig']
              : AccuracyConfig.fromMap(
                  Map<String, dynamic>.from(partialConfig['accuracyConfig'])))
          : null,
    );

    if (kIsWeb) {
      face_detection.WebFaceDetection.setPerformanceMode(
          faceDetectionConfig.performanceMode);
    }
    notifyListeners();
  }

  void init(BuildContext context, Function(File?)? onCapture,
      Function(dynamic)? onError) {
    if (!kIsWeb) {
      faceCameraController = FaceCameraController(
          defaultCameraLens: initialCamera,
          autoCapture: faceDetectionConfig.autoCapture,
          imageResolution: faceDetectionConfig.imageResolution,
          defaultFlashMode: faceDetectionConfig.defaultFlashMode,
          orientation: faceDetectionConfig.orientation,
          performanceMode: faceDetectionConfig.performanceMode,
          onCapture: (dynamic image) async {
            if (image != null) {
              try {
                notifyListeners();

                // Convert the image to a File object
                final fileSize = await image.length();
                final fileExtension = image.path?.split('.').last ?? 'jpg';
                final fileName = image.path?.split('/').last ??
                    '${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
                final file =
                    File(fileName, fileExtension, fileSize, image.path, null);

                onCapture?.call(file);
              } catch (e) {
                print('Error capturing image: $e');
                onError?.call(e);
              }
            }
          });
    }
  }

  void dispose() {
    faceCameraController?.dispose();
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
  final bool showStatusMessage;
  final IndicatorShape indicatorShape;
  final bool autoDisableCaptureControl;
  final bool autoCapture;
  final ImageResolution imageResolution;
  final CameraFlashMode defaultFlashMode;
  final CameraOrientation orientation;
  final FaceDetectorMode performanceMode;
  final AccuracyConfig? accuracyConfig;

  FaceDetectionConfig({
    this.message = '',
    this.messageStyle = const TextStyle(color: Colors.white),
    this.showControls = true,
    this.showCaptureControl = true,
    this.showFlashControl = true,
    this.showCameraLensControl = true,
    this.showStatusMessage = true,
    this.indicatorShape = IndicatorShape.defaultShape,
    this.autoDisableCaptureControl = false,
    this.autoCapture = false,
    this.imageResolution = ImageResolution.high,
    this.defaultFlashMode = CameraFlashMode.off,
    this.orientation = CameraOrientation.portraitUp,
    this.performanceMode = FaceDetectorMode.fast,
    this.accuracyConfig,
  });

  FaceDetectionConfig copyWith({
    String? message,
    TextStyle? messageStyle,
    bool? showControls,
    bool? showCaptureControl,
    bool? showFlashControl,
    bool? showCameraLensControl,
    bool? showStatusMessage,
    IndicatorShape? indicatorShape,
    bool? autoDisableCaptureControl,
    bool? autoCapture,
    ImageResolution? imageResolution,
    CameraFlashMode? defaultFlashMode,
    CameraOrientation? orientation,
    FaceDetectorMode? performanceMode,
    AccuracyConfig? accuracyConfig,
  }) {
    return FaceDetectionConfig(
      message: message ?? this.message,
      messageStyle: messageStyle ?? this.messageStyle,
      showControls: showControls ?? this.showControls,
      showCaptureControl: showCaptureControl ?? this.showCaptureControl,
      showFlashControl: showFlashControl ?? this.showFlashControl,
      showCameraLensControl:
          showCameraLensControl ?? this.showCameraLensControl,
      showStatusMessage: showStatusMessage ?? this.showStatusMessage,
      indicatorShape: indicatorShape ?? this.indicatorShape,
      autoDisableCaptureControl:
          autoDisableCaptureControl ?? this.autoDisableCaptureControl,
      autoCapture: autoCapture ?? this.autoCapture,
      imageResolution: imageResolution ?? this.imageResolution,
      defaultFlashMode: defaultFlashMode ?? this.defaultFlashMode,
      orientation: orientation ?? this.orientation,
      performanceMode: performanceMode ?? this.performanceMode,
      accuracyConfig: accuracyConfig ?? this.accuracyConfig,
    );
  }

  factory FaceDetectionConfig.fromMap(Map<String, dynamic>? map) {
    log('message $map');
    if (map == null) return FaceDetectionConfig();

    return FaceDetectionConfig(
      message: map['message'] ?? '',
      messageStyle: Utils.getTextStyle(map['messageStyle']) ??
          const TextStyle(color: Colors.white),
      showControls: map['showControls'] ?? true,
      showCaptureControl: map['showCaptureControl'] ?? true,
      showFlashControl: map['showFlashControl'] ?? true,
      showCameraLensControl: map['showCameraLensControl'] ?? true,
      showStatusMessage: map['showStatusMessage'] ?? true,
      indicatorShape: map['indicatorShape'] ?? IndicatorShape.defaultShape,
      autoDisableCaptureControl: map['autoDisableCaptureControl'] ?? false,
      autoCapture: map['autoCapture'] ?? false,
      imageResolution: map['imageResolution'] ?? ImageResolution.high,
      defaultFlashMode: map['defaultFlashMode'] ?? CameraFlashMode.off,
      orientation: map['orientation'] ?? CameraOrientation.portraitUp,
      performanceMode: _parsePerformanceMode(map['performanceMode']),
      accuracyConfig: map['accuracyConfig'] != null
          ? AccuracyConfig.fromMap(
              Map<String, dynamic>.from(map['accuracyConfig']))
          : null,
    );
  }

  static FaceDetectorMode _parsePerformanceMode(dynamic value) {
    if (value == 'accurate') {
      return FaceDetectorMode.accurate;
    }
    return FaceDetectorMode.fast;
  }
}
