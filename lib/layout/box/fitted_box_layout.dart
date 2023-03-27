import 'package:ensemble/framework/model.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/layout/box/base_box_layout.dart';
import 'package:ensemble/layout/box/box_layout.dart';
import 'package:ensemble/layout/box/box_utils.dart';
import 'package:ensemble/layout/templated.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as flutter;

class FittedRow extends FittedBoxLayout {
  static const type = 'FittedRow';
  FittedRow({super.key});

  @override
  bool isVertical() => false;
}

class FittedColumn extends FittedBoxLayout {
  static const type = 'FittedColumn';
  FittedColumn({super.key});

  @override
  bool isVertical() => true;
}

abstract class FittedBoxLayout extends StatefulWidget
    with
        UpdatableContainer,
        Invokable,
        HasController<FittedBoxLayoutController, FittedBoxLayoutState> {
  FittedBoxLayout({super.key});

  final FittedBoxLayoutController _controller = FittedBoxLayoutController();
  @override
  FittedBoxLayoutController get controller => _controller;

  @override
  State<StatefulWidget> createState() => FittedBoxLayoutState();

  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {};
  }

  @override
  void initChildren({List<Widget>? children, ItemTemplate? itemTemplate}) {
    _controller.children = children;
  }

  bool isVertical();
}

class FittedBoxLayoutState extends WidgetState<FittedBoxLayout>
    with TemplatedWidgetState {
  @override
  Widget buildWidget(BuildContext context) {
    if (widget._controller.children == null ||
        widget._controller.children!.isEmpty) {
      return const SizedBox.shrink();
    }

    // by default wrap each child inside Expanded unless `auto` is specified
    List<Widget> items = [];
    for (int i = 0; i < widget._controller.children!.length; i++) {
      Widget child = widget._controller.children![i];

      // default flex is 1 if not specified
      BoxFlex flex = widget._controller.childrenFlex != null &&
              i < widget._controller.childrenFlex!.length
          ? widget._controller.childrenFlex![i]
          : BoxFlex.asFlex(1);

      if (flex.auto) {
        items.add(child);
      } else {
        items.add(Expanded(flex: flex.flex, child: child));
      }
    }
    // add gap if needed
    items = BoxUtils.buildChildrenAndGap(widget._controller, children: items);

    Widget boxWidget;
    if (widget.isVertical()) {
      boxWidget = flutter.Column(
        mainAxisSize: MainAxisSize.max, // always stretch to parent's
        mainAxisAlignment: widget._controller.mainAxis,
        crossAxisAlignment: widget._controller.crossAxis,
        children: items,
      );
    } else {
      boxWidget = flutter.Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: widget._controller.mainAxis,
        crossAxisAlignment: widget._controller.crossAxis,
        children: items,
      );
    }
    return BoxLayoutWrapper(
        boxWidget: boxWidget, controller: widget._controller);
  }
}
