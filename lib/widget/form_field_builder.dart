import 'package:ensemble/widget/widget_builder.dart';

/// base class for form input widgets
abstract class FormFieldBuilder extends WidgetBuilder {
  FormFieldBuilder({
    this.enabled = true,
    this.required = false,
    this.label,
    this.hintText,
    this.fontSize,
    styles,
  }) : super(styles: styles);

  bool enabled;
  bool required;
  String? label;
  String? hintText;
  int? fontSize;
}