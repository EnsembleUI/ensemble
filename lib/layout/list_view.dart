

import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/layout/box_layout.dart';
import 'package:ensemble/layout/layout_helper.dart';
import 'package:ensemble/layout/templated.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as flutter;
import 'package:ensemble/screen_controller.dart';


class ListView extends StatefulWidget
    with
        UpdatableContainer,
        Invokable,
        HasController<BoxLayoutController, BoxLayoutState> {
  static const type = 'ListView';
  ListView({Key? key}) : super(key: key);

  late final ItemTemplate? itemTemplate;

  final BoxLayoutController _controller = BoxLayoutController();
  @override
  BoxLayoutController get controller => _controller;

  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {
      'onItemTap': (funcDefinition) =>
      _controller.onItemTap = Utils.getAction(funcDefinition, initiator: this),
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
  State<StatefulWidget> createState() => ListViewState();

// bool isVertical();
}

class ListViewState extends WidgetState<ListView> with TemplatedWidgetState {
  List<Widget>? templatedChildren;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (widget.itemTemplate != null) {
      // initial value maybe set before the screen rendered
      if (widget.itemTemplate!.initialValue != null) {
        templatedChildren = buildWidgetsFromTemplate(
            context, widget.itemTemplate!.initialValue!, widget.itemTemplate!);
      }

      // listen for changes
      // Note that when visibility is toggled after rendering, the API may already be populated.
      // In that case we want to evaluate the data to see if they are there
      registerItemTemplate(context, widget.itemTemplate!,
          evaluateInitialValue: true, onDataChanged: (List dataList) {
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
      children.addAll(widget._controller.children!);
    }
    if (templatedChildren != null) {
      children.addAll(templatedChildren!);
    }
    return _buildBoxWidget(children);
  }

  Widget _buildBoxWidget(List<Widget> children) {
    // propagate text styling to all its children
    return DefaultTextStyle.merge(
      style: TextStyle(
          fontFamily: widget._controller.fontFamily,
          fontSize: widget._controller.fontSize != null
              ? widget._controller.fontSize!.toDouble()
              : null),
      child: Container(
        width: widget._controller.width?.toDouble(),
        height: widget._controller.height?.toDouble(),
        decoration: _buildBoxDecoration(),
        child: flutter.ListView.builder(
            padding: widget._controller.padding ?? const EdgeInsets.all(0),
            scrollDirection: Axis.vertical,
            physics: const ScrollPhysics(),
            itemCount: children.length,
            shrinkWrap: true,
            itemBuilder: (BuildContext context, int index) {
              return GestureDetector(
                  onTap: widget._controller.onItemTap == null ? null : () =>
                      ScreenController().executeAction(context, widget._controller.onItemTap!),
                  child: children[index]);
            }),
      ),);
  }
  BoxDecoration _buildBoxDecoration() {
    return BoxDecoration(
        color: widget._controller.backgroundColor,
        border: !widget._controller.hasBorder() ? null : Border.all(
            color: widget._controller.borderColor ?? flutter.Colors.black26,
            width: (widget._controller.borderWidth ?? 1).toDouble()),
        borderRadius: widget._controller.borderRadius != null ? widget._controller.borderRadius!.getValue() : null,
        boxShadow: widget._controller.shadowColor == null ? null : <BoxShadow>[
          BoxShadow(
            color: Color(widget._controller.shadowColor!),
            blurRadius: (widget._controller.shadowRadius ?? 0).toDouble(),
            offset: widget._controller.shadowOffset ?? const Offset(0, 0),
          )
        ]
    );
  }
}
