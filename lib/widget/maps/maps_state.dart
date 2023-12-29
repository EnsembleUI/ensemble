import 'dart:async';
import 'dart:developer';

import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/layout/templated.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/debouncer.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/maps/map_actions.dart';
import 'package:ensemble/widget/maps/maps.dart';
import 'package:ensemble/widget/maps/maps_overlay.dart';
import 'package:ensemble/widget/maps/maps_toolbar.dart';
import 'package:ensemble/widget/maps/maps_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../framework/device.dart';

abstract class MapsActionableState extends WidgetState<EnsembleMap> {
  List<MarkerPayload> getMarkerPayloads();

  Position? getCurrentLocation();

  Future<GoogleMapController> getMapController();

  void zoom(List<LatLng> points, {bool? hasCurrentLocation});
}

class EnsembleMapState extends MapsActionableState
    with TemplatedWidgetState, LocationCapability, MapActions {
  static const selectedMarkerZIndex = 100.0;

  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();

  @override
  Future<GoogleMapController> getMapController() => _controller.future;

  // reduce # of onCameraMove
  final _cameraMoveDebouncer = Debouncer(const Duration(milliseconds: 300));

  // Google Maps don't support current location on Web. Add our own
  BitmapDescriptor? currentLocationIcon;

  /// markers are required to have unique ID. We'll use the lat/lng
  /// and keep track of all unique IDs (ignore duplicate lat/lng)
  Set<MarkerId> uniqueMarkerIds = {};

  List<MarkerPayload> _markerPayloads = [];

  @override
  List<MarkerPayload> getMarkerPayloads() => _markerPayloads;

  MarkerId? _selectedMarkerId;
  Widget? _overlayWidget;

  Position? currentLocation;

  @override
  Position? getCurrentLocation() => currentLocation;

  // we use both geolocator to get the location and google maps to show
  // location marker on non-Web. Both of these request permission and can
  // clash if they run at the same time. So we first get the location, then
  // tell Google Maps it can now show its location.
  bool showLocationOnMap = false;

  @override
  void didUpdateWidget(covariant EnsembleMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.controller.mapActions = this;
  }

  @override
  void initState() {
    super.initState();
    _initCurrentLocation();
  }

  void _initCurrentLocation() {
    if (widget.controller.locationEnabled) {
      // add our own location icon on Web
      if (kIsWeb) {
        BitmapDescriptor.fromAssetImage(
                ImageConfiguration.empty, 'assets/images/map_location.png',
                package: 'ensemble')
            .then((asset) => currentLocationIcon = asset);
      }

      getLocation().then((device) {
        currentLocation = device.location;

        // we got the location here, now tell Google Maps it can show its location
        // marker so they don't both request permission at the same time
        setState(() {
          showLocationOnMap = true;
        });

        bool isAutoZoom = widget.controller.autoZoom &&
            widget.controller.includeCurrentLocationInAutoZoom;
        if (currentLocation != null &&
            (isAutoZoom || widget.controller.initialCameraPosition == null)) {
          zoomToFit();
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // anti-pattern. We are manipulating State from StatefulWidget
    widget.controller.mapActions = this;

    _registerMarkerListener(context);
  }

  void _registerMarkerListener(BuildContext context) {
    if (widget.controller.markerItemTemplate != null) {
      registerItemTemplate(context, widget.controller.markerItemTemplate!,
          evaluateInitialValue: true,
          onDataChanged: (dataList) => _updateMarkers(context, dataList));
    }
  }

  void _updateMarkers(BuildContext context, List dataList) {
    List<MarkerPayload> payloads = _buildMarkerPayloads(context, dataList);

    // we have the Lat/Lng of each marker, zoom map to fit
    if (widget.controller.autoZoom) {
      List<LatLng> points = payloads.map((e) => e.latLng).toList();
      if (currentLocation != null &&
          widget.controller.includeCurrentLocationInAutoZoom) {
        points
            .add(LatLng(currentLocation!.latitude, currentLocation!.longitude));
      }
      zoom(points);
    }

    // now build the actual markers
    _buildMarkers(payloads);
  }

  @override
  void zoom(List<LatLng> points, {bool? hasCurrentLocation}) {
    LatLngBounds? bound = MapsUtils.calculateBounds(points);
    if (bound != null) {
      CameraUpdate cameraUpdate;

      // if we only have 1 marker (also apply to just the current location),
      // simply move the camera with a reasonable zoom, as the LatLngBound
      // otherwise may zoom in all the way.
      if (points.length == 1) {
        cameraUpdate = CameraUpdate.newCameraPosition(CameraPosition(
            target: LatLng(points[0].latitude, points[0].longitude),
            zoom: widget.controller.initialCameraZoom?.toDouble() ??
                widget.controller.defaultCameraZoom));
      }
      // otherwise bound the markers and add some reasonable padding
      else {
        cameraUpdate = CameraUpdate.newLatLngBounds(
            bound, widget.controller.autoZoomPadding?.toDouble() ?? 50);
      }
      _controller.future
          .then((controller) => controller.animateCamera(cameraUpdate));
    }
  }

  /// from the list of marker data, build a list of marker payloads. These
  /// payloads are quick and sufficient to draw a Map boundary.
  List<MarkerPayload> _buildMarkerPayloads(
      BuildContext context, List dataList) {
    List<MarkerPayload> payloads = [];

    MarkerItemTemplate? itemTemplate = widget.controller.markerItemTemplate;
    ScopeManager? myScope = DataScopeWidget.getScope(context);
    if (myScope != null && itemTemplate != null) {
      for (dynamic dataItem in dataList) {
        ScopeManager dataScope = myScope.createChildScope();
        dataScope.dataContext.addDataContextById(itemTemplate.name, dataItem);

        // eval lat/lng
        LatLng? latLng =
            Utils.getLatLng(dataScope.dataContext.eval(itemTemplate.latLng));
        if (latLng != null) {
          payloads.add(MarkerPayload(scopeManager: dataScope, latLng: latLng));
        }
      }
    }
    return payloads;
  }

  void _buildMarkers(List<MarkerPayload> payloads) async {
    MarkerTemplate? markerTemplate = widget.controller.markerTemplate;
    MarkerTemplate? selectedMarkerTemplate =
        widget.controller.selectedMarkerTemplate;
    dynamic overlayTemplate = widget.controller.overlayTemplate;

    MarkerItemTemplate? itemTemplate = widget.controller.markerItemTemplate;
    if (itemTemplate == null) {
      throw LanguageError("markers is not set properly.");
    }

    bool? foundSelectedMarker;
    uniqueMarkerIds.clear();
    for (int i = 0; i < payloads.length; i++) {
      MarkerPayload markerPayload = payloads[i];

      // ignore marker with duplicate Lat/Lng
      MarkerId markerId = MarkerId(markerPayload.latLng.hashCode.toString());
      if (!uniqueMarkerIds.contains(markerId)) {
        uniqueMarkerIds.add(markerId);

        // auto select the first one if needed
        if (_selectedMarkerId == null && widget.controller.autoSelect) {
          _selectedMarkerId = markerId;
        }

        BitmapDescriptor? markerAsset;
        double zIndex = 0;
        if (markerId == _selectedMarkerId) {
          // selected marker
          foundSelectedMarker = true;
          markerAsset = await _buildMarkerFromTemplate(
              markerPayload, selectedMarkerTemplate ?? markerTemplate);
          zIndex = selectedMarkerZIndex;

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
            zIndex: zIndex,
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
    // rebuild widget
    setState(() {
      _markerPayloads = payloads;
    });

    // markers are updated but we can't find a selected marker. This may
    // mean that marker is no longer there.
    if (_selectedMarkerId != null && foundSelectedMarker != true) {
      _clearSelectedMarker();
      if (widget.controller.autoSelect) {
        _selectNextMarker();
      }
    }

    if (itemTemplate.onMarkersUpdated != null) {
      ScreenController().executeAction(context, itemTemplate.onMarkersUpdated!,
          event: EnsembleEvent(widget));
    }
  }

  void _clearSelectedMarker() {
    if (_selectedMarkerId != null) {
      MarkerPayload? previousSelectedMarker =
          _getMarkerPayloadById(_selectedMarkerId!);
      if (previousSelectedMarker != null) {
        _buildMarkerFromTemplate(
                previousSelectedMarker, widget.controller.markerTemplate)
            .then((asset) {
          asset ??= BitmapDescriptor.defaultMarker;
          setState(() {
            previousSelectedMarker.marker = previousSelectedMarker.marker
                ?.copyWith(iconParam: asset, zIndexParam: 0);
          });
        });
        // BitmapDescriptor markerAsset = await _buildMarkerFromTemplate(
        //         previousSelectedMarker, widget.controller.markerTemplate) ??
        //     BitmapDescriptor.defaultMarker;
        // previousSelectedMarker.marker =
        //     previousSelectedMarker.marker?.copyWith(iconParam: markerAsset);
      }
      _selectedMarkerId = null;
    }

    // clear the overlay
    if (_overlayWidget != null) {
      setState(() {
        _overlayWidget = null;
      });
    }
  }

  void _selectMarker(MarkerId markerId) {
    if (markerId != _selectedMarkerId) {
      // first reset the previously selected marker
      _clearSelectedMarker();

      // mark the markerId as selected
      _selectedMarkerId = markerId;
      MarkerPayload? newSelectedMarker =
          _getMarkerPayloadById(_selectedMarkerId!);
      if (newSelectedMarker != null) {
        _buildMarkerFromTemplate(
                newSelectedMarker,
                widget.controller.selectedMarkerTemplate ??
                    widget.controller.markerTemplate)
            .then((asset) {
          asset ??= BitmapDescriptor.defaultMarker;
          setState(() {
            newSelectedMarker.marker = newSelectedMarker.marker
                ?.copyWith(iconParam: asset, zIndexParam: selectedMarkerZIndex);
          });
        });

        // BitmapDescriptor markerAsset = await _buildMarkerFromTemplate(
        //         newSelectedMarker,
        //         widget.controller.selectedMarkerTemplate ??
        //             widget.controller.markerTemplate) ??
        //     BitmapDescriptor.defaultMarker;
        // if (markerAsset != null) {
        //   newSelectedMarker.marker =
        //       newSelectedMarker.marker?.copyWith(iconParam: markerAsset);
        // }

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

// wrong logic here. See
  void _selectNextMarker() {
    if (_markerPayloads.isNotEmpty) {
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
  }

  void _selectPreviousMarker() {
    if (_markerPayloads.isNotEmpty) {
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
  }

  MarkerPayload? _getMarkerPayloadById(MarkerId markerId) {
    for (MarkerPayload markerPayload in _markerPayloads) {
      if (markerPayload.marker?.markerId == markerId) {
        return markerPayload;
      }
    }
    return null;
  }

  // TODO: LRU cache
  Map<String, BitmapDescriptor> markersCache = {};

  Future<BitmapDescriptor?> _buildMarkerFromTemplate(
      MarkerPayload markerPayload, MarkerTemplate? template) async {
    if (template != null) {
      if (template.source != null) {
        String? source =
            markerPayload.scopeManager.dataContext.eval(template.source!);
        if (source != null) {
          if (markersCache[source] == null) {
            var asset = await MapsUtils.fromAsset(context, source);
            if (asset != null) {
              markersCache[source] = asset;
            }
          }
          return markersCache[source];
        }
      }
      // TODO: from icon/widget
    }
    return null;
  }

  @override
  Widget buildWidget(BuildContext context) {
    Widget rtn = Stack(children: [
      GoogleMap(
        onMapCreated: _onMapCreated,
        myLocationEnabled: showLocationOnMap,
        mapType: widget.controller.mapType ?? MapType.normal,
        myLocationButtonEnabled: false,
        // use our own button
        mapToolbarEnabled: false,
        zoomControlsEnabled: false,
        onCameraMove: _onCameraMove,
        onCameraIdle: _onCameraIdle,
        rotateGesturesEnabled: widget.controller.rotateEnabled,
        scrollGesturesEnabled: widget.controller.scrollEnabled,
        tiltGesturesEnabled: widget.controller.tiltEnabled,
        zoomGesturesEnabled: widget.controller.zoomEnabled,
        initialCameraPosition: CameraPosition(
            target: widget.controller.initialCameraPosition ??
                widget.controller.defaultCameraLatLng,
            zoom: widget.controller.initialCameraZoom?.toDouble() ??
                widget.controller.defaultCameraZoom),
        markers: _getMarkers(),
      ),
      widget.controller.showToolbar
          ? MapsToolbar(
              margin: widget.controller.toolbarMargin,
              alignment: widget.controller.toolbarAlignment,
              top: widget.controller.toolbarTop,
              bottom: widget.controller.toolbarBottom,
              left: widget.controller.toolbarLeft,
              right: widget.controller.toolbarRight,
              onMapLayerChanged: widget.controller.showMapTypesButton
                  ? (mapType) {
                      setState(() {
                        widget.controller.mapType = mapType;
                      });
                    }
                  : null,
              onShowLocationButtonCallback: widget.controller.showLocationButton
                  ? () => _moveCamera(MapsUtils.fromPosition(currentLocation))
                  : null)
          : const SizedBox.shrink(),
      _overlayWidget != null && _selectedMarkerId != null
          ? MapsOverlay(
              _overlayWidget!,
              onScrolled: widget.controller.scrollableMarkerOverlay
                  ? (isNext) =>
                      isNext ? _selectNextMarker() : _selectPreviousMarker()
                  : null,
              onDismissed: widget.controller.dismissibleMarkerOverlay
                  ? () => _clearSelectedMarker()
                  : null,
              maxWidth: widget.controller.markerOverlayMaxWidth,
              maxHeight: widget.controller.markerOverlayMaxHeight,
            )
          : const SizedBox.shrink()
    ]);
    if (widget.controller.width != null || widget.controller.height != null) {
      rtn = SizedBox(
          width: widget.controller.width?.toDouble(),
          height: widget.controller.height?.toDouble(),
          child: rtn);
    }
    return rtn;
  }

  void _onMapCreated(GoogleMapController controller) async {
    _controller.complete(controller);

    if (widget.controller.onMapCreated != null) {
      ScreenController().executeAction(context, widget.controller.onMapCreated!,
          event: EnsembleEvent(widget));
    }

    // Native properly dispatches onCameraMove when map is created, but not Web.
    // we dispatch the event manually for Web
    if (kIsWeb && widget.controller.onCameraMove != null) {
      _executeCameraMoveAction(
          widget.controller.onCameraMove!, await controller.getVisibleRegion());
    }
  }

  void _moveCamera(LatLng? latLng) async {
    if (latLng != null) {
      CameraUpdate cameraUpdate = CameraUpdate.newCameraPosition(CameraPosition(
          target: latLng,
          zoom: await (await _controller.future).getZoomLevel()));
      _controller.future
          .then((controller) => controller.animateCamera(cameraUpdate));
    }
  }

  void _onCameraMove(CameraPosition position) async {
    if (widget.controller.onCameraMove != null) {
      _cameraMoveDebouncer.run(() async {
        LatLngBounds bounds =
            await (await _controller.future).getVisibleRegion();
        _executeCameraMoveAction(widget.controller.onCameraMove!, bounds);
        //log("Camera moved");
      });
    }
  }

  void _onCameraIdle() {}

  void _executeCameraMoveAction(
      EnsembleAction onCameraMove, LatLngBounds bounds) {
    // save the bound to expose it as getter
    widget.controller.currentBounds = {
      "southwest": {
        "lat": bounds.southwest.latitude,
        "lng": bounds.southwest.longitude
      },
      "northeast": {
        "lat": bounds.northeast.latitude,
        "lng": bounds.northeast.longitude
      }
    };

    ScreenController().executeAction(context, onCameraMove,
        event: EnsembleEvent(widget,
            data: {'bounds': widget.controller.currentBounds}));
  }

  Set<Marker> _getMarkers() {
    Set<Marker> markers = {};
    for (MarkerPayload markerPayload in _markerPayloads) {
      if (markerPayload.marker != null) {
        markers.add(markerPayload.marker!);
      }
    }

    // Google Maps doesn't support current location on Web. We have to
    // add our own indicator
    if (kIsWeb &&
        widget.controller.locationEnabled &&
        currentLocation != null) {
      markers.add(Marker(
          markerId: const MarkerId('ensemble_current_location'),
          position:
              LatLng(currentLocation!.latitude, currentLocation!.longitude),
          icon: currentLocationIcon ?? BitmapDescriptor.defaultMarker));
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
