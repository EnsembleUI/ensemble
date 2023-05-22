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
import 'package:ensemble/widget/maps/map_actions.dart';
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
      'markerOverlayMaxWidth': (value) => _controller.markerOverlayMaxWidth =
          Utils.getInt(value, fallback: _controller.markerOverlayMaxWidth),
      'markerOverlayMaxHeight': (value) => _controller.markerOverlayMaxHeight =
          Utils.getInt(value, fallback: _controller.markerOverlayMaxHeight),
      'initialCameraPosition': (cameraPosition) =>
          _controller.initialCameraPosition = cameraPosition,
      'autoZoom': (value) => _controller.autoZoom =
          Utils.getBool(value, fallback: _controller.autoZoom),
      'autoZoomPadding': (value) =>
          _controller.autoZoomPadding = Utils.optionalInt(value),
      'locationEnabled': (value) => _controller.locationEnabled =
          Utils.getBool(value, fallback: _controller.locationEnabled),
      'includeCurrentLocationInAutoZoom': (value) =>
          _controller.includeCurrentLocationInAutoZoom = Utils.getBool(value,
              fallback: _controller.includeCurrentLocationInAutoZoom),
      'mapType': (value) => _controller.mapType = value,
      'markers': (markerData) => setMarkers(markerData),
      'scrollableMarkerOverlay': (value) => _controller
              .scrollableMarkerOverlay =
          Utils.getBool(value, fallback: _controller.scrollableMarkerOverlay),
      'autoSelect': (value) => _controller.autoSelect =
          Utils.getBool(value, fallback: _controller.autoSelect),
      'onMapCreated': (action) => _controller.onMapCreated =
          EnsembleAction.fromYaml(action, initiator: this),
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
                initiator: this),
            onMarkersUpdated: EnsembleAction.fromYaml(
                markerData['onMarkersUpdated'],
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
    return {
      'runAutoZoom': () => _controller.mapActions?.zoomToFit(),
      'moveCamera': (num lat, num lng, [int? zoom]) => _controller.mapActions
          ?.moveCamera(LatLng(lat.toDouble(), lng.toDouble()), zoom: zoom)
    };
  }
}

class MyController extends WidgetController with LocationCapability {
  MapActions? mapActions;
  // a size is required, either explicit or via parent
  int? height;
  int? width;

  // overlay fill available horizontal space, so cap max width/height
  int markerOverlayMaxWidth = 500;
  int markerOverlayMaxHeight = 500;
  bool scrollableMarkerOverlay = false;

  final defaultCameraLatLng = const LatLng(37.773972, -122.431297);
  final double defaultCameraZoom = 10;
  dynamic initialCameraPosition;

  bool autoSelect = true;

  bool autoZoom = false;
  int? autoZoomPadding;
  bool locationEnabled = false;
  bool includeCurrentLocationInAutoZoom = true;

  EnsembleAction? onMapCreated;
  EnsembleAction? onMarkersUpdated;
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
      this.onMarkerTap,
      this.onMarkersUpdated})
      : super(data, name, template);

  String lat;
  String lng;

  // `template` and `selectedTemplate` can be one of multiple types
  MarkerTemplate? selectedTemplate;

  // widget only
  dynamic overlayTemplate;

  EnsembleAction? onMarkerTap;
  EnsembleAction? onMarkersUpdated;
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
