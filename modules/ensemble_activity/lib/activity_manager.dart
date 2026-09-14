import 'dart:async';

import 'package:async/async.dart';
import 'package:ensemble/framework/stub/activity_manager.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';

class ActivityManagerImpl extends ActivityManager {
  // Subscriptions
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;
  StreamSubscription? _pedometerSubscription;

  // Controller
  StreamController<MotionData>? _motionController;
  bool _running = false;

  // Latest sensor values
  AccelerometerData? _latestAccelerometer;
  GyroscopeData? _latestGyroscope;
  MagnetometerData? _latestMagnetometer;
  PedometerData? _latestPedometer;

  // Pedometer state
  int? _stepsOnStart;
  int _stepsSinceStart = 0;
  String _pedestrianStatus = 'initializing';

  static const double stepLengthMeters = 0.75;

  // Permissions
  Future<bool> requestActivityPermission() async {
    final status = await Permission.activityRecognition.status;
    if (status.isGranted) return true;

    final result = await Permission.activityRecognition.request();
    return result.isGranted;
  }

  // Public API
  @override
  Stream<MotionData> startMotionStream({
    List<MotionSensorType>? sensors,
    Duration? updateInterval,
  }) {
    if (_running && _motionController != null) {
      return _motionController!.stream;
    }

    _running = true;

    final activeSensors = (sensors == null || sensors.isEmpty)
        ? MotionSensorType.values
        : sensors;

    print(
        'Starting motion stream with sensors: $activeSensors and updateInterval: $updateInterval');

    _motionController = StreamController<MotionData>.broadcast(
      onCancel: stopMotionStream,
    );

    _startSensors(activeSensors);

    return _motionController!.stream;
  }

  @override
  void stopMotionStream() {
    if (!_running) return;

    _running = false;

    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _magnetometerSubscription?.cancel();
    _pedometerSubscription?.cancel();

    _accelerometerSubscription = null;
    _gyroscopeSubscription = null;
    _magnetometerSubscription = null;
    _pedometerSubscription = null;

    _motionController?.close();
    _motionController = null;

    _resetState();
  }

  @override
  Future<MotionData?> getMotionData({
    List<MotionSensorType>? sensors,
  }) async {
    try {
      final stream = startMotionStream(sensors: sensors);
      final data = await stream.first;
      stopMotionStream();
      return data;
    } catch (_) {
      stopMotionStream();
      return null;
    }
  }

  void dispose() {
    stopMotionStream();
  }

  // Internal helpers
  void _resetState() {
    _latestAccelerometer = null;
    _latestGyroscope = null;
    _latestMagnetometer = null;
    _latestPedometer = null;

    _stepsOnStart = null;
    _stepsSinceStart = 0;
    _pedestrianStatus = 'initializing';
  }

  void _startSensors(List<MotionSensorType> sensors) async {
    if (sensors.contains(MotionSensorType.pedometer)) {
      final ok = await requestActivityPermission();
      if (!ok) {
        _motionController?.addError(
          Exception('Activity recognition permission denied'),
        );
        return;
      }
      _startPedometer();
    }

    if (sensors.contains(MotionSensorType.accelerometer)) {
      _accelerometerSubscription = accelerometerEvents.listen(_onAccelerometer);
    }

    if (sensors.contains(MotionSensorType.gyroscope)) {
      _gyroscopeSubscription = gyroscopeEvents.listen(_onGyroscope);
    }

    if (sensors.contains(MotionSensorType.magnetometer)) {
      _magnetometerSubscription = magnetometerEvents.listen(_onMagnetometer);
    }
  }

  // Sensor handlers
  void _onAccelerometer(AccelerometerEvent event) {
    if (!_running) return;

    _latestAccelerometer = AccelerometerData(
      x: event.x,
      y: event.y,
      z: event.z,
    );

    _emit();
  }

  void _onGyroscope(GyroscopeEvent event) {
    if (!_running) return;

    _latestGyroscope = GyroscopeData(
      x: event.x,
      y: event.y,
      z: event.z,
    );

    _emit();
  }

  void _onMagnetometer(MagnetometerEvent event) {
    if (!_running) return;

    _latestMagnetometer = MagnetometerData(
      x: event.x,
      y: event.y,
      z: event.z,
    );

    _emit();
  }

  void _startPedometer() {
    _stepsOnStart = null;
    _stepsSinceStart = 0;
    _pedestrianStatus = 'initializing';

    _latestPedometer = PedometerData(
      steps: 0,
      stepsOnStart: 0,
      distanceMeters: 0,
      status: 'initializing',
    );

    _pedometerSubscription = StreamGroup.merge([
      Pedometer.stepCountStream.map((event) {
        _stepsOnStart ??= event.steps;
        _stepsSinceStart = event.steps - (_stepsOnStart ?? event.steps);
      }),
      Pedometer.pedestrianStatusStream.map((event) {
        _pedestrianStatus = event.status;
      }),
    ]).listen((_) {
      if (!_running) return;

      _latestPedometer = PedometerData(
        steps: _stepsSinceStart,
        stepsOnStart: _stepsOnStart ?? 0,
        distanceMeters: _stepsSinceStart * stepLengthMeters,
        status: _pedestrianStatus,
      );

      _emit();
    });
  }

  void _emit() {
    if (!_running || _motionController == null) return;

    if (_latestAccelerometer == null &&
        _latestGyroscope == null &&
        _latestMagnetometer == null &&
        _latestPedometer == null) {
      return;
    }

    _motionController!.add(
      MotionData(
        accelerometer: _latestAccelerometer,
        gyroscope: _latestGyroscope,
        magnetometer: _latestMagnetometer,
        pedometer: _latestPedometer,
        timestamp: DateTime.now(),
      ),
    );
  }
}
