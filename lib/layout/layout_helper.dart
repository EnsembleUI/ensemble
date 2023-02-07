
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/cupertino.dart';

/// Controller for anything with a Box around it (border, padding, shadow,...)
/// This may be a widget itself (e.g Image), not necessary an actual Container with children
class BoxController extends WidgetController {
  EdgeInsets? margin;
  EdgeInsets? padding;

  BackgroundImage? backgroundImage;
  LinearGradient? backgroundGradient;

  Color? borderColor;
  EBorderRadius? borderRadius;
  int? borderWidth;

  @override
  Map<String, Function> getBaseSetters() {
    Map<String, Function> setters = super.getBaseSetters();
    setters.addAll({
      // support short-hand notation margin: 10 5 10
      'margin': (value) => margin = Utils.optionalInsets(value),
      'padding': (value) => padding = Utils.optionalInsets(value),

      'backgroundImage': (value) => backgroundImage = Utils.getBackgroundImage(value),
      'backgroundGradient': (value) => backgroundGradient = Utils.getBackgroundGradient(value),

      'borderColor': (value) =>  borderColor = Utils.getColor(value),
      'borderRadius': (value) =>  borderRadius = Utils.getBorderRadius(value),
      'borderWidth': (value) =>  borderWidth = Utils.optionalInt(value),
    });
    return setters;
  }

  bool hasBorder() {
    return borderColor != null || borderWidth != null;
  }
}


/// base controller for Column/Row
class BoxLayoutController extends BoxController {
  EnsembleAction? onTap;

  bool scrollable = false;
  bool autoFit = false;
  String? mainAxis;
  String? crossAxis;
  String? mainAxisSize;
  int? width;
  int? maxWidth;
  int? height;
  int? maxHeight;
  int? gap;

  Color? backgroundColor;

  String? fontFamily;
  int? fontSize;

  int? shadowColor;
  Offset? shadowOffset;
  int? shadowRadius;

  List<Widget>? children;

  // applicable to Flex container only
  String? direction;
  // applicable only for ListView
  EnsembleAction? onItemTap;
  Color? sepratorColor;
  double? sepratorWidth;
  EdgeInsets? sepratorPadding;


  @override
  Map<String, Function> getBaseSetters() {
    Map<String, Function> setters = super.getBaseSetters();
    setters.addAll({
      'scrollable': (value) => scrollable = Utils.getBool(value, fallback: false),
      'autoFit': (value) =>  autoFit = Utils.getBool(value, fallback: false),
      'mainAxis': (value) => mainAxis = Utils.optionalString(value),
      'crossAxis': (value) => crossAxis = Utils.optionalString(value),
      'mainAxisSize': (value) => mainAxisSize = Utils.optionalString(value),
      'width': (value) => width = Utils.optionalInt(value),
      'maxWidth': (value) => maxWidth = Utils.optionalInt(value),
      'height': (value) => height = Utils.optionalInt(value),
      'maxHeight': (value) => maxHeight = Utils.optionalInt(value),
      'gap': (value) => gap = Utils.optionalInt(value),

      'backgroundColor': (value) => backgroundColor = Utils.getColor(value),

      'fontFamily': (value) => fontFamily = Utils.optionalString(value),
      'fontSize': (value) =>  fontSize = Utils.optionalInt(value),

      'shadowColor': (value) => shadowColor = Utils.optionalInt(value),
      'shadowOffset': (list) => shadowOffset = Utils.getOffset(list),
      'shadowRadius': (value) =>  shadowRadius = Utils.optionalInt(value),

    });
    return setters;
  }
}