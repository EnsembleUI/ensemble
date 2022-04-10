import 'package:ensemble/page_model.dart';
import 'package:ensemble/widget/widget_builder.dart' as ensemble;
import 'package:ensemble/widget/widget_registry.dart';
import 'package:flutter/material.dart';

class UnknownBuilder extends ensemble.WidgetBuilder {
  static const type = 'unknown';
  UnknownBuilder({
    styles
  }): super(styles: styles);

  static UnknownBuilder fromDynamic(Map<String, dynamic> props, Map<String, dynamic> styles, {WidgetRegistry? registry})
  {
    return UnknownBuilder(styles: styles);
  }

  @override
  Widget buildWidget({
    required BuildContext context,
    List<Widget>? children,
    ItemTemplate? itemTemplate}) {
    return const Text("Unsupported Widget");
  }
}
