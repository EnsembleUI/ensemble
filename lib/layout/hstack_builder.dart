import 'package:ensemble/layout/base_layout.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/layout_utils.dart';
import 'package:ensemble/widget/form_text_input_builder.dart';
import 'package:ensemble/widget/image_builder.dart';
import 'package:ensemble/widget/widget_registry.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';

class HStackBuilder extends BaseLayout {
  static const type = 'HStack';
  HStackBuilder({
    backgroundColor,
    padding,
    gap,
    this.expanded=false,
    layout,
    alignment,
    borderRadius,
    boxShadowColor,
    boxShadowOffset,     // HStack sometimes need to stretch content to 100%
    this.height,

    onTap,
  }) : super(backgroundColor: backgroundColor, padding: padding, gap: gap, layout: layout, alignment: alignment, borderRadius: borderRadius, boxShadowColor: boxShadowColor, boxShadowOffset: boxShadowOffset, onTap: onTap);

  int? height;
  final bool expanded;

  static HStackBuilder fromDynamic(Map<String, dynamic> props, Map<String, dynamic> styles, {WidgetRegistry? registry})
  {
    return HStackBuilder(
      // props
      onTap: props['onTap'],

      // styles
      height: styles['height'] is int ? styles['height'] : null,
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
    return HStack(builder: this, children: children, itemTemplate: itemTemplate);
  }

}

class HStack extends StatefulWidget {
  const HStack({
    required this.builder,
    this.children,
    this.itemTemplate,
    Key? key
  }) : super(key: key);

  final HStackBuilder builder;
  final List<Widget>? children;
  final ItemTemplate? itemTemplate;

  @override
  State<StatefulWidget> createState() => HStackState();
}

class HStackState extends State<HStack> {
  // data exclusively for item template (e.g api result)
  Map? itemTemplateData;

  @override
  void initState() {
    super.initState();

    // register listener for item template's data changes
    if (widget.itemTemplate != null) {

    }


  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();

    itemTemplateData = null;
  }




  @override
  Widget build(BuildContext context) {
    List<Widget> children = [];
    List<Widget> originalChildren = widget.children ?? [];
    for (Widget originalChild in originalChildren) {
      // Input Widgets stretches 100% to its parent,
      // so need to be wrapped inside a Flexible to size more than 1
      if (originalChild is TextInput || originalChild is EnsembleImage) {
        children.add(Flexible(child: originalChild));
      } else {
        children.add(originalChild);
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
          updatedChildren.add(SizedBox(width: widget.builder.gap!.toDouble()));
        }
      }
      children = updatedChildren;
    }

    Widget rtn = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(
                (widget.builder.borderRadius ?? 0).toDouble())),
        border:
          widget.builder.backgroundColor != null ?
          Border.all(color: Color(widget.builder.backgroundColor!), width: 3) :
          null


      ),
      child: Ink(
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
                    child: Row(
                      mainAxisAlignment: mainAxis,
                      crossAxisAlignment: crossAxis,
                      children: children,
                    ),
                  )
                )
            )




    );

    // if height is specified
    if (widget.builder.height is int) {
      return SizedBox(
          height: (widget.builder.height as int).toDouble(),
          child: rtn);
    }
    // if specified to stretch, and it's parent is HStack, wraps around Expanded widget
    else if (widget.builder.expanded) {
      // TODO: need to check, as only valid within a HStack/VStack/Flex
      return Expanded(child: rtn);
    }
    return rtn;



  }

  WidgetModel translateModel(WidgetModel itemTemplate, Map data, String variableName) {


    /*

    data.forEach((key, value) {
      translateExpression(keyValue, key, data, variableName)
    })
*/
    return itemTemplate;
  }

  void translateExpression(Map keyValue, String key, Map data, String variableName) {
    dynamic value = keyValue[key];
    if (value is String && value.startsWith("\$(") && value.endsWith(")")) {


    } else if (value is Map) {
      //translateExpression(value.v, data, variableName)
    }

  }


}