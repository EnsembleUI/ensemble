import 'package:ensemble/widget/widget_builder.dart';

abstract class FormInputBuilder extends WidgetBuilder {
  FormInputBuilder({
    this.enabled = true,
    this.required = false,
    this.label,
    this.hintText,
    this.fontSize,
    expanded,
  }) : super(expanded: expanded);

  bool? enabled;
  bool? required;
  String? label;
  String? hintText;
  int? fontSize;
}