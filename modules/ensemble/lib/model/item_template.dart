import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/util/utils.dart';

class ItemTemplate extends BaseItemTemplate {
  final dynamic template;

  ItemTemplate(
    super.data,
    super.name,
    this.template, {
    super.indexId,
    super.initialValue,
    super.inheritedStyles,
  });

  static ItemTemplate? from(Map? input) {
    if (input != null) {
      var data = input["data"];
      var name = input["name"];
      var template = input["template"];
      if (data == null || name == null || template == null) {
        throw LanguageError("Item template require data, name and template.");
      }
      return ItemTemplate(data, name, template,
          indexId: Utils.optionalString(input["indexId"]),
          initialValue: input["initialValue"],
          inheritedStyles: input["inheritedStyles"]);
    }
    return null;
  }
}

// for widgets that have label/labelWidget and value (e.g. RadioGroup, Dropdown)
class LabelValueItemTemplate extends BaseItemTemplate {
  final String? label;
  final dynamic labelWidget;
  final dynamic value;

  LabelValueItemTemplate(super.data, super.name, this.value,
      {super.indexId, this.label, this.labelWidget}) {
    if (label == null && labelWidget == null) {
      throw LanguageError("Either label or labelWidget is required.");
    }
  }

  static LabelValueItemTemplate? from(Map? input) {
    if (input != null) {
      dynamic data = input['data'];
      String? name = input['name'];

      dynamic value = input['value'];
      String? label = Utils.optionalString(input['label']);
      dynamic labelWidget = input['labelWidget'] ?? input["template"];

      if (data == null || name == null || value == null) {
        throw LanguageError(
            "This item template requires data, name and value.");
      }
      if (label == null && labelWidget == null) {
        throw LanguageError(
            "This item template requires either the label or labelWidget to render each item's label.");
      }

      return LabelValueItemTemplate(data, name, value,
          indexId: Utils.optionalString(input["indexId"]),
          label: label,
          labelWidget: labelWidget);
    }
    return null;
  }
}

class BaseItemTemplate {
  // array of data to iterate through
  dynamic data;

  // use this as the id name for each loop
  final String name;

  // this is the id for the index that can be accessed inside an item template (default 'index')
  final String indexId;

  // what the data list's initial value should be
  dynamic initialValue;
  Map<String, dynamic>? inheritedStyles;

  BaseItemTemplate(this.data, this.name,
      {String? indexId, this.initialValue, this.inheritedStyles})
      : this.indexId = indexId ?? 'index';
}
