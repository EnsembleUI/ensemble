
import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/widget/view.dart';
import 'package:ensemble/layout/templated.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:flutter/material.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:yaml/yaml.dart';

class EnsembleMap extends StatefulWidget with Invokable, HasController<MyController, MapState> {
  static const type = 'Map';
  EnsembleMap({Key? key}) : super(key: key);

  @override
  MapState createState() => MapState();

  final MyController _controller = MyController();
  @override
  MyController get controller => _controller;

  @override
  Map<String, Function> setters() {
    return {
      'currentLocation': _controller.updateCurrentLocationStatus,
      'markers': _controller.updateMarkerTemplate,
      'markerWidth': (width) => _controller.markerWidth = width,
      'markerHeight': (height) => _controller.markerHeight = height,
    };
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

class MyController extends WidgetController {
  final MapController _mapController = MapController();

  // unfortunately these are needed for flutter_map
  int? markerWidth;
  int? markerHeight;

  MarkerTemplate? _markerTemplate;
  List<Marker> _markers = [];
  set markers(List<Marker> items) {
    _markers = items;
    resetMapBounds();
  }

  Position? currentLocation;    // user's location if enabled & given permission
  dynamic customLocationWidget;


  void updateMarkerTemplate(dynamic markerData) {
    if (markerData is YamlMap) {
      String? data = markerData['data'];
      String? name = markerData['name'];
      YamlMap? template = markerData['marker'];
      String? lat = markerData['location']?['lat'];
      String? lng = markerData['location']?['lng'];
      YamlMap? selectedMarker = markerData['selectedMarker'];
      if (data != null && name != null && template != null && lat != null && lng != null) {
        _markerTemplate = MarkerTemplate(
          data: data,
          name: name,
          template: template,
          lat: lat,
          lng: lng,
          selectedMarker: selectedMarker);
      }
    }
  }

  void updateCurrentLocationStatus(dynamic locationData) {
    if (locationData is YamlMap) {
      if (locationData['enabled'] == true) {
        customLocationWidget = locationData['widget'];
        if (currentLocation == null) {
          requestUserLocation();
        }
      }
    }
  }

  void requestUserLocation() async {
    currentLocation = await getLocation();
    resetMapBounds();
    notifyListeners();
  }

  Future<Position?> getLocation() async {
    if (await Geolocator.isLocationServiceEnabled()) {
      LocationPermission permission = await Geolocator.checkPermission();
      // ask for permission if not already
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      log("Location permission $permission");

      if (![LocationPermission.denied, LocationPermission.deniedForever].contains(permission)) {
        return await Geolocator.getCurrentPosition();
      }
    }
    return Future.value(null);
  }



  /// zoom the map to fit our markers and current location
  void resetMapBounds() {
    _mapController.onReady.then((value) {
      List<LatLng> points = [];
      if (currentLocation != null) {
        points.add(LatLng(currentLocation!.latitude, currentLocation!.longitude));
      }
      points.addAll(_markers.map((item) => item.point).toList());

      if (points.isNotEmpty) {
        _mapController.fitBounds(
            LatLngBounds.fromPoints(points),
            options: const FitBoundsOptions(padding: EdgeInsets.all(100)));
      }
    });
  }

}

class MapState extends WidgetState<EnsembleMap> with TemplatedWidgetState {
  // Mapbox raster's max zoom is 18
  static const double mapboxMaxZoom = 18;
  static const double defaultMarkerWidth = 60;
  static const double defaultMarkerHeight = 30;


  late final String _mapAccessToken;
  Widget? overlayWidget;

  @override
  void initState() {
    super.initState();
    // TODO: use Provider to inject account in
    _mapAccessToken = Ensemble().getAccount()?.mapAccessToken ?? '';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // listen for changes
    if (widget._controller._markerTemplate != null) {
      registerItemTemplate(
          context,
          widget._controller._markerTemplate!,
          evaluateInitialValue: true,
          onDataChanged: (List dataList) {
            setState(() {
              widget._controller.markers = buildMarkersFromTemplate(dataList);
            });
          }
      );
    }
  }
  /// build the markers from our item-template data
  List<Marker> buildMarkersFromTemplate(List dataList) {
    List<DataScopeWidget>? markerWidgets = buildWidgetsFromTemplate(context, dataList, widget._controller._markerTemplate!);

    List<Marker> markers = [];
    if (markerWidgets != null && widget._controller._markerTemplate != null) {
      for (DataScopeWidget markerWidget in markerWidgets) {
        ScopeManager scopeManager = markerWidget.scopeManager;

        // evaluate the lat/lng
        double? lat = Utils.optionalDouble(scopeManager.dataContext.eval(widget._controller._markerTemplate!.lat));
        double? lng = Utils.optionalDouble(scopeManager.dataContext.eval(widget._controller._markerTemplate!.lng));
        if (lat != null && lng != null) {
          Widget w;
          // if selectedMarker template is specified, wrap our marker widget to listen for tap events
          if (widget._controller._markerTemplate!.selectedMarker != null) {
            w = InkWell(
              child: markerWidget,
              onTap: () => selectMarker(markerWidget),
            );
          } else {
            w = markerWidget;
          }

          // add the marker
          markers.add(Marker(
            point: LatLng(lat, lng),
            width: widget._controller.markerWidth?.toDouble() ?? defaultMarkerWidth,
            height: widget._controller.markerHeight?.toDouble() ?? defaultMarkerHeight,
            builder: (context) => w));

        }
      }
    }
    return markers;
  }



  void selectMarker(DataScopeWidget markerWidget) {
    if (widget._controller._markerTemplate!.selectedMarker != null) {
      setState(() {
        overlayWidget = markerWidget.scopeManager.buildWidgetFromDefinition(widget._controller._markerTemplate!.selectedMarker);
      });
    }
  }

  @override
  Widget buildWidget(BuildContext context) {
    List<Marker> items = widget._controller._markers;

    // render the current location widget
    if (widget._controller.currentLocation != null) {
      Widget? locationWidget;
      if (widget._controller.customLocationWidget != null) {
        locationWidget = DataScopeWidget.getScope(context)?.buildWidgetFromDefinition(widget._controller.customLocationWidget);
      }
      locationWidget ??= const Icon(Icons.filter_tilt_shift);

      items.add(Marker(
        point: LatLng(widget._controller.currentLocation!.latitude, widget._controller.currentLocation!.longitude),
        builder: (context) => locationWidget!
      ));
    }

    Widget map = FlutterMap(
        mapController: widget._controller._mapController,
        options: MapOptions(
            maxZoom: mapboxMaxZoom,
            interactiveFlags: InteractiveFlag.all - InteractiveFlag.rotate
        ),
        layers: [
          TileLayerOptions(
            urlTemplate: "https://api.mapbox.com/styles/v1/ensembleui/cl5ladr0w002316nitdjrqj3w/tiles/512/{z}/{x}/{y}@2x?access_token=$_mapAccessToken",
            additionalOptions: {
              "access_token": _mapAccessToken
            },
          ),
          MarkerLayerOptions(
              markers: items
          )
        ]
    );



    return Stack(
      children: [
        map,
        overlayWidget == null ?
        const SizedBox.shrink() :
        Container(
            margin: const EdgeInsets.only(bottom: 20, left: 10, right: 10),
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: Ensemble().deviceInfo.size.height / 2),
                child: SingleChildScrollView(
                  child: overlayWidget,
                )
            )
        )
      ],
    );
  }





  /*

  void initGoogleMap() {
    _googleMapController = Completer();
    if (Platform.isAndroid) {
      AndroidGoogleMapsFlutter.useAndroidViewSurface = true;
    }
  }

  Widget buildGoogleMap() {
    return GoogleMap(
      mapType: MapType.normal,
      initialCameraPosition: const CameraPosition(
        target: LatLng(37.42796133580664, -122.085749655962),
        zoom: 14.4746,
      ),
      onMapCreated: (GoogleMapController controller) {
        _googleMapController.complete(controller);
      },
    );
  }
  */


}

class MarkerTemplate extends ItemTemplate {
  MarkerTemplate({
    required String data,
    required String name,
    required YamlMap template,
    required this.lat,
    required this.lng,
    this.selectedMarker
  }) : super(data, name, template);

  String lat;
  String lng;
  YamlMap? selectedMarker;
}