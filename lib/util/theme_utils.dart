import 'package:flutter/material.dart';

/// Utils for managing theme
/// Theme is finicky. There are multiple layers of theme settings, so if you
/// don't have a value don't set it, otherwise it'll overwrite the previous layer.
/// Also try not to use any default value here for the same reasons.
class ThemeUtils {

  /// Border requires all attributes to be set
  static OutlineInputBorder getInputBoxBorder({required Color borderColor, required int borderRadius}) {
    return OutlineInputBorder(
        borderSide: BorderSide(color: borderColor),
        borderRadius: BorderRadius.all(Radius.circular(borderRadius.toDouble()))
    );
  }
  static UnderlineInputBorder getInputUnderlineBorder({required Color borderColor}) {
    return UnderlineInputBorder(
      borderSide: BorderSide(color: borderColor)
    );
  }


  /// this function is also called while building the button, so make sure we don't use any fallback
  /// to ensure the style reverts to the button theming
  static ButtonStyle getButtonStyle({required bool isOutline, Color? backgroundColor, Color? color, RoundedRectangleBorder? border, EdgeInsets? padding, FontWeight? fontWeight, int? fontSize,double? buttonWidth,double? buttonHeight}) {
    TextStyle? textStyle;
    if (fontWeight != null || fontSize != null) {
      textStyle = TextStyle(
        fontWeight: fontWeight,
        fontSize: fontSize?.toDouble()
      );
    }

    if (isOutline) {
      return TextButton.styleFrom(
        padding: padding,
        fixedSize: Size(buttonWidth??Size.infinite.width, buttonHeight??Size.infinite.height),
        primary: color,
        shape: border,
        textStyle: textStyle
      );
    } else {
      return ElevatedButton.styleFrom(
        padding: padding,
        fixedSize: Size(buttonWidth??Size.infinite.width, buttonHeight??Size.infinite.height),
        primary: backgroundColor,
        onPrimary: color,
        shape: border,
        textStyle: textStyle
      );
    }

  }
}