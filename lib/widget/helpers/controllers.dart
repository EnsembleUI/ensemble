/// This class contains helper controllers for our widgets.
import 'package:ensemble/controller/controller_mixins.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/errors.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';

/// Widget property that have nested properties should be extending this,
/// as this allows any setters on the nested properties to trigger changes
abstract class WidgetCompositeProperty with Invokable {
  WidgetCompositeProperty(this.widgetController);

  WidgetController widgetController;

  @override
  void setProperty(prop, val) {
    Function? func = setters()[prop];
    if (func != null) {
      func(val);
      widgetController.notifyListeners();
    } else {
      throw InvalidPropertyException("Settable property '$prop' not found.");
    }
  }
}

class TextStyleComposite extends WidgetCompositeProperty {
  TextStyleComposite(super.widgetController,
      {LinearGradient? textGradient,
      dynamic textAlign,
      TextStyle? styleWithFontFamily})
      : fontFamily = styleWithFontFamily,
        fontSize = styleWithFontFamily?.fontSize?.toInt(),
        lineHeightMultiple = styleWithFontFamily?.height,
        fontWeight = styleWithFontFamily?.fontWeight,
        isItalic = styleWithFontFamily?.fontStyle == FontStyle.italic,
        color = textGradient == null ? styleWithFontFamily?.color : null,
        gradient = textGradient,
        textAlign = Utils.getTextAlignment(textAlign),
        backgroundColor = styleWithFontFamily?.backgroundColor,
        decoration = styleWithFontFamily?.decoration,
        decorationStyle = styleWithFontFamily?.decorationStyle,
        overflow = styleWithFontFamily?.overflow,
        letterSpacing = styleWithFontFamily?.letterSpacing,
        wordSpacing = styleWithFontFamily?.wordSpacing;

  TextStyle? fontFamily;
  int? fontSize;
  double? lineHeightMultiple;
  FontWeight? fontWeight;
  bool? isItalic;
  Color? color;
  Color? backgroundColor;
  LinearGradient? gradient;
  TextDecoration? decoration;
  TextDecorationStyle? decorationStyle;
  TextOverflow? overflow;
  double? letterSpacing;
  double? wordSpacing;
  TextAlign? textAlign;

  TextStyle getTextStyle() => (fontFamily ?? const TextStyle()).copyWith(
      fontSize: fontSize?.toDouble(),
      height: lineHeightMultiple,
      fontWeight: fontWeight,
      fontStyle: isItalic == true ? FontStyle.italic : FontStyle.normal,
      color: gradient == null ? color : null,
      backgroundColor: backgroundColor,
      decoration: decoration,
      decorationStyle: decorationStyle,
      overflow: overflow,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing);

  @override
  Map<String, Function> setters() {
    return {
      'fontFamily': (value) => fontFamily = Utils.getFontFamily(value),
      'fontSize': (value) =>
          fontSize = Utils.optionalInt(value, min: 1, max: 1000),
      'lineHeightMultiple': (value) =>
          lineHeightMultiple = Utils.optionalDouble(value),
      'fontWeight': (value) => fontWeight = Utils.getFontWeight(value),
      'isItalic': (value) => isItalic = Utils.optionalBool(value),
      'gradient': (value) => gradient = Utils.getBackgroundGradient(value),
      'color': (value) =>
          color = gradient == null ? Utils.getColor(value) : null,
      'backgroundColor': (value) => backgroundColor = Utils.getColor(value),
      'decoration': (value) => decoration = Utils.getDecoration(value),
      'decorationStyle': (value) =>
          decorationStyle = TextDecorationStyle.values.from(value),
      'overflow': (value) => overflow = TextOverflow.values.from(value),
      'letterSpacing': (value) => letterSpacing = Utils.optionalDouble(value),
      'wordSpacing': (value) => wordSpacing = Utils.optionalDouble(value),
      'textAlign': (value) => textAlign = Utils.getTextAlignment(value),
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

/// TODO: Legacy, transition to EnsembleWidgetController
/// base Controller class for your Ensemble widget
abstract class WidgetController extends Controller {
  // Note: we manage these here so the user doesn't need to do in their widgets
  // base properties applicable to all widgets
  bool expanded = false;

  bool focusable = false;
  EnsembleAction? onFocusSelect;

  bool visible = true;
  Duration? visibilityTransitionDuration; // in seconds

  int? elevation;
  Color? elevationShadowColor;
  EBorderRadius? elevationBorderRadius;

  String? id; // do we need this?

  // wrap widget inside an Align widget
  Alignment? alignment;

  int? stackPositionTop;
  int? stackPositionBottom;
  int? stackPositionLeft;
  int? stackPositionRight;

  // https://pub.dev/packages/pointer_interceptor
  bool? captureWebPointer;

  // optional label/labelHint for use in Forms
  String? label;
  String? description;
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
      'focusable': (value) =>
          focusable = Utils.getBool(value, fallback: focusable),
      'onFocusSelect': (value) =>
          onFocusSelect = EnsembleAction.fromYaml(value),
      'visible': (value) => visible = Utils.getBool(value, fallback: true),
      'visibilityTransitionDuration': (value) =>
          visibilityTransitionDuration = Utils.getDuration(value),
      'elevation': (value) =>
          elevation = Utils.optionalInt(value, min: 0, max: 24),
      'elevationShadowColor': (value) =>
          elevationShadowColor = Utils.getColor(value),
      'elevationBorderRadius': (value) =>
          elevationBorderRadius = Utils.getBorderRadius(value),
      'alignment': (value) => alignment = Utils.getAlignment(value),
      'stackPositionTop': (value) =>
          stackPositionTop = Utils.optionalInt(value),
      'stackPositionBottom': (value) =>
          stackPositionBottom = Utils.optionalInt(value),
      'stackPositionLeft': (value) =>
          stackPositionLeft = Utils.optionalInt(value),
      'stackPositionRight': (value) =>
          stackPositionRight = Utils.optionalInt(value),
      'captureWebPointer': (value) =>
          captureWebPointer = Utils.optionalBool(value),
      'label': (value) => label = Utils.optionalString(value),
      'description': (value) => description = Utils.optionalString(value),
      'labelHint': (value) => labelHint = Utils.optionalString(value),
    };
  }

  bool hasPositions() {
    return (stackPositionTop ??
            stackPositionBottom ??
            stackPositionLeft ??
            stackPositionRight) !=
        null;
  }
}

/// TODO: Legacy - move to EnsembleBoxController
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

  // some children like Image don't get clipped properly with Box's clipBehavior
  bool? clipContent;

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
      'shadowStyle': (value) => shadowStyle = Utils.getShadowBlurStyle(value),

      'clipContent': (value) => clipContent = Utils.optionalBool(value)
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

/// Base Widget Controller
abstract class EnsembleWidgetController extends EnsembleController {
  // Note: we manage these here so the user doesn't need to do in their widgets
  // base properties applicable to all widgets
  bool expanded = false;

  bool visible = true;
  Duration? visibilityTransitionDuration; // in seconds

  int? elevation;
  Color? elevationShadowColor;
  EBorderRadius? elevationBorderRadius;

  String? id; // do we need this?

  // wrap widget inside an Align widget
  Alignment? alignment;

  int? stackPositionTop;
  int? stackPositionBottom;
  int? stackPositionLeft;
  int? stackPositionRight;

  // https://pub.dev/packages/pointer_interceptor
  bool? captureWebPointer;

  // optional label/labelHint for use in Forms
  String? label;
  String? description;
  String? labelHint;

  @override
  Map<String, Function> getters() {
    return {
      'expanded': () => expanded,
      'visible': () => visible,
    };
  }

  @override
  Map<String, Function> setters() {
    return {
      'expanded': (value) => expanded = Utils.getBool(value, fallback: false),
      'visible': (value) => visible = Utils.getBool(value, fallback: true),
      'visibilityTransitionDuration': (value) =>
          visibilityTransitionDuration = Utils.getDuration(value),
      'elevation': (value) =>
          elevation = Utils.optionalInt(value, min: 0, max: 24),
      'elevationShadowColor': (value) =>
          elevationShadowColor = Utils.getColor(value),
      'elevationBorderRadius': (value) =>
          elevationBorderRadius = Utils.getBorderRadius(value),
      'alignment': (value) => alignment = Utils.getAlignment(value),
      'stackPositionTop': (value) =>
          stackPositionTop = Utils.optionalInt(value),
      'stackPositionBottom': (value) =>
          stackPositionBottom = Utils.optionalInt(value),
      'stackPositionLeft': (value) =>
          stackPositionLeft = Utils.optionalInt(value),
      'stackPositionRight': (value) =>
          stackPositionRight = Utils.optionalInt(value),
      'captureWebPointer': (value) =>
          captureWebPointer = Utils.optionalBool(value),
      'label': (value) => label = Utils.optionalString(value),
      'description': (value) => description = Utils.optionalString(value),
      'labelHint': (value) => labelHint = Utils.optionalString(value),
    };
  }

  bool hasPositions() {
    return (stackPositionTop ??
            stackPositionBottom ??
            stackPositionLeft ??
            stackPositionRight) !=
        null;
  }

  @override
  Map<String, Function> methods() {
    return {};
  }
}

/// for Controllers that need Box properties
class EnsembleBoxController extends EnsembleWidgetController
    with HasBackgroundController, HasBorderController, HasPassThrough {
  EdgeInsets? margin;
  EdgeInsets? padding;

  int? width;
  int? height;

  Color? shadowColor;
  Offset? shadowOffset;
  int? shadowRadius;
  BlurStyle? shadowStyle;

  // some children like Image don't get clipped properly with Box's clipBehavior
  bool? clipContent;

  @override
  Map<String, Function> setters() {
    return Map<String, Function>.from(super.setters())
      ..addAll(hasBackgroundSetters())
      ..addAll(hasBorderSetters())
      ..addAll({
        // support short-hand notation margin: 10 5 10
        'margin': (value) => margin = Utils.optionalInsets(value),
        'padding': (value) => padding = Utils.optionalInsets(value),

        'width': (value) => width = Utils.optionalInt(value),
        'height': (value) => height = Utils.optionalInt(value),

        'shadowColor': (value) => shadowColor = Utils.getColor(value),
        'shadowOffset': (list) => shadowOffset = Utils.getOffset(list),
        'shadowRadius': (value) => shadowRadius = Utils.optionalInt(value),
        'shadowStyle': (value) => shadowStyle = Utils.getShadowBlurStyle(value),

        'clipContent': (value) => clipContent = Utils.optionalBool(value)
      });
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

  bool hasBoxShadow() =>
      shadowColor != null ||
      shadowOffset != null ||
      shadowRadius != null ||
      shadowStyle != null;
}
