import 'package:ensemble/framework/device.dart';
import 'package:ensemble/framework/stub/location_manager.dart';
import 'package:geolocator/geolocator.dart';

class LocationManagerImpl extends LocationManager {
  @override
  Future<DeviceLocation> getLocation() async {
    LocationData? locationCoordinate;
    LocationStatus status = await getLocationStatus();
    if (status == LocationStatus.ready) {
      final position = await simplyGetLocation();
      locationCoordinate = LocationData(
          latitude: position.latitude, longitude: position.longitude);
    }
    return DeviceLocation(status: status, location: locationCoordinate);
  }

  @override
  Future<LocationStatus> getLocationStatus() async {
    if (await Geolocator.isLocationServiceEnabled()) {
      LocationPermission permission = await Geolocator.checkPermission();
      // ask for permission if not already
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (![LocationPermission.denied, LocationPermission.deniedForever]
          .contains(permission)) {
        return LocationStatus.ready;
      } else {
        return LocationStatus.denied;
      }
    }
    return LocationStatus.disabled;
  }

  @override
  Future<LocationData> simplyGetLocation() async {
    final lastLocation = await Geolocator.getCurrentPosition();
    final locationCoordinate = LocationData(
        latitude: lastLocation.latitude, longitude: lastLocation.longitude);
    return locationCoordinate;
  }

  @override
  Stream<LocationData> getPositionStream({int? distanceFilter}) {
    return Geolocator.getPositionStream(
            locationSettings: LocationSettings(
                accuracy: LocationAccuracy.high,
                distanceFilter: distanceFilter ?? 1000))
        .map((position) => LocationData(
            latitude: position.latitude, longitude: position.longitude));
  }

  @override
  double distanceBetween(
      double startLat, double startLng, double endLat, double endLng) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  @override
  Future<LocationPermissionStatus> checkPermission() async {
    final permission = await Geolocator.checkPermission();
    return LocationPermissionStatus.values
        .firstWhere((element) => element.name == permission.name);
  }
}
