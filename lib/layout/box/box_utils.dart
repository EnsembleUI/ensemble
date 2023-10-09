import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/layout/box/base_box_layout.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';

import '../../framework/view/page.dart';
import '../../framework/widget/custom_view.dart';

class BoxUtils {
  /// combine the children and templated children,
  /// plus the gap in between if specified
  static List<Widget> buildChildrenAndGap(BaseBoxLayoutController controller,
      {List<Widget>? children, List<Widget>? templatedChildren}) {
    // children will be rendered before templated children
    children = [...?children, ...?templatedChildren];

    List<Widget> items = [];
    // if gap is specified, insert SizeBox between children
    if (controller.gap != null) {
      final gap = SizedBox(
          width: controller.gap!.toDouble(),
          height: controller.gap!.toDouble());

      for (var i = 0; i < children.length; i++) {
        // first add the child
        items.add(children[i]);

        // then add the gap
        final visibleChild = _checkVisibleChild(children[i]);
        if (i != children.length - 1 && visibleChild) {
          items.add(gap);
        }
      }
    } else {
      items = children;
    }
    return items;
  }

  static bool _checkVisibleChild(Widget child) {
    Widget view = child;
    if (view is DataScopeWidget) {
      if (view.child is CustomView) {
        // Custom Widgets
        final CustomView customView = view.child as CustomView;
        // TODO: this logic is hosed since body is now just the model.
        // TODO: But then we shouldn't be reaching in like this anyway
        // view = customView.body;
        return true;

      } else {
        // Native Widgets like Button, Text
        view = view.child;
      }
    }

    final isWidgetController =
        view is HasController && (view.controller is WidgetController);
    if (isWidgetController) {
      final visibleChild = (view.controller as WidgetController).visible;
      return visibleChild;
    }
    return false;
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
