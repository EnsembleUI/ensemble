import 'package:ensemble/layout/base_layout.dart';
import 'package:ensemble/layout/hstack_builder.dart';
import 'package:ensemble/layout/templated.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/layout_utils.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/widget_builder.dart' as ensemble;
import 'package:ensemble/widget/widget_registry.dart';
import 'package:flutter/material.dart';

class VStackBuilder extends BaseLayout {
  static const type = 'VStack';
  VStackBuilder({
    backgroundColor,
    padding,
    gap,
    this.expanded=false,
    layout,
    alignment,
    borderRadius,
    boxShadowColor,
    boxShadowOffset,
    this.width,

    onTap,
  }) : super(backgroundColor: backgroundColor, padding: padding, gap: gap, layout: layout, alignment: alignment, borderRadius: borderRadius, boxShadowColor: boxShadowColor, boxShadowOffset: boxShadowOffset, onTap: onTap);

  int? width;
  final bool expanded;

  static VStackBuilder fromDynamic(Map<String, dynamic> props, Map<String, dynamic> styles, {WidgetRegistry? registry})
  {
    return VStackBuilder(
      // props
      onTap: props['onTap'],


      // styles
      width: styles['width'] is int ? styles['width'] : null,
      backgroundColor: styles['backgroundColor'] is int ? styles['backgroundColor'] : null,
      padding: styles['padding'],
      gap: styles['gap'],
      expanded: styles['expanded'] is bool ? styles['expanded'] : false,
      layout: styles['layout'],
      alignment: styles['alignment'],
      borderRadius: styles['borderRadius'],
      boxShadowColor: styles['boxShadowColor'],
      boxShadowOffset: styles['boxShadowOffset']
    );
  }


  @override
  Widget buildWidget({
    required BuildContext context,
    List<Widget>? children,
    ItemTemplate? itemTemplate}) {
    return VStack(builder: this, children: children, itemTemplate: itemTemplate);
  }

}

class VStack extends StatefulWidget {
  const VStack({
    required this.builder,
    this.children,
    this.itemTemplate,
    Key? key
  }) : super(key: key);

  final VStackBuilder builder;
  final List<Widget>? children;
  final ItemTemplate? itemTemplate;

  @override
  State<StatefulWidget> createState() => VStackState();
}

class VStackState extends State<VStack> {
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




  @override
  Widget build(BuildContext context) {

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
          dynamic dataList = Utils.evalVariable(dataTokens.sublist(1).join('.'), itemTemplateData);
          if (dataList is List) {
            rendererItems = dataList;
          }
        }
      }


      // now loop through each and render the content
      if (rendererItems != null) {
        for (Map<String, dynamic> dataMap in rendererItems) {
          // our dataMap needs to have a prefix using item-template's name
          Map<String, dynamic> updatedDataMap = {widget.itemTemplate!.name: dataMap};

          // Unfortunately we need to get the SubView as we are building the template.
          // TODO: refactor this. Widget shouldn't need to know about this
          WidgetModel model = PageModel.buildModel(
              widget.itemTemplate!.template,
              updatedDataMap,
              ScreenController().getSubViewDefinitionsFromRootView(context));
          Widget templatedWidget = ScreenController().buildWidget(context, model);

          // wraps each templated widget under Templated so we can
          // constraint the data scope
          children.add(Templated(localDataMap: updatedDataMap, child: templatedWidget));
        }
      }


    }


    MainAxisAlignment mainAxis = widget.builder.layout != null ?
        LayoutUtils.getMainAxisAlignment(widget.builder.layout!) :
        MainAxisAlignment.start;


    CrossAxisAlignment crossAxis = widget.builder.alignment != null ?
        LayoutUtils.getCrossAxisAlignment(widget.builder.alignment!) :
        CrossAxisAlignment.start;

    // if gap is specified, insert SizeBox between children
    if (widget.builder.gap != null) {
      List<Widget> updatedChildren = [];
      for (var i=0; i<children.length; i++) {
        updatedChildren.add(children[i]);
        if (i != children.length-1) {
          updatedChildren.add(SizedBox(height: widget.builder.gap!.toDouble()));
        }
      }
      children = updatedChildren;
    }

    Widget rtn = Ink(
      color:
        widget.builder.backgroundColor != null ?
        Color(widget.builder.backgroundColor!) :
        null,
      child: Padding(
        padding: EdgeInsets.all((widget.builder.padding ?? 0).toDouble()),
        child: InkWell(
          splashColor: Colors.transparent,
          onTap: widget.builder.onTap == null ? null : () =>
            ScreenController().executeAction(context, widget.builder.onTap),
          child: Container(
            decoration: widget.builder.boxShadowColor == null ? null : BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.all(Radius.circular((widget.builder.borderRadius ?? 0).toDouble())),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.grey.withOpacity(0.6),
                  offset: widget.builder.boxShadowOffset != null && widget.builder.boxShadowOffset!.length == 2 ?
                    Offset(
                        widget.builder.boxShadowOffset![0].toDouble(),
                        widget.builder.boxShadowOffset![1].toDouble()) :
                    const Offset(4, 4),
                  blurRadius: (widget.builder.borderRadius ?? 0).toDouble(),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular((widget.builder.borderRadius ?? 0).toDouble())),
              child: Column(
                mainAxisAlignment: mainAxis,
                crossAxisAlignment: crossAxis,
                children: children,
              )
            )
          )
        )
      )
    );

    // if width is specified
    if (widget.builder.width is int) {
      return SizedBox(
        width: (widget.builder.width as int).toDouble(),
        child: rtn);
    }
    // else if specified to stretch, and it's parent is HStack, wraps around Expanded widget
    else if (widget.builder.expanded) {
      // TODO: need to check, as only valid within a HStack/VStack/Flex otherwise exception
      return Expanded(child: rtn);
    }
    return rtn;

  }



}