import 'package:ensemble/framework/device.dart';
import 'package:ensemble/framework/error_handling.dart';

abstract class LocationManager {
  Future<DeviceLocation> getLocation();
  Future<LocationStatus> getLocationStatus();
  Future<LocationData> simplyGetLocation();
  Stream<LocationData> getPositionStream({int? distanceFilter});
  double distanceBetween(
      double startLat, double startLng, double endLat, double endLng);
  Future<LocationPermissionStatus> checkPermission();
}

class LocationManagerStub extends LocationManager {
  @override
  Future<DeviceLocation> getLocation() {
    throw ConfigError(
        "Location Manager is not enabled. Please review the Ensemble documentation.");
  }

  @override
  Future<LocationStatus> getLocationStatus() {
    throw ConfigError(
        "Location Manager is not enabled. Please review the Ensemble documentation.");
  }

  @override
  Future<LocationData> simplyGetLocation() {
    throw ConfigError(
        "Location Manager is not enabled. Please review the Ensemble documentation.");
  }

  @override
  Stream<LocationData> getPositionStream({int? distanceFilter}) {
    throw ConfigError(
        "Location Manager is not enabled. Please review the Ensemble documentation.");
  }

  @override
  double distanceBetween(
      double startLat, double startLng, double endLat, double endLng) {
    throw ConfigError(
        "Location Manager is not enabled. Please review the Ensemble documentation.");
  }

  @override
  Future<LocationPermissionStatus> checkPermission() {
    throw ConfigError(
        "Location Manager is not enabled. Please review the Ensemble documentation.");
  }
}

class LocationData {
  LocationData({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

enum LocationPermissionStatus {
  denied,
  deniedForever,
  whileInUse,
  always,
  unableToDetermine,
}
