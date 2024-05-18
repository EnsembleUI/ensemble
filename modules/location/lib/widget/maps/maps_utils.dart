import 'dart:developer';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:ensemble/framework/stub/location_manager.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
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

  static Future<BitmapDescriptor?> fromAsset(BuildContext context, String asset,
      {int? resizedWidth, int? resizedHeight}) async {
    /// assets load from URL uses actual pixels, which may appear smaller
    /// for device with high device pixel ratio.
    if (Utils.isUrl(asset)) {
      try {
        // use cache manager
        final File file = await DefaultCacheManager().getSingleFile(asset);
        final Uint8List imageBytes = await file.readAsBytes();

        if (!kIsWeb) {
          return _resizeImageWithDeviceRatio(
              imageBytes, MediaQuery.of(context).devicePixelRatio,
              resizedWidth: resizedWidth, resizedHeight: resizedHeight);
        } else {
          // Web uses ratio 1.0, nothing to do here
          return BitmapDescriptor.fromBytes(imageBytes);
        }
      } catch (e) {
        // do nothing
      }
    }

    /// local asset already handle device pixels natively
    else {
      return BitmapDescriptor.fromAssetImage(
          ImageConfiguration.empty, Utils.getLocalAssetFullPath(asset));
    }
    return null;
  }

  /// Images via URL uses actual pixels. We need to convert to device pixels
  static Future<BitmapDescriptor?> _resizeImageWithDeviceRatio(
      Uint8List imageBytes, double devicePixelRatio,
      {int? resizedWidth, int? resizedHeight}) async {
    final Codec imageCodec = await instantiateImageCodecWithSize(
        await ImmutableBuffer.fromUint8List(imageBytes),
        getTargetSize: (intrinsicWidth, intrinsicHeight) {
      if (resizedWidth != null || resizedHeight != null) {
        return TargetImageSize(
            width: resizedWidth != null ? (resizedWidth * devicePixelRatio).toInt() : null,
            height: resizedHeight != null ? (resizedHeight * devicePixelRatio).toInt() : null);
      }
      return TargetImageSize(
          width: (intrinsicWidth * devicePixelRatio).toInt());
    });

    final FrameInfo frameInfo = await imageCodec.getNextFrame();
    final ByteData? byteData = await frameInfo.image.toByteData(
      format: ImageByteFormat.png,
    );
    if (byteData != null) {
      final Uint8List resizedImageBytes = byteData.buffer.asUint8List();
      return BitmapDescriptor.fromBytes(resizedImageBytes);
    }
  }

  static Future<Uint8List?> _getBytesFromUrl(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    log('Failed to load image from url: $url');
    return null;
  }

  static LatLng? fromPosition(LocationData? position) {
    if (position != null) {
      return LatLng(position.latitude, position.longitude);
    }
    return null;
  }
}
