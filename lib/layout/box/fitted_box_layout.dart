import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/framework/widget/has_children.dart';
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
    return {
      'onTap': (funcDefinition) => _controller.onTap =
          EnsembleAction.fromYaml(funcDefinition, initiator: this),
    };
  }

  @override
  void initChildren({List<WidgetModel>? children, ItemTemplate? itemTemplate}) {
    _controller.children = children;
  }

  bool isVertical();
}

class FittedBoxLayoutState extends WidgetState<FittedBoxLayout>
    with TemplatedWidgetState, HasChildren<FittedBoxLayout> {
  @override
  Widget buildWidget(BuildContext context) {
    if (widget._controller.children == null ||
        widget._controller.children!.isEmpty) {
      return const SizedBox.shrink();
    }

    // by default wrap each child inside Expanded unless `auto` is specified
    List<Widget> items = [];
    for (int i = 0; i < widget._controller.children!.length; i++) {
      Widget child = buildChild(widget._controller.children![i]);

      // default flex is 1 if not specified
      BoxFlex flex = widget._controller.childrenFits != null &&
              i < widget._controller.childrenFits!.length
          ? widget._controller.childrenFits![i]
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
    // TODO: is there a better way than using LayoutBuilder just to catch these errors?
    // Layout builder is finicking, and some containers which required children
    // to have intrinsic size will have issues with this.
    return LayoutBuilder(builder: (context, constraints) {
      if (widget.isVertical()) {
        // if the parent has unbounded height, using FittedColumn is bad
        if (!constraints.hasBoundedHeight) {
          throw LanguageError(
              "FittedColumn stretches vertically to fill its parent, which causes an issue when the parent (such as Column) calculates its height based on the children, or when the parent is scrollable (such as ListView).",
              recovery: "Consider using Column to fix this problem.");
        }
      } else {
        // if the parent has unbounded width, using FittedRow is bad
        if (!constraints.hasBoundedWidth) {
          throw LanguageError(
              "FittedRow stretches horizontally to fill its parent, which causes an issue when the parent (such as Row) calculates its width based on the children, or when the parent is a horizontal scrollable.",
              recovery: "Consider using Row to fix this problem.");
        }
      }
      return BoxLayoutWrapper(
          boxWidget: boxWidget, controller: widget._controller);
    });
  }
}
