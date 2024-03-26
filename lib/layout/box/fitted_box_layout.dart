import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/framework/studio/studio_debugger.dart';
import 'package:ensemble/framework/widget/has_children.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/layout/box/base_box_layout.dart';
import 'package:ensemble/layout/box/box_layout.dart';
import 'package:ensemble/layout/box/box_utils.dart';
import 'package:ensemble/layout/templated.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/widget/spacer.dart';
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
      if (StudioDebugger().debugMode && child is EnsembleSpacer) {
        throw LanguageError(
            "Spacer cannot be used inside FittedRow/FittedColumn. Use FlexRow or FlexColumn parent instead.");
      }

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
    if (StudioDebugger().debugMode) {
      boxWidget = LayoutBuilder(builder: (context, constraints) {
        if (!constraints.hasBoundedHeight && widget.isVertical()) {
          throw StudioError(
              "FittedColumn requires a height for child distribution.",
              errorId: 'flexcolumn-no-bounded-height');
        }
        if (!constraints.hasBoundedWidth && !widget.isVertical()) {
          throw StudioError("FittedRow requires a width for child distribution",
              errorId: 'flexrow-no-bounded-width');
        }
        return boxWidget;
      });
    }

    return BoxLayoutWrapper(
        boxWidget: boxWidget, controller: widget._controller);
  }
}
