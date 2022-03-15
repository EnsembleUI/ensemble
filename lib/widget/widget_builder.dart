
import 'package:ensemble/page_model.dart';
import 'package:flutter/material.dart';

@immutable
abstract class WidgetBuilder {
  const WidgetBuilder({
    this.expanded = false
  });

  final bool expanded;

  Widget buildWidget({required BuildContext context, List<Widget>? children, ItemTemplate? itemTemplate});


}