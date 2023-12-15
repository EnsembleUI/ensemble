import 'package:ensemble/widget/maps/maps_state.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// expose actions
mixin MapActions on MapsActionableState {
  /// zoom to fit all markers. If location is enabled and
  /// includeLocationInAutoZoom is true, then also fit the location in the bound.
  void zoomToFit() {
    List<LatLng> points = [];

    // add user location
    Position? currentLocation = getCurrentLocation();
    if (currentLocation != null &&
        widget.controller.includeCurrentLocationInAutoZoom) {
      points.add(LatLng(currentLocation.latitude, currentLocation.longitude));
    }

    for (var payload in getMarkerPayloads()) {
      points.add(payload.latLng);
    }

    zoom(points, hasCurrentLocation: currentLocation != null);
  }

  void moveCamera(LatLng target, {int? zoom}) {
    getMapController().then((controller) async => controller.animateCamera(
        CameraUpdate.newCameraPosition(CameraPosition(
            target: target,
            zoom: zoom?.toDouble() ?? await controller.getZoomLevel()))));
  }

  void moveCameraBounds(LatLng southwest, LatLng northeast, {int? padding}) {
    getMapController().then((controller) => controller.animateCamera(
        CameraUpdate.newLatLngBounds(
            LatLngBounds(southwest: southwest, northeast: northeast),
            padding?.toDouble() ?? 50)));
  }
}
