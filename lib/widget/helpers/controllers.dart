/// This class contains helper controllers for our widgets.
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/framework/styles/style_provider.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

/// base Controller class for your Ensemble widget
abstract class WidgetController extends Controller {
  // Note: we manage these here so the user doesn't need to do in their widgets
  // base properties applicable to all widgets
  bool expanded = false;
  bool visible = true;
  String? id; // do we need this?

  // optional label/labelHint for use in Forms
  String? label;
  String? description;
  String? labelHint;
  String? namedStyle;

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
      'description': (value) => description = Utils.optionalString(value),
      'labelHint': (value) => labelHint = Utils.optionalString(value),
      'namedStyle': (value) =>
          namedStyle = Utils.optionalString(value ?? 'Not Found')
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
  LinearGradient? borderGradient;

  Color? borderColor;
  int? borderWidth;
  EBorderRadius? borderRadius;

  Color? shadowColor;
  Offset? shadowOffset;
  int? shadowRadius;
  BlurStyle? shadowStyle;

  @override
  Map<String, Function> getBaseSetters() {
    Map<String, Function> setters = super.getBaseSetters();
    final styleModel = GetIt.I<StyleProvider>();
    final StyleTheme? style = styleModel.getNamedStyle(namedStyle);

    if (style != null) {
      backgroundColor = style.backgroundColor;
      borderColor = style.borderColor;
      shadowColor = style.shadowColor;
      shadowRadius = style.shadowRadius;
      borderRadius = Utils.getBorderRadius(style.borderRadius);
      borderWidth = style.borderWidth;
    }

    setters.addAll({
      // support short-hand notation margin: 10 5 10
      'margin': (value) => margin = Utils.optionalInsets(value),
      'padding': (value) => padding = Utils.optionalInsets(value),

      'width': (value) => width = Utils.optionalInt(value),
      'height': (value) => height = Utils.optionalInt(value),

      'backgroundColor': (value) => backgroundColor = Utils.getColor(value),
      'backgroundImage': (value) =>
          backgroundImage = Utils.getBackgroundImage(value),
      'backgroundGradient': (value) =>
          backgroundGradient = Utils.getBackgroundGradient(value),
      'borderGradient': (value) =>
          borderGradient = Utils.getBackgroundGradient(value),

      'borderColor': (value) => borderColor = Utils.getColor(value),
      'borderWidth': (value) => borderWidth = Utils.optionalInt(value),
      'borderRadius': (value) => borderRadius = Utils.getBorderRadius(value),

      'shadowColor': (value) => shadowColor = Utils.getColor(value),
      'shadowOffset': (list) => shadowOffset = Utils.getOffset(list),
      'shadowRadius': (value) => shadowRadius = Utils.optionalInt(value),
      'shadowStyle': (value) => shadowStyle = Utils.getShadowBlurStyle(value)
    });
    return setters;
  }

  /// optimization. This is important to review if more properties are added
  bool requiresBox(
          {required bool ignoresMargin,
          required bool ignoresPadding,
          required bool ignoresDimension}) =>
      (!ignoresDimension && hasDimension()) ||
      (!ignoresMargin && margin != null) ||
      (!ignoresPadding && padding != null) ||
      hasBoxDecoration();

  bool hasDimension() => width != null || height != null;

  bool hasBoxDecoration() =>
      hasBackground() || hasBorder() || borderRadius != null || hasBoxShadow();

  bool hasBackground() =>
      backgroundColor != null ||
      backgroundImage != null ||
      backgroundGradient != null;

  bool hasBorder() =>
      borderGradient != null || borderColor != null || borderWidth != null;

  bool hasBoxShadow() =>
      shadowColor != null ||
      shadowOffset != null ||
      shadowRadius != null ||
      shadowStyle != null;
}
