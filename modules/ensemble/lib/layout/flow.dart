import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/widget/has_children.dart';
import 'package:ensemble/framework/widget/view_util.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/layout/templated.dart';
import 'package:ensemble/model/item_template.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/layout_utils.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/box_wrapper.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as flutter;
import 'package:flutter/rendering.dart';

class Flow extends StatefulWidget
    with
        UpdatableContainer,
        Invokable,
        HasController<FlowController, FlowState> {
  static const type = 'Flow';

  Flow({Key? key}) : super(key: key);

  late final ItemTemplate? itemTemplate;

  final FlowController _controller = FlowController();

  @override
  FlowController get controller => _controller;

  @override
  Map<String, Function> getters() {
    return {
      'selectedItemIndex': () => _controller.selectedItemIndex,
    };
  }

  @override
  Map<String, Function> setters() {
    return {
      'direction': (value) =>
          _controller.direction = Utils.optionalString(value),
      'mainAxis': (value) =>
          _controller.mainAxis = LayoutUtils.getWrapAlignment(value),
      'crossAxis': (value) =>
          _controller.crossAxis = LayoutUtils.getWrapCrossAlignment(value),
      'gap': (value) => _controller.gap = Utils.optionalInt(value),
      'lineGap': (value) => _controller.lineGap = Utils.optionalInt(value),
      'maxWidth': (value) =>
          _controller.maxWidth = Utils.optionalInt(value, min: 0),
      'maxHeight': (value) =>
          _controller.maxHeight = Utils.optionalInt(value, min: 0),
      'onItemTap': (funcDefinition) => _controller.onItemTap =
          EnsembleAction.from(funcDefinition, initiator: this),
    };
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  void initChildren({List<WidgetModel>? children, Map? itemTemplate}) {
    _controller.children = children;
    this.itemTemplate = ItemTemplate.from(itemTemplate);
  }

  @override
  State<StatefulWidget> createState() => FlowState();
}

class FlowController extends BoxController {
  String? direction;
  WrapAlignment? mainAxis;
  WrapCrossAlignment? crossAxis;
  int? gap;
  int? lineGap;
  int? maxWidth;
  int? maxHeight;

  List<WidgetModel>? children;
  EnsembleAction? onItemTap;
  int selectedItemIndex = -1;
}

class FlowState extends EWidgetState<Flow>
    with TemplatedWidgetState, HasChildren<Flow> {
  List<Widget>? templatedChildren;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (widget.itemTemplate != null) {
      // initial value
      if (widget.itemTemplate!.initialValue != null) {
        templatedChildren = buildWidgetsFromTemplate(
            context, widget.itemTemplate!.initialValue!, widget.itemTemplate!);
      }
      // listen for changes
      registerItemTemplate(context, widget.itemTemplate!,
          onDataChanged: (List dataList) {
        setState(() {
          templatedChildren =
              buildWidgetsFromTemplate(context, dataList, widget.itemTemplate!);
        });
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
    templatedChildren = null;
  }

  @override
  Widget buildWidget(BuildContext context) {
    // children will be rendered before templated children
    List<Widget> children = [];

    if (widget._controller.children != null) {
      children.addAll(buildChildren(widget._controller.children!));
    }

    if (templatedChildren != null) {
      children.addAll(templatedChildren!);
    }

    if (widget._controller.onItemTap != null) {
      children = ViewUtil.addGesture(children, _onItemTap);
    }

    Widget rtn = BoxWrapper(
      boxController: widget._controller,
      ignoresMargin: true,
      widget: Wrap(
        direction: widget._controller.direction == Axis.vertical.name
            ? Axis.vertical
            : Axis.horizontal,
        spacing: widget.controller.gap?.toDouble() ?? 0,
        runSpacing: widget._controller.lineGap?.toDouble() ?? 0,
        alignment: widget._controller.mainAxis ?? WrapAlignment.start,
        crossAxisAlignment:
            widget._controller.crossAxis ?? WrapCrossAlignment.start,
        children: children,
      ),
    );

    if (widget._controller.margin != null) {
      rtn = Padding(padding: widget._controller.margin!, child: rtn);
    }

    if (widget._controller.maxWidth != null ||
        widget._controller.maxHeight != null) {
      return ConstrainedBox(
          constraints: BoxConstraints(
              maxWidth:
                  widget._controller.maxWidth?.toDouble() ?? double.infinity,
              maxHeight:
                  widget._controller.maxHeight?.toDouble() ?? double.infinity),
          child: rtn);
    }

    return rtn;
  }

  void _onItemTap(int index) {
    if (widget.controller.onItemTap != null) {
      widget._controller.selectedItemIndex = index;
      ScreenController().executeAction(context, widget._controller.onItemTap!);
    }
  }
}
