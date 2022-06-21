import 'package:ensemble/ensemble_theme.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';

class ThemeUtils {

  /// parse the FormInput's theme from the theme YAML
  static InputDecorationTheme? buildFormInputTheme(dynamic input) {
    if (input is YamlMap) {
      if (input['variant'] == 'Box') {
        return getBoxInputDecoration(
          borderRadius: Utils.optionalInt(input['borderRadius']),
          disabledColor: Utils.getColor(input['disabledColor']));
      } else {
        return getUnderlineInputDecoration(
          disabledColor: Utils.getColor(input['disabledColor']));
      }
    }
    return null;
  }
  static InputDecorationTheme getBoxInputDecoration({int? borderRadius, Color? disabledColor}) {
    return InputDecorationTheme(
      border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(borderRadius?.toDouble() ?? EnsembleTheme.inputBorderRadius))),
      disabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: disabledColor ?? EnsembleTheme.inputDisabledColor)),
      isDense: true,
      contentPadding: const EdgeInsets.all(10),
    );
  }
  static InputDecorationTheme getUnderlineInputDecoration({Color? disabledColor}) {
    return InputDecorationTheme(
      border: const UnderlineInputBorder(),
      disabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: disabledColor ?? EnsembleTheme.inputDisabledColor)
      ),
      isDense: false,
      contentPadding: EdgeInsets.zero,
    );
  }


  static ButtonStyle? buildButtonTheme(dynamic input, {required bool isOutline}) {
    if (input is YamlMap) {
      return getButtonStyle(
        isOutline: isOutline,
        backgroundColor: Utils.getColor(input['backgroundColor']),
        borderColor: Utils.getColor(input['borderColor']),
        color: Utils.getColor(input['color']),
        borderRadius: Utils.optionalInt(input['borderRadius']),
        borderThickness: Utils.optionalInt(input['borderThickness']),
        padding: Utils.optionalInsets(input['padding']),
      );
    }
    return null;
  }
  /// this function is also called while building the button, so make sure we don't use any fallback
  /// to ensure the style reverts to the button theming
  static ButtonStyle getButtonStyle({required bool isOutline, Color? backgroundColor, Color? borderColor, Color? color, int? borderRadius, int? borderThickness, EdgeInsets? padding}) {
    // outline button ignores background color
    MaterialStateProperty<Color>? realBackgroundColor;
    if (backgroundColor != null && !isOutline) {
      realBackgroundColor = MaterialStateProperty.all<Color>(backgroundColor);
    }

    // outline button always have a border color
    Color? realBorderColor = borderColor;
    if (realBorderColor == null && isOutline) {
      realBorderColor = EnsembleTheme.buttonOutlineBorderColor;
    }

    BorderSide borderSide = realBorderColor == null && borderThickness == null ? BorderSide.none : BorderSide(
      color: realBorderColor ?? EnsembleTheme.buttonOutlineBorderColor,
      width: borderThickness?.toDouble() ?? 1
    );

    return ButtonStyle(
        padding: MaterialStateProperty.all<EdgeInsetsGeometry>(padding ?? EnsembleTheme.buttonPadding),
        foregroundColor: color != null ? MaterialStateProperty.all<Color>(color) : null,
        backgroundColor: realBackgroundColor,
        shape: MaterialStateProperty.all<RoundedRectangleBorder>(
            RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius?.toDouble() ?? EnsembleTheme.buttonBorderRadius),
                side: borderSide
            )
        )
    );

  }
}