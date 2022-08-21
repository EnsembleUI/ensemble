import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/layout/layout_helper.dart';
import 'package:ensemble/layout/templated.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/layout_utils.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as flutter;
import 'package:flutter/rendering.dart';

class Flow extends StatefulWidget with UpdatableContainer, Invokable, HasController<FlowController, FlowState> {
  static const type = 'Flow';
  Flow({Key? key}) : super(key: key);

  late final ItemTemplate? itemTemplate;

  final FlowController _controller = FlowController();
  @override
  FlowController get controller => _controller;

  @override
  Map<String, Function> getters() {
    return {};
  }
  @override
  Map<String, Function> setters() {
    return {
      'direction': (value) => _controller.direction = Utils.optionalString(value),
      'gap': (value) => _controller.gap = Utils.optionalInt(value),
      'lineGap': (value) => _controller.lineGap = Utils.optionalInt(value),
      'maxWidth': (value) => _controller.maxWidth = Utils.optionalInt(value, min: 0),
      'maxHeight': (value) => _controller.maxHeight = Utils.optionalInt(value, min: 0),
    };
  }
  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  void initChildren({List<Widget>? children, ItemTemplate? itemTemplate}) {
    _controller.children = children;
    this.itemTemplate = itemTemplate;
  }

  @override
  State<StatefulWidget> createState() => FlowState();

}

class FlowController extends WidgetController {
  String? direction;
  int? gap;
  int? lineGap;
  int? maxWidth;
  int? maxHeight;

  List<Widget>? children;
}

class FlowState extends WidgetState<Flow> with TemplatedWidgetState {
  List<Widget>? templatedChildren;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (widget.itemTemplate != null) {
      // initial value
      if (widget.itemTemplate!.initialValue != null) {
        templatedChildren = buildWidgetsFromTemplate(context, widget.itemTemplate!.initialValue!, widget.itemTemplate!);
      }
      // listen for changes
      registerItemTemplate(context, widget.itemTemplate!, onDataChanged: (List dataList) {
        setState(() {
          templatedChildren = buildWidgetsFromTemplate(context, dataList, widget.itemTemplate!);
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
  Widget build(BuildContext context) {
    if (!widget._controller.visible) {
      return const SizedBox.shrink();
    }

    // children will be rendered before templated children
    List<Widget> children = [];
    if (widget._controller.children != null) {
      children.addAll(widget._controller.children!);
    }
    if (templatedChildren != null) {
      children.addAll(templatedChildren!);
    }

    Widget rtn = Wrap(
      direction: widget._controller.direction == Axis.vertical.name ? Axis.vertical : Axis.horizontal,
      spacing: widget.controller.gap?.toDouble() ?? 0,
      runSpacing: widget._controller.lineGap?.toDouble() ?? 0,
      children: children,
    );

    if (widget._controller.maxWidth != null || widget._controller.maxHeight != null) {
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: widget._controller.maxWidth?.toDouble() ?? double.infinity,
          maxHeight: widget._controller.maxHeight?.toDouble() ?? double.infinity
        ),
        child: rtn
      );
    }
    return rtn;
  }


}
