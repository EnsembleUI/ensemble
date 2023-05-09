import 'dart:developer';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapsUtils {
  /// calculate a rectangular bound from a given list of LatLng points
  static LatLngBounds? calculateBounds(List<LatLng> points) {
    if (points.isNotEmpty) {
      double minLatitude = points[0].latitude,
          minLongitude = points[0].longitude,
          maxLatitude = points[0].latitude,
          maxLongitude = points[0].longitude;

      for (var i = 1; i < points.length; i++) {
        minLatitude = math.min(minLatitude, points[i].latitude);
        minLongitude = math.min(minLongitude, points[i].longitude);
        maxLatitude = math.max(maxLatitude, points[i].latitude);
        maxLongitude = math.max(maxLongitude, points[i].longitude);
      }
      return LatLngBounds(
          southwest: LatLng(minLatitude, minLongitude),
          northeast: LatLng(maxLatitude, maxLongitude));
    }
    return null;
  }

  // TODO: assets from local
  static Future<BitmapDescriptor?> fromAsset(String asset) async {
    Uint8List? bytes = await MapsUtils._getBytesFromUrl(asset);
    if (bytes != null) {
      return BitmapDescriptor.fromBytes(bytes);
    }
    return null;
  }

  static Future<Uint8List?> _getBytesFromUrl(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    log('Failed to load image from url: $url');
    return null;
  }
}
