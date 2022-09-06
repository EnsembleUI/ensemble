import 'package:ensemble/util/theme_utils.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';

class EnsembleTheme {

  static ThemeData getAppTheme(YamlMap? overrides) {
    ColorScheme colorScheme = _defaultColorScheme.copyWith(
        primary: Utils.getColor(overrides?['Colors']?['primary']),
        onPrimary: Utils.getColor(overrides?['Colors']?['onPrimary']),
        secondary: Utils.getColor(overrides?['Colors']?['secondary']),
        onSecondary: Utils.getColor(overrides?['Colors']?['onSecondary'])
    );

    return ThemeData(
      // color scheme
      colorScheme: colorScheme,
      // disabled inputs / button
      disabledColor: Utils.getColor(overrides?['Colors']?['disabled']) ?? _disabledColor,
      // toggleable inputs e.g. switch, checkbox
      toggleableActiveColor: colorScheme.secondary,

      // input theme (TextInput, Switch, Dropdown, ...)
      inputDecorationTheme: _buildInputTheme(
        overrides?['Widgets']?['Input'],
        primaryColor: colorScheme.primary
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
  }

  /// Ensemble default color scheme
  static const ColorScheme _defaultColorScheme = ColorScheme(
    brightness: Brightness.light,
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
  static const Color _disabledColor = Colors.black38;
  static const Color _inputBorderColor = Color(0xFFBDBDBD);
  static const Color _inputBorderDisabledColor = Colors.black12;
  static const int _inputBorderRadius = 3;
  static const EdgeInsets _buttonPadding = EdgeInsets.only(left: 15, top: 5, right: 15, bottom: 5);
  static const int _buttonBorderRadius = 3;
  static const Color _buttonBorderOutlineColor = Colors.black12;



  static TextTheme _buildTextTheme(YamlMap? textTheme) {
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
  static InputDecorationTheme? _buildInputTheme(YamlMap? input, {required Color primaryColor}) {
    Color focusColor = Utils.getColor(input?['focusColor']) ?? primaryColor;
    Color borderColor = Utils.getColor(input?['borderColor']) ?? _inputBorderColor;
    Color disabledColor = Utils.getColor(input?['borderDisabledColor']) ?? _inputBorderDisabledColor;

    if (input?['variant'] == 'box') {
      return _getInputBoxDecoration(
        focusColor: focusColor,
        borderColor: borderColor,
        disabledColor: disabledColor,
        borderRadius: Utils.optionalInt(input?['borderRadius']) ?? _inputBorderRadius);
    } else {
      return _getInputUnderlineDecoration(
        focusColor: focusColor,
        borderColor: borderColor,
        disabledColor: disabledColor);
    }
  }
  static InputDecorationTheme _getInputBoxDecoration({required Color focusColor, required Color borderColor, required Color disabledColor, required int borderRadius}) {
    return InputDecorationTheme(
      focusedBorder: ThemeUtils.getInputBoxBorder(
        borderColor: focusColor,
        borderRadius: borderRadius,
      ),
      enabledBorder: ThemeUtils.getInputBoxBorder(
        borderColor: borderColor,
        borderRadius: borderRadius,
      ),
      disabledBorder: ThemeUtils.getInputBoxBorder(
        borderColor: disabledColor,
        borderRadius: borderRadius,
      ),
      isDense: true,
      contentPadding: const EdgeInsets.all(10),
    );
  }
  static InputDecorationTheme _getInputUnderlineDecoration({required Color focusColor, required Color borderColor, required Color disabledColor}) {
    return InputDecorationTheme(
      focusedBorder: ThemeUtils.getInputUnderlineBorder(borderColor: focusColor),
      enabledBorder: ThemeUtils.getInputUnderlineBorder(borderColor: borderColor),
      disabledBorder: ThemeUtils.getInputUnderlineBorder(borderColor: disabledColor),
      isDense: false,
      contentPadding: EdgeInsets.zero,
    );
  }


  static ButtonStyle? _buildButtonTheme(YamlMap? input, {required ColorScheme colorScheme, required bool isOutline}) {
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

    return ThemeUtils.getButtonStyle(
      isOutline: isOutline,
      backgroundColor: backgroundColor,
      color: Utils.getColor(input?['color']),
      border: border,
      padding: Utils.optionalInsets(input?['padding']) ?? _buttonPadding,
    );
  }

  static SwitchThemeData buildSwitchTheme(YamlMap? input) {
    return const SwitchThemeData();
  }














  /// legacy stuff
  static const Color notWhite = Color(0xFFEDF0F2);
  static const Color nearlyWhite = Color(0xFFFFFFFF);
  static const Color nearlyBlue = Color(0xFF00B6F0);
  static const Color nearlyBlack = Color(0xFF213333);
  static const Color grey = Color(0xFF3A5160);
  static const Color dark_grey = Color(0xFF313A44);

  static const Color darkText = Color(0xFF253840);
  static const Color darkerText = Color(0xFF17262A);
  static const Color lightText = Color(0xFF4A6572);
  static const Color deactivatedText = Color(0xFF767676);
  static const Color dismissibleBackground = Color(0xFF364A54);
  static const Color chipBackground = Color(0xFFEEF1F3);
  static const Color spacer = Color(0xFFF2F2F2);


  static ThemeData get lightTheme {
    return ThemeData(
        disabledColor: const Color(0xffE0E0E0),
    );
  }

  static ThemeData get payAppTheme {
    return ThemeData(
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: Color(0xFF08B48F),
        onPrimary: Colors.white,

        secondary: Color(0xFFED5742),
        onSecondary: Colors.white,

        error: Color(0xFFB00020),
        onError: Colors.white,

        background: Colors.white,
        onBackground: Color(0xFF404040),

        surface: Colors.white,
        onSurface: Color(0xFF404040)



      )
    );
  }



  static const TextTheme textTheme = TextTheme(
    headline4: display1,
    headline5: headline,
    headline6: title,
    subtitle2: subtitle,
    bodyText1: body2,
    bodyText2: body1,
    caption: caption,
  );

  static const TextStyle display1 = TextStyle(
    // h4 -> display1
    fontFamily: 'WorkSans',
    fontWeight: FontWeight.bold,
    fontSize: 36,
    letterSpacing: 0.4,
    height: 0.9,
    color: darkerText,
  );

  static const TextStyle headline = TextStyle(
    // h5 -> headline
    fontFamily: 'WorkSans',
    fontWeight: FontWeight.bold,
    fontSize: 24,
    letterSpacing: 0.27,
    color: darkerText,
  );

  static const TextStyle title = TextStyle(
    // h6 -> title
    fontFamily: 'WorkSans',
    fontWeight: FontWeight.bold,
    fontSize: 16,
    letterSpacing: 0.18,
    color: darkerText,
  );

  static const TextStyle subtitle = TextStyle(
    // subtitle2 -> subtitle
    fontFamily: 'WorkSans',
    fontWeight: FontWeight.w400,
    fontSize: 14,
    letterSpacing: -0.04,
    color: darkText,
  );

  static const TextStyle body2 = TextStyle(
    // body1 -> body2
    fontFamily: 'WorkSans',
    fontWeight: FontWeight.w400,
    fontSize: 14,
    letterSpacing: 0.2,
    color: darkText,
  );

  static const TextStyle body1 = TextStyle(
    // body2 -> body1
    fontFamily: 'WorkSans',
    fontWeight: FontWeight.w400,
    fontSize: 16,
    letterSpacing: -0.05,
    color: darkText,
  );

  static const TextStyle caption = TextStyle(
    // Caption -> caption
    fontFamily: 'WorkSans',
    fontWeight: FontWeight.w400,
    fontSize: 12,
    letterSpacing: 0.2,
    color: lightText, // was lightText
  );


  static TextTheme _buildTextThemeOld(TextTheme base) {
    const String fontName = 'WorkSans';
    return base.copyWith(
      headline1: base.headline1?.copyWith(fontFamily: fontName),
      headline2: base.headline2?.copyWith(fontFamily: fontName),
      headline3: base.headline3?.copyWith(fontFamily: fontName),
      headline4: base.headline4?.copyWith(fontFamily: fontName),
      headline5: base.headline5?.copyWith(fontFamily: fontName),
      headline6: base.headline6?.copyWith(fontFamily: fontName),
      button: base.button?.copyWith(fontFamily: fontName),
      caption: base.caption?.copyWith(fontFamily: fontName),
      bodyText1: base.bodyText1?.copyWith(fontFamily: fontName),
      bodyText2: base.bodyText2?.copyWith(fontFamily: fontName),
      subtitle1: base.subtitle1?.copyWith(fontFamily: fontName),
      subtitle2: base.subtitle2?.copyWith(fontFamily: fontName),
      overline: base.overline?.copyWith(fontFamily: fontName),
    );
  }

  static ThemeData buildLightTheme() {
    final Color primaryColor = HexColor('#54D3C2');
    final Color secondaryColor = HexColor('#54D3C2');
    final ColorScheme colorScheme = const ColorScheme.light().copyWith(
      primary: primaryColor,
      secondary: secondaryColor,
    );
    final ThemeData base = ThemeData.light();
    return base.copyWith(
      colorScheme: colorScheme,
      primaryColor: primaryColor,
      indicatorColor: Colors.white,
      splashColor: Colors.white24,
      splashFactory: InkRipple.splashFactory,
      //accentColor: secondaryColor,
      canvasColor: Colors.white,
      backgroundColor: const Color(0xFFFFFFFF),
      scaffoldBackgroundColor: const Color(0xFFF6F6F6),
      errorColor: const Color(0xFFB00020),
      buttonTheme: ButtonThemeData(
        colorScheme: colorScheme,
        textTheme: ButtonTextTheme.primary,
      ),
      textTheme: _buildTextThemeOld(base.textTheme),
      primaryTextTheme: _buildTextThemeOld(base.primaryTextTheme),
      //accentTextTheme: _buildTextThemeOld(base.accentTextTheme),
      platform: TargetPlatform.iOS,
    );
  }
}

class HexColor extends Color {
  HexColor(final String hexColor) : super(_getColorFromHex(hexColor));

  static int _getColorFromHex(String hexColor) {
    hexColor = hexColor.toUpperCase().replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF' + hexColor;
    }
    return int.parse(hexColor, radix: 16);
  }
}
