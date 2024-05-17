import 'dart:developer';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/ensemble_widget.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/stub/location_manager.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:flutter/cupertino.dart';

/// non-interactive Google Map as an image
class StaticMap extends EnsembleWidget<StaticMapController> {
  static const type = 'StaticMap';

  const StaticMap._(super.controller, {super.key});

  factory StaticMap.build(dynamic controller) => StaticMap._(
      controller is StaticMapController ? controller : StaticMapController());

  @override
  State<StatefulWidget> createState() => StaticMapState();
}

class StaticMapController extends EnsembleBoxController {
  int? mapWidth;
  int? mapHeight;
  LocationData? center;
  int? zoom;
  List<StaticMapMarker>? markers;

  @override
  Map<String, Function> setters() => Map<String, Function>.from(super.setters())
    ..addAll({
      'mapWidth': (value) => mapWidth = Utils.optionalInt(value, min: 0),
      'mapHeight': (value) => mapHeight = Utils.optionalInt(value, min: 0),
      'center': (value) => center = Utils.getLatLng(value),
      'zoom': (value) => zoom = Utils.optionalInt(value, min: 1, max: 22),
      'markers': (list) => markers = _getMarkers(list),
    });

  List<StaticMapMarker>? _getMarkers(dynamic input) {
    List<StaticMapMarker>? markers;
    if (input is List) {
      for (var item in input) {
        var marker = StaticMapMarker.fromMap(item);
        if (marker != null) {
          (markers ??= []).add(marker);
        }
      }
    }
    return markers;
  }
}

class StaticMapState extends EnsembleWidgetState<StaticMap> {
  static const defaultSize = 300;
  static const defaultZoom = 6;
  late final apiKey;

  @override
  void initState() {
    super.initState();
    apiKey = Ensemble().getAccount()?.googleMapsAPIKey;
    if (apiKey == null) {
      throw LanguageError("Google Maps API Key is required.");
    }
  }

  @override
  Widget buildWidget(BuildContext context) {
    String url = 'https://maps.googleapis.com/maps/api/staticmap' +
        '?key=$apiKey' +
        '&size=${widget.controller.mapWidth ?? defaultSize}x${widget.controller.mapHeight ?? defaultSize}';
    url += _addMapBounds(url);
    log(url);

    return Image.network(
      url,
      fit: BoxFit.cover,
    );
  }

  /// bound the Map either with markers or center/zoom
  String _addMapBounds(String url) {
    if (widget.controller.markers != null) {
      String str =
          "&markers=${widget.controller.markers!.map((e) => e.asString()).join(' ')}";
      if (widget.controller.zoom != null) {
        str += '&zoom=${widget.controller.zoom}';
      }
      return str;
    }
    // center is needed (together with zoom)
    else if (widget.controller.center != null) {
      return '&center=${_toLatLngString(widget.controller.center!)}&zoom=${widget.controller.zoom ?? defaultZoom}';
    } else {
      throw RuntimeError("Either 'markers' or 'center' is required.");
    }
  }

  /// return in format lat,lng
  String _toLatLngString(LocationData position) =>
      '${position.latitude},${position.longitude}';
}

class StaticMapMarker {
  StaticMapMarker({required this.location, this.size, this.color, this.label});

  String location;
  MapMarkerSize? size;
  Color? color;
  String? label;

  static StaticMapMarker? fromMap(dynamic input) {
    if (input is Map) {
      String? loc = Utils.optionalString(input['location'])?.trim();
      if (loc != null && loc.isNotEmpty) {
        return StaticMapMarker(
            location: loc,
            size: MapMarkerSize.values.from(input['size']),
            color: Utils.getColor(input['color']),
            label: Utils.optionalString(input['label']));
      }
    }
    return null;
  }

  /// return the marker conforming to Map's static API
  String asString() {
    String str = '';
    if (color != null) {
      str += 'color:${toGoogleMapsColor(color!)}|';
    }
    if (label != null && label!.isNotEmpty) {
      str += 'label:$label|';
    }
    return str + toGoogleLatLngOrAddress(location) + '|';
  }

  /// Static API can only do 6 digits 0xFFFFFF (no transparency)
  String toGoogleMapsColor(Color color) =>
      '0x${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';

  String toGoogleLatLngOrAddress(String location) {
    LocationData? latLng = Utils.getLatLng(location);
    if (latLng != null) {
      return '${latLng.latitude},${latLng.longitude}';
    }
    return location;
  }
}

enum MapMarkerSize { normal, small, xsmall }
