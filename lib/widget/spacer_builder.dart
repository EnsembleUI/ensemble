import 'package:ensemble/ensemble_theme.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/widget/widget_builder.dart' as ensemble;
import 'package:ensemble/widget/widget_registry.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';

class SpacerBuilder extends ensemble.WidgetBuilder {
  static const type = 'Spacer';
  SpacerBuilder({
    this.size,
    styles
  }): super(styles: styles);

  int? size;

  static SpacerBuilder fromDynamic(Map<String, dynamic> props, Map<String, dynamic> styles, {WidgetRegistry? registry})
  {
    return SpacerBuilder(
      // props

      // styles
      size: styles['size'],
      styles: styles
    );
  }


  @override
  Widget buildWidget({
    required BuildContext context,
    List<Widget>? children,
    ItemTemplate? itemTemplate}) {
    return EnsembleSpacer(builder: this);
  }

}

class EnsembleSpacer extends StatefulWidget {
  const EnsembleSpacer({
    required this.builder,
    Key? key
  }) : super(key: key);

  final SpacerBuilder builder;

  @override
  State<StatefulWidget> createState() => SpacerState();
}

class SpacerState extends State<EnsembleSpacer> {
  @override
  Widget build(BuildContext context) {

    if (widget.builder.size != null) {
      return SizedBox(
          width: widget.builder.size!.toDouble(),
          height: widget.builder.size!.toDouble());
    }
    return const Spacer();
  }


}