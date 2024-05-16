import 'package:flutter/cupertino.dart';

class LayoutUtils {
  static MainAxisAlignment? getMainAxisAlignment(String spec) {
    switch (spec) {
      case 'spaceBetween':
      case 'space-between':
        return MainAxisAlignment.spaceBetween;
      case 'spaceAround':
      case 'space-around':
        return MainAxisAlignment.spaceAround;
      case 'spaceEvenly':
      case 'space-evenly':
        return MainAxisAlignment.spaceEvenly;
      case 'center':
      case 'middle':
        return MainAxisAlignment.center;
      case 'end':
      case 'bottom':
        return MainAxisAlignment.end;
      case 'start':
      case 'top':
        return MainAxisAlignment.start;
    }
    return null;
  }

  static CrossAxisAlignment? getCrossAxisAlignment(String spec) {
    switch (spec) {
      case 'center':
      case 'middle':
        return CrossAxisAlignment.center;
      case 'end':
      case 'bottom':
        return CrossAxisAlignment.end;
      case 'stretch':
        return CrossAxisAlignment.stretch;
      case 'baseline':
        return CrossAxisAlignment.baseline;
      case 'start':
      case 'top':
        return CrossAxisAlignment.start;
    }
    return null;
  }

  static WrapAlignment? getWrapAlignment(dynamic value) {
    switch (value) {
      case 'start':
        return WrapAlignment.start;
      case 'center':
        return WrapAlignment.center;
      case 'end':
        return WrapAlignment.end;
      case 'spaceAround':
        return WrapAlignment.spaceAround;
      case 'spaceBetween':
        return WrapAlignment.spaceBetween;
      case 'spaceEvenly':
        return WrapAlignment.spaceEvenly;
    }
    return null;
  }

  static WrapCrossAlignment? getWrapCrossAlignment(dynamic value) {
    switch (value) {
      case 'start':
        return WrapCrossAlignment.start;
      case 'center':
        return WrapCrossAlignment.center;
      case 'end':
        return WrapCrossAlignment.end;
    }
    return null;
  }

  /// insert the specified gap between the widgets
  static List<Widget> withGap(List<Widget> widgets, int gap) {
    if (gap > 0) {
      List<Widget> rtn = [];
      for (int i = 0; i < widgets.length; i++) {
        rtn.add(widgets[i]);
        if (i != widgets.length - 1) {
          rtn.add(SizedBox(
            width: gap.toDouble(),
            height: gap.toDouble(),
          ));
        }
      }
      return rtn;
    }
    return widgets;
  }
}
