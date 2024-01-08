import 'package:ensemble/framework/model.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:flutter/cupertino.dart';

mixin HasPassThrough on EnsembleWidgetController {
  /// a widget can tell the framework not to automatically evaluate its value
  /// while calling the setters can include the passthrough list here.
  /// This is useful if the widget wants to evaluate the value later (e.g.
  /// evaluate an Action's variables upon the action execution), or it wants
  /// to handle the binding listeners itself (e.g. item-template like)
  List<String> passthroughSetters() => [];
}

/// for widgets that want to have borders
mixin HasBorderController on EnsembleWidgetController {
  LinearGradient? borderGradient;
  Color? borderColor;
  int? borderWidth;
  EBorderRadius? borderRadius;

  Map<String, Function> hasBorderSetters() => {
        'borderGradient': (value) =>
            borderGradient = Utils.getBackgroundGradient(value),
        'borderColor': (value) => borderColor = Utils.getColor(value),
        'borderWidth': (value) => borderWidth = Utils.optionalInt(value),
        'borderRadius': (value) => borderRadius = Utils.getBorderRadius(value),
      };

  bool hasBorder() =>
      borderGradient != null || borderColor != null || borderWidth != null;
}

/// for widgets that want to have a background
mixin HasBackgroundController on EnsembleWidgetController {
  Color? backgroundColor;
  BackgroundImage? backgroundImage;
  LinearGradient? backgroundGradient;

  Map<String, Function> hasBackgroundSetters() => {
        'backgroundColor': (value) => backgroundColor = Utils.getColor(value),
        'backgroundImage': (value) =>
            backgroundImage = Utils.getBackgroundImage(value),
        'backgroundGradient': (value) =>
            backgroundGradient = Utils.getBackgroundGradient(value),
      };

  bool hasBackground() =>
      backgroundColor != null ||
      backgroundImage != null ||
      backgroundGradient != null;
}
