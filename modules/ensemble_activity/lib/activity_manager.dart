import 'dart:async';
import 'package:ensemble/framework/stub/activity_manager.dart';
import 'package:sensors_plus/sensors_plus.dart';

class ActivityManagerImpl extends ActivityManager {
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;

  final StreamController<MotionData> _motionController =
      StreamController<MotionData>.broadcast();

  // Track latest readings from each sensor for combining when sensorType is 'all'
  AccelerometerData? _latestAccelerometer;
  GyroscopeData? _latestGyroscope;
  MagnetometerData? _latestMagnetometer;

  @override
  Stream<MotionData> startMotionStream({
    MotionSensorType? sensorType,
    Duration? updateInterval,
  }) {
    final sensor = sensorType ?? MotionSensorType.all;

    // Reset latest readings when starting a new stream
    if (sensor == MotionSensorType.all) {
      _latestAccelerometer = null;
      _latestGyroscope = null;
      _latestMagnetometer = null;
    }

    if (sensor == MotionSensorType.accelerometer ||
        sensor == MotionSensorType.all) {
      _accelerometerSubscription = accelerometerEvents.listen(
        (AccelerometerEvent event) {
          final accelerometerData = AccelerometerData(
            x: event.x,
            y: event.y,
            z: event.z,
          );

          if (sensor == MotionSensorType.all) {
            // Store latest accelerometer reading
            _latestAccelerometer = accelerometerData;
            // Emit combined data with all available sensors
            _emitCombinedMotionData();
          } else {
            // Emit single sensor data
            final data = MotionData(
              accelerometer: accelerometerData,
              timestamp: DateTime.now(),
            );
            _motionController.add(data);
          }
        },
        onError: (error) {
          _motionController.addError(error);
        },
      );
    }

    if (sensor == MotionSensorType.gyroscope ||
        sensor == MotionSensorType.all) {
      _gyroscopeSubscription = gyroscopeEvents.listen(
        (GyroscopeEvent event) {
          final gyroscopeData = GyroscopeData(
            x: event.x,
            y: event.y,
            z: event.z,
          );

          if (sensor == MotionSensorType.all) {
            // Store latest gyroscope reading
            _latestGyroscope = gyroscopeData;
            // Emit combined data with all available sensors
            _emitCombinedMotionData();
          } else {
            // Emit single sensor data
            final data = MotionData(
              gyroscope: gyroscopeData,
              timestamp: DateTime.now(),
            );
            _motionController.add(data);
          }
        },
        onError: (error) {
          _motionController.addError(error);
        },
      );
    }

    if (sensor == MotionSensorType.magnetometer ||
        sensor == MotionSensorType.all) {
      _magnetometerSubscription = magnetometerEvents.listen(
        (MagnetometerEvent event) {
          final magnetometerData = MagnetometerData(
            x: event.x,
            y: event.y,
            z: event.z,
          );

          if (sensor == MotionSensorType.all) {
            // Store latest magnetometer reading
            _latestMagnetometer = magnetometerData;
            // Emit combined data with all available sensors
            _emitCombinedMotionData();
          } else {
            // Emit single sensor data
            final data = MotionData(
              magnetometer: magnetometerData,
              timestamp: DateTime.now(),
            );
            _motionController.add(data);
          }
        },
        onError: (error) {
          _motionController.addError(error);
        },
      );
    }

    return _motionController.stream;
  }

  void _emitCombinedMotionData() {
    // Only emit if we have at least one sensor reading
    // This ensures we don't emit empty data initially
    if (_latestAccelerometer != null ||
        _latestGyroscope != null ||
        _latestMagnetometer != null) {
      final data = MotionData(
        accelerometer: _latestAccelerometer,
        gyroscope: _latestGyroscope,
        magnetometer: _latestMagnetometer,
        timestamp: DateTime.now(),
      );
      _motionController.add(data);
    }
  }

  @override
  void stopMotionStream() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _gyroscopeSubscription?.cancel();
    _gyroscopeSubscription = null;
    _magnetometerSubscription?.cancel();
    _magnetometerSubscription = null;
    // Clear latest readings when stopping
    _latestAccelerometer = null;
    _latestGyroscope = null;
    _latestMagnetometer = null;
  }

  @override
  Future<MotionData?> getMotionData({MotionSensorType? sensorType}) async {
    try {
      final sensor = sensorType ?? MotionSensorType.accelerometer;
      final stream = startMotionStream(sensorType: sensor);
      final data = await stream.first.timeout(const Duration(seconds: 2));
      stopMotionStream();
      return data;
    } catch (e) {
      stopMotionStream();
      return null;
    }
  }

  void dispose() {
    stopMotionStream();
    _motionController.close();
  }
}
