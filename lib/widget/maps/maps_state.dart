import 'dart:async';
import 'dart:developer';

import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/view/page.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/layout/templated.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/maps/maps.dart';
import 'package:ensemble/widget/maps/maps_overlay.dart';
import 'package:ensemble/widget/maps/maps_utils.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:yaml/yaml.dart';

import '../../framework/device.dart';

class MapsState extends WidgetState<Maps>
    with TemplatedWidgetState, LocationCapability {
  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();

  /// markers are required to have unique ID. We'll use the lat/lng
  /// and keep track of all unique IDs (ignore duplicate lat/lng)
  Set<MarkerId> uniqueMarkerIds = {};

  List<MarkerPayload> _markerPayloads = [];
  MarkerId? _selectedMarkerId;
  Widget? _overlayWidget;

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
    if (widget.controller.locationEnabled) {
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
      registerItemTemplate(context, widget.controller.markerItemTemplate!,
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

    MarkerItemTemplate? itemTemplate = widget.controller.markerItemTemplate;
    ScopeManager? myScope = DataScopeWidget.getScope(context);
    if (myScope != null && itemTemplate != null) {
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
    MarkerTemplate? markerTemplate = widget.controller.markerTemplate;
    MarkerTemplate? selectedMarkerTemplate =
        widget.controller.selectedMarkerTemplate;
    dynamic overlayTemplate = widget.controller.overlayTemplate;

    MarkerItemTemplate? itemTemplate = widget.controller.markerItemTemplate;
    if (itemTemplate == null) {
      throw LanguageError("markers is not set properly.");
    }

    bool foundSelectedMarker = false;
    uniqueMarkerIds.clear();
    for (int i = 0; i < markerPayloads.length; i++) {
      MarkerPayload markerPayload = markerPayloads[i];

      // ignore marker with duplicate Lat/Lng
      MarkerId markerId = MarkerId(markerPayload.latLng.hashCode.toString());
      if (!uniqueMarkerIds.contains(markerId)) {
        uniqueMarkerIds.add(markerId);

        // auto select the first one if needed
        if (_selectedMarkerId == null && widget.controller.autoSelect) {
          _selectedMarkerId = markerId;
        }

        BitmapDescriptor? markerAsset;
        if (markerId == _selectedMarkerId) {
          // selected marker
          foundSelectedMarker = true;
          markerAsset = await _buildMarkerFromTemplate(
              markerPayload, selectedMarkerTemplate ?? markerTemplate);

          if (overlayTemplate != null) {
            _overlayWidget = markerPayload.scopeManager
                .buildWidgetWithScopeFromDefinition(overlayTemplate);
          }
        } else {
          // regular marker
          markerAsset =
              await _buildMarkerFromTemplate(markerPayload, markerTemplate);
        }

        markerPayload.marker = Marker(
            markerId: markerId,
            position: markerPayload.latLng,
            icon: markerAsset ?? BitmapDescriptor.defaultMarker,
            consumeTapEvents: true,
            onTap: () {
              _selectMarker(markerId);

              // dispatch onMarkerTap
              if (itemTemplate.onMarkerTap != null) {
                ScreenController().executeAction(
                    context, itemTemplate.onMarkerTap!,
                    event: EnsembleEvent(widget, data: {
                      itemTemplate.name: markerPayload.scopeManager.dataContext
                          .getContextById(itemTemplate.name)
                    }));
              }
            });
      }
    }

    // markers are updated but we can't find a selected marker. This may
    // mean that marker is no longer there.
    if (_selectedMarkerId != null && !foundSelectedMarker) {
      _selectedMarkerId = null;
      if (widget.controller.autoSelect) {
        _selectNextMarker();
      }
    }

    setState(() {
      _markerPayloads = markerPayloads;
    });
  }

  void _selectMarker(MarkerId markerId) async {
    if (markerId != _selectedMarkerId) {
      // first reset the previously selected marker
      if (_selectedMarkerId != null) {
        MarkerPayload? previousSelectedMarker =
            _getMarkerPayloadById(_selectedMarkerId!);
        if (previousSelectedMarker != null) {
          BitmapDescriptor markerAsset = await _buildMarkerFromTemplate(
                  previousSelectedMarker, widget.controller.markerTemplate) ??
              BitmapDescriptor.defaultMarker;
          previousSelectedMarker.marker =
              previousSelectedMarker.marker?.copyWith(iconParam: markerAsset);
        }
      }

      // mark the markerId as selected
      _selectedMarkerId = markerId;
      MarkerPayload? newSelectedMarker =
          _getMarkerPayloadById(_selectedMarkerId!);
      if (newSelectedMarker != null) {
        // update marker
        BitmapDescriptor markerAsset = await _buildMarkerFromTemplate(
                newSelectedMarker,
                widget.controller.selectedMarkerTemplate ??
                    widget.controller.markerTemplate) ??
            BitmapDescriptor.defaultMarker;
        if (markerAsset != null) {
          newSelectedMarker.marker =
              newSelectedMarker.marker?.copyWith(iconParam: markerAsset);
        }

        // update overlay
        if (widget.controller.overlayTemplate != null) {
          _overlayWidget = newSelectedMarker.scopeManager
              .buildWidgetWithScopeFromDefinition(
                  widget.controller.overlayTemplate);
        }
      }

      // reload
      setState(() {});
    }
  }

  void _selectNextMarker() {
    if (_markerPayloads.length <= 1) {
      return;
    }

    MarkerPayload? nextMarker;
    if (_selectedMarkerId == null) {
      nextMarker = _markerPayloads[0];
    } else {
      int nextIndex = _markerPayloads.indexWhere((markerPayload) =>
              markerPayload.marker?.markerId == _selectedMarkerId) +
          1;
      if (nextIndex < _markerPayloads.length) {
        nextMarker = _markerPayloads[nextIndex];
      }
    }

    if (nextMarker != null && nextMarker.marker != null) {
      _selectMarker(nextMarker.marker!.markerId);
    }
  }

  void _selectPreviousMarker() {
    if (_markerPayloads.length <= 1) {
      return;
    }

    MarkerPayload? previousMarker;
    if (_selectedMarkerId == null) {
      previousMarker = _markerPayloads[_markerPayloads.length - 1];
    } else {
      int prevIndex = _markerPayloads.indexWhere((markerPayload) =>
              markerPayload.marker?.markerId == _selectedMarkerId) -
          1;
      if (prevIndex >= 0) {
        previousMarker = _markerPayloads[prevIndex];
      }
    }

    if (previousMarker != null && previousMarker.marker != null) {
      _selectMarker(previousMarker.marker!.markerId);
    }
  }

  MarkerPayload? _getMarkerPayloadById(MarkerId markerId) {
    for (MarkerPayload markerPayload in _markerPayloads) {
      if (markerPayload.marker?.markerId == markerId) {
        return markerPayload;
      }
    }
    return null;
  }

  Future<BitmapDescriptor?> _buildMarkerFromTemplate(
      MarkerPayload markerPayload, MarkerTemplate? template) async {
    if (template != null) {
      if (template.source != null) {
        String? source =
            markerPayload.scopeManager.dataContext.eval(template.source!);
        if (source != null) {
          return await MapsUtils.fromAsset(template.source!);
        }
      }
      // TODO: from icon/widget
    }
    return null;
  }

  @override
  Widget buildWidget(BuildContext context) {
    return Stack(children: [
      GoogleMap(
        onMapCreated: (controller) => _controller.complete(controller),
        myLocationEnabled: widget.controller.locationEnabled,
        mapType: widget.controller.mapType ?? MapType.normal,
        myLocationButtonEnabled: false,
        mapToolbarEnabled: true,
        initialCameraPosition: CameraPosition(
            target:
                initialCameraLatLng ?? widget.controller.defaultCameraLatLng,
            zoom: initialCameraZoom?.toDouble() ?? 10),
        markers: _getMarkers(),
      ),
      _overlayWidget != null && _selectedMarkerId != null
          ? MapsOverlay(
              _overlayWidget!,
              scrollable: widget.controller.scrollableOverlay,
              onScrolled: (isNext) =>
                  isNext ? _selectNextMarker() : _selectPreviousMarker(),
            )
          : const SizedBox.shrink()
    ]);
  }

  Set<Marker> _getMarkers() {
    Set<Marker> markers = {};
    for (MarkerPayload markerPayload in _markerPayloads) {
      if (markerPayload.marker != null) {
        markers.add(markerPayload.marker!);
      }
    }
    return markers;
  }
}

class MarkerPayload {
  MarkerPayload({required this.scopeManager, required this.latLng});

  final ScopeManager scopeManager;
  final LatLng latLng;
  Marker? marker;
}
