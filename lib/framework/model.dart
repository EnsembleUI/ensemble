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
  BackgroundImage(this.source, {this.fit, this.alignment});

  String source;
  BoxFit? fit;
  Alignment? alignment;

  bool _isUrl() {
    return source.startsWith('https://') || source.startsWith('http://');
  }

  DecorationImage get image {
    ImageProvider imageProvider;
    if (_isUrl()) {
      imageProvider = NetworkImage(source);
    } else {
      imageProvider = AssetImage(Utils.getLocalAssetFullPath(source));
    }
    return DecorationImage(
        image: imageProvider,
        fit: fit ?? BoxFit.cover,
        alignment: alignment ?? Alignment.center);
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

/// validator for Input widgets
class InputValidator {
  InputValidator({this.minLength, this.maxLength, this.regex, this.regexError});

  int? minLength;
  int? maxLength;
  String? regex;
  String? regexError;
}
