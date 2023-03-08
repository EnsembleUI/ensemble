

import 'package:ensemble/framework/theme/theme_manager.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';

mixin ThemeLoader {

  /// Ensemble's default light color scheme
  final ColorScheme _defaultColorScheme = const ColorScheme.light(
    primary: Color(0xff1565c0),
    onPrimary: Color(0xffffffff),
    primaryContainer: Color(0xff90caf9),
    onPrimaryContainer: Color(0xff192228),
    secondary: Color(0xff039be5),
    onSecondary: Color(0xffffffff),
    secondaryContainer: Color(0xffcbe6ff),
    onSecondaryContainer: Color(0xff222728),
    tertiary: Color(0xff0277bd),
    onTertiary: Color(0xffffffff),
    tertiaryContainer: Color(0xffbedcff),
    onTertiaryContainer: Color(0xff202528),
    error: Color(0xffb00020),
    onError: Color(0xffffffff),
    errorContainer: Color(0xfffcd8df),
    onErrorContainer: Color(0xff282526),
    outline: Color(0xff5c5c62),
    background: Color(0xffecf2fa),
    onBackground: Color(0xff121213),
    surface: Color(0xfff5f8fc),
    onSurface: Color(0xff090909),
    surfaceVariant: Color(0xffecf2fa),
    onSurfaceVariant: Color(0xff121213),
    inverseSurface: Color(0xff111417),
    onInverseSurface: Color(0xfff5f5f5),
    inversePrimary: Color(0xffaedfff),
    shadow: Color(0xff000000),
  );

  /// Ensemble's default dark color scheme. TODO: it's the same as light :)
  final ColorScheme _defaultDarkColorScheme = const ColorScheme.dark(
    primary: Color(0xff1565c0),
    onPrimary: Color(0xffffffff),
    primaryContainer: Color(0xff90caf9),
    onPrimaryContainer: Color(0xff192228),
    secondary: Color(0xff039be5),
    onSecondary: Color(0xffffffff),
    secondaryContainer: Color(0xffcbe6ff),
    onSecondaryContainer: Color(0xff222728),
    tertiary: Color(0xff0277bd),
    onTertiary: Color(0xffffffff),
    tertiaryContainer: Color(0xffbedcff),
    onTertiaryContainer: Color(0xff202528),
    error: Color(0xffb00020),
    onError: Color(0xffffffff),
    errorContainer: Color(0xfffcd8df),
    onErrorContainer: Color(0xff282526),
    outline: Color(0xff5c5c62),
    background: Color(0xffecf2fa),
    onBackground: Color(0xff121213),
    surface: Color(0xfff5f8fc),
    onSurface: Color(0xff090909),
    surfaceVariant: Color(0xffecf2fa),
    onSurfaceVariant: Color(0xff121213),
    inverseSurface: Color(0xff111417),
    onInverseSurface: Color(0xfff5f5f5),
    inversePrimary: Color(0xffaedfff),
    shadow: Color(0xff000000),
  );

  /// Ensemble's fallback default values. These will be used
  /// if certain theme is not specified
  /// TODO: these should be deprecated
  final Color _disabledColor = Colors.black38;
  final Color _inputBorderColor = Color(0xFFBDBDBD);
  final Color _inputBorderDisabledColor = Colors.black12;
  final int _inputBorderRadius = 3;
  final EdgeInsets _buttonPadding = EdgeInsets.only(left: 15, top: 5, right: 15, bottom: 5);
  final int _buttonBorderRadius = 3;
  final Color _buttonBorderOutlineColor = Colors.black12;

  ThemeData getAppTheme(YamlMap? overrides) {

    ColorScheme colorScheme = _defaultColorScheme.copyWith(
        primary: Utils.getColor(overrides?['Colors']?['primary']),
        onPrimary: Utils.getColor(overrides?['Colors']?['onPrimary']),
        secondary: Utils.getColor(overrides?['Colors']?['secondary']),
        onSecondary: Utils.getColor(overrides?['Colors']?['onSecondary'])
    );

    ThemeData themeData = ThemeData(
      // color scheme
      colorScheme: colorScheme,
      // disabled inputs / button
      disabledColor: Utils.getColor(overrides?['Colors']?['disabled']) ?? _disabledColor,
      // toggleable inputs e.g. switch, checkbox
      toggleableActiveColor: colorScheme.secondary,

      // input theme (TextInput, Switch, Dropdown, ...)
      inputDecorationTheme: _buildInputTheme(
          overrides?['Widgets']?['Input'],
          colorScheme: colorScheme
      ),

      textTheme: _buildTextTheme(overrides?['Text']),

      //switchTheme: buildSwitchTheme(overrides?['Widgets']?['Switch']),

      // button themes
      textButtonTheme: TextButtonThemeData(style: _buildButtonTheme(
          overrides?['Widgets']?['Button'],
          isOutline: true,
          colorScheme: colorScheme)
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: _buildButtonTheme(
          overrides?['Widgets']?['Button'],
          isOutline: false,
          colorScheme: colorScheme)
      ),

    );

    // extends ThemeData
    return themeData.copyWith(
        extensions: [
          EnsembleThemeExtension(
            loadingScreenBackgroundColor: Utils.getColor(overrides?['Colors']?['loadingScreenBackgroundColor']),
            loadingScreenIndicatorColor: Utils.getColor(overrides?['Colors']?['loadingScreenIndicatorColor']),
          )
        ]
    );
  }

  TextTheme _buildTextTheme(YamlMap? textTheme) {
    return ThemeData.light().textTheme.copyWith(
      displayLarge: Utils.getTextStyle(textTheme?['displayLarge']),
      displayMedium: Utils.getTextStyle(textTheme?['displayMedium']),
      displaySmall: Utils.getTextStyle(textTheme?['displaySmall']),
      headlineLarge: Utils.getTextStyle(textTheme?['headlineLarge']),
      headlineMedium: Utils.getTextStyle(textTheme?['headlineMedium']),
      headlineSmall: Utils.getTextStyle(textTheme?['headlineSmall']),
      titleLarge: Utils.getTextStyle(textTheme?['titleLarge']),
      titleMedium: Utils.getTextStyle(textTheme?['titleMedium']),
      titleSmall: Utils.getTextStyle(textTheme?['titleSmall']),
      bodyLarge: Utils.getTextStyle(textTheme?['bodyLarge']),
      bodyMedium: Utils.getTextStyle(textTheme?['bodyMedium']),
      bodySmall: Utils.getTextStyle(textTheme?['bodySmall']),
      labelLarge: Utils.getTextStyle(textTheme?['labelLarge']),
      labelMedium: Utils.getTextStyle(textTheme?['labelMedium']),
      labelSmall: Utils.getTextStyle(textTheme?['labelSmall']),
    );
  }



  /// parse the FormInput's theme from the theme YAML
  InputDecorationTheme? _buildInputTheme(YamlMap? input, {required ColorScheme colorScheme}) {
    Color focusColor = Utils.getColor(input?['focusColor']) ?? colorScheme.primary;
    Color borderColor = Utils.getColor(input?['borderColor']) ?? _inputBorderColor;
    Color disabledColor = Utils.getColor(input?['borderDisabledColor']) ?? _inputBorderDisabledColor;
    Color errorColor = Utils.getColor(input?['borderErrorColor']) ?? colorScheme.error;
    Color backgroundColor = Utils.getColor(input?['backgroundColor']) ?? Colors.transparent;

    if (input?['variant'] == 'box') {
      return _getInputBoxDecoration(
          focusColor: focusColor,
          borderColor: borderColor,
          disabledColor: disabledColor,
          errorColor: errorColor,
          backgroundColor: backgroundColor,
          borderRadius: Utils.optionalInt(input?['borderRadius']) ?? _inputBorderRadius);
    } else {
      return _getInputUnderlineDecoration(
          focusColor: focusColor,
          borderColor: borderColor,
          disabledColor: disabledColor,
          backgroundColor: backgroundColor,
          errorColor: errorColor);
    }
  }
  InputDecorationTheme _getInputBoxDecoration({required Color focusColor, required Color borderColor, required Color disabledColor, required Color errorColor, required int borderRadius , required Color backgroundColor}) {
    return InputDecorationTheme(
      focusedBorder: getInputBoxBorder(
        borderColor: focusColor,
        borderRadius: borderRadius,
      ),
      enabledBorder: getInputBoxBorder(
        borderColor: borderColor,
        borderRadius: borderRadius,
      ),
      errorBorder: getInputBoxBorder(
          borderColor: errorColor,
          borderRadius: borderRadius),
      focusedErrorBorder: getInputBoxBorder(
          borderColor: errorColor,
          borderRadius: borderRadius),
      disabledBorder: getInputBoxBorder(
        borderColor: disabledColor,
        borderRadius: borderRadius,
      ),
      isDense: true,
      filled: true,
      fillColor: backgroundColor,
      contentPadding: const EdgeInsets.all(10),
    );
  }
  InputDecorationTheme _getInputUnderlineDecoration({required Color focusColor, required Color borderColor, required Color errorColor, required Color disabledColor, required Color backgroundColor}) {
    return InputDecorationTheme(
        focusedBorder: getInputUnderlineBorder(borderColor: focusColor),
        enabledBorder: getInputUnderlineBorder(borderColor: borderColor),
        disabledBorder: getInputUnderlineBorder(borderColor: disabledColor),
        errorBorder:  getInputUnderlineBorder(borderColor: errorColor),
        focusedErrorBorder: getInputUnderlineBorder(borderColor: errorColor),
        isDense: false,
        contentPadding: EdgeInsets.zero,
        filled: true,
        fillColor: backgroundColor
    );
  }

  ButtonStyle? _buildButtonTheme(YamlMap? input, {required ColorScheme colorScheme, required bool isOutline}) {
    // outline button can simply use backgroundColor as borderColor (if not set)
    Color? borderColor = Utils.getColor(input?['borderColor']);
    if (borderColor == null && isOutline) {
      borderColor = Utils.getColor(input?['backgroundColor']) ?? _buttonBorderOutlineColor;
    }

    // outline button ignores backgroundColor
    Color? backgroundColor = isOutline ? null : Utils.getColor(input?['backgroundColor']);

    RoundedRectangleBorder border = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
            Utils.getInt(input?['borderRadius'], fallback: _buttonBorderRadius).toDouble()),
        side: borderColor == null ? BorderSide.none : BorderSide(
            color: borderColor,
            width: Utils.getInt(input?['borderWidth'], fallback: 1).toDouble()
        )
    );

    return getButtonStyle(
      isOutline: isOutline,
      backgroundColor: backgroundColor,
      color: Utils.getColor(input?['color']),
      border: border,
      padding: Utils.optionalInsets(input?['padding']) ?? _buttonPadding,
    );
  }

  SwitchThemeData buildSwitchTheme(YamlMap? input) {
    return const SwitchThemeData();
  }

  /// Border requires all attributes to be set
  OutlineInputBorder getInputBoxBorder({required Color borderColor, required int borderRadius}) {
    return OutlineInputBorder(
        borderSide: BorderSide(color: borderColor),
        borderRadius: BorderRadius.all(Radius.circular(borderRadius.toDouble()))
    );
  }
  UnderlineInputBorder getInputUnderlineBorder({required Color borderColor}) {
    return UnderlineInputBorder(
        borderSide: BorderSide(color: borderColor)
    );
  }


  /// this function is also called while building the button, so make sure we don't use any fallback
  /// to ensure the style reverts to the button theming
  ButtonStyle getButtonStyle({required bool isOutline, Color? backgroundColor, Color? color, RoundedRectangleBorder? border, EdgeInsets? padding, FontWeight? fontWeight, int? fontSize,double? buttonWidth,double? buttonHeight}) {
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


/// extend Theme to add our own special color parameters
class EnsembleThemeExtension extends ThemeExtension<EnsembleThemeExtension> {
  EnsembleThemeExtension({
    this.loadingScreenBackgroundColor,
    this.loadingScreenIndicatorColor
  });

  final Color? loadingScreenBackgroundColor;
  final Color? loadingScreenIndicatorColor;

  @override
  ThemeExtension<EnsembleThemeExtension> copyWith({
    Color? loadingScreenBackgroundColor,
    Color? loadingScreenIndicatorColor
  }) {
    return EnsembleThemeExtension(
        loadingScreenBackgroundColor: loadingScreenBackgroundColor ?? this.loadingScreenBackgroundColor,
        loadingScreenIndicatorColor: loadingScreenIndicatorColor ?? this.loadingScreenIndicatorColor
    );
  }

  @override
  ThemeExtension<EnsembleThemeExtension> lerp(ThemeExtension<EnsembleThemeExtension>? other, double t) {
    if (other is! EnsembleThemeExtension) {
      return this;
    }
    return EnsembleThemeExtension(
      loadingScreenBackgroundColor: Color.lerp(loadingScreenBackgroundColor, other.loadingScreenBackgroundColor, t),
      loadingScreenIndicatorColor: Color.lerp(loadingScreenIndicatorColor, other.loadingScreenIndicatorColor, t),
    );
  }
}

