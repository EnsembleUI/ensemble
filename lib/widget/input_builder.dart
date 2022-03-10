import 'package:ensemble/widget/widget_builder.dart';

abstract class InputBuilder extends WidgetBuilder {
  InputBuilder({
    this.enabled,
    this.required,
    this.label,
    this.hintText});

  final bool? enabled;
  final bool? required;
  final String? label;
  final String? hintText;
}