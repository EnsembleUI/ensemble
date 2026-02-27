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
