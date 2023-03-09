

import 'package:ensemble/framework/model.dart';
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
    Color? fillColor = Utils.getColor(input?['fillColor']);
    InputDecorationTheme baseInputDecoration = InputDecorationTheme(
      // dense so user can control the contentPadding effectively
      isDense: true,
      filled: fillColor != null,
      fillColor: fillColor
    );

    EdgeInsets? contentPadding = Utils.optionalInsets(input?['contentPadding']);
    BorderRadius borderRadius = Utils.getBorderRadius(input?['borderRadius'])
        ?.getValue() ??
        const BorderRadius.all(Radius.circular(4));
    int borderWidth = Utils.optionalInt(input?['borderWidth']) ?? 1;

    Color? borderColor = Utils.getColor(input?['borderColor']);
    Color? enabledBorderColor = Utils.getColor(input?['enabledBorderColor']);
    Color? disabledBorderColor = Utils.getColor(input?['disabledBorderColor']);
    Color? errorBorderColor = Utils.getColor(input?['errorBorderColor']);
    Color? focusedBorderColor = Utils.getColor(input?['focusedBorderColor']);
    Color? focusedErrorBorderColor = Utils.getColor(input?['focusedErrorBorderColor']);


    if (input?['variant'] == 'box') {
      // we always need to set the base border since user can be setting other
      // values besides the color
      OutlineInputBorder baseBorder = OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(
              color: borderColor ??
                  (colorScheme.brightness == Brightness.light
                      ? Colors.black87
                      : Colors.white70),
              width: borderWidth.toDouble()));

      return baseInputDecoration.copyWith(
        contentPadding: contentPadding ?? const EdgeInsets.symmetric(vertical: 15, horizontal: 8),

        border: baseBorder,
        enabledBorder: _getOutlineInputBorder(
            borderColor: enabledBorderColor,
            borderWidth: borderWidth,
            borderRadius: borderRadius) ?? baseBorder,

        disabledBorder: _getOutlineInputBorder(
            borderColor: disabledBorderColor,
            borderWidth: borderWidth,
            borderRadius: borderRadius),
        errorBorder: _getOutlineInputBorder(
            borderColor: errorBorderColor,
            borderWidth: borderWidth,
            borderRadius: borderRadius),
        focusedBorder: _getOutlineInputBorder(
            borderColor: focusedBorderColor,
            borderWidth: borderWidth,
            borderRadius: borderRadius),
        focusedErrorBorder: _getOutlineInputBorder(
            borderColor: focusedErrorBorderColor,
            borderWidth: borderWidth,
            borderRadius: borderRadius),
      );
    } else {
      // base border needs to be filled
      UnderlineInputBorder baseBorder = UnderlineInputBorder(
          borderSide: BorderSide(
              color: borderColor ??
                  (colorScheme.brightness == Brightness.light
                      ? Colors.black87
                      : Colors.white70),
              width: borderWidth.toDouble()));
      return baseInputDecoration.copyWith(
        //contentPadding: contentPadding ?? const EdgeInsets.symmetric(vertical: 12, horizontal: 3),

        border: baseBorder,
        enabledBorder: _getUnderlineInputBorder(
          borderColor: enabledBorderColor,
          borderWidth: borderWidth) ?? baseBorder,

        disabledBorder: _getUnderlineInputBorder(
          borderColor: disabledBorderColor,
          borderWidth: borderWidth),
        errorBorder: _getUnderlineInputBorder(
            borderColor: errorBorderColor,
            borderWidth: borderWidth),
        focusedBorder: _getUnderlineInputBorder(
            borderColor: focusedBorderColor,
            borderWidth: borderWidth),
        focusedErrorBorder: _getUnderlineInputBorder(
            borderColor: focusedErrorBorderColor,
            borderWidth: borderWidth),
      );
    }
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
  OutlineInputBorder? _getOutlineInputBorder({Color? borderColor, required int borderWidth, required BorderRadius borderRadius}) {
    return borderColor == null
      ? null
      : OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(
            color: borderColor,
            width: borderWidth.toDouble()));
  }
  UnderlineInputBorder? _getUnderlineInputBorder({Color? borderColor, required int borderWidth}) {
    return borderColor == null
      ? null
      : UnderlineInputBorder(
          borderSide: BorderSide(
            color: borderColor,
            width: borderWidth.toDouble()));
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


  ///------------  publicly available theme getters -------------




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

