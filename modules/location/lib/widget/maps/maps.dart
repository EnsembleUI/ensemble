import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/device.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/stub/location_manager.dart';
import 'package:ensemble/model/item_template.dart';
import 'package:ensemble/module/location_module.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_location/widget/maps/map_actions.dart';
import 'package:ensemble_location/widget/maps/maps_state.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class EnsembleMapWidget extends StatefulWidget
    with Invokable, HasController<MyController, EnsembleMapState>
    implements EnsembleMap {
  static const type = 'Map';

  EnsembleMapWidget({Key? key}) : super(key: key);

  @override
  EnsembleMapState createState() => EnsembleMapState();

  final MyController _controller = MyController();

  @override
  MyController get controller => _controller;

  @override
  List<String> passthroughSetters() => ['markers'];

  @override
  Map<String, Function> setters() {
    return {
      'width': (value) => _controller.width = Utils.optionalInt(value),
      'height': (value) => _controller.height = Utils.optionalInt(value),
      'markerOverlayMaxWidth': (value) => _controller.markerOverlayMaxWidth =
          Utils.getInt(value, fallback: _controller.markerOverlayMaxWidth),
      'markerOverlayMaxHeight': (value) => _controller.markerOverlayMaxHeight =
          Utils.getInt(value, fallback: _controller.markerOverlayMaxHeight),
      'initialCameraPosition': (value) =>
          _controller.initialCameraPosition = Utils.getLatLng(value),
      'initialCameraZoom': (value) =>
          _controller.initialCameraZoom = Utils.optionalInt(value, min: 0),
      'autoZoom': (value) => _controller.autoZoom =
          Utils.getBool(value, fallback: _controller.autoZoom),
      'autoZoomPadding': (value) =>
          _controller.autoZoomPadding = Utils.optionalInt(value),
      'locationEnabled': (value) => _controller.locationEnabled =
          Utils.getBool(value, fallback: _controller.locationEnabled),
      'includeCurrentLocationInAutoZoom': (value) =>
          _controller.includeCurrentLocationInAutoZoom = Utils.getBool(value,
              fallback: _controller.includeCurrentLocationInAutoZoom),

      'rotateEnabled': (value) => _controller.rotateEnabled =
          Utils.getBool(value, fallback: _controller.rotateEnabled),
      'scrollEnabled': (value) => _controller.scrollEnabled =
          Utils.getBool(value, fallback: _controller.scrollEnabled),
      'tiltEnabled': (value) => _controller.tiltEnabled =
          Utils.getBool(value, fallback: _controller.tiltEnabled),
      'zoomEnabled': (value) => _controller.zoomEnabled =
          Utils.getBool(value, fallback: _controller.zoomEnabled),

      // toolbar contains multiple controls
      'showToolbar': (value) => _controller.showToolbar =
          Utils.getBool(value, fallback: _controller.showToolbar),
      'showMapTypesButton': (value) => _controller.showMapTypesButton =
          Utils.getBool(value, fallback: _controller.showMapTypesButton),
      'showLocationButton': (value) => _controller.showLocationButton =
          Utils.getBool(value, fallback: _controller.showLocationButton),
      'showZoomButtons': (value) => _controller.showZoomButtons =
          Utils.getBool(value, fallback: _controller.showZoomButtons),
      'toolbarMargin': (value) => _controller.toolbarMargin =
          Utils.getInsets(value, fallback: _controller.toolbarMargin),
      'toolbarAlignment': (alignment) => _controller.toolbarAlignment =
          Utils.getAlignment(alignment) ?? _controller.toolbarAlignment,
      'toolbarTop': (value) =>
          _controller.toolbarTop = Utils.optionalInt(value, min: 0),
      'toolbarBottom': (value) =>
          _controller.toolbarBottom = Utils.optionalInt(value, min: 0),
      'toolbarLeft': (value) =>
          _controller.toolbarLeft = Utils.optionalInt(value, min: 0),
      'toolbarRight': (value) =>
          _controller.toolbarRight = Utils.optionalInt(value, min: 0),

      'mapType': (value) => _controller.mapType = value,
      'markers': (markerData) => setMarkers(markerData),
      'scrollableMarkerOverlay': (value) => _controller
              .scrollableMarkerOverlay =
          Utils.getBool(value, fallback: _controller.scrollableMarkerOverlay),
      'dismissibleMarkerOverlay': (value) => _controller
              .dismissibleMarkerOverlay =
          Utils.getBool(value, fallback: _controller.dismissibleMarkerOverlay),
      'autoSelect': (value) => _controller.autoSelect =
          Utils.getBool(value, fallback: _controller.autoSelect),
      'onMapCreated': (action) => _controller.onMapCreated =
          EnsembleAction.from(action, initiator: this),
      'onCameraMove': (action) => _controller.onCameraMove =
          EnsembleAction.from(action, initiator: this),
    };
  }

  void setMarkers(dynamic markerData) {
    if (markerData is Map) {
      dynamic data = markerData['data'];
      String? name = markerData['name'];
      String? latLng = markerData['location'];

      if (data != null && name != null && latLng != null) {
        _controller.markerItemTemplate = MarkerItemTemplate(
            data: data,
            name: name,
            latLng: latLng,
            template: MarkerTemplate.build(
                image: Utils.getMap(markerData['marker']?['image']),
                widget: markerData['marker']?['widget'],
                icon: Utils.getMap(markerData['marker']?['icon'])),
            selectedTemplate: MarkerTemplate.build(
                image: Utils.getMap(markerData['selectedMarker']?['image']),
                widget: markerData['selectedMarker']?['widget'],
                icon: Utils.getMap(markerData['selectedMarker']?['icon'])),
            overlayTemplate: markerData['overlayWidget'],
            onMarkerTap:
                EnsembleAction.from(markerData['onMarkerTap'], initiator: this),
            onMarkersUpdated: EnsembleAction.from(
                markerData['onMarkersUpdated'],
                initiator: this));
      }
    }
  }

  @override
  Map<String, Function> getters() {
    return {'currentBounds': () => controller.currentBounds};
  }

  @override
  Map<String, Function> methods() {
    return {
      'runAutoZoom': () => _controller.mapActions?.zoomToFit(),
      'moveCamera': (num lat, num lng, [int? zoom]) => _controller.mapActions
          ?.moveCamera(LatLng(lat.toDouble(), lng.toDouble()), zoom: zoom),
      'moveCameraBounds': (num southwestLat, num southwestLng, num northeastLat,
              northeastLng, [int? padding]) =>
          _controller.mapActions?.moveCameraBounds(
              LatLng(southwestLat.toDouble(), southwestLng.toDouble()),
              LatLng(northeastLat.toDouble(), northeastLng.toDouble()),
              padding: padding)
    };
  }
}

class MyController extends WidgetController with LocationCapability {
  MapActions? mapActions;

  // a size is required, either explicit or via parent
  int? height;
  int? width;

  // current map boundary exposed as setter
  // This will be set ever time the camera moves
  dynamic currentBounds;

  // overlay fill available horizontal space, so cap max width/height
  int markerOverlayMaxWidth = 500;
  int markerOverlayMaxHeight = 500;
  bool scrollableMarkerOverlay = false;
  bool dismissibleMarkerOverlay = true;

  final defaultCameraLatLng = const LatLng(37.773972, -122.431297);
  final double defaultCameraZoom = 10;
  LocationData? initialCameraPosition;
  int? initialCameraZoom;

  bool autoSelect = true;

  bool autoZoom = false;
  int? autoZoomPadding;
  bool locationEnabled = false;
  bool includeCurrentLocationInAutoZoom = true;

  bool rotateEnabled = true;
  bool scrollEnabled = true;
  bool tiltEnabled = true;
  bool zoomEnabled = true;

  // toolbar has multiple button options
  bool showToolbar = true;
  bool showMapTypesButton = true;
  bool showLocationButton = true;
  bool showZoomButtons = true; // applicable on Web only
  EdgeInsets toolbarMargin = const EdgeInsets.all(10);
  Alignment toolbarAlignment = Alignment.bottomRight;
  int? toolbarTop;
  int? toolbarBottom;
  int? toolbarLeft;
  int? toolbarRight;

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
      {required dynamic data,
      required String name,
      required dynamic
          template, // this is the marker image/widget, just piggyback on the name
      required this.latLng,
      this.selectedTemplate,
      this.overlayTemplate,
      this.onMarkerTap,
      this.onMarkersUpdated})
      : super(data, name, template);

  String latLng;

  // `template` and `selectedTemplate` can be one of multiple types
  MarkerTemplate? selectedTemplate;

  // widget only
  dynamic overlayTemplate;

  EnsembleAction? onMarkerTap;
  EnsembleAction? onMarkersUpdated;
}

/// a marker template and selectedTemplate can take in an image, an icon, or a custom widget
class MarkerTemplate {
  MarkerTemplate._({this.image, this.icon, this.widget});

  final Map<String, dynamic>? image;
  final Map<String, dynamic>? icon;
  final dynamic widget;

  static MarkerTemplate? build(
      {Map<String, dynamic>? image,
      Map<String, dynamic>? icon,
      dynamic widget}) {
    if (image != null || icon != null || widget != null) {
      return MarkerTemplate._(image: image, icon: icon, widget: widget);
    }
    return null;
  }
}
