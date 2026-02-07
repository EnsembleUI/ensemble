import 'dart:async';
import 'package:ensemble/framework/error_handling.dart';

abstract class ActivityManager {
  // Motion sensor methods
  Stream<MotionData> startMotionStream({
    MotionSensorType? sensorType,
    Duration? updateInterval,
  });
  void stopMotionStream();
  Future<MotionData?> getMotionData({MotionSensorType? sensorType});
}

class ActivityManagerStub extends ActivityManager {
  @override
  Stream<MotionData> startMotionStream({
    MotionSensorType? sensorType,
    Duration? updateInterval,
  }) {
    throw ConfigError(
        "Activity Manager is not enabled. Please review the Ensemble documentation.");
  }

  @override
  void stopMotionStream() {
    throw ConfigError(
        "Activity Manager is not enabled. Please review the Ensemble documentation.");
  }

  @override
  Future<MotionData?> getMotionData({MotionSensorType? sensorType}) {
    throw ConfigError(
        "Activity Manager is not enabled. Please review the Ensemble documentation.");
  }
}

class MotionData {
  MotionData({
    this.accelerometer,
    this.gyroscope,
    this.magnetometer,
    this.pedometer,
    required this.timestamp,
  });

  final AccelerometerData? accelerometer;
  final GyroscopeData? gyroscope;
  final MagnetometerData? magnetometer;
  final PedometerData? pedometer;
  final DateTime timestamp;

  Map<String, dynamic> toJson() {
    return {
      'accelerometer': accelerometer?.toJson(),
      'gyroscope': gyroscope?.toJson(),
      'magnetometer': magnetometer?.toJson(),
      'pedometer': pedometer?.toJson(),
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class AccelerometerData {
  AccelerometerData({required this.x, required this.y, required this.z});

  final double x;
  final double y;
  final double z;

  Map<String, dynamic> toJson() {
    return {'x': x, 'y': y, 'z': z};
  }
}

class GyroscopeData {
  GyroscopeData({required this.x, required this.y, required this.z});

  final double x;
  final double y;
  final double z;

  Map<String, dynamic> toJson() {
    return {'x': x, 'y': y, 'z': z};
  }
}

class MagnetometerData {
  MagnetometerData({required this.x, required this.y, required this.z});

  final double x;
  final double y;
  final double z;

  Map<String, dynamic> toJson() {
    return {'x': x, 'y': y, 'z': z};
  }
}

class PedometerData {
  PedometerData(
      {required this.steps,
      required this.stepsOnStart,
      required this.distanceMeters,
      required this.status});

  final int steps;
  final int stepsOnStart;
  final double distanceMeters;
  final String status;

  Map<String, dynamic> toJson() {
    return {
      'steps': steps,
      'stepsOnStart': stepsOnStart,
      'distanceMeters': distanceMeters,
      'status': status
    };
  }
}

enum MotionSensorType {
  accelerometer,
  gyroscope,
  magnetometer,
  pedometer,
  all,
}
