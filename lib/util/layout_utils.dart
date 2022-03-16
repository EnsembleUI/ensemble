import 'package:flutter/cupertino.dart';

class LayoutUtils {

  static MainAxisAlignment getMainAxisAlignment(String spec) {
    switch (spec) {
      case 'space-between':
        return MainAxisAlignment.spaceBetween;
      case 'center':
      case 'middle':
        return MainAxisAlignment.center;
      case 'end':
      case 'bottom':
        return MainAxisAlignment.end;
      case 'start':
      case 'top':
      default:
        return MainAxisAlignment.start;
    }
  }


  static CrossAxisAlignment getCrossAxisAlignment(String spec) {
    switch(spec) {
      case 'center':
      case 'middle':
        return CrossAxisAlignment.center;
      case 'end':
      case 'bottom':
        return CrossAxisAlignment.end;
      case 'stretch':
        return CrossAxisAlignment.stretch;
      case 'start':
      case 'top':
      default:
        return CrossAxisAlignment.start;
    }

  }




}