/// Accuracy thresholds used by the web face-detection pipeline.
library accuracy_config;

/// Configuration values that tune face-detection quality checks.
class AccuracyConfig {
  /// Minimum detection confidence required for a face.
  final double detectionThreshold;

  /// Required overlap ratio between the face and target frame.
  final double intersectionRatioThreshold;

  /// Extra vertical frame allowance around the detected face.
  final double extraHeightFactor;

  /// Input image size used by the detector.
  final int inputSize;

  /// Required facial-landmark confidence ratio.
  final double landmarkRatio;

  /// Allowed margin around the frame.
  final double frameMargin;

  /// Maximum allowed head tilt angle.
  final double tiltAngleThreshold;

  /// Allowed horizontal offset from the frame center.
  final double horizontalCenterTolerance;

  /// Eye aspect ratio threshold used for quality checks.
  final double earThreshold;

  /// Minimum face width relative to the frame.
  final double minFaceWidthRatio;

  /// Maximum face width relative to the frame.
  final double maxFaceWidthRatio;

  /// Overall quality score required to pass.
  final double qualityPassThreshold;

  /// Lower yaw ratio threshold.
  final double yawLowerThreshold;

  /// Upper yaw ratio threshold.
  final double yawUpperThreshold;

  /// Creates accuracy settings for face detection.
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

  /// Converts this configuration to a JavaScript-friendly map.
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

  /// Creates accuracy settings from a map payload.
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
