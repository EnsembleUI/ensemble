import 'package:ensemble/framework/model.dart';
import 'package:ensemble/framework/theme/theme_manager.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/material.dart';
import 'package:ensemble/framework/widget/icon.dart' as ensemble;

class MapMarkerIconModel extends IconModel {
  MapMarkerIconModel(super.icon,
      {super.library,
      super.size,
      super.color,
      required this.iconPadding,
      required this.padding,
      this.iconBackgroundColor,
      this.backgroundColor});

  // is the background and padding around the icon
  final int iconPadding;
  final Color? iconBackgroundColor;

  // this is the outside padding and the pin background color
  final int padding;
  final Color? backgroundColor;

  static MapMarkerIconModel? from(dynamic value) {
    IconModel? iconModel = Utils.getIcon(value);
    if (iconModel != null && value is Map) {
      return MapMarkerIconModel(iconModel.icon,
          library: iconModel.library,
          size: iconModel.size ?? defaultSize,
          color: iconModel.color,
          iconPadding: Utils.getInt(value["iconPadding"], fallback: 4),
          padding: Utils.getInt(value["padding"], fallback: 4),
          iconBackgroundColor: Utils.getColor(value["iconBackgroundColor"]),
          backgroundColor: Utils.getColor(value["backgroundColor"]));
    }
    return null;
  }

  static const defaultSize = 20;
}

class CustomMarkerPin extends StatelessWidget {
  const CustomMarkerPin(this.model, {super.key});

  final MapMarkerIconModel model;

  @override
  Widget build(BuildContext context) {
    return Center(
        child: Stack(
      alignment: Alignment.topCenter,
      children: [
        Image.asset(
          "assets/images/pin.png",
          package: 'ensemble',
          width: (model.size ?? MapMarkerIconModel.defaultSize) +
              (model.iconPadding + model.padding) * 2,
          fit: BoxFit.fitWidth,
          color:
              model.backgroundColor ?? ThemeManager().getPrimaryColor(context),
        ),
        Padding(
            padding: EdgeInsets.only(top: model.padding.toDouble()),
            child: Container(
              padding: EdgeInsets.all(model.iconPadding.toDouble()),
              decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(100)),
                  color: model.iconBackgroundColor ??
                      ThemeManager().getMapMarkerIconBackgroundColor(context)),
              child: ensemble.Icon(model.icon,
                  library: model.library, size: model.size, color: model.color),
            ))
      ],
    ));
  }
}
