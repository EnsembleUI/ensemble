import 'package:flutter/material.dart';

/// Ensemble's default light color scheme
const ColorScheme defaultColorScheme = ColorScheme.light(
  primary: Color(0xFFE01B9D),
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
const ColorScheme defaultDarkColorScheme = ColorScheme.dark(
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

class DesignSystem {
  static bool filled = true;

  static Color primary = const Color(0xFFE01B9D);

  static Color inputFillColor = const Color(0xFFF3F2F5);
  static Color inputBorderColor = const Color(0xFFF3F2F5);
  static Color inputIconColor = const Color(0xFF878199);
  static Color inputLabelColor = const Color(0xFF3E345C);
  static Color inputErrorColor = const Color(0xFFE00909);
  static Color inputDarkBorder = const Color(0xFFEAE9ED);

  static Color scaffoldBackgroundColor = Colors.white;

  static Color borderColor = const Color(0xFFD7D5DF);

  static Color disableColor = const Color(0xFFBDBDBD);

  static Color successColor = const Color(0xFF009966);
  static Color successBackgroundColor = successColor.withOpacity(.26);
  static Color warningColor = const Color(0xFFFFBE0A);
  static Color warningBackgroundColor = warningColor.withOpacity(.26);
  static Color errorColor = const Color(0xFFE00909);
  static Color errorBackgroundColor = errorColor.withOpacity(.26);
}
