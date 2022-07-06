
import 'package:ensemble/framework/action.dart' as framework;
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/widget/form_helper.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:ensemble_ts_interpreter/invokables/invokablelist.dart';
import 'package:ensemble_ts_interpreter/invokables/invokablemap.dart';
import 'package:ensemble_ts_interpreter/invokables/invokableprimitives.dart';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';
//import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
  void setItemsFromString(dynamic strValues,[dynamic delimiter=',']) {
    if ( strValues is InvokableString ) {
      strValues = strValues.val;
    }
    if ( delimiter is InvokableString ) {
      delimiter = delimiter.val;
    }
    delimiter ??= ',';
    List<Map<String,String>> values = [];
    setItemsFromArray(strValues.split(delimiter));
  }
  void setItemsFromArray(dynamic arrValues) {
    if ( arrValues is InvokableList ) {
      arrValues = arrValues.list;
    }
    List<Map<String,String>> values = [];
    for ( String str in arrValues ) {
      values.add({'label':str,'value':str});
    }
    updateItems(values);
  }
  @override
  Map<String, Function> setters() {
    return {
      'value': (value) => _controller.maybeValue = value,
      'items': (values) => updateItems(values),
      'onChange': (definition) => _controller.onChange = Utils.getAction(definition, initiator: this),
      'itemsFromString': (dynamic strValues) => setItemsFromString(strValues),
      'itemsFromArray': (dynamic arrValues) => setItemsFromArray(arrValues)
    };
  }

  @override
  Map<String, Function> methods() {
    return {
      'itemsFromString': (dynamic strValues,[dynamic delimiter=',']) {
        setItemsFromString(strValues,delimiter);
      }
    };
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
    if ( values is InvokableList ) {
      values = values.list;
    }
    if (values is List) {
      for (var element in values) {
        if ( element is InvokableMap ) {
          element = element.map;
        }
        // must be of value/label pair. Maybe let user overrides later
        if (element is Map) {
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

  framework.EnsembleAction? onChange;
}

class SelectOneState extends FormFieldWidgetState<SelectOne> {
  final focusNode = FocusNode();
  @override
  void initState() {
    // validate on blur
    /*focusNode.addListener(() {
      if (!focusNode.hasFocus && validatorKey.currentState != null) {
        validatorKey.currentState!.validate();
      }
    });*/
    super.initState();
  }

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  void onSelectionChanged(dynamic value) {
    widget.onSelectionChanged(value);
    if (widget._controller.onChange != null) {
      ScreenController().executeAction(context, widget._controller.onChange!);
    }
  }



  @override
  Widget build(BuildContext context) {
    if (widget.getType() == SelectOneType.dropdown) {
      return DropdownButtonFormField<dynamic>(
        key: validatorKey,
        validator: (value) {
          if (widget._controller.required && widget.getValue() == null) {
            //return AppLocalizations.of(context)!.widget_form_required;
            return "This field is required";
          }
          return null;
        },
        hint: widget._controller.hintText == null ? null : Text(widget._controller.hintText!),
        value: widget.getValue(),
        items: buildItems(widget._controller.items),
        onChanged: isEnabled() ? (item) => onSelectionChanged(item) : null,
        focusNode: focusNode,
        decoration: inputDecoration);
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
          child: Text(Utils.optionalString(item.label) ?? item.value)));
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