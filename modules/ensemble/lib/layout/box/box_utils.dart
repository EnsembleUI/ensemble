import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/layout/box/base_box_layout.dart';
import 'package:ensemble/widget/widget_util.dart';
import 'package:flutter/material.dart';

class BoxUtils {
  /// combine the children and templated children,
  /// plus the gap in between if specified
  static List<Widget> buildChildrenAndGap(int? gap,
      {List<Widget>? children, List<Widget>? templatedChildren}) {
    // children will be rendered before templated children
    children = [...?children, ...?templatedChildren];
    if (gap == null) return children;


    List<Widget> items = [];
    for (var i = 0; i < children.length; i++) {
      // first add the child
      items.add(children[i]);

      // then add the gap
      final visibleChild = WidgetUtils.isVisible(children[i]);
      if (i != children.length - 1 && visibleChild) {
        items.add(SizedBox(
            width: gap.toDouble(),
            height: gap.toDouble()));
      }
    }
    return items;
  }

  /// get the flex value for each child of FittedRow or FittedColumn
  static List<BoxFlex> getChildrenFits(dynamic input) {
    if (input is! List) {
      throw LanguageError(
          "BoxLayout's childrenFlex requires a list of non-zero integers or 'auto'.");
    }
    List<BoxFlex> flexItems = [];
    for (dynamic item in input) {
      BoxFlex? flexItem;
      if (item == 'auto' || item == '') {
        flexItem = BoxFlex.asAuto();
      } else if (item != null) {
        int? flex = item is int ? item : int.tryParse(item.toString());
        if (flex != null && flex > 0) {
          flexItem = BoxFlex.asFlex(flex);
        }
      }

      if (flexItem == null) {
        throw LanguageError(
            "Each childrenFlex's value needs to be a valid non-zero integer or 'auto'.");
      }
      flexItems.add(flexItem);

      // TODO: if all flex=auto, then it's not FittedRow/FittedColumn
    }
    return flexItems;
  }
}
