import 'package:cached_network_image/cached_network_image.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/material.dart';

/// misc models
///
/// A type that can be an integer or 0-100 percent
class IntegerOrPercentage {
  IntegerOrPercentage._({this.integer, this.percent});

  final int? integer;
  final int? percent;

  static IntegerOrPercentage? from(dynamic value) {
    if (value is String) {
      value = value.trim();
      if (value.endsWith('%')) {
        final percent = Utils.optionalInt(
            int.tryParse(value.substring(0, value.length - 1)),
            min: 0,
            max: 100);
        if (percent != null) {
          return IntegerOrPercentage._(percent: percent);
        }
      } else {
        final integer = int.tryParse(value);
        if (integer != null) {
          return IntegerOrPercentage._(integer: integer);
        }
      }
    }
    return value is int
        ? IntegerOrPercentage._(integer: value)
        : value is double
            ? IntegerOrPercentage._(integer: value.toInt())
            : null;
  }

  /// return if this is a percentage or not
  /// Note that we handle 100% as a fixed value instead (i.e. double.infinity)
  bool isPercentage() => percent != null && percent != 100;

  /// return the fixed integer value if specified but converted into a double
  double? getFixedValue() {
    return integer?.toDouble() ?? (percent == 100 ? double.infinity : null);
  }

  /// return the percentage (if specified) but converted into a fraction (0 -> 1).
  double? getFractionalValue() {
    return isPercentage() ? percent! / 100.0 : null;
  }
}

class IconModel {
  IconModel(this.icon, {this.library, this.size, this.color});

  dynamic icon;
  String? library;
  int? size;
  Color? color;
}

class BackgroundImage {
  BackgroundImage(
    this._source, {
    BoxFit? fit,
    Alignment? alignment,
    dynamic fallback,
  })  : _fit = fit ?? BoxFit.cover,
        _alignment = alignment ?? Alignment.center,
        _fallback = fallback;

  final String _source;
  final BoxFit _fit;
  final Alignment _alignment;
  final dynamic _fallback;

  DecorationImage getImageAsDecorated() {
    ImageProvider imageProvider;
    if (Utils.isUrl(_source)) {
      imageProvider = NetworkImage(_source);
    } else {
      imageProvider = AssetImage(Utils.getLocalAssetFullPath(_source));
    }
    return DecorationImage(
      image: imageProvider,
      fit: _fit,
      alignment: _alignment,
    );
  }

  Widget getImageAsWidget(ScopeManager? scopeManager) {
    final Widget? fallbackWidget = _fallback != null
        ? scopeManager?.buildWidgetFromDefinition(_fallback)
        : null;

    if (Utils.isUrl(_source)) {
      return CachedNetworkImage(
        imageUrl: _source,
        fit: _fit,
        alignment: _alignment,
        errorWidget:
            fallbackWidget != null ? (_, __, ___) => fallbackWidget : null,
      );
    } else {
      return Image.asset(
        Utils.getLocalAssetFullPath(_source),
        fit: _fit,
        alignment: _alignment,
        errorBuilder:
            fallbackWidget != null ? (_, __, ___) => fallbackWidget : null,
      );
    }
  }
}

class EBorderRadius {
  EBorderRadius._(
      int _topLeft, int _topRight, int _bottomRight, int _bottomLeft)
      : topLeft =
            _topLeft == 0 ? Radius.zero : Radius.circular(_topLeft.toDouble()),
        topRight = _topRight == 0
            ? Radius.zero
            : Radius.circular(_topRight.toDouble()),
        bottomRight = _bottomRight == 0
            ? Radius.zero
            : Radius.circular(_bottomRight.toDouble()),
        bottomLeft = _bottomLeft == 0
            ? Radius.zero
            : Radius.circular(_bottomLeft.toDouble());

  Radius topLeft, topRight, bottomRight, bottomLeft;

  factory EBorderRadius.all(int val) {
    return EBorderRadius._(val, val, val, val);
  }

  // first value: top-left & bottom-right
  // second value: top-right & bottom-left
  factory EBorderRadius.two(int first, int second) {
    return EBorderRadius._(first, second, first, second);
  }

  // first value: top-left
  // second value: top-right & bottom-left
  // third value: bottom-right
  factory EBorderRadius.three(int first, int second, int third) {
    return EBorderRadius._(first, second, third, second);
  }

  factory EBorderRadius.only(
      int topLeft, int topRight, int bottomRight, int bottomLeft) {
    return EBorderRadius._(topLeft, topRight, bottomRight, bottomLeft);
  }

  BorderRadius getValue() {
    return BorderRadius.only(
        topLeft: topLeft,
        topRight: topRight,
        bottomLeft: bottomLeft,
        bottomRight: bottomRight);
  }
}

/// the flex value for FittedRow/FittedColumn
class BoxFlex {
  BoxFlex._({required this.auto, this.flex = 1});

  int flex;
  bool auto;

  factory BoxFlex.asFlex(int flex) {
    return BoxFlex._(flex: flex, auto: false);
  }

  factory BoxFlex.asAuto() {
    return BoxFlex._(auto: true);
  }
}

/// validator for Input widgets
class InputValidator {
  InputValidator({this.minLength, this.maxLength, this.regex, this.regexError});

  int? minLength;
  int? maxLength;
  String? regex;
  String? regexError;
}
