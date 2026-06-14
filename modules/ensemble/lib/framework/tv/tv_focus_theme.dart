import 'package:flutter/material.dart';

/// Holds TV focus styling configuration parsed from theme.yaml.
///
/// This is the highest priority source for TV focus styling, followed by
/// [TVFocusProvider] values, then default fallbacks.
///
/// ## Theme YAML Configuration
///
/// ```yaml
/// Common:
///   Tokens:
///     TV:
///       focusColor: 0xFF00AAFF
///       focusBorderWidth: 3
///       focusBorderRadius: 8
///       focusAnimationDuration: 150
/// ```
class TVFocusTheme {
  const TVFocusTheme({
    this.focusColor,
    this.focusBorderWidth,
    this.focusBorderRadius,
    this.focusAnimationDurationMs,
  });

  /// Focus indicator border color from theme.
  final Color? focusColor;

  /// Focus indicator border width from theme.
  final double? focusBorderWidth;

  /// Focus indicator border radius from theme.
  final double? focusBorderRadius;

  /// Focus animation duration in milliseconds from theme.
  final int? focusAnimationDurationMs;

  /// Default values for border width, radius, and animation.
  /// Note: focusColor defaults to app's primary color (passed at resolve time).
  static const double defaultBorderWidth = 3.0;
  static const double defaultBorderRadius = 8.0;
  static const int defaultAnimationDurationMs = 150;

  /// Creates a copy with non-null values from [other] taking precedence.
  TVFocusTheme mergeWith(TVFocusTheme? other) {
    if (other == null) return this;
    return TVFocusTheme(
      focusColor: other.focusColor ?? focusColor,
      focusBorderWidth: other.focusBorderWidth ?? focusBorderWidth,
      focusBorderRadius: other.focusBorderRadius ?? focusBorderRadius,
      focusAnimationDurationMs:
          other.focusAnimationDurationMs ?? focusAnimationDurationMs,
    );
  }

  /// Resolves the final focus color with fallback chain.
  ///
  /// Priority: this.focusColor > providerColor > appPrimaryColor
  ///
  /// [appPrimaryColor] is typically `Theme.of(context).colorScheme.primary`
  Color resolveFocusColor(Color? providerColor, Color appPrimaryColor) {
    return focusColor ?? providerColor ?? appPrimaryColor;
  }

  /// Resolves the final border width with fallback chain.
  double resolveBorderWidth(double? providerWidth) {
    return focusBorderWidth ?? providerWidth ?? defaultBorderWidth;
  }

  /// Resolves the final border radius with fallback chain.
  double resolveBorderRadius(double? providerRadius) {
    return focusBorderRadius ?? providerRadius ?? defaultBorderRadius;
  }

  /// Resolves the final animation duration with fallback chain.
  Duration resolveAnimationDuration(int? providerDurationMs) {
    final ms = focusAnimationDurationMs ??
        providerDurationMs ??
        defaultAnimationDurationMs;
    return Duration(milliseconds: ms);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TVFocusTheme &&
        other.focusColor == focusColor &&
        other.focusBorderWidth == focusBorderWidth &&
        other.focusBorderRadius == focusBorderRadius &&
        other.focusAnimationDurationMs == focusAnimationDurationMs;
  }

  @override
  int get hashCode => Object.hash(
        focusColor,
        focusBorderWidth,
        focusBorderRadius,
        focusAnimationDurationMs,
      );
}
