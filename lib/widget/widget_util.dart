
import 'package:ensemble/layout/layout_helper.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as flutter;

/// utility for our Widgets
class WidgetUtils {

  /// wrap our widget in a Box, which supports margin, padding, border, ...
  static Widget wrapInBox(Widget widget, BoxController boxController) {
    BorderRadius? borderRadius = boxController.borderRadius == null ?
      null :
      BorderRadius.all(Radius.circular(boxController.borderRadius!.toDouble()));

    return Container(
        margin: boxController.margin,
        decoration: BoxDecoration(
            border: !boxController.hasBorder() ?
            null :
            Border.all(
                color: boxController.borderColor ?? Colors.black26,
                width: (boxController.borderWidth ?? 1).toDouble()),
            borderRadius: borderRadius
        ),
        padding: boxController.padding,
        child: ClipRRect(
            child: widget,
            borderRadius: borderRadius ?? const BorderRadius.all(Radius.zero)
        )
    );

  }
}






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