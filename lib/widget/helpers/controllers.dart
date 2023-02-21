/// This class contains helper controllers for our widgets.
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';



/// base Controller class for your Ensemble widget
abstract class WidgetController extends Controller {
  // Note: we manage these here so the user doesn't need to do in their widgets
  // base properties applicable to all widgets
  bool expanded = false;
  bool visible = true;
  String? id;             // do we need this?

  // optional label/labelHint for use in Forms
  String? label;
  String? labelHint;

  @override
  Map<String, Function> getBaseGetters() {
    return {
      'expanded': () => expanded,
      'visible': () => visible,
    };
  }

  @override
  Map<String, Function> getBaseSetters() {
    return {
      'expanded': (value) => expanded = Utils.getBool(value, fallback: false),
      'visible': (value) => visible = Utils.getBool(value, fallback: true),
      'label': (value) => label = Utils.optionalString(value),
      'labelHint': (value) => labelHint = Utils.optionalString(value),
    };
  }
}

/// Controller for anything with a Box around it (border, padding, shadow,...)
/// This may be a widget itself (e.g Image), not necessary an actual Container with children
class BoxController extends WidgetController {
  EdgeInsets? margin;
  EdgeInsets? padding;

  int? width;
  int? height;

  Color? backgroundColor;
  BackgroundImage? backgroundImage;
  LinearGradient? backgroundGradient;

  Color? borderColor;
  EBorderRadius? borderRadius;
  int? borderWidth;

  int? shadowColor;
  Offset? shadowOffset;
  int? shadowRadius;

  @override
  Map<String, Function> getBaseSetters() {
    Map<String, Function> setters = super.getBaseSetters();
    setters.addAll({
      // support short-hand notation margin: 10 5 10
      'margin': (value) => margin = Utils.optionalInsets(value),
      'padding': (value) => padding = Utils.optionalInsets(value),

      'width': (value) => width = Utils.optionalInt(value),
      'height': (value) => height = Utils.optionalInt(value),

      'backgroundColor': (value) => backgroundColor = Utils.getColor(value),
      'backgroundImage': (value) => backgroundImage = Utils.getBackgroundImage(value),
      'backgroundGradient': (value) => backgroundGradient = Utils.getBackgroundGradient(value),

      'borderColor': (value) =>  borderColor = Utils.getColor(value),
      'borderRadius': (value) =>  borderRadius = Utils.getBorderRadius(value),
      'borderWidth': (value) =>  borderWidth = Utils.optionalInt(value),

      'shadowColor': (value) => shadowColor = Utils.optionalInt(value),
      'shadowOffset': (list) => shadowOffset = Utils.getOffset(list),
      'shadowRadius': (value) =>  shadowRadius = Utils.optionalInt(value),
    });
    return setters;
  }

  bool hasBorder() {
    return borderColor != null || borderWidth != null;
  }
}