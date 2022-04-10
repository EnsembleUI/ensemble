import 'package:ensemble/layout/base_layout.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/widget/form_text_input_builder.dart';
import 'package:ensemble/widget/image_builder.dart';
import 'package:ensemble/widget/widget_builder.dart' as ensemble;
import 'package:ensemble/widget/widget_registry.dart';
import 'package:flutter/material.dart';

class GridBuilder extends ensemble.WidgetBuilder {
  static const type = 'Grid';
  GridBuilder({
    this.columnCount = 1,
    styles
  }) : super(styles: styles);

  int columnCount;


  static GridBuilder fromDynamic(Map<String, dynamic> props, Map<String, dynamic> styles, {WidgetRegistry? registry})
  {
    return GridBuilder(
      // props
      columnCount: props['columnCount'],

      // styles

      styles: styles
    );
  }


  @override
  Widget buildWidget({
    required BuildContext context,
    List<Widget>? children,
    ItemTemplate? itemTemplate}) {
    return Grid(builder: this, children: children, itemTemplate: itemTemplate);
  }

}

class Grid extends StatefulWidget {
  const Grid({
    required this.builder,
    this.children,
    this.itemTemplate,
    Key? key
  }) : super(key: key);

  final GridBuilder builder;
  final List<Widget>? children;
  final ItemTemplate? itemTemplate;

  @override
  State<StatefulWidget> createState() => GridState();
}

class GridState extends State<Grid> {
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


    return Container(
      width: 400,
      height: 800,
      child: GridView.count(
        crossAxisCount: widget.builder.columnCount,
        childAspectRatio: 3,
        children: widget.children ?? [],
      ),
    );
  }

}