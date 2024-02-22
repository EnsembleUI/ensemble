import 'package:ensemble/ensemble_theme.dart';
import 'package:ensemble/framework/ensemble_widget.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/framework/widget/custom_view.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as flutter;
import 'package:ensemble/util/utils.dart';
import 'package:google_fonts/google_fonts.dart';

/// utility for our Widgets
class WidgetUtils {
  /// check if an Ensemble widget is visible or not
  /// This is not a sure-fire approach - just trying our best
  static bool isVisible(Widget widget) {
    Widget view = widget;
    if (view is DataScopeWidget) {
      if (view.child is CustomView) {
        // Custom Widgets
        final CustomView customView = view.child as CustomView;
        // TODO: this logic is hosed since body is now just the model.
        // TODO: But then we shouldn't be reaching in like this anyway
        // view = customView.body;
        return true;
      } else {
        // Native Widgets like Button, Text
        view = view.child;
      }
    }

    final isWidgetController =
        view is HasController && (view.controller is WidgetController);
    if (isWidgetController) {
      final visibleChild = (view.controller as WidgetController).visible;
      return visibleChild;
    }
    // new widget renderer
    if (view is EnsembleWidget && view.controller is EnsembleWidgetController) {
      return (view.controller as EnsembleWidgetController).visible;
    }
    return false;
  }

  /// check if a widget is an Expanded or Flexible
  static bool isExpandedOrFlexible(Widget widget) {
    if (widget is HasController) {
      if (widget.controller is WidgetController) {
        return (widget.controller as WidgetController).flex != null ||
            (widget.controller as WidgetController).flexMode != null ||
            (widget.controller as WidgetController).expanded;
      }
      if (widget.controller is EnsembleWidgetController) {
        return (widget.controller as EnsembleWidgetController).flex != null ||
            (widget.controller as EnsembleWidgetController).flexMode != null;
      }
    }
    return false;
  }
}

class GenericTextController extends BoxController {
  // set from caller
  String? text;
  String? textAlign;

  String? overflow;
  int? maxLines;

  // use our setters
  String? font; // pre-defined font styles
  String? fontFamily;
  int? fontSize;
  FontWeight? fontWeight;
  Color? color;
  String? lineHeight;
  String? textStyle;
}

class TextUtils {
  static void setStyles(Map styles, GenericTextController controller) {
    Map<String, Function> setters = styleSetters(controller);
    styles.forEach((key, value) {
      if (setters.containsKey(key)) {
        if (setters[key] != null) {
          setters[key]!.call(value);
        }
      }
    });
  }

  static Map<String, Function> styleSetters(GenericTextController _controller) {
    return {
      'font': (value) => _controller.font = Utils.optionalString(value),
      'fontFamily': (value) =>
          _controller.fontFamily = Utils.optionalString(value),
      'fontSize': (value) => _controller.fontSize = Utils.optionalInt(value),
      'fontWeight': (value) =>
          _controller.fontWeight = Utils.getFontWeight(value),
      'color': (value) => _controller.color = Utils.getColor(value),
      'lineHeight': (value) =>
          _controller.lineHeight = Utils.optionalString(value),
      'textStyle': (value) =>
          _controller.textStyle = Utils.optionalString(value),
    };
  }

  static flutter.Text buildText(GenericTextController controller) {
    FontWeight? fontWeight;
    double? fontSize;
    Color? fontColor;

    // built-in font
    if (controller.font == 'heading') {
      fontWeight = FontWeight.w600;
      fontSize = 24;
      fontColor = EnsembleTheme.darkerText;
    } else if (controller.font == 'title') {
      fontWeight = FontWeight.w600;
      fontSize = 22;
      fontColor = EnsembleTheme.darkerText;
    } else if (controller.font == 'subtitle') {
      fontWeight = FontWeight.w500;
      fontSize = 16;
      fontColor = EnsembleTheme.grey;
    }

    if (controller.fontSize != null) {
      fontSize = controller.fontSize!.toDouble();
    }
    if (controller.fontWeight != null) {
      fontWeight = controller.fontWeight;
    }
    if (controller.color != null) {
      fontColor = controller.color!;
    }

    TextOverflow textOverflow = TextOverflow.from(controller.overflow);

    TextAlign? textAlign;
    switch (controller.textAlign) {
      case 'start':
        textAlign = TextAlign.start;
        break;
      case 'end':
        textAlign = TextAlign.end;
        break;
      case 'center':
        textAlign = TextAlign.center;
        break;
      case 'justify':
        textAlign = TextAlign.justify;
        break;
    }

    FontStyle? fontStyle;
    TextDecoration? textDecoration;
    switch (controller.textStyle) {
      case 'italic':
        fontStyle = FontStyle.italic;
        break;
      case 'underline':
        textDecoration = TextDecoration.underline;
        break;
      case 'strikethrough':
        textDecoration = TextDecoration.lineThrough;
        break;
      case 'italic_underline':
        fontStyle = FontStyle.italic;
        textDecoration = TextDecoration.underline;
        break;
      case 'italic_strikethrough':
        fontStyle = FontStyle.italic;
        textDecoration = TextDecoration.lineThrough;
        break;
    }

    // Note: default should be null, as it may not be 1.0 depending on fonts
    double? lineHeight;
    switch (controller.lineHeight) {
      case '1.0':
        lineHeight = 1;
        break;
      case '1.15':
        lineHeight = 1.15;
        break;
      case '1.25':
        lineHeight = 1.25;
        break;
      case '1.5':
        lineHeight = 1.5;
        break;
      case '2.0':
        lineHeight = 2;
        break;
      case '2.5':
        lineHeight = 2.5;
        break;
    }

    var textStyle = const TextStyle();

    try {
      if (controller.fontFamily != null) {
        textStyle = GoogleFonts.getFont(controller.fontFamily!.trim(),
            color: Colors.black);
      }
    } catch (_) {}

    return flutter.Text(controller.text ?? '',
        textAlign: textAlign,
        overflow: textOverflow.overflow,
        maxLines: controller.maxLines ?? textOverflow.maxLine,
        softWrap: textOverflow.softWrap,
        style: textStyle.copyWith(
            decorationColor: flutter.Colors.blue,
            fontWeight: fontWeight,
            fontStyle: fontStyle,
            decoration: textDecoration,
            fontSize: fontSize,
            color: fontColor,
            height: lineHeight));
  }
}

class TextOverflow {
  TextOverflow(this.overflow, this.maxLine, this.softWrap);

  flutter.TextOverflow? overflow;
  int? maxLine = 1;
  bool? softWrap = false;

  static TextOverflow from(String? overflow) {
    flutter.TextOverflow? textOverflow;
    int? maxLine = 1;
    bool? softWrap = false;
    switch (overflow) {
      case 'visible':
        textOverflow = flutter.TextOverflow.visible;
        break;
      case 'clip':
        textOverflow = flutter.TextOverflow.clip;
        break;
      // NOTE: fade is not working correctly on web renderer. https://github.com/flutter/flutter/issues/71413
      case 'fade':
        textOverflow = flutter.TextOverflow.fade;
        break;
      case 'ellipsis':
        textOverflow = flutter.TextOverflow.ellipsis;
        break;
      case 'wrap':
      default:
        textOverflow = null;
        maxLine = null;
        softWrap = null;
    }
    return TextOverflow(textOverflow, maxLine, softWrap);
  }
}
