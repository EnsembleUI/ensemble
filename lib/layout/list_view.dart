import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/layout/box_layout.dart';
import 'package:ensemble/layout/layout_helper.dart';
import 'package:ensemble/layout/templated.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as flutter;

// ignore: must_be_immutable
class ListView extends ListViewWidget {
  static const type = 'ListView';
  ListView({Key? key}) : super(key: key);
}

 class ListViewWidget extends StatefulWidget
    with
        UpdatableContainer,
        Invokable,
        HasController<BoxLayoutController, BoxLayoutState> {
   ListViewWidget({Key? key}) : super(key: key);

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
      'onTap': (funcDefinition) =>
      _controller.onTap = Utils.getAction(funcDefinition, initiator: this),
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
  State<StatefulWidget> createState() => ListViewWidgetState();

  // bool isVertical();
}

class ListViewWidgetState extends WidgetState<ListViewWidget> with TemplatedWidgetState {
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
        child: SizedBox(
          width: widget._controller.width != null ? widget._controller.width!.toDouble() : null,
          height: widget._controller.height != null ? widget._controller.height!.toDouble() : null,
          child: flutter.ListView.builder(
              scrollDirection: Axis.vertical,
              physics: const ScrollPhysics(),
              itemCount: children.length,
              shrinkWrap: true,
              itemBuilder: (BuildContext context, int index) {
                return children[index];
              }),
        ),);
  }
}
