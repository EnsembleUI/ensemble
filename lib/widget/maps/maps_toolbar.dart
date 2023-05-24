import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapsToolbar extends StatelessWidget {
  const MapsToolbar({super.key, this.onMapLayerChanged, this.onShowLocationButtonCallback});

  final MapLayerChangeCallback? onMapLayerChanged;
  final ShowLocationButtonCallback? onShowLocationButtonCallback;

  static final mapLayers = [
    { "label": "Normal", "value": MapType.normal.name },
    { "label": "Satellite", "value": MapType.satellite.name },
    { "label": "Terrain", "value": MapType.terrain.name },
    { "label": "Hybrid", "value": MapType.hybrid.name },
  ];

  void showMapLayers(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return ListView.builder(
          shrinkWrap: true,
          itemCount: mapLayers.length,
          itemBuilder: (context, index) {
            return ListTile(
              contentPadding: EdgeInsets.only(left: 20),
              title: Text(mapLayers[index]['label']!.toString()),
              onTap: () {
                Navigator.pop(context);
                onMapLayerChanged!(mapLayers[index]['value']!);
              },
            );
          },

        );
      });
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [];
    if (onMapLayerChanged != null) {
      children.add(IconButton(
          onPressed: () => showMapLayers(context),
          icon: Image.asset(
            'assets/images/map_layers_button.png',
            package: 'ensemble')));
    }
    if (onShowLocationButtonCallback != null) {
      children.add(
        IconButton(
            onPressed: onShowLocationButtonCallback,
            icon: Image.asset(
              'assets/images/map_location_button.png',
              package: 'ensemble')));
    }

    return Positioned(
        right: 10,
        bottom: 10,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ));
  }

}

typedef ShowLocationButtonCallback = void Function();
typedef MapLayerChangeCallback = void Function(String mapType);