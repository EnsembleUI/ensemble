import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// all the functions should resolve to our theme, and fallback to colorScheme.
/// If anything is hardcoded, they need to be corrected later on.
class ThemeManager {


  // color when clicking on (InkWell)
  static getSplashColor(BuildContext context) {
    return Theme.of(context).colorScheme.primary;
  }
  static Color getBorderColor(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }
  static double getBorderThickness(BuildContext context) {
    return 1;
  }

  static Color getShadowColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? const Color(0xff000000)
        : const Color(0xffffffff);
  }
  static getShadowRadius(BuildContext context) {
    return 0;
  }
  static getShadowOffset(BuildContext context) {
    return const Offset(0, 0);
  }
  static getShadowStyle(BuildContext context) {
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