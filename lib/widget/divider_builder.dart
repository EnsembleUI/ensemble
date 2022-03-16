import 'package:ensemble/ensemble_theme.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/widget/widget_builder.dart' as ensemble;
import 'package:ensemble/widget/widget_registry.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';

class DividerBuilder extends ensemble.WidgetBuilder {
  static const type = 'Divider';
  DividerBuilder({
    this.thickness,
    this.color,
    this.indent,
    this.endIndent,
    expanded,
  }) : super(expanded: expanded);
  final int? thickness;
  int? color;
  int? indent;
  int? endIndent;

  static DividerBuilder fromDynamic(Map<String, dynamic> props, Map<String, dynamic> styles, {WidgetRegistry? registry})
  {
    return DividerBuilder(
      // props

      // styles
      expanded: styles['expanded'] is bool ? styles['expanded'] : false,
      thickness: styles['thickness'] is int? styles['thickness'] : 1,
      color: styles['color'],
      indent: styles['indent'],
      endIndent: styles['endIndent'],
    );
  }


  @override
  Widget buildWidget({
    required BuildContext context,
    List<Widget>? children,
    ItemTemplate? itemTemplate}) {
    return EnsembleDivider(builder: this);
  }

}

class EnsembleDivider extends StatefulWidget {
  const EnsembleDivider({
    required this.builder,
    Key? key
  }) : super(key: key);

  final DividerBuilder builder;

  @override
  State<StatefulWidget> createState() => DividerState();
}

class DividerState extends State<EnsembleDivider> {
  @override
  Widget build(BuildContext context) {

    return Divider(
        thickness: (widget.builder.thickness ?? 1).toDouble(),
        indent: (widget.builder.indent ?? 0).toDouble(),
        endIndent: (widget.builder.endIndent ?? 0).toDouble(),
        color:
          widget.builder.color != null ?
          Color(widget.builder.color!) :
          const Color(0xFFD3D3D3)
    );


  }


}