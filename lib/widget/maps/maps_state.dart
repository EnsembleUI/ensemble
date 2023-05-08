import 'dart:async';
import 'dart:developer';

import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/view/page.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/layout/templated.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/maps/maps.dart';
import 'package:ensemble/widget/maps/maps_overlay.dart';
import 'package:ensemble/widget/maps/maps_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:yaml/yaml.dart';

import '../../framework/device.dart';

class MapsState extends WidgetState<Maps>
    with TemplatedWidgetState, LocationCapability {
  Completer<GoogleMapController> _controller = Completer<GoogleMapController>();
  Set<Marker> _markers = {};
  Widget? overlayWidget;

  /// markers are required to have unique ID. We'll use the lat/lng
  /// and keep track of all unique IDs (ignore duplicate lat/lng)
  MarkerId? _selectedMarker;
  Set<MarkerId> uniqueMarkerIds = {};

  // misc
  Position? currentLocation;
  LatLng? initialCameraLatLng;
  int? initialCameraZoom;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _getCurrentLocation();
    _initInitialCameraPosition(context);
    _registerMarkerListener(context);
  }

  void _getCurrentLocation() async {
    if (widget.controller.locationEnabled == true) {
      currentLocation = (await getLocation()).location;
    }
  }

  void _initInitialCameraPosition(BuildContext context) {
    if (widget.controller.initialCameraPosition is YamlMap) {
      YamlMap initialCameraPosition =
          widget.controller.initialCameraPosition as YamlMap;
      double? lat = Utils.optionalDouble(initialCameraPosition['lat']);
      double? lng = Utils.optionalDouble(initialCameraPosition['lng']);
      if (lat != null && lng != null) {
        initialCameraLatLng = LatLng(lat, lng);
      }
      initialCameraZoom =
          Utils.optionalInt(initialCameraPosition['zoom'], min: 0);
    }
  }

  void _registerMarkerListener(BuildContext context) {
    if (widget.controller.markerItemTemplate != null) {
      registerItemTemplate(context, widget.controller.markerItemTemplate,
          evaluateInitialValue: true,
          onDataChanged: (dataList) => _updateMarkers(context, dataList));
    }
  }

  void _updateMarkers(BuildContext context, List dataList) async {
    List<MarkerPayload> markerPayloads =
        _buildMarkerPayloads(context, dataList);

    // we have the Lat/Lng of each marker, zoom map to fit
    _runAutoZoom(markerPayloads.map((e) => e.latLng).toList());

    // now build the actual markers
    _buildMarkers(markerPayloads);
  }

  void _runAutoZoom(List<LatLng> locations) async {
    if (widget.controller.autoZoom != false) {
      List<LatLng> points = locations.toList(growable: true);
      if (currentLocation != null &&
          widget.controller.includeCurrentLocationInAutoZoom != false) {
        points
            .add(LatLng(currentLocation!.latitude, currentLocation!.longitude));
      }
      LatLngBounds? bound = MapsUtils.calculateBounds(points);
      if (bound != null) {
        CameraUpdate cameraUpdate = CameraUpdate.newLatLngBounds(
            bound, widget.controller.autoZoomPadding?.toDouble() ?? 50);
        _controller.future
            .then((controller) => controller.animateCamera(cameraUpdate));
      }
    }
  }

  /// from the list of marker data, build a list of marker payloads. These
  /// payloads are quick and sufficient to draw a Map boundary.
  List<MarkerPayload> _buildMarkerPayloads(
      BuildContext context, List dataList) {
    List<MarkerPayload> markerPayloads = [];

    MarkerItemTemplate itemTemplate = widget.controller.markerItemTemplate;
    ScopeManager? myScope = DataScopeWidget.getScope(context);
    if (myScope != null) {
      for (dynamic dataItem in dataList) {
        ScopeManager dataScope = myScope.createChildScope();
        dataScope.dataContext.addDataContextById(itemTemplate.name, dataItem);

        // eval lat/lng
        double? lat =
            Utils.optionalDouble(dataScope.dataContext.eval(itemTemplate.lat));
        double? lng =
            Utils.optionalDouble(dataScope.dataContext.eval(itemTemplate.lng));
        if (lat != null && lng != null) {
          markerPayloads.add(
              MarkerPayload(scopeManager: dataScope, latLng: LatLng(lat, lng)));
        }
      }
    }
    return markerPayloads;
  }

  void _buildMarkers(List<MarkerPayload> markerPayloads) async {
    MarkerItemTemplate itemTemplate = widget.controller.markerItemTemplate;
    if (itemTemplate.template is! MarkerTemplate) {
      throw LanguageError("Invalid marker template.");
    }
    MarkerTemplate markerTemplate = itemTemplate.template as MarkerTemplate;
    MarkerTemplate? selectedMarkerTemplate = itemTemplate.selectedTemplate;
    dynamic overlayTemplate = itemTemplate.overlayTemplate;
    Set<Marker> markers = {};
    uniqueMarkerIds.clear();

    for (int i = 0; i < markerPayloads.length; i++) {
      MarkerPayload markerPayload = markerPayloads[i];

      // ignore marker with duplicate Lat/Lng
      MarkerId markerId = MarkerId(markerPayload.latLng.hashCode.toString());
      if (!uniqueMarkerIds.contains(markerId)) {
        uniqueMarkerIds.add(markerId);

        BitmapDescriptor? markerAsset;

        // if selected, generate selected marker
        if (markerId == _selectedMarker && selectedMarkerTemplate != null) {
          markerAsset = await _buildMarkerFromTemplate(
              markerPayload.scopeManager, selectedMarkerTemplate);

          if (overlayTemplate != null) {
            overlayWidget = markerPayload.scopeManager
                .buildWidgetWithScopeFromDefinition(overlayTemplate);
          }
        }

        // generate the marker, don't override if already drawn as selected marker
        markerAsset ??= await _buildMarkerFromTemplate(
            markerPayload.scopeManager, markerTemplate);

        if (markerAsset != null) {
          markers.add(Marker(
              markerId: markerId,
              position: markerPayload.latLng,
              icon: markerAsset,
              consumeTapEvents: true,
              onTap: () => _selectMarker(markerId, markerPayload.scopeManager,
                  markerTemplate, selectedMarkerTemplate, overlayTemplate)));
        }
      }
    }

    setState(() {
      _markers = markers;
    });
  }

  void _selectMarker(
      MarkerId markerId,
      ScopeManager scopeManager,
      MarkerTemplate markerTemplate,
      MarkerTemplate? selectedMarkerTemplate,
      dynamic overlayTemplate) async {
    if (markerId != _selectedMarker) {
      // first reset the previously selected marker
      if (_selectedMarker != null) {
        Marker? previousSelectedMarker = _getMarkerById(_selectedMarker!);
        if (previousSelectedMarker != null) {
          BitmapDescriptor? markerAsset =
              await _buildMarkerFromTemplate(scopeManager, markerTemplate);
          if (markerAsset == null) {
            log('Unable to un-select an selected marker');
          } else {
            _markers.remove(previousSelectedMarker);
            _markers
                .add(previousSelectedMarker.copyWith(iconParam: markerAsset));
          }
        }
      }

      // mark the markerId as selected
      _selectedMarker = markerId;
      BitmapDescriptor? markerAsset = await _buildMarkerFromTemplate(
          scopeManager, selectedMarkerTemplate ?? markerTemplate);
      if (markerAsset != null) {
        Marker? newSelectedMarker = _getMarkerById(_selectedMarker!);
        if (newSelectedMarker != null) {
          _markers.remove(newSelectedMarker);
          _markers.add(newSelectedMarker.copyWith(iconParam: markerAsset));
        }
      }

      // update overlay widget
      if (overlayTemplate != null) {
        overlayWidget =
            scopeManager.buildWidgetWithScopeFromDefinition(overlayTemplate);
      }

      // reload
      setState(() {});
    }
  }

  void _selectNextMarker() {}
  void _selectPreviousMarker() {}

  Marker? _getMarkerById(MarkerId markerId) {
    for (Marker marker in _markers) {
      if (marker.markerId == markerId) {
        return marker;
      }
    }
    return null;
  }

  Future<BitmapDescriptor?> _buildMarkerFromTemplate(
      ScopeManager scopeManager, MarkerTemplate template) async {
    if (template.source != null) {
      String? source = scopeManager.dataContext.eval(template.source!);
      if (source != null) {
        return await MapsUtils.fromAsset(template.source!);
      }
    }
    // TODO: from icon/widget
    return null;
  }

  @override
  Widget buildWidget(BuildContext context) {
    return Stack(children: [
      GoogleMap(
        onMapCreated: (controller) => _controller.complete(controller),
        myLocationEnabled: widget.controller.locationEnabled == true,
        mapType: widget.controller.mapType ?? MapType.normal,
        initialCameraPosition: CameraPosition(
            target:
                initialCameraLatLng ?? widget.controller.defaultCameraLatLng,
            zoom: initialCameraZoom?.toDouble() ?? 10),
        markers: _markers,
      ),
      overlayWidget != null && _selectedMarker != null
          ? MapsOverlay(
              overlayWidget!,
              scrollable: widget.controller.scrollableOverlay,
              onScrolled: (isNext) =>
                  isNext ? _selectNextMarker() : _selectPreviousMarker(),
            )
          : const SizedBox.shrink()
    ]);
  }
}

class MarkerPayload {
  MarkerPayload({required this.scopeManager, required this.latLng});

  ScopeManager scopeManager;
  LatLng latLng;
}
