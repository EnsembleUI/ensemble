
import 'package:flutter/material.dart' as flutter;

/// utility for our Widgets

class TextOverflow {
  TextOverflow(this.overflow, this.maxLine, this.softWrap);
  flutter.TextOverflow? overflow;
  int? maxLine = 1;
  bool? softWrap = false;

  static TextOverflow from(String? overflow) {
    flutter.TextOverflow? textOverflow;
    int? maxLine = 1;
    bool? softWrap = false;
    switch(overflow) {
      case 'visible':
        textOverflow = flutter.TextOverflow.visible;
        break;
      case 'clip':
        textOverflow = flutter.TextOverflow.clip;
        break;
      case 'fade':
        textOverflow = flutter.TextOverflow.fade;
        break;
      case 'ellipsis':
        textOverflow = flutter.TextOverflow.ellipsis;
        break;
      case 'wrap':
      default:
        textOverflow = null;
        maxLine = null;
        softWrap = null;
    }
    return TextOverflow(textOverflow, maxLine, softWrap);
  }
}