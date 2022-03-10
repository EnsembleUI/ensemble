
import 'package:ensemble/ensemble_theme.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/widget/widget_builder.dart' as ensemble;
import 'package:ensemble/widget/widget_registry.dart';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';

class IconBuilder extends ensemble.WidgetBuilder {
  static const type = 'Icon';
  IconBuilder({
    required this.icon,
    this.size,
    this.color,
    this.padding
  });

  final String icon;
  final int? size;
  final int? color;
  final int? padding;

  static IconBuilder fromDynamic(Map<String, dynamic> props, Map<String, dynamic> styles, {WidgetRegistry? registry}) {
    return IconBuilder(
      icon: props['icon'],


      size: styles['size'],
      color: styles['color'],
      padding: styles['padding'],
    );
  }

  @override
  Widget buildWidget({
    required BuildContext context,
    List<Widget>? children,
    ItemTemplate? itemTemplate}) {
    return EnsembleIcon(
      builder: this
    );
  }

}


class EnsembleIcon extends StatefulWidget {
  const EnsembleIcon({required this.builder, Key? key})
      : super(key: key);

  final IconBuilder builder;

  @override
  IconState createState() => IconState();
}


class IconState extends State<EnsembleIcon> {

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: EdgeInsets.all((widget.builder.padding ?? 0).toDouble()),
        child: Icon(
                Icons.star,
                color: EnsembleTheme.nearlyBlue,
                size: (widget.builder.size ?? 24).toDouble()
              ),
    );
  }



}