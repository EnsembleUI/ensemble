import 'package:ensemble/widget/icon_button.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapsToolbar extends StatelessWidget {
  const MapsToolbar(
      {super.key,
      this.margin,
      this.alignment,
      this.top,
      this.bottom,
      this.left,
      this.right,
      this.onMapLayerChanged,
      this.onShowLocationButtonCallback});

  final EdgeInsets? margin;
  final Alignment? alignment;
  final int? top;
  final int? bottom;
  final int? left;
  final int? right;
  final MapLayerChangeCallback? onMapLayerChanged;
  final ShowLocationButtonCallback? onShowLocationButtonCallback;

  static final mapLayers = [
    {"label": "Normal", "image": "map_normal", "value": MapType.normal.name},
    {
      "label": "Satellite",
      "image": "map_satellite",
      "value": MapType.satellite.name
    },
    {"label": "Terrain", "image": "map_terrain", "value": MapType.terrain.name},
    {"label": "Hybrid", "image": "map_hybrid", "value": MapType.hybrid.name},
  ];

  void showMapLayers(BuildContext context) {
    showModalBottomSheet(
        context: context,
        builder: (context) {
          return ListView.builder(
            padding:
                const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 10),
            shrinkWrap: true,
            itemCount: mapLayers.length,
            itemBuilder: (context, index) {
              return ListTile(
                contentPadding: const EdgeInsets.only(bottom: 10),
                leading: Image.asset(
                    "assets/images/${mapLayers[index]['image']!}.png",
                    package: 'ensemble'),
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
      children.add(FrameworkIconButton(
          onTap: () => showMapLayers(context),
          child: Image.asset('assets/images/map_layers_button.png',
              package: 'ensemble')));
    }
    if (onShowLocationButtonCallback != null) {
      children.add(FrameworkIconButton(
          onTap: onShowLocationButtonCallback,
          child: Image.asset('assets/images/map_location_button.png',
              package: 'ensemble')));
    }

    Widget rtn = Column(mainAxisSize: MainAxisSize.min, children: children);
    if (margin != null) {
      rtn = Padding(padding: margin!, child: rtn);
    }
    if (alignment != null) {
      rtn = Align(alignment: alignment!, child: rtn);
    }
    if (top != null || bottom != null || left != null || right != null) {
      rtn = Positioned(
          top: top?.toDouble(),
          bottom: bottom?.toDouble(),
          left: left?.toDouble(),
          right: right?.toDouble(),
          child: rtn);
    }
    return rtn;
  }
}

typedef ShowLocationButtonCallback = void Function();
typedef MapLayerChangeCallback = void Function(String mapType);

//
// class EnsembleIconButton extends StatelessWidget {
//   const EnsembleIconButton({super.key, required this.child, this.size, this.onTap});
//
//   final Widget child;
//   final Function? onTap;
//
//   @override
//   Widget build(BuildContext context) {
//     return Material(
//
//       color: Colors.transparent,
//       child: InkWell(
//         onTap: onTap != null ? () => onTap!() : null,
//         // splashColor: Colors.red,
//         customBorder: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(999)
//         ),
//         child: Container(
//           width: size?.toDouble() ?? defaultSize,
//           height: size?.toDouble() ?? defaultSize,
//           //padding: const EdgeInsets.all(8),
//           decoration: BoxDecoration(
//             borderRadius: BorderRadius.circular(999),
//             // color: Colors.grey[200]
//           ),
//           child: child,
//         )));
//   }
//
// }
