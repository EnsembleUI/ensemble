import 'package:ensemble/widget/widget.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';

class Dropdown extends SelectOne {
  static const type = "Dropdown";
  Dropdown({Key? key}) : super(key: key);

  @override
  SelectOneType getType() {
    return SelectOneType.dropdown;
  }

}


abstract class SelectOne extends StatefulWidget with Invokable, HasController<SelectOneController, SelectOneState> {
  SelectOne({Key? key}) : super(key: key);

  final SelectOneController _controller = SelectOneController();
  @override
  SelectOneController get controller => _controller;

  @override
  State<StatefulWidget> createState() => SelectOneState();

  @override
  Map<String, Function> getters() {
    return {
      'value': () => _controller.value,
    };
  }

  @override
  Map<String, Function> setters() {
    return {
      'value': (value) => _controller.value = value,
      'items': (values) => updateItems(values)
    };
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  /// each value can be an YamlMap (value/label pair) or dynamic
  void updateItems(dynamic values) {
    List<SelectOneItem> entries = [];
    if (values is YamlList) {
      for (var element in values) {
        // must be of value/label pair. Maybe let user overrides later
        if (element is YamlMap) {
          if (element['value'] != null) {
            entries.add(SelectOneItem(
                value: element['value'],
                label: element['label']?.toString()
            ));
          }
        }
        // simply use the value
        else {
          entries.add(SelectOneItem(
            value: element
          ));
        }
      }
    }
    _controller.items = entries;
  }

  void onSelectionChanged(dynamic value) {
    setProperty('value', value);
    print("new value $value");
  }

  SelectOneType getType();

}

enum SelectOneType {
  dropdown
}

class SelectOneController extends FormFieldController {
  List<SelectOneItem>? items;
  dynamic value;
}

class SelectOneState extends WidgetState<SelectOne> {
  @override
  Widget build(BuildContext context) {
    if (widget.getType() == SelectOneType.dropdown) {
      return DropdownButtonFormField<dynamic>(
        hint: widget._controller.hintText == null ? null : Text(widget._controller.hintText!),
        value: widget._controller.value,
        items: buildItems(widget._controller.items),
        onChanged: (item) => widget.onSelectionChanged(item));
    }
    return const Text("Unimplemented SelectOne");
  }

  List<DropdownMenuItem<dynamic>>? buildItems(List<SelectOneItem>? items) {
    List<DropdownMenuItem<dynamic>>? results;
    if (items != null) {
      results = [];
      for (SelectOneItem item in items) {
        results.add(DropdownMenuItem(
          value: item.value,
          child: Text(item.label ?? item.value)));
      }
    }
    return results;
  }

}

/// Data Object for a SelectOne's item
class SelectOneItem {
  SelectOneItem({
    required this.value,
    this.label
  });

  final dynamic value;
  final String? label;
}