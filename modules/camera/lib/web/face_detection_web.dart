import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:js/js.dart';
import 'package:js/js_util.dart' as js_util;
import 'package:face_camera/face_camera.dart';

@JS('window')
external dynamic get window;

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

class AccuracyConfig {
  final double detectionThreshold;
  final double intersectionRatioThreshold;
  final double extraHeightFactor;
  final int inputSize;
  final double landmarkRatio;
  final double frameMargin;
  final double tiltAngleThreshold;
  final double horizontalCenterTolerance;
  final double earThreshold;
  final double minFaceWidthRatio;
  final double maxFaceWidthRatio;
  final double qualityPassThreshold;
  final double yawLowerThreshold;
  final double yawUpperThreshold;

  const AccuracyConfig({
    this.detectionThreshold = 0.6,
    this.intersectionRatioThreshold = 0.9,
    this.extraHeightFactor = 0.3,
    this.inputSize = 224,
    this.landmarkRatio = 0.95,
    this.frameMargin = 0.05,
    this.tiltAngleThreshold = 6,
    this.horizontalCenterTolerance = 0.08,
    this.earThreshold = 0.25,
    this.minFaceWidthRatio = 0.18,
    this.maxFaceWidthRatio = 0.82,
    this.qualityPassThreshold = 0.8,
    this.yawLowerThreshold = 0.85,
    this.yawUpperThreshold = 1.15,
  });

  Map<String, dynamic> toMap() {
    return {
      'detectionThreshold': detectionThreshold,
      'intersectionRatioThreshold': intersectionRatioThreshold,
      'extraHeightFactor': extraHeightFactor,
      'inputSize': inputSize,
      'landmarkRatio': landmarkRatio,
      'frameMargin': frameMargin,
      'tiltAngleThreshold': tiltAngleThreshold,
      'horizontalCenterTolerance': horizontalCenterTolerance,
      'earThreshold': earThreshold,
      'minFaceWidthRatio': minFaceWidthRatio,
      'maxFaceWidthRatio': maxFaceWidthRatio,
      'qualityPassThreshold': qualityPassThreshold,
      'yawLowerThreshold': yawLowerThreshold,
      'yawUpperThreshold': yawUpperThreshold,
    };
  }

  factory AccuracyConfig.fromMap(Map<String, dynamic> map) {
    return AccuracyConfig(
      detectionThreshold: map['detectionThreshold']?.toDouble() ?? 0.6,
      intersectionRatioThreshold:
          map['intersectionRatioThreshold']?.toDouble() ?? 0.9,
      extraHeightFactor: map['extraHeightFactor']?.toDouble() ?? 0.3,
      inputSize: map['inputSize']?.toInt() ?? 224,
      landmarkRatio: map['landmarkRatio']?.toDouble() ?? 0.95,
      frameMargin: map['frameMargin']?.toDouble() ?? 0.05,
      tiltAngleThreshold: map['tiltAngleThreshold']?.toDouble() ?? 6,
      horizontalCenterTolerance:
          map['horizontalCenterTolerance']?.toDouble() ?? 0.08,
      earThreshold: map['earThreshold']?.toDouble() ?? 0.25,
      minFaceWidthRatio: map['minFaceWidthRatio']?.toDouble() ?? 0.18,
      maxFaceWidthRatio: map['maxFaceWidthRatio']?.toDouble() ?? 0.82,
      qualityPassThreshold: map['qualityPassThreshold']?.toDouble() ?? 0.8,
      yawLowerThreshold: map['yawLowerThreshold']?.toDouble() ?? 0.85,
      yawUpperThreshold: map['yawUpperThreshold']?.toDouble() ?? 1.15,
    );
  }
}

class WebFaceDetection {
  static bool _initialized = false;
  static bool _scriptLoaded = false;
  static Timer? _faceDetectionTimer;
  static CameraController? _cameraController;
  static List<CameraDescription> _cameras = [];
  static bool _isCapturing = false;
  static bool _autoCaptureDone = false;
  static FaceDetectorMode _performanceMode = FaceDetectorMode.fast;
  static AccuracyConfig? _accuracyConfig;

  // New properties for additional configuration
  static IndicatorShape _indicatorShape = IndicatorShape.defaultShape;
  static ImageResolution _imageResolution = ImageResolution.high;
  static CameraFlashMode _defaultFlashMode = CameraFlashMode.off;
  static bool _isFlashSupported = false;

  // State variables for face detection box (normalized values)
  static ValueNotifier<double?> faceLeft = ValueNotifier<double?>(null);
  static ValueNotifier<double?> faceTop = ValueNotifier<double?>(null);
  static ValueNotifier<double?> faceWidth = ValueNotifier<double?>(null);
  static ValueNotifier<double?> faceHeight = ValueNotifier<double?>(null);
  static ValueNotifier<bool> faceDetected = ValueNotifier<bool>(false);
  static ValueNotifier<String> statusMessage = ValueNotifier<String>('');

  static Future<void> _loadScript() async {
    if (_scriptLoaded) return;

    final completer = Completer<void>();

    String getAssetPath(String filename) {
      return 'assets/packages/ensemble_camera/web/$filename';
    }

    void handleScriptError(event, String scriptName) {
      final error = event is html.Event ? event.type : event.toString();
      print('Error loading $scriptName: $error');
      if (!completer.isCompleted) {
        completer.completeError('Failed to load $scriptName: $error');
      }
    }

    // Load face-api.js first
    final faceApiScript = html.ScriptElement()
      ..src = getAssetPath('face_api.js')
      ..type = 'text/javascript'
      ..onLoad.listen((_) {
        final scriptElement = html.ScriptElement()
          ..src = getAssetPath('face_detection.js')
          ..type = 'text/javascript'
          ..onLoad.listen((_) {
            _scriptLoaded = true;
            completer.complete();
          })
          ..onError
              .listen((event) => handleScriptError(event, 'face_detection.js'));

        html.document.head!.append(scriptElement);
      })
      ..onError.listen((event) => handleScriptError(event, 'face-api.js'));

    html.document.head!.append(faceApiScript);
    await completer.future;
  }

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await _loadScript();
      await js_util
          .promiseToFuture(js_util.callMethod(window, 'initFaceDetection', []));
      _initialized = true;
    } catch (e) {
      print('Error initializing face detection: $e');
      throw Exception('Failed to initialize face detection: $e');
    }
  }

  static Future<FaceDetectionResult> detectFace(
      {bool accurateMode = false, Map<String, dynamic>? accuracyConfig}) async {
    if (!_initialized) return FaceDetectionResult(detected: false);

    final videoElements = html.document.getElementsByTagName('video');
    if (videoElements.isEmpty) return FaceDetectionResult(detected: false);

    try {
      final result = await js_util.promiseToFuture<FaceDetectionResult>(js_util
          .callMethod(window, 'detectFace',
              [videoElements[0], accurateMode, js_util.jsify(accuracyConfig)]));
      return result;
    } catch (e) {
      print('Face detection error: $e');
      return FaceDetectionResult(detected: false);
    }
  }

  static Future<String?> captureImage() async {
    final videoElements = html.document.getElementsByTagName('video');
    if (videoElements.isEmpty) return null;

    try {
      return js_util.callMethod(window, 'captureImage', [videoElements[0]])
          as String;
    } catch (e) {
      print('Image capture error: $e');
      return null;
    }
  }

  /// Initialize camera and start face detection
  static Future<void> initializeCamera({
    required CameraLens initialLens,
    required Function(dynamic) onError,
    ImageResolution imageResolution = ImageResolution.high,
    CameraFlashMode defaultFlashMode = CameraFlashMode.off,
    IndicatorShape indicatorShape = IndicatorShape.defaultShape,
    AccuracyConfig? accuracyConfig,
  }) async {
    try {
      // Store the configuration
      _accuracyConfig = accuracyConfig;
      _imageResolution = imageResolution;
      _defaultFlashMode = defaultFlashMode;
      _indicatorShape = indicatorShape;

      // Clean up any existing camera resources first
      _faceDetectionTimer?.cancel();
      if (_cameraController != null) {
        if (_cameraController!.value.isInitialized) {
          await _cameraController!.dispose();
        }
        _cameraController = null;
      }

      // Reset face detection values
      faceDetected.value = false;
      statusMessage.value = '';
      faceLeft.value = null;
      faceTop.value = null;
      faceWidth.value = null;
      faceHeight.value = null;

      // Initialize face detection first
      await initialize();

      // Initialize cameras after face detection is ready
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        onError('No cameras available');
        return;
      }

      // Select initial camera
      final initialCamera = initialLens == CameraLens.front
          ? _cameras.firstWhere(
              (camera) => camera.lensDirection == CameraLensDirection.front,
              orElse: () => _cameras.first)
          : _cameras.firstWhere(
              (camera) => camera.lensDirection == CameraLensDirection.back,
              orElse: () => _cameras.first);

      // Map ImageResolution to ResolutionPreset
      ResolutionPreset resolutionPreset =
          _mapResolutionToPreset(_imageResolution);

      // Initialize camera controller with resolution
      _cameraController = CameraController(
        initialCamera,
        resolutionPreset,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      // Apply flash mode settings
      await _applyInitialFlashMode();

      // Start face detection after ensuring everything is initialized
      await Future.delayed(const Duration(milliseconds: 1000));
      startFaceDetection();
    } catch (e) {
      print('Camera initialization error: $e');
      onError(e);
    }
  }

  /// Apply flash mode settings
  static Future<bool> _applyInitialFlashMode() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return false;
    }

    FlashMode flashMode = FlashMode.off;
    switch (_defaultFlashMode) {
      case CameraFlashMode.off:
        flashMode = FlashMode.off;
        break;
      case CameraFlashMode.always:
        flashMode = FlashMode.torch;
        break;
      case CameraFlashMode.auto:
        flashMode = FlashMode.auto;
        break;
    }

    // Try to set the flash mode
    try {
      await _cameraController!.setFlashMode(flashMode);
      _isFlashSupported = true;
      return true;
    } catch (e) {
      _isFlashSupported = false;
      return false;
    }
  }

  /// Check if flash is supported
  static bool isFlashSupported() {
    return _isFlashSupported;
  }

  /// Start periodic face detection
  static void startFaceDetection() {
    _faceDetectionTimer?.cancel();
    _faceDetectionTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _processFaceDetection(),
    );
  }

  /// Process face detection on current camera frame
  static Future<void> _processFaceDetection() async {
    if (!_initialized) {
      return;
    }

    // Check for valid camera controller
    if (_cameraController == null) {
      return;
    }

    // Safely check if camera is initialized
    bool isInitialized = false;
    try {
      isInitialized = _cameraController!.value.isInitialized;
    } catch (e) {
      print('Error checking camera initialization: $e');
      return;
    }

    if (!isInitialized) {
      return;
    }

    try {
      final accurateMode = _performanceMode == FaceDetectorMode.accurate;
      final result = await detectFace(
          accurateMode: accurateMode, accuracyConfig: _accuracyConfig?.toMap());

      if (result.detected) {
        faceLeft.value = result.left;
        faceTop.value = result.top;
        faceWidth.value = result.width;
        faceHeight.value = result.height;
        faceDetected.value = true;
        statusMessage.value = result.message ?? 'Face properly positioned';
      } else {
        faceLeft.value = result.left;
        faceTop.value = result.top;
        faceWidth.value = result.width;
        faceHeight.value = result.height;
        faceDetected.value = false;
        statusMessage.value = result.message ?? 'No face detected';
      }

      // Reset the auto capture flag when no face is detected
      if (!result.detected) {
        _autoCaptureDone = false;
      }
    } catch (e) {
      print('Face detection error: $e');
      // Don't update status message for camera errors to avoid UI flashing
      if (!e.toString().contains('after being disposed')) {
        statusMessage.value = 'Error: $e';
      }
    }
  }

  /// Capture image from camera
  static Future<String?> takePicture() async {
    if (!_isCapturing) {
      _isCapturing = true;
      try {
        // Verify camera is initialized
        if (_cameraController == null) {
          print('Cannot take picture: Camera controller is null');
          return null;
        }

        bool isInitialized = false;
        try {
          isInitialized = _cameraController!.value.isInitialized;
        } catch (e) {
          print('Error checking camera initialization before capture: $e');
          return null;
        }

        if (!isInitialized) {
          print('Cannot take picture: Camera is not initialized');
          return null;
        }

        final image = await _cameraController!.takePicture();
        return image.path;
      } catch (e) {
        print('Capture error: $e');
        return null;
      } finally {
        _isCapturing = false;
      }
    }
    return null;
  }

  /// Check if camera should auto-capture based on face detection and settings
  static bool shouldAutoCapture(bool autoCapture) {
    return faceDetected.value &&
        autoCapture &&
        !_isCapturing &&
        !_autoCaptureDone;
  }

  /// Mark that auto capture has been done
  static void markAutoCaptured() {
    _autoCaptureDone = true;
  }

  /// Switch between front and back cameras
  static Future<void> switchCamera() async {
    if (_cameras.length <= 1) return;

    try {
      // Cancel face detection timer while switching
      _faceDetectionTimer?.cancel();

      final currentCamera = _cameraController?.description;
      final newCamera = _cameras.firstWhere(
        (camera) => camera.lensDirection != currentCamera?.lensDirection,
        orElse: () => _cameras.first,
      );

      // Safely dispose the old controller
      if (_cameraController != null) {
        if (_cameraController!.value.isInitialized) {
          await _cameraController!.dispose();
        }
        _cameraController = null;
      }

      _cameraController = CameraController(
        newCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      // Restart face detection
      startFaceDetection();
    } catch (e) {
      print('Camera switch error: $e');
      // Don't throw, just log the error to prevent UI crashes
    }
  }

  /// Set performance mode for face detection
  static void setPerformanceMode(FaceDetectorMode mode) {
    _performanceMode = mode;
  }

  /// Set indicator shape for face detection
  static void setIndicatorShape(IndicatorShape shape) {
    _indicatorShape = shape;
  }

  /// Get current indicator shape
  static IndicatorShape getIndicatorShape() {
    return _indicatorShape;
  }

  /// Set image resolution for camera
  static void setImageResolution(ImageResolution resolution) {
    _imageResolution = resolution;

    // Apply resolution change if camera is initialized
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      // Save current camera
      final currentCamera = _cameraController!.description;

      try {
        // Map ImageResolution to ResolutionPreset
        ResolutionPreset preset = _mapResolutionToPreset(resolution);

        // Dispose old controller
        _faceDetectionTimer?.cancel();
        _cameraController!.dispose();

        // Create new controller with updated resolution
        _cameraController = CameraController(
          currentCamera,
          preset,
          enableAudio: false,
        );

        // Initialize and restart face detection
        _cameraController!.initialize().then((_) {
          startFaceDetection();
        });
      } catch (e) {
        print('Error updating resolution: $e');
      }
    }
  }

  /// Helper to map ImageResolution to ResolutionPreset
  static ResolutionPreset _mapResolutionToPreset(ImageResolution resolution) {
    switch (resolution) {
      case ImageResolution.low:
        return ResolutionPreset.low;
      case ImageResolution.medium:
        return ResolutionPreset.medium;
      case ImageResolution.high:
        return ResolutionPreset.high;
      case ImageResolution.veryHigh:
        return ResolutionPreset.veryHigh;
      default:
        return ResolutionPreset.medium;
    }
  }

  /// Get current image resolution
  static ImageResolution getImageResolution() {
    return _imageResolution;
  }

  /// Set default flash mode for camera
  static void setDefaultFlashMode(CameraFlashMode mode) {
    _defaultFlashMode = mode;

    // Map CameraFlashMode to FlashMode for the camera controller
    FlashMode flashMode = FlashMode.off;

    switch (mode) {
      case CameraFlashMode.off:
        flashMode = FlashMode.off;
        break;
      case CameraFlashMode.always: // Corrected from 'on' to 'always'
        flashMode = FlashMode.torch; // Use torch as 'always' in web
        break;
      case CameraFlashMode.auto:
        flashMode = FlashMode.auto;
        break;
      default:
        flashMode = FlashMode.off;
    }

    // Update flash mode if camera is initialized
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      _cameraController!.setFlashMode(flashMode).catchError((e) {
        print('Error setting flash mode: $e');
      });
    }
  }

  /// Get camera controller
  static CameraController? getCameraController() {
    return _cameraController;
  }

  /// Get camera aspect ratio
  static double? getAspectRatio() {
    return _cameraController?.value.aspectRatio;
  }

  /// Get camera flash mode
  static FlashMode? getFlashMode() {
    return _cameraController?.value.flashMode;
  }

  /// Set camera flash mode
  static Future<bool> setFlashMode(FlashMode mode) async {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        await _cameraController!.setFlashMode(mode);
        return true;
      } catch (e) {
        print('Flash mode not supported: $e');
        // If torch mode fails, set to off mode
        if (mode == FlashMode.torch) {
          try {
            await _cameraController!.setFlashMode(FlashMode.off);
          } catch (_) {
            // If even setting to off fails, just ignore
          }
        }
        return false;
      }
    }
    return false;
  }

  /// Get cameras list
  static List<CameraDescription> getCameras() {
    return _cameras;
  }

  /// Clean up resources
  static void dispose() {
    try {
      _faceDetectionTimer?.cancel();
      _faceDetectionTimer = null;

      if (_cameraController != null) {
        if (_cameraController!.value.isInitialized) {
          _cameraController!.dispose();
        }
        _cameraController = null;
      }

      // Clear detection state
      faceDetected.value = false;
      statusMessage.value = '';
      faceLeft.value = null;
      faceTop.value = null;
      faceWidth.value = null;
      faceHeight.value = null;

      // Keep the cameras list and initialized flag
      // as we may need them for the next initialization
    } catch (e) {
      print('Error during camera disposal: $e');
    }
  }
}
