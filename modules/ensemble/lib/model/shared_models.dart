import 'package:ensemble/framework/error_handling.dart';

// for widgets that have label/labelWidget and value (e.g. RadioGroup, Dropdown)
class LabelValueItemTemplate extends BaseItemTemplate {
  final String? label;
  final dynamic labelWidget;
  final dynamic value;

  LabelValueItemTemplate(super.data, super.name, this.value,
      {this.label, this.labelWidget}) {
    if (label == null && labelWidget == null) {
      throw LanguageError("Either label or labelWidget is required.");
    }
  }
}

class ItemTemplate extends BaseItemTemplate {
  final dynamic template;

  ItemTemplate(
    super.data,
    super.name,
    this.template, {
    super.initialValue,
    super.inheritedStyles,
  });
}

class BaseItemTemplate {
  // array of data to iterate through
  dynamic data;

  // use this as the id name for each loop
  final String name;

  // what the data list's initial value should be
  List<dynamic>? initialValue;
  Map<String, dynamic>? inheritedStyles;

  BaseItemTemplate(this.data, this.name,
      {this.initialValue, this.inheritedStyles});
}
