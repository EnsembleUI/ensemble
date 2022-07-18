
import 'dart:async';
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
      'markers': (data) => _controller.markers = data,
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
  int? markerWidth;
  int? markerHeight;

  // set the marker template
  MarkerTemplate? markerTemplate;
  set markers(dynamic markerData) {
    if (markerData is YamlMap) {
      String? data = markerData['data'];
      String? name = markerData['name'];
      YamlMap? template = markerData['marker'];
      String? lat = markerData['location']?['lat'];
      String? lng = markerData['location']?['lng'];
      YamlMap? selectedMarker = markerData['selectedMarker'];
      if (data != null && name != null && template != null && lat != null && lng != null) {
        markerTemplate = MarkerTemplate(
          data: data,
          name: name,
          template: template,
          lat: lat,
          lng: lng,
          selectedMarker: selectedMarker);
      }
    }
  }

}

class MapState extends WidgetState<EnsembleMap> with TemplatedWidgetState {
  // Mapbox raster's max zoom is 18
  static const double mapboxMaxZoom = 18;
  static const double defaultMarkerWidth = 60;
  static const double defaultMarkerHeight = 30;


  late final MapController _mapController;
  late final String _mapAccessToken;
  List<Marker> markers = [];
  Widget? overlayWidget;

  @override
  void initState() {
    super.initState();
    initMap();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // listen for changes
    if (widget._controller.markerTemplate != null) {
      registerItemTemplate(
          context,
          widget._controller.markerTemplate!,
          evaluateInitialValue: true,
          onDataChanged: (List dataList) {
            setState(() {
              markers = buildMarkersFromTemplate(dataList);
            });
          }
      );
    }
  }
  /// build the markers from our item-template data
  List<Marker> buildMarkersFromTemplate(List dataList) {
    List<DataScopeWidget>? markerWidgets = buildWidgetsFromTemplate(context, dataList, widget._controller.markerTemplate!);

    List<Marker> markers = [];
    if (markerWidgets != null && widget._controller.markerTemplate != null) {
      for (DataScopeWidget markerWidget in markerWidgets) {
        ScopeManager scopeManager = markerWidget.scopeManager;

        // evaluate the lat/lng
        double? lat = Utils.optionalDouble(scopeManager.dataContext.eval(widget._controller.markerTemplate!.lat));
        double? lng = Utils.optionalDouble(scopeManager.dataContext.eval(widget._controller.markerTemplate!.lng));
        if (lat != null && lng != null) {
          Widget w;
          // if selectedMarker template is specified, wrap our marker widget to listen for tap events
          if (widget._controller.markerTemplate!.selectedMarker != null) {
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
    if (widget._controller.markerTemplate!.selectedMarker != null) {
      setState(() {
        overlayWidget = markerWidget.scopeManager.buildWidgetFromDefinition(widget._controller.markerTemplate!.selectedMarker);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget._controller.visible) {
      return const SizedBox.shrink();
    }
    return buildMap();
  }

  void initMap() {
    _mapController = MapController();
    _mapAccessToken = Ensemble().account?.mapAccessToken ?? '';
  }

  Widget buildMap() {
    Widget map = FlutterMap(
      mapController: _mapController,
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
          markers: markers
        )
      ]
    );

    // adjust the bound to fit all the markers
    _mapController.onReady.then((value) {
      if (markers.isNotEmpty) {
        _mapController.fitBounds(
            LatLngBounds.fromPoints(markers.map((e) => e.point).toList()),
            options: const FitBoundsOptions(padding: EdgeInsets.all(100)));
      }
    });

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