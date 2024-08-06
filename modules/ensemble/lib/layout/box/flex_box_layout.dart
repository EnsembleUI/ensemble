import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/ensemble_widget.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/framework/studio/studio_debugger.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/framework/widget/has_children.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/layout/box/base_box_layout.dart';
import 'package:ensemble/layout/box/box_layout.dart';
import 'package:ensemble/layout/box/box_utils.dart';
import 'package:ensemble/layout/templated.dart';
import 'package:ensemble/model/item_template.dart';
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
          EnsembleAction.from(funcDefinition, initiator: this),
    };
  }

  @override
  void initChildren({List<WidgetModel>? children, Map? itemTemplate}) {
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
      // this child is not marked as a FlexBox, so we force
      // it to be an Expanded by default as a child of this container
      if (!hasFlex(child)) {
        items.add(Expanded(child: child));
      } else {
        items.add(child);
      }
    }
    // add gap if needed
    items =
        BoxUtils.buildChildrenAndGap(widget._controller.gap, children: items);

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
    // when FlexRow doesn't get the cross axis constraint from its parent, we
    // can calculate by its children's dimension (if at least 1 is set) and set
    // the constraint. This way if any children without sizes will work
    if (widget._controller.crossAxisConstraint ==
        CrossAxisConstraint.largestChild) {
      boxWidget = widget.isVertical()
          ? IntrinsicWidth(child: boxWidget)
          : IntrinsicHeight(child: boxWidget);
    }

    Widget rtn = StudioDebugger()
        .assertFlexBoxHasBoundedDimension(boxWidget, widget.isVertical());
    return BoxLayoutWrapper(boxWidget: rtn, controller: widget._controller);
  }

  /// check if a widget have flex or flexMode set. This essentially means the
  /// widget already handles this themselves already
  bool hasFlex(Widget widget) {
    if (widget is DataScopeWidget) {
      widget = widget.child;
    }

    // legacy widgets
    if (widget is HasController && widget.controller is WidgetController) {
      return (widget.controller as WidgetController).flex != null ||
          (widget.controller as WidgetController).flexMode != null ||
          (widget.controller as WidgetController).expanded;
    }
    // new widgets
    else if (widget is EnsembleWidget &&
        widget.controller is EnsembleWidgetController) {
      return (widget.controller as EnsembleWidgetController).flex != null ||
          (widget.controller as EnsembleWidgetController).flexMode != null;
    }
    return false;
  }
}
