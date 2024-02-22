import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/ensemble_widget.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/framework/studio_debugger.dart';
import 'package:ensemble/framework/widget/has_children.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/layout/box/base_box_layout.dart';
import 'package:ensemble/layout/box/box_layout.dart';
import 'package:ensemble/layout/box/box_utils.dart';
import 'package:ensemble/layout/templated.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/spacer.dart';
import 'package:ensemble/widget/widget_util.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as flutter;

class FlexRow extends FlexBoxLayout {
  static const type = 'FlexRow';
  FlexRow({super.key});

  @override
  bool isVertical() => false;
}

class FlexColumn extends FlexBoxLayout {
  static const type = 'FlexColumn';
  FlexColumn({super.key});

  @override
  bool isVertical() => true;
}

abstract class FlexBoxLayout extends StatefulWidget
    with
        UpdatableContainer,
        Invokable,
        HasController<FlexBoxLayoutController, FlexBoxLayoutState> {
  FlexBoxLayout({super.key});

  final FlexBoxLayoutController _controller = FlexBoxLayoutController();
  @override
  FlexBoxLayoutController get controller => _controller;

  @override
  State<StatefulWidget> createState() => FlexBoxLayoutState();

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

class FlexBoxLayoutState extends WidgetState<FlexBoxLayout>
    with TemplatedWidgetState, HasChildren<FlexBoxLayout> {
  @override
  Widget buildWidget(BuildContext context) {
    if (widget._controller.children == null ||
        widget._controller.children!.isEmpty) {
      return const SizedBox.shrink();
    }

    List<Widget> items = [];
    for (int i = 0; i < widget._controller.children!.length; i++) {
      Widget child = buildChild(widget._controller.children![i]);
      // by default each child is an Expanded inside our container
      // so wrap it if not already a Flexible/Expanded
      if (!WidgetUtils.isExpandedOrFlexible(child)) {
        items.add(Expanded(child: child));
      } else {
        items.add(child);
      }
    }
    // add gap if needed
    items = BoxUtils.buildChildrenAndGap(widget._controller, children: items);

    Widget boxWidget;
    if (widget.isVertical()) {
      boxWidget = flutter.Column(
        mainAxisSize: widget._controller.mainAxisSize ?? MainAxisSize.max,
        mainAxisAlignment: widget._controller.mainAxis,
        crossAxisAlignment: widget._controller.crossAxis,
        children: items,
      );
    } else {
      boxWidget = flutter.Row(
        mainAxisSize: widget._controller.mainAxisSize ?? MainAxisSize.max,
        mainAxisAlignment: widget._controller.mainAxis,
        crossAxisAlignment: widget._controller.crossAxis,
        children: items,
      );
    }
    Widget rtn =
        BoxLayoutWrapper(boxWidget: boxWidget, controller: widget._controller);

    // handle invalid layout in Studio
    if (StudioDebugger().debugMode) {
      rtn = RequiresRowColumnFlexWidget(child: rtn);

      // Layout builder is finicking, and some containers which required children
      // to have intrinsic size will have issues with this.
      return LayoutBuilder(builder: (context, constraints) {
        if (widget.isVertical()) {
          // if the parent has unbounded height, using FittedColumn is bad
          if (!constraints.hasBoundedHeight) {
            throw LanguageError(
                "FlexColumn stretches vertically to fill its parent, which causes an issue when the parent (such as Column) calculates its height based on the children, or when the parent is scrollable (such as ListView).",
                recovery: "Consider using Column to fix this problem.");
          }
        } else {
          // if the parent has unbounded width, using FittedRow is bad
          if (!constraints.hasBoundedWidth) {
            throw LanguageError(
                "FlexRow stretches horizontally to fill its parent, which causes an issue when the parent (such as Row) calculates its width based on the children, or when the parent is a horizontal scrollable.",
                recovery: "Consider using Row to fix this problem.");
          }
        }
        return rtn;
      });
    }
    return rtn;
  }
}
