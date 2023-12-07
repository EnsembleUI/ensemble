import 'package:cached_network_image/cached_network_image.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/material.dart';

/// misc models

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

class EBorderWidth {
  EBorderWidth._({double? top, double? bottom, double? left, double? right}) {
    this.top = top?.toDouble();
    this.bottom = bottom?.toDouble();
    this.left = left?.toDouble();
    this.right = right?.toDouble();
  }

  double? top, bottom, left, right;

  factory EBorderWidth.create() {
    return EBorderWidth._();
  }

  factory EBorderWidth.all(double? val) {
    return EBorderWidth._(
      top: val,
      bottom: val,
      left: val,
      right: val,
    );
  }

  factory EBorderWidth.two(
    double? first,
    double? second,
  ) {
    return EBorderWidth._(
      top: first,
      bottom: first,
      left: second,
      right: second,
    );
  }

  factory EBorderWidth.three(
    double? first,
    double? second,
    double? third,
  ) {
    return EBorderWidth._(
      top: first,
      bottom: third,
      left: second,
      right: second,
    );
  }

  factory EBorderWidth.only(
    double? top,
    double? right,
    double? bottom,
    double? left,
  ) {
    return EBorderWidth._(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
    );
  }

  update({
    double? top,
    double? bottom,
    double? left,
    double? right,
  }) {
    this.top = top ?? this.top;
    this.bottom = bottom ?? this.bottom;
    this.left = left ?? this.left;
    this.right = right ?? this.right;
  }
}

class EBorderColor {
  EBorderColor._({dynamic top, dynamic bottom, dynamic left, dynamic right}) {
    this.top = Utils.getColor(top);
    this.bottom = Utils.getColor(bottom);
    this.left = Utils.getColor(left);
    this.right = Utils.getColor(right);
  }

  Color? top, bottom, left, right;

  factory EBorderColor.create() {
    return EBorderColor._();
  }

  factory EBorderColor.all(dynamic val) {
    return EBorderColor._(
      top: val,
      bottom: val,
      left: val,
      right: val,
    );
  }

  factory EBorderColor.two(
    dynamic first,
    dynamic second,
  ) {
    return EBorderColor._(
      top: first,
      bottom: first,
      left: second,
      right: second,
    );
  }

  factory EBorderColor.three(
    dynamic first,
    dynamic second,
    dynamic third,
  ) {
    return EBorderColor._(
      top: first,
      bottom: third,
      left: second,
      right: second,
    );
  }

  factory EBorderColor.only(
    dynamic top,
    dynamic right,
    dynamic bottom,
    dynamic left,
  ) {
    return EBorderColor._(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
    );
  }

  void update({
    dynamic top,
    dynamic bottom,
    dynamic left,
    dynamic right,
  }) {
    this.top = Utils.getColor(top) ?? this.top;
    this.bottom = Utils.getColor(bottom) ?? this.bottom;
    this.left = Utils.getColor(left) ?? this.left;
    this.right = Utils.getColor(right) ?? this.right;
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
