import 'package:ensemble/ensemble_theme.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/layout/layout_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as flutter;
import 'package:ensemble/util/utils.dart';

/// utility for our Widgets
class WidgetUtils {
  /// wrap our widget in a Box, which supports margin, padding, border, ...
  static Widget wrapInBox(Widget widget, BoxController boxController) {
    BorderRadius? borderRadius;
    Widget realWidget = widget;

    if (boxController.borderRadius != null) {
      borderRadius = boxController.borderRadius!.getValue();
      realWidget = ClipRRect(child: widget, borderRadius: borderRadius);
    }

    return Container(
        margin: boxController.margin,
        decoration: BoxDecoration(
            border: !boxController.hasBorder()
                ? null
                : Border.all(
                    color: boxController.borderColor ?? Colors.black26,
                    width: (boxController.borderWidth ?? 1).toDouble()),
            borderRadius: borderRadius),
        padding: boxController.padding,
        child: realWidget);
  }

  static BoxFit? getBoxFit(String? inputFit) {
    BoxFit? fit;
    switch (inputFit) {
      case 'fill':
        fit = BoxFit.fill;
        break;
      case 'contain':
        fit = BoxFit.contain;
        break;
      case 'cover':
        fit = BoxFit.cover;
        break;
      case 'fitWidth':
        fit = BoxFit.fitWidth;
        break;
      case 'fitHeight':
        fit = BoxFit.fitHeight;
        break;
      case 'none':
        fit = BoxFit.none;
        break;
      case 'scaleDown':
        fit = BoxFit.scaleDown;
        break;
    }
    return fit;
  }
}

class TextController extends WidgetController {
  String? text;
  String? font; // pre-defined font styles
  String? fontFamily;
  int? fontSize;
  FontWeight? fontWeight;
  Color? color;
  String? overflow;
  String? textAlign;
  String? textStyle;
  String? lineHeight;
}

class TextUtils {
  static void setStyles(Map styles, TextController controller) {
    Map<String, Function> setters = styleSetters(controller);
    styles.forEach((key, value) {
      if (setters.containsKey(key)) {
        if (setters[key] != null) {
          setters[key]!.call(value);
        }
      }
    });
  }

  static Map<String, Function> styleSetters(TextController _controller) {
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

  static flutter.Text buildText(TextController controller) {
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
    return flutter.Text(controller.text ?? '',
        textAlign: textAlign,
        overflow: textOverflow.overflow,
        maxLines: textOverflow.maxLine,
        softWrap: textOverflow.softWrap,
        style: flutter.TextStyle(
            decorationColor: flutter.Colors.blue,
            fontFamily: controller.fontFamily,
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

      // fade is not working correctly on web renderer. https://github.com/flutter/flutter/issues/71413
      // case 'fade':
      //   textOverflow = flutter.TextOverflow.fade;
      //   break;

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
