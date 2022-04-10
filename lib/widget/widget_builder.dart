
import 'package:ensemble/page_model.dart';
import 'package:flutter/material.dart';

/// base class for all our widgets
abstract class WidgetBuilder {
  WidgetBuilder({
    required Map<String, dynamic> styles,
  }) {
    expanded = styles['expanded'] is bool ? styles['expanded'] : false;

  }
  late final bool expanded;

  Widget buildWidget({required BuildContext context, List<Widget>? children, ItemTemplate? itemTemplate});

}