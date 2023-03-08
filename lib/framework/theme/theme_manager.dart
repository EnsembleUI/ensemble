import 'package:ensemble/framework/theme/theme_loader.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// ThemeManager will resolve the styles at runtime using the BuildContext.
/// All available methods should take in the BuildContext to resolve the style.
///
/// ThemeManager also uses ThemeLoader mixin, which initialize the overall theme
/// when the App starts for the first time
class ThemeManager with ThemeLoader {
  static final ThemeManager _instance = ThemeManager._internal();
  ThemeManager._internal();
  factory ThemeManager() {
    return _instance;
  }


  // color when clicking on (InkWell)
  getSplashColor(BuildContext context) {
    return Theme.of(context).colorScheme.primary;
  }
  Color getBorderColor(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }
  Color getPrimaryColor(BuildContext context) {
    return Theme.of(context).colorScheme.primary;
  }
  double getBorderThickness(BuildContext context) {
    return 1;
  }

  Color getShadowColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? const Color(0xff000000)
        : const Color(0xffffffff);
  }
  getShadowRadius(BuildContext context) {
    return 0;
  }
  getShadowOffset(BuildContext context) {
    return const Offset(0, 0);
  }
  getShadowStyle(BuildContext context) {
    return BlurStyle.normal;
  }



}

enum ResponsiveBreakpoint {
  xSmall,
  small,
  medium,
  large,
  xLarge
}
extension BoxConstraintsExtension on BoxConstraints {
  bool isXSmall() => maxWidth <= 480;
  bool isSmall() => maxWidth > 480 && maxWidth <= 800;
  bool isMedium() => maxWidth > 800 && maxWidth <= 1200;
  bool isLarge() => maxWidth > 1200 && maxWidth <= 1600;
  bool isXLarge() => maxWidth > 1600;

  bool isSmallOrLess() => isSmall() || isXSmall();
  bool isLargeOrMore() => isLarge() || isXLarge();
}
