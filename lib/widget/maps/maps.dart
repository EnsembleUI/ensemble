import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/device.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/maps/maps_state.dart';
import 'package:flutter/material.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:yaml/yaml.dart';

class Maps extends StatefulWidget
    with Invokable, HasController<MyController, MapsState> {
  static const type = 'Maps';
  Maps({Key? key}) : super(key: key);

  @override
  MapsState createState() => MapsState();

  final MyController _controller = MyController();
  @override
  MyController get controller => _controller;

  @override
  Map<String, Function> setters() {
    return {
      'width': (value) => _controller.width = Utils.optionalInt(value),
      'height': (value) => _controller.height = Utils.optionalInt(value),
      'initialCameraPosition': (cameraPosition) =>
          _controller.initialCameraPosition = cameraPosition,
      'autoZoom': (value) => _controller.autoZoom = Utils.optionalBool(value),
      'autoZoomPadding': (value) =>
          _controller.autoZoomPadding = Utils.optionalInt(value),
      'locationEnabled': (value) => _controller.locationEnabled =
          Utils.getBool(value, fallback: _controller.locationEnabled),
      'includeCurrentLocationInAutoZoom': (value) => _controller
          .includeCurrentLocationInAutoZoom = Utils.optionalBool(value),
      'mapType': (value) => _controller.mapType = value,
      'markers': (markerData) => setMarkers(markerData),
      'scrollableOverlay': (value) => _controller.scrollableOverlay =
          Utils.getBool(value, fallback: _controller.scrollableOverlay),
      'autoSelect': (value) => _controller.autoSelect =
          Utils.getBool(value, fallback: _controller.autoSelect),
      'onCameraMove': (action) => _controller.onCameraMove =
          EnsembleAction.fromYaml(action, initiator: this),
    };
  }

  void setMarkers(dynamic markerData) {
    if (markerData is YamlMap) {
      String? data = markerData['data'];
      String? name = markerData['name'];

      String? lat = markerData['location']?['lat'];
      String? lng = markerData['location']?['lng'];

      if (data != null && name != null && lat != null && lng != null) {
        _controller.markerItemTemplate = MarkerItemTemplate(
            data: data,
            name: name,
            lat: lat,
            lng: lng,
            template: MarkerTemplate.build(
                source: markerData['marker']?['source'],
                widget: markerData['marker']?['widget']),
            selectedTemplate: MarkerTemplate.build(
                source: markerData['selectedMarker']?['source'],
                widget: markerData['selectedMarker']?['widget']),
            overlayTemplate: markerData['overlayWidget'],
            onMarkerTap: EnsembleAction.fromYaml(markerData['onMarkerTap'],
                initiator: this));
      }
    }
  }

  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> methods() {
    return {};
  }
}

class MyController extends WidgetController with LocationCapability {
  // a size is required, either explicit or via parent
  int? height;
  int? width;

  final defaultCameraLatLng = const LatLng(37.773972, -122.431297);
  dynamic initialCameraPosition;

  bool scrollableOverlay = false;
  bool autoSelect = true;

  bool? autoZoom;
  int? autoZoomPadding;
  bool locationEnabled = false;
  bool? includeCurrentLocationInAutoZoom;

  EnsembleAction? onCameraMove;

  MapType? _mapType;
  MapType? get mapType => _mapType;
  set mapType(dynamic input) {
    _mapType = MapType.values.from(input);
    if (_mapType == MapType.none) {
      _mapType = null;
    }
  }

  MarkerItemTemplate? markerItemTemplate;

  MarkerTemplate? get markerTemplate {
    return markerItemTemplate?.template;
  }

  MarkerTemplate? get selectedMarkerTemplate {
    return markerItemTemplate?.selectedTemplate;
  }

  dynamic get overlayTemplate {
    return markerItemTemplate?.overlayTemplate;
  }
}

class MarkerItemTemplate extends ItemTemplate {
  MarkerItemTemplate(
      {required String data,
      required String name,
      required dynamic
          template, // this is the marker image/widget, just piggyback on the name
      required this.lat,
      required this.lng,
      this.selectedTemplate,
      this.overlayTemplate,
      this.onMarkerTap})
      : super(data, name, template);

  String lat;
  String lng;

  // `template` and `selectedTemplate` can be one of multiple types
  MarkerTemplate? selectedTemplate;

  // widget only
  dynamic overlayTemplate;

  EnsembleAction? onMarkerTap;
}

/// a marker template and selectedTemplate can take in an image, an icon, or a custom widget
class MarkerTemplate {
  MarkerTemplate._({this.source, this.icon, this.widget});
  final String? source;
  final String? icon;
  final String? widget;

  static MarkerTemplate? build({String? source, String? icon, String? widget}) {
    if (source != null || icon != null || widget != null) {
      return MarkerTemplate._(source: source, icon: icon, widget: widget);
    }
    return null;
  }
}
