import 'package:ensemble/framework/templated.dart';
import 'package:ensemble/layout/layout_helper.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/layout_utils.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as flutter;
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';

class Column extends StatefulWidget with UpdatableContainer, Invokable, HasController<BoxLayoutController, ColumnState> {
  static const type = 'Column';
  Column({Key? key}) : super(key: key);

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
      'onTap': (funcDefinition) => _controller.onTap = Utils.getAction(funcDefinition, initiator: this),
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
  State<StatefulWidget> createState() => ColumnState();


}

class ColumnState extends WidgetState<Column> with TemplatedWidgetState {
  List<Widget>? templatedChildren;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (widget.itemTemplate != null) {
      // initial value
      if (widget.itemTemplate!.initialValue != null) {
        templatedChildren = buildItemsFromTemplate(context, widget.itemTemplate!.initialValue!, widget.itemTemplate!);
      }
      // listen for changes
      registerItemTemplate(context, widget.itemTemplate!, onDataChanged: (List dataList) {
        setState(() {
          templatedChildren = buildItemsFromTemplate(context, dataList, widget.itemTemplate!);
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
  Widget build(BuildContext buildContext) {
    // children will be rendered before templated children
    List<Widget> children = [];
    if (widget._controller.children != null) {
      children.addAll(widget._controller.children!);
    }
    if (templatedChildren != null) {
      children.addAll(templatedChildren!);
    }

    // wrap each child with Expanded if specified
    List<Widget> updatedChildren = [];
    for (Widget child in children) {
      if (child is HasController &&
          child.controller is WidgetController &&
          (child.controller as WidgetController).expanded) {
        updatedChildren.add(Expanded(child: child));
      } else {
        updatedChildren.add(child);
      }
    }
    children = updatedChildren;


    MainAxisAlignment mainAxis = widget._controller.mainAxis != null ?
    LayoutUtils.getMainAxisAlignment(widget._controller.mainAxis!) :
    MainAxisAlignment.start;


    CrossAxisAlignment crossAxis = widget._controller.crossAxis != null ?
    LayoutUtils.getCrossAxisAlignment(widget._controller.crossAxis!) :
    CrossAxisAlignment.start;

    MainAxisSize mainAxisSize =
      widget._controller.mainAxisSize == 'min' ?
      MainAxisSize.min :
      MainAxisSize.max;

    // if gap is specified, insert SizeBox between children
    if (widget._controller.gap != null) {
      List<Widget> updatedChildren = [];
      for (var i=0; i<children.length; i++) {
        updatedChildren.add(children[i]);
        if (i != children.length-1) {
          updatedChildren.add(SizedBox(height: widget._controller.gap!.toDouble()));
        }
      }
      children = updatedChildren;
    }

    Widget column = DefaultTextStyle.merge(
        style: TextStyle(
            fontFamily: widget._controller.fontFamily,
            fontSize: widget._controller.fontSize != null ? widget._controller.fontSize!.toDouble() : null
        ), child: flutter.Column(
            mainAxisAlignment: mainAxis,
            crossAxisAlignment: crossAxis,
            mainAxisSize: mainAxisSize,
            children: children)
        );

    BoxDecoration boxDecoration = BoxDecoration(
        color: widget._controller.backgroundColor != null ? Color(widget._controller.backgroundColor!) : null,
        border: !widget._controller.hasBorder() ? null : Border.all(
            color: widget._controller.borderColor ?? Colors.black26,
            width: (widget._controller.borderWidth ?? 1).toDouble()),
        borderRadius: widget._controller.borderRadius != null ? BorderRadius.all(Radius.circular(widget._controller.borderRadius!.toDouble())) : null,
        boxShadow: widget._controller.shadowColor == null ? null : <BoxShadow>[
          BoxShadow(
            color: Color(widget._controller.shadowColor!),
            blurRadius: (widget._controller.shadowRadius ?? 0).toDouble(),
            offset:
              (widget._controller.shadowOffset != null && widget._controller.shadowOffset!.length >= 2) ?
              Offset(
                widget._controller.shadowOffset![0].toDouble(),
                widget._controller.shadowOffset![1].toDouble(),
              ) :
              const Offset(0, 0),
          )
        ]
    );

    Widget rtn = Container(
        width: widget._controller.width != null ? widget._controller.width!.toDouble() : null,
        height: widget._controller.height != null ? widget._controller.height!.toDouble() : null,
        margin: Utils.getInsets(widget._controller.margin),

        //clipBehavior: Clip.hardEdge,
        decoration: boxDecoration,

        child: InkWell(
            splashColor: Colors.transparent,
            onTap: widget._controller.onTap == null ? null : () =>
                ScreenController().executeAction(context, widget._controller.onTap!),
            child: Padding(
                padding: Utils.getInsets(widget._controller.padding),
                child: widget._controller.autoFit ? IntrinsicWidth(child: column) : column
            )
        )
    );

    return widget._controller.scrollable ?
    SingleChildScrollView(child: rtn) :
    rtn;
  }



}