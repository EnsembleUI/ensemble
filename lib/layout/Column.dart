import 'package:ensemble/framework/context.dart';
import 'package:ensemble/framework/data.dart';
import 'package:ensemble/framework/view.dart';
import 'package:ensemble/layout/layout_helper.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/layout_utils.dart';
import 'package:ensemble/framework/widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as flutter;
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';

class Column extends StatefulWidget with UpdatableContainer, Invokable, HasController<BoxLayoutController, ColumnState> {
  static const type = 'Column';
  Column({Key? key}) : super(key: key);

  late final List<Widget>? children;
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
    return {};
  }
  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  void initChildren({List<Widget>? children, ItemTemplate? itemTemplate}) {
    this.children = children;
    this.itemTemplate = itemTemplate;
  }

  @override
  State<StatefulWidget> createState() => ColumnState();


}

class ColumnState extends WidgetState<Column> {
  // data exclusively for item template (e.g api result)
  Map<String, dynamic>? itemTemplateData;

  @override
  void initState() {
    super.initState();

    // register listener for item template's data changes.
    // Only work with API for now e.g. data: ${apiName.*}
    if (widget.itemTemplate != null) {
      String dataVar = widget.itemTemplate!.data.substring(2, widget.itemTemplate!.data.length-1);
      String apiName = dataVar.split('.').first;

      ScreenController().registerDataListener(context, apiName, (Map<String, dynamic> data) {
        itemTemplateData = data;
        setState(() {

        });
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
    itemTemplateData = null;
  }



  List<Widget> getChildren() {
    List<Widget> children = widget.children ?? [];



    return children;
  }


  @override
  Widget build(BuildContext buildContext) {

    List<Widget> children = widget.children ?? [];

    // itemTemplate widgets will be rendered after our children
    if (widget.itemTemplate != null) {
      List? rendererItems;
      // if our itemTemplate's dataList has already been resolved
      if (widget.itemTemplate!.localizedDataList != null && widget.itemTemplate!.localizedDataList!.isNotEmpty) {
        rendererItems = widget.itemTemplate!.localizedDataList;
      }
      // else attempt to resolve via itemTemplate and itemTemplateData, which is updated by API response
      else if (itemTemplateData != null) {
        // Example format:
        // data: $(apiName.*)
        // name: item

        // hack for now, reconstructing the dataPath
        String dataNode = widget.itemTemplate!.data;
        List<String> dataTokens = dataNode
            .substring(2, dataNode.length - 1)
            .split(".");
        // we need to have at least 2+ tokens e.g apiName.key1
        if (dataTokens.length >= 2) {
          // exclude the apiName and reconstruct the variable
          DataContext context = DataContext(buildContext: buildContext, initialMap: itemTemplateData);
          dynamic dataList = context.evalVariable(dataTokens.sublist(1).join('.'));
          if (dataList is List) {
            rendererItems = dataList;
          }
        }
      }


      // now loop through each and render the content
      if (rendererItems != null) {
        // for each templated item, we create a new scope, which is a copy of
        // the parent scope + dataContext specific to this item
        ScopeManager? parentScope = DataScopeWidget.getScope(context);
        if (parentScope != null) {
          for (Map<String, dynamic> dataMap in rendererItems) {
            // create a new scope for each item template
            ScopeManager itemScope = parentScope.createChildScope();
            itemScope.dataContext.addDataContextById(widget.itemTemplate!.name, dataMap);

            Widget templatedWidget = itemScope.buildWidgetFromDefinition(widget.itemTemplate!.template);

            // wraps each templated widget under Templated so we can
            // constraint the data scope
            children.add(DataScopeWidget(scopeManager: itemScope, child: templatedWidget));
          }
        }
      }
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
        border: widget._controller.borderColor != null ? Border.all(color: Color(widget._controller.borderColor!)) : null,
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
        margin: EdgeInsets.all((widget._controller.margin ?? 0).toDouble()),

        //clipBehavior: Clip.hardEdge,
        decoration: boxDecoration,

        child: InkWell(
            splashColor: Colors.transparent,
            onTap: widget._controller.onTap == null ? null : () =>
                ScreenController().executeAction(context, widget._controller.onTap),
            child: Padding(
                padding: EdgeInsets.all((widget._controller.padding ?? 0).toDouble()),
                child: widget._controller.autoFit ? IntrinsicWidth(child: column) : column
            )
        )
    );

    return widget._controller.scrollable ?
    SingleChildScrollView(child: rtn) :
    rtn;
  }



}