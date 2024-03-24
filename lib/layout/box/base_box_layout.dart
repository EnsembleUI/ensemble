import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/model/pull_to_refresh.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/layout_utils.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/carousel.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:flutter/material.dart';

import 'box_utils.dart';

/// convenience wrapper for BoxLayout
class BoxLayoutWrapper extends StatelessWidget {
  const BoxLayoutWrapper(
      {super.key,
      required this.boxWidget,
      required this.controller,
      this.ignoresMargin = false});
  final Widget boxWidget;
  final BaseBoxLayoutController controller;
  final bool ignoresMargin;

  @override
  Widget build(BuildContext context) {
    Widget rtn = BoxWrapper(
      boxController: controller,
      widget: DefaultTextStyle.merge(
          style: controller._textStyle?.getTextStyle(),
          textAlign: controller._textStyle?.textAlign,
          maxLines: controller.maxLines,
          child: boxWidget),
      ignoresMargin: true,
    );
    if (controller.onTap != null) {
      rtn = GestureDetector(
        child: rtn,
        onTap: () =>
            ScreenController().executeAction(context, controller.onTap!),
      );
    }
    if (!ignoresMargin && controller.margin != null) {
      rtn = Padding(padding: controller.margin!, child: rtn);
    }
    return rtn;
  }
}

// controller for FlexRow/FlexColumn
class FlexBoxLayoutController extends BaseBoxLayoutController {}

/// controller for FittedRow/FittedColumn
class FittedBoxLayoutController extends BaseBoxLayoutController {
  List<BoxFlex>? childrenFits;

  @override
  Map<String, Function> getBaseSetters() {
    Map<String, Function> setters = super.getBaseSetters();
    setters.addAll({
      'childrenFits': (value) => childrenFits = BoxUtils.getChildrenFits(value)
    });
    return setters;
  }
}

/// controller for Column/Row/Flex
class BoxLayoutController extends BaseBoxLayoutController
    with HasPullToRefresh {
  ItemTemplate? itemTemplate;

  bool scrollable = false;
  bool autoFit = false;
  int? maxWidth;
  int? maxHeight;

  // applicable to Flex container only
  String? direction;

  @override
  Map<String, Function> getBaseSetters() {
    Map<String, Function> setters = super.getBaseSetters();
    setters.addAll({
      'scrollable': (value) =>
          scrollable = Utils.getBool(value, fallback: false),
      'autoFit': (value) => autoFit = Utils.getBool(value, fallback: false),
      'maxWidth': (value) => maxWidth = Utils.optionalInt(value),
      'maxHeight': (value) => maxHeight = Utils.optionalInt(value),
    });
    return setters;
  }
}

abstract class BaseBoxLayoutController extends BoxController {
  List<WidgetModel>? children;
  EnsembleAction? onTap;
  EnsembleAction? onItemTap;

  MainAxisSize mainAxisSize = MainAxisSize.max;
  MainAxisAlignment mainAxis = MainAxisAlignment.start;
  CrossAxisAlignment crossAxis = CrossAxisAlignment.start;
  int? gap;

  // TODO: think through this. Need more style overrides.
  String? fontFamily;
  int? fontSize;
  TextStyleComposite? _textStyle;
  int? maxLines;

  @override
  Map<String, Function> getBaseSetters() {
    Map<String, Function> setters = super.getBaseSetters();
    setters.addAll({
      'mainAxisSize': (value) =>
          mainAxisSize = MainAxisSize.values.from(value) ?? mainAxisSize,
      'mainAxis': (value) =>
          mainAxis = LayoutUtils.getMainAxisAlignment(value) ?? mainAxis,
      'crossAxis': (value) =>
          crossAxis = LayoutUtils.getCrossAxisAlignment(value) ?? crossAxis,
      'gap': (value) => gap = Utils.optionalInt(value),
      'fontFamily': (value) => fontFamily = Utils.optionalString(value),
      'fontSize': (value) => fontSize = Utils.optionalInt(value),
      'maxLines': (value) => maxLines = Utils.optionalInt(value, min: 1),
      'textStyle': (style) =>
          _textStyle = Utils.getTextStyleAsComposite(this, style: style),
    });
    return setters;
  }

  @override
  Map<String, Function> getBaseGetters() {
    Map<String, Function> getters = super.getBaseGetters();
    getters.addAll({
      'mainAxisSize': () => mainAxisSize,
      'mainAxis': () => mainAxis,
      'crossAxis': () => crossAxis,
      'gap': () => gap,
      'fontFamily': () => fontFamily,
      'fontSize': () => fontSize,
      'textStyle': () => _textStyle,
    });
    return getters;
  }
}
