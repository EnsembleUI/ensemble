import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/theme/default_theme.dart';
import 'package:ensemble/framework/theme/theme_manager.dart';
import 'package:ensemble/framework/theme/theme_utils.dart';
import 'package:ensemble/model/text_scale.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';

mixin ThemeLoader {
  final EdgeInsets _buttonPadding =
      const EdgeInsets.only(left: 15, top: 5, right: 15, bottom: 5);
  final int _buttonBorderRadius = 8;
  final Color _buttonBorderOutlineColor = Colors.black12;

  /**
   * Build the App's theme based on the theme configuration
   */
  ThemeData getAppTheme(YamlMap? themeConfig) {
    var colorScheme = _getColorScheme(themeConfig);
    var baselineTheme = _getBaselineTheme(themeConfig);

    final themeData = baselineTheme.copyWith(
      useMaterial3: Utils.getBool(themeConfig?['material3'], fallback: true),
      colorScheme: colorScheme,
      disabledColor: Utils.getColor(themeConfig?['Colors']?['disabled']),
      inputDecorationTheme: _buildInputTheme(themeConfig?['Widgets']?['Input'],
          colorScheme: colorScheme),
      textButtonTheme: TextButtonThemeData(
          style: _buildButtonTheme(getProp(themeConfig, ['Widgets', 'Button']),
              baselineTheme: baselineTheme, isOutline: true)),
      filledButtonTheme: FilledButtonThemeData(
          style: _buildButtonTheme(getProp(themeConfig, ['Widgets', 'Button']),
              baselineTheme: baselineTheme, isOutline: false)),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(),
      switchTheme: const SwitchThemeData(),
      checkboxTheme: _buildCheckboxTheme(
          themeConfig?['Widgets']?['Checkbox'], colorScheme),
    );

    // extends ThemeData
    return themeData.copyWith(extensions: [
      EnsembleThemeExtension(
        appTheme: AppTheme(
            textScale: TextScale(
                enabled: Utils.optionalBool(
                    getProp(themeConfig, ['App', 'textScale', 'enabled'])),
                minFactor: Utils.optionalDouble(
                    getProp(themeConfig, ['App', 'textScale', 'minFactor']),
                    min: 0),
                maxFactor: Utils.optionalDouble(
                    getProp(themeConfig, ['App', 'textScale', 'maxFactor']),
                    min: 0))),
        loadingScreenBackgroundColor:
            Utils.getColor(themeConfig?['Screen']?['loadingBackgroundColor']) ??
                Utils.getColor(
                    themeConfig?['Colors']?['loadingScreenBackgroundColor']),
        loadingScreenIndicatorColor: Utils.getColor(
            themeConfig?['Colors']?['loadingScreenIndicatorColor']),
        transitions: Utils.getMap(themeConfig?['Transitions']),
      )
    ]);
  }

  /**
   * Generate a Color Scheme for our App based on the seed and/or specific Color functions
   */
  ColorScheme _getColorScheme(Map? themeConfig) {
    // generate Colors from seed if specified
    final seedColor = Utils.getColor(getProp(themeConfig, ['Colors', 'seed']));
    var colorScheme = seedColor == null
        ? defaultColorScheme
        : ColorScheme.fromSeed(seedColor: seedColor);

    // then further override with specific Color functions
    return colorScheme.copyWith(
      primary: Utils.getColor(getProp(themeConfig, ['Colors', 'primary'])),
      onPrimary: Utils.getColor(getProp(themeConfig, ['Colors', 'onPrimary'])),
      secondary: Utils.getColor(getProp(themeConfig, ['Colors', 'secondary'])),
      onSecondary:
          Utils.getColor(getProp(themeConfig, ['Colors', 'onSecondary'])),
    );
  }

  /**
   * return the baseline theme from the theme configuration.
   * We need this when overriding certain widgets/attributes
   */
  ThemeData _getBaselineTheme(Map? themeConfig) {
    final seedColor = Utils.getColor(getProp(themeConfig, ['Colors', 'seed']));

    return ThemeData(
      useMaterial3: true,
      colorScheme: seedColor == null
          ? defaultColorScheme
          : ColorScheme.fromSeed(seedColor: seedColor),
      scaffoldBackgroundColor:
          Utils.getColor(getProp(themeConfig, ['Screen', 'backgroundColor'])) ??
              DesignSystem.scaffoldBackgroundColor,
      appBarTheme: _getAppBarTheme(getProp(themeConfig, ['Screen'])),
      disabledColor: DesignSystem.disableColor,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DesignSystem.inputFillColor,
        iconColor: DesignSystem.inputIconColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide:
              BorderSide(color: DesignSystem.inputBorderColor, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide:
              BorderSide(color: DesignSystem.inputBorderColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: DesignSystem.inputErrorColor, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide:
              BorderSide(color: DesignSystem.inputBorderColor, width: 2),
        ),
      ),
      textTheme: _buildTextTheme(themeConfig?['Text']),
      // outlinedButtonTheme: OutlinedButtonThemeData(
      //   style: OutlinedButton.styleFrom(
      //     textStyle: const TextStyle(fontSize: 16),
      //     shape: RoundedRectangleBorder(
      //       borderRadius: BorderRadius.circular(8.0),
      //     ),
      //   ),
      // ),
      // textButtonTheme: TextButtonThemeData(
      //   style: TextButton.styleFrom(
      //     textStyle: const TextStyle(fontSize: 16),
      //   ),
      // ),
      // ,
      tabBarTheme: TabBarTheme(
        labelColor: DesignSystem.primary,
      ),
      tooltipTheme: const TooltipThemeData(
        textStyle: TextStyle(color: Colors.white),
        decoration: BoxDecoration(
          color: Colors.black,
        ),
      ),
    );
  }

  _resolveButtonTextStyle(ThemeData baselineTheme) {
    return baselineTheme.textTheme.labelLarge;
  }

  AppBarTheme? _getAppBarTheme(YamlMap? screenMap) {
    return AppBarTheme(
        foregroundColor: Utils.getColor(screenMap?['Header']?['color']),
        backgroundColor:
            Utils.getColor(screenMap?['Header']?['backgroundColor']),
        surfaceTintColor:
            Utils.getColor(screenMap?['Header']?['surfaceTintColor']),
        titleTextStyle:
            Utils.getTextStyle(screenMap?['Header']?['titleTextStyle']));
  }

  TextTheme _buildTextTheme([YamlMap? textTheme]) {
    final defaultThemeColor = ThemeManager().defaultTextColor();
    TextStyle defaultStyle =
        Utils.getTextStyle(textTheme)?.copyWith(color: defaultThemeColor) ??
            TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
                color: defaultThemeColor);

    var fontFamily = defaultStyle.fontFamily;

    return ThemeData.light()
        .textTheme
        .copyWith(
            displayLarge: Utils.getTextStyle(textTheme?['displayLarge']) ??
                defaultStyle.copyWith(fontSize: 64, letterSpacing: -2),
            displayMedium: Utils.getTextStyle(textTheme?['displayMedium']) ??
                defaultStyle.copyWith(fontSize: 48, letterSpacing: -1),
            displaySmall: Utils.getTextStyle(textTheme?['displaySmall']) ??
                defaultStyle.copyWith(fontSize: 32, letterSpacing: -0.5),
            headlineLarge: Utils.getTextStyle(textTheme?['headlineLarge']) ??
                defaultStyle.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5),
            headlineMedium: Utils.getTextStyle(textTheme?['headlineMedium']) ??
                defaultStyle.copyWith(
                    fontSize: 20, fontWeight: FontWeight.w600),
            headlineSmall: Utils.getTextStyle(textTheme?['headlineSmall']) ??
                defaultStyle.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.15),
            titleLarge: Utils.getTextStyle(textTheme?['titleLarge']) ??
                defaultStyle.copyWith(
                    fontSize: 20, fontWeight: FontWeight.w500),
            titleMedium: Utils.getTextStyle(textTheme?['titleMedium']) ??
                defaultStyle.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.15),
            titleSmall: Utils.getTextStyle(textTheme?['titleSmall']) ??
                defaultStyle.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.15),
            bodyLarge: Utils.getTextStyle(textTheme?['bodyLarge']) ??
                defaultStyle.copyWith(fontSize: 16, letterSpacing: 0.5),
            bodyMedium: Utils.getTextStyle(textTheme?['bodyMedium']) ??
                defaultStyle.copyWith(fontSize: 14, letterSpacing: 0.25),
            bodySmall: Utils.getTextStyle(textTheme?['bodySmall']) ??
                defaultStyle.copyWith(fontSize: 12, letterSpacing: 0.4),
            labelLarge: Utils.getTextStyle(textTheme?['labelLarge']) ??
                defaultStyle.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.4),
            labelMedium: Utils.getTextStyle(textTheme?['labelMedium']),
            labelSmall: Utils.getTextStyle(textTheme?['labelSmall']))
        .apply(fontFamily: defaultStyle.fontFamily);
  }

  /// parse the FormInput's theme from the theme YAML
  InputDecorationTheme? _buildInputTheme(YamlMap? input,
      {required ColorScheme colorScheme}) {
    if (input == null) return null;
    Color? fillColor = Utils.getColor(input['fillColor']);
    InputDecorationTheme baseInputDecoration = InputDecorationTheme(
      // dense so user can control the contentPadding effectively
      isDense: true,
      filled: fillColor != null,
      fillColor: fillColor,
      hintStyle: Utils.getTextStyle(input['hintStyle']),
    );

    InputVariant? variant = InputVariant.values.from(input['variant']);
    EdgeInsets? contentPadding = Utils.optionalInsets(input['contentPadding']);
    BorderRadius borderRadius =
        Utils.getBorderRadius(input['borderRadius'])?.getValue() ??
            getInputDefaultBorderRadius(variant);
    int borderWidth = Utils.optionalInt(input['borderWidth']) ?? 1;

    Color? borderColor = Utils.getColor(input['borderColor']);
    Color? disabledBorderColor = Utils.getColor(input['disabledBorderColor']);
    Color? errorBorderColor = Utils.getColor(input['errorBorderColor']);
    Color? focusedBorderColor = Utils.getColor(input['focusedBorderColor']);
    Color? focusedErrorBorderColor =
        Utils.getColor(input['focusedErrorBorderColor']);

    if (variant == InputVariant.box) {
      // we always need to set the base border since user can be setting other
      // values besides the color
      OutlineInputBorder baseBorder = OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(
              color: borderColor ??
                  (colorScheme.brightness == Brightness.light
                      ? Colors.black54
                      : Colors.white70),
              width: borderWidth.toDouble()));

      return baseInputDecoration.copyWith(
        contentPadding: contentPadding ??
            const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
        border: baseBorder,
        disabledBorder: getInputBorder(
            variant: variant,
            borderColor: disabledBorderColor,
            borderWidth: borderWidth,
            borderRadius: borderRadius),
        errorBorder: getInputBorder(
            variant: variant,
            borderColor: errorBorderColor,
            borderWidth: borderWidth,
            borderRadius: borderRadius),
        focusedBorder: getInputBorder(
            variant: variant,
            borderColor: focusedBorderColor,
            borderWidth: borderWidth,
            borderRadius: borderRadius),
        focusedErrorBorder: getInputBorder(
            variant: variant,
            borderColor: focusedErrorBorderColor,
            borderWidth: borderWidth,
            borderRadius: borderRadius),
      );
    } else {
      // base border needs to be filled
      UnderlineInputBorder baseBorder = UnderlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(
              color: borderColor ??
                  (colorScheme.brightness == Brightness.light
                      ? Colors.black87
                      : Colors.white70),
              width: borderWidth.toDouble()));
      return baseInputDecoration.copyWith(
        contentPadding: contentPadding ??
            const EdgeInsets.symmetric(vertical: 15, horizontal: 3),
        border: baseBorder,
        disabledBorder: getInputBorder(
            variant: variant,
            borderColor: disabledBorderColor,
            borderWidth: borderWidth,
            borderRadius: borderRadius),
        errorBorder: getInputBorder(
            variant: variant,
            borderColor: errorBorderColor,
            borderWidth: borderWidth,
            borderRadius: borderRadius),
        focusedBorder: getInputBorder(
            variant: variant,
            borderColor: focusedBorderColor,
            borderWidth: borderWidth,
            borderRadius: borderRadius),
        focusedErrorBorder: getInputBorder(
            variant: variant,
            borderColor: focusedErrorBorderColor,
            borderWidth: borderWidth,
            borderRadius: borderRadius),
      );
    }
  }

  ButtonStyle? _buildButtonTheme(YamlMap? input,
      {required ThemeData baselineTheme, required bool isOutline}) {
    // outline button can simply use backgroundColor as borderColor (if not set)
    Color? borderColor = Utils.getColor(input?['borderColor']);
    if (borderColor == null && isOutline) {
      borderColor = Utils.getColor(input?['backgroundColor']) ??
          _buttonBorderOutlineColor;
    }

    // outline button ignores backgroundColor
    Color? backgroundColor =
        isOutline ? null : Utils.getColor(input?['backgroundColor']);

    RoundedRectangleBorder border = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
            Utils.getInt(input?['borderRadius'], fallback: _buttonBorderRadius)
                .toDouble()),
        side: borderColor == null
            ? BorderSide.none
            : BorderSide(
                color: borderColor,
                width: Utils.getInt(input?['borderWidth'], fallback: 1)
                    .toDouble()));

    // labelStyle starts at Text->labelLarge and overriden at Widgets->Button
    var textStyle = Utils.getTextStyle(input?["labelStyle"]);
    var labelStyle = baselineTheme.textTheme.labelLarge?.merge(textStyle) ?? textStyle;

    var buttonStyle = _getButtonStyle(
        isOutline: isOutline,
        backgroundColor: backgroundColor,
        border: border,
        padding: Utils.optionalInsets(input?['padding']) ?? _buttonPadding,
        // this is important. This is the only way to get the fontFamily/textStyle
        // set at the theme Text's root or labelLarge (which maps to button label).
        // Also note that this is only important initially at the theme level.
        // Subsequently with the Context we will already fallback properly
        labelStyle: labelStyle);
    return buttonStyle;
  }

  InputBorder? getInputBorder(
      {InputVariant? variant,
      Color? borderColor,
      required int borderWidth,
      required BorderRadius borderRadius}) {
    if (borderColor != null) {
      if (variant == InputVariant.box) {
        return OutlineInputBorder(
            borderRadius: borderRadius,
            borderSide:
                BorderSide(color: borderColor, width: borderWidth.toDouble()));
      }
      // default is underline
      return UnderlineInputBorder(
          borderRadius: borderRadius,
          borderSide:
              BorderSide(color: borderColor, width: borderWidth.toDouble()));
    }
    return null;
  }

  ButtonStyle _getButtonStyle(
      {required bool isOutline,
      Color? backgroundColor,
      RoundedRectangleBorder? border,
      EdgeInsets? padding,
      TextStyle? labelStyle}) {
    if (isOutline) {
      return OutlinedButton.styleFrom(
          padding: padding,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: border,
          textStyle: labelStyle);
    } else {
      return FilledButton.styleFrom(
        backgroundColor: backgroundColor,
        padding: padding,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: border,
        textStyle: labelStyle,
      );
    }
  }

  CheckboxThemeData _buildCheckboxTheme(
      YamlMap? input, ColorScheme colorSchema) {
    Color borderColor =
        Utils.getColor(input?['borderColor']) ?? colorSchema.onSurface;
    Color? fillColor = Utils.getColor(input?["fillColor"]);
    Color? activeColor = Utils.getColor(input?["activeColor"]);
    Color? checkColor = Utils.getColor(input?["checkColor"]);
    int borderWidth = Utils.optionalInt(input?['borderWidth'], min: 0) ?? 2;

    var checkboxTheme = CheckboxThemeData(
      side: MaterialStateBorderSide.resolveWith((states) {
        if (states.contains(MaterialState.disabled)) {
          return BorderSide(
              width: borderWidth.toDouble(), color: DesignSystem.disableColor);
        }
        if (states.contains(MaterialState.error)) {
          return BorderSide(
              width: borderWidth.toDouble(),
              color: DesignSystem.inputErrorColor);
        }
        if (!states.contains(MaterialState.selected)) {
          return BorderSide(width: borderWidth.toDouble(), color: borderColor);
        }
        // use default
        return null;
      }),
      shape: RoundedRectangleBorder(
          borderRadius:
              Utils.getBorderRadius(input?['borderRadius'])?.getValue() ??
                  BorderRadius.circular(4)),
      checkColor: checkColor == null
          ? null
          : MaterialStateProperty.resolveWith<Color?>(
              (Set<MaterialState> states) {
              if (states.contains(MaterialState.disabled)) {
                return DesignSystem.disableColor;
              }
              return states.contains(MaterialState.selected)
                  ? checkColor
                  : null;
            }),
      fillColor: MaterialStateProperty.resolveWith<Color?>(
          (Set<MaterialState> states) {
        if (states.contains(MaterialState.selected)) {
          return activeColor;
        }
        // use the default color
        if (states.contains(MaterialState.error) ||
            states.contains(MaterialState.disabled)) {
          return null;
        }
        // fillColor if specified should be the same for most states
        return fillColor;
      }),
    );
    checkboxTheme.size = Utils.optionalInt(input?["size"]);
    return checkboxTheme;
  }

  ///------------  publicly available theme getters -------------
  BorderRadius getInputDefaultBorderRadius(InputVariant? variant) =>
      BorderRadius.all(Radius.circular(variant == InputVariant.box ? 8 : 0));
}

// add more data to checkbox theme
extension CheckboxThemeDataExtension on CheckboxThemeData {
  static int? _size;

  set size(int? value) => _size = value;

  int? get size => _size;
}

/// extend Theme to add our own special color parameters
class EnsembleThemeExtension extends ThemeExtension<EnsembleThemeExtension> {
  EnsembleThemeExtension(
      {this.appTheme,
      this.loadingScreenBackgroundColor,
      this.loadingScreenIndicatorColor,
      this.transitions});

  final AppTheme? appTheme;
  final Color? loadingScreenBackgroundColor;
  final Color? loadingScreenIndicatorColor; // should deprecate this
  final Map<String, dynamic>? transitions;

  @override
  ThemeExtension<EnsembleThemeExtension> copyWith(
      {Color? loadingScreenBackgroundColor,
      Color? loadingScreenIndicatorColor}) {
    return EnsembleThemeExtension(
        loadingScreenBackgroundColor:
            loadingScreenBackgroundColor ?? this.loadingScreenBackgroundColor,
        loadingScreenIndicatorColor:
            loadingScreenIndicatorColor ?? this.loadingScreenIndicatorColor);
  }

  @override
  ThemeExtension<EnsembleThemeExtension> lerp(
      ThemeExtension<EnsembleThemeExtension>? other, double t) {
    if (other is! EnsembleThemeExtension) {
      return this;
    }
    return EnsembleThemeExtension(
      loadingScreenBackgroundColor: Color.lerp(
          loadingScreenBackgroundColor, other.loadingScreenBackgroundColor, t),
      loadingScreenIndicatorColor: Color.lerp(
          loadingScreenIndicatorColor, other.loadingScreenIndicatorColor, t),
    );
  }
}

class AppTheme {
  AppTheme({this.textScale});

  TextScale? textScale;
}

class ScreenTheme {}

enum InputVariant { box, underline }

enum WidgetVariant { cupertino, material }
