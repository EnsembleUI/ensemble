import 'package:ensemble/framework/icon.dart' as ensemble;
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
      'value': () => getValue(),
    };
  }

  @override
  Map<String, Function> setters() {
    return {
      'value': (value) => _controller.maybeValue = value,
      'items': (values) => updateItems(values)
    };
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  bool isValueInItems() {
    if (_controller.maybeValue != null && _controller.items != null) {
      for (SelectOneItem item in _controller.items!) {
        if (_controller.maybeValue == item.value) {
          return true;
        }
      }
    }
    return false;
  }

  dynamic getValue() {
    if (isValueInItems()) {
      return _controller.maybeValue;
    }
    return null;
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

    // ensure that the value is still correct
    if (!isValueInItems()) {
      _controller.maybeValue = null;
    }


  }

  void onSelectionChanged(dynamic value) {
    setProperty('value', value);
  }

  // to be implemented by subclass
  SelectOneType getType();

}

enum SelectOneType {
  dropdown
}

class SelectOneController extends FormFieldController {
  List<SelectOneItem>? items;

  // this is our value but it can be in an invalid state.
  // Since user can set items/value in any order and at anytime, the value may
  // not be one of the items, hence it could be in an incorrect state
  dynamic maybeValue;
}

class SelectOneState extends WidgetState<SelectOne> {
  final focusNode = FocusNode();
  String? error;

  void validate() {
    if (widget.controller.required) {
      setState(() {
        error = widget.getValue() == null ? "This field is required" : null;
      });
    }
  }

  @override
  void initState() {
    // validate on blur
    focusNode.addListener(() {
      if (!focusNode.hasFocus) {
        validate();
      }
    });
    super.initState();
  }
  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.getType() == SelectOneType.dropdown) {
      return DropdownButtonFormField<dynamic>(
        hint: widget._controller.hintText == null ? null : Text(widget._controller.hintText!),
        value: widget.getValue(),
        items: buildItems(widget._controller.items),
        onChanged: (item) => widget.onSelectionChanged(item),
        focusNode: focusNode,
        decoration: getDecoration());
    }
    return const Text("Unimplemented SelectOne");
  }

  InputDecoration getDecoration() {
    return InputDecoration(
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelText: widget.controller.label,
        hintText: widget.controller.hintText,
        errorText: error,
        icon: widget.controller.icon == null ? null :
          ensemble.Icon(
            widget.controller.icon!,
            library: widget.controller.iconLibrary,
            size: widget.controller.iconSize,
            color:
              widget._controller.iconColor != null ?
              Color(widget.controller.iconColor!) :
              null)
    );
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