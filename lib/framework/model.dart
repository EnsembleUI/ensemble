import 'package:flutter/material.dart';

/// misc models

class IconModel {
  IconModel(this.icon, {
    this.library,
    this.size,
    this.color
  });
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
      imageProvider = AssetImage('assets/images/$source');
    }
    return DecorationImage(
      image: imageProvider,
      fit: fit ?? BoxFit.cover,
      alignment: alignment ?? Alignment.center
    );
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