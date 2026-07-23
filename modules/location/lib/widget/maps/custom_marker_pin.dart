/// Custom map marker pin widgets for Ensemble maps.
library custom_marker_pin;

import 'package:ensemble/framework/model.dart';
import 'package:ensemble/framework/theme/theme_manager.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/material.dart';
import 'package:ensemble/framework/widget/icon.dart' as ensemble;

/// Icon and color configuration for a custom map marker pin.
class MapMarkerIconModel extends IconModel {
  /// Creates a custom map marker icon model.
  MapMarkerIconModel(super.icon,
      {super.library,
      super.size,
      super.color,
      required this.iconPadding,
      required this.padding,
      this.iconBackgroundColor,
      this.backgroundColor});

  /// Padding around the icon inside its circular background.
  final int iconPadding;

  /// Background color behind the icon.
  final Color? iconBackgroundColor;

  /// Outer padding around the marker icon.
  final int padding;

  /// Pin background color.
  final Color? backgroundColor;

  /// Creates a marker icon model from an Ensemble icon payload.
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

  /// Default marker icon size.
  static const defaultSize = 20;
}

/// Renders a custom map marker pin.
class CustomMarkerPin extends StatelessWidget {
  /// Creates a marker pin for [model].
  const CustomMarkerPin(this.model, {super.key});

  /// Marker icon model used by this pin.
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
