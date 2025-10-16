/// This class contains helper controllers for our widgets.
import 'package:ensemble/controller/controller_mixins.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/framework/theme/theme_manager.dart';
import 'package:ensemble/model/transform_matrix.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/box_animation_composite.dart';
import 'package:ensemble/widget/helpers/tooltip_composite.dart';
import 'package:ensemble_ts_interpreter/errors.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../model/capabilities.dart';

/// Widget property that have nested properties should be extending this,
/// as this allows any setters on the nested properties to trigger changes
abstract class WidgetCompositeProperty with Invokable {
  WidgetCompositeProperty(this.widgetController);

  ChangeNotifier widgetController;

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

class BoxShadowComposite extends WidgetCompositeProperty {
  BoxShadowComposite(super.widgetController, {required Map inputs}) {
    color = inputs['color'];
    offset = inputs['offset'];
    blur = inputs['blur'];
    spread = inputs['spread'];
    blurStyle = inputs['blurStyle'];
  }

  Color? _color;

  set color(value) => _color = Utils.getColor(value);

  Offset? _offset;

  set offset(value) => _offset = Utils.getOffset(value);

  int? _blur;

  set blur(value) => _blur = Utils.optionalInt(value);

  int? _spread;

  set spread(value) => _spread = Utils.optionalInt(value);

  BlurStyle? _blurStyle;

  set blurStyle(value) => _blurStyle = BlurStyle.values.from(value);

  @override
  Map<String, Function> getters() => {};

  @override
  Map<String, Function> methods() => {};

  @override
  Map<String, Function> setters() {
    return {
      'color': (value) => color = value,
      'offset': (value) => offset = value,
      'blur': (value) => blur = value,
      'spread': (value) => spread = value,
      'blurStyle': (value) => blurStyle = value,
    };
  }

  BoxShadow getValue(context) {
    return BoxShadow(
        color: _color ?? ThemeManager().getShadowColor(context),
        offset: _offset ?? Offset.zero,
        blurRadius: (_blur ?? 0).toDouble(),
        spreadRadius: (_spread ?? 0).toDouble(),
        blurStyle: _blurStyle ?? BlurStyle.normal);
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
        decorationColor =
            styleWithFontFamily?.decorationColor ?? styleWithFontFamily?.color,
        decorationThickness = styleWithFontFamily?.decorationThickness,
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
  Color? decorationColor;
  double? decorationThickness;
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
      decorationColor: decorationColor ?? color, // Default to text color
      decorationThickness: decorationThickness,
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
      'decorationColor': (value) => decorationColor = Utils.getColor(value),
      'decorationThickness': (value) =>
          decorationThickness = Utils.optionalDouble(value),
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

enum FlexMode {
  expanded, // default
  flexible,
  none,
}

/// TODO: Legacy, transition to [EnsembleWidgetController]
/// base Controller class for your Ensemble widget
abstract class WidgetController extends Controller with HasStyles {
  // Note: we manage these here so the user doesn't need to do in their widgets
  // base properties applicable to all widgets

  FlexMode? flexMode;
  int? flex;
  @Deprecated("use flexLayout/flex instead")
  bool expanded = false;

  bool? visible;
  Duration? visibilityTransitionDuration; // in seconds

  double? opacity;

  TextDirection? textDirection;

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

  // properties for tooltip
  Map<String, dynamic>? toolTip;

  EnsembleSemantics? semantics;
  // legacy used to show as the form label if used inside Form
  @Deprecated("don't use anymore")
  String? label;
  String? _testId;

  String? get testId {
    String? _ = _testId ?? id;
    return _;
  }

  set testId(value) => _testId = value;

  /// Returns the best available label for semantics/aria-label accessibility.
  /// Widgets should set [label] if they want to participate in accessibility fallback.
  String? getSemanticsLabel() {
    if (semantics?.label != null && semantics!.label!.isNotEmpty) {
      return semantics!.label;
    }
    if (label != null && label!.isNotEmpty) {
      return label;
    }

    // Try to find a label by looking up the current value in the items
    try {
      // First, try to get the current value
      dynamic currentValue;

      // Try to access value property directly
      try {
        currentValue = (this as dynamic).maybeValue;
      } catch (e) {
        // Try getValue method
        try {
          currentValue = (this as dynamic).getValue();
        } catch (e) {
          // No value property found
          return null;
        }
      }

      if (currentValue == null) return null;

      // Now try to find the items and look up the label
      try {
        final items = (this as dynamic).items;
        if (items != null && items is List) {
          for (final item in items) {
            if (item is Map) {
              // Handle item as Map with value/label structure
              final itemValue = item['value'];
              final itemLabel = item['label'];

              // Compare values more robustly
              if (itemValue != null &&
                  (itemValue.toString() == currentValue.toString() ||
                      itemValue == currentValue)) {
                // Found matching item, return its label
                if (itemLabel != null && itemLabel.toString().isNotEmpty) {
                  return itemLabel.toString();
                }
                // If no label, use the value itself
                return currentValue.toString();
              }
            } else {
              // Handle custom objects
              try {
                // Try to access properties dynamically
                final itemValue = (item as dynamic).value;
                final itemLabel = (item as dynamic).label;

                // Compare values more robustly
                if (itemValue != null &&
                    (itemValue.toString() == currentValue.toString() ||
                        itemValue == currentValue)) {
                  // Found matching item, return its label
                  if (itemLabel != null && itemLabel.toString().isNotEmpty) {
                    // Check if the label is a translation key and translate it
                    final translatedLabel =
                        Utils.translate(itemLabel.toString(), null);
                    return translatedLabel;
                  }
                  // If no label, use the value itself
                  return currentValue.toString();
                }
              } catch (e) {
                // Try to access as simple value
                if (item != null &&
                    (item.toString() == currentValue.toString() ||
                        item == currentValue)) {
                  // Item is a simple value that matches, use it directly
                  return currentValue.toString();
                }
              }
            }
          }
        }
      } catch (e) {}

      return currentValue.toString();
    } catch (e) {
      return null;
    }
  }

  @override
  Map<String, Function> getBaseGetters() {
    return {
      'expanded': () => expanded,
      'visible': () => visible != false,
      'opacity': () => opacity,
      'className': () => className,
      'classList': () => classList,
      'testId': () => testId,
      'textDirection': () => textDirection,
    };
  }

  @override
  Map<String, Function> getBaseSetters() {
    return {
      'testId': (value) => testId = Utils.optionalString(value),
      'flexMode': (value) => flexMode = FlexMode.values.from(value),
      'flex': (value) => flex = Utils.optionalInt(value, min: 1),
      'expanded': (value) => expanded = Utils.getBool(value, fallback: false),
      'visible': (value) => visible = Utils.getBool(value, fallback: true),
      'opacity': (value) => opacity = Utils.optionalDouble(value, min: 0, max: 1),
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
      'textDirection': (value) => textDirection = Utils.getTextDirection(value),
      'label': (value) => label = Utils.optionalString(value),
      'classList': (value) => classList = value,
      'className': (value) => className = value,
      'tooltip': (value) => toolTip = Utils.getMap(value),
      'semantics': (value) => semantics = EnsembleSemantics.fromYaml(Utils.getMap(value)),
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

  Color? borderColor;
  int? borderWidth;
  EBorderRadius? borderRadius;
  LinearGradient? borderGradient;

  BoxShadowComposite? boxShadow;

  @Deprecated("use boxShadow")
  Color? shadowColor;
  @Deprecated("use boxShadow")
  Offset? shadowOffset;
  @Deprecated("use boxShadow")
  int? shadowRadius;
  @Deprecated("use boxShadow")
  BlurStyle? shadowStyle;

  // some children like Image don't get clipped properly with Box's clipBehavior
  bool? clipContent;

  BoxAnimationComposite? animation;
  Matrix4? transform;

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

      'boxShadow': (value) =>
          boxShadow = Utils.getBoxShadowComposite(this, value),

      'shadowColor': (value) => shadowColor = Utils.getColor(value),
      'shadowOffset': (list) => shadowOffset = Utils.getOffset(list),
      'shadowRadius': (value) => shadowRadius = Utils.optionalInt(value),
      'shadowStyle': (value) => shadowStyle = Utils.getShadowBlurStyle(value),

      'clipContent': (value) => clipContent = Utils.optionalBool(value),
      'animation': (payload) =>
          animation = BoxAnimationComposite.from(this, payload),
      'transform': (value) => transform = TransformMatrix.from(value)
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
      boxShadow != null ||
      shadowColor != null ||
      shadowOffset != null ||
      shadowRadius != null ||
      shadowStyle != null;
}

class TapEnabledBoxController extends BoxController with TapEnabled {
  @override
  Map<String, Function> getBaseSetters() => {
        ...super.getBaseSetters(),
        'onTap': (action) => onTap = EnsembleAction.from(action),
        'onLongPress': (action) => onLongPress = EnsembleAction.from(action),
        'enableSplashFeedback': (value) => enableSplashFeedback =
            Utils.getBool(value, fallback: enableSplashFeedback),
        'splashColor': (color) => splashColor = Utils.getColor(color),
        'splashDuration': (value) =>
            splashDuration = Utils.getDurationMs(value),
        'splashFadeDuration': (value) =>
            splashFadeDuration = Utils.getDurationMs(value),
        'unconfirmedSplashDuration': (value) =>
            unconfirmedSplashDuration = Utils.getDurationMs(value),
        'focusColor': (color) => focusColor = Utils.getColor(color),
        'hoverColor': (color) => hoverColor = Utils.getColor(color),
      };
}

/// Base Widget Controller
abstract class EnsembleWidgetController extends EnsembleController
    with HasStyles {
  FlexMode? flexMode;
  int? flex;

  bool? visible;
  Duration? visibilityTransitionDuration; // in seconds

  double? opacity;

  TextDirection? textDirection;

  int? elevation;
  Color? elevationShadowColor;
  EBorderRadius? elevationBorderRadius;

  @override
  String? id; // do we need this?

  String? _testId;

  String? get testId {
    String? _ = _testId ?? id;
    return _;
  }

  set testId(value) => _testId = value;

  // wrap widget inside an Align widget
  Alignment? alignment;

  int? stackPositionTop;
  int? stackPositionBottom;
  int? stackPositionLeft;
  int? stackPositionRight;

  // https://pub.dev/packages/pointer_interceptor
  bool? captureWebPointer;

  // properties for tooltip
  Map<String, dynamic>? toolTip;

  EnsembleSemantics? semantics;

  @override
  Map<String, Function> getters() {
    return {
      'visible': () => visible != false,
      'opacity': () => opacity,
      'className': () => className,
      'classList': () => classList,
      'testId': () => testId,
      'textDirection': () => textDirection,
    };
  }

  @override
  Map<String, Function> setters() {
    return {
      'testId': (value) => testId = Utils.optionalString(value),
      'flexMode': (value) => flexMode = FlexMode.values.from(value),
      'flex': (value) => flex = Utils.optionalInt(value, min: 1),
      'visible': (value) => visible = Utils.getBool(value, fallback: true),
      'opacity': (value) => opacity = Utils.optionalDouble(value, min: 0, max: 1),
      'visibilityTransitionDuration': (value) =>
          visibilityTransitionDuration = Utils.getDuration(value),
      'textDirection': (value) => textDirection = Utils.getTextDirection(value),
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
      'classList': (value) => classList = value,
      'className': (value) => className = value,
      'tooltip': (value) => toolTip = Utils.getMap(value),
      'semantics': (value) => semantics = EnsembleSemantics.fromYaml(Utils.getMap(value)),
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

  BoxShadowComposite? boxShadow;

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

        'boxShadow': (value) =>
            boxShadow = Utils.getBoxShadowComposite(this, value),

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
      hasBackground() ||
      hasBorder() ||
      borderRadius != null ||
      boxShadow != null;
}

class EnsembleSemantics {
  bool focusable;
  String? label;
  String? hint;
  String? role;

  EnsembleSemantics(
      {this.label, this.hint, this.role, required this.focusable});

  // Factory constructor to map from YAML
  factory EnsembleSemantics.fromYaml(Map<String, dynamic>? yamlMap) {
    return EnsembleSemantics(
      focusable: Utils.optionalBool(yamlMap!['focusable']) ?? true,
      label: Utils.optionalString(yamlMap['label']) ?? '',
      hint: Utils.optionalString(yamlMap['hint']) ?? '',
      role: Utils.optionalString(yamlMap['role']) ?? '',
    );
  }
}
