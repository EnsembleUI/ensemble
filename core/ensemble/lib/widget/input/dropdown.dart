import 'package:ensemble/ensemble_theme.dart';
import 'package:ensemble/framework/action.dart' as framework;
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/widget/icon.dart' as iconframework;
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble/widget/input/form_helper.dart';
import 'package:ensemble/widget/input/form_textfield.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../framework/model.dart';
//import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class Dropdown extends SelectOne {
  static const type = "Dropdown";
  Dropdown({Key? key}) : super(key: key);

  @override
  SelectOneType getType() {
    return SelectOneType.dropdown;
  }
}

abstract class SelectOne extends StatefulWidget
    with Invokable, HasController<SelectOneController, SelectOneState> {
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

  void setItemsFromString(dynamic strValues, [dynamic delimiter = ',']) {
    delimiter ??= ',';
    List<Map<String, String>> values = [];
    setItemsFromArray(strValues.split(delimiter));
  }

  void setItemsFromArray(dynamic arrValues) {
    List<Map<String, String>> values = [];
    for (String str in arrValues) {
      values.add({'label': str, 'value': str});
    }
    updateItems(values);
  }

  @override
  Map<String, Function> setters() {
    return {
      'value': (value) => _controller.maybeValue = value,
      'items': (values) => updateItems(values),
      'onChange': (definition) => _controller.onChange =
          framework.EnsembleAction.fromYaml(definition, initiator: this),
      'itemsFromString': (dynamic strValues) => setItemsFromString(strValues),
      'itemsFromArray': (dynamic arrValues) => setItemsFromArray(arrValues),
      'autoComplete': (value) =>
          _controller.autoComplete = Utils.getBool(value, fallback: false),
    };
  }

  @override
  Map<String, Function> methods() {
    return {
      'getValue': () => getValue(),
      'clear': () => _controller.inputFieldAction?.clear(),
      'focus': () => _controller.inputFieldAction?.focusInputField(),
      'unfocus': () => _controller.inputFieldAction?.unfocusInputField(),
      'itemsFromString': (dynamic strValues, [dynamic delimiter = ',']) {
        setItemsFromString(strValues, delimiter);
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

  void updateItems(dynamic values) {
    List<SelectOneItem> entries = [];
    if (values is List) {
      calculateIconSize(values);
      for (var element in values) {
        // must be of value/label pair. Maybe let user overrides later
        if (element is Map) {
          if (element['value'] != null) {
            entries.add(
              SelectOneItem(
                value: element['value'],
                label: element['label']?.toString(),
                icon: Utils.getIcon(element['icon']),
                isIcon: isIconExist(values),
              ),
            );
          }
        }
        // simply use the value
        else {
          entries.add(SelectOneItem(value: element));
        }
      }
    }
    _controller.items = entries;

    // ensure that the value is still correct
    if (!isValueInItems()) {
      _controller.maybeValue = null;
    }
  }

  bool isIconExist(List v) {
    for (var e in v) {
      if (e['icon'] != null) {
        return true;
      }
    }
    return false;
  }

  void calculateIconSize(List v) {
    List iconSize = [];
    _controller.gap = 0;
    for (var e in v) {
      if (e is Map) {
        if (e['icon'] != null) {
          if (e['icon']['size'] != null) {
            iconSize.add(e['icon']['size']);
          }
        }
      }
    }
    if (iconSize.isNotEmpty) {
      _controller.gap =
          iconSize.reduce((curr, next) => curr > next ? curr : next);
    } else {
      _controller.gap = 0;
    }
  }

  void onSelectionChanged(dynamic value) {
    setProperty('value', value);
  }

  // to be implemented by subclass
  SelectOneType getType();
}

enum SelectOneType { dropdown }

mixin SelectOneInputFieldAction on FormFieldWidgetState<SelectOne> {
  void clear();
  void focusInputField();
  void unfocusInputField();
}

class SelectOneController extends FormFieldController {
  SelectOneInputFieldAction? inputFieldAction;
  List<SelectOneItem>? items;

  // this is our value but it can be in an invalid state.
  // Since user can set items/value in any order and at anytime, the value may
  // not be one of the items, hence it could be in an incorrect state
  dynamic maybeValue;
  int gap = 0;
  bool autoComplete = false;

  framework.EnsembleAction? clear;
  framework.EnsembleAction? onChange;
}

class SelectOneState extends FormFieldWidgetState<SelectOne>
    with SelectOneInputFieldAction {
  FocusNode focusNode = FocusNode();
  TextEditingController textEditingController = TextEditingController();

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.controller.inputFieldAction = this;
  }

  @override
  void didUpdateWidget(covariant SelectOne oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.controller.inputFieldAction = this;
  }

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  void onSelectionChanged(dynamic value) {
    final oldValue = widget._controller.maybeValue;

    if (oldValue != value) {
      widget.onSelectionChanged(value);

      if (widget._controller.onChange != null) {
        ScreenController().executeAction(
          context,
          widget._controller.onChange!,
          event: EnsembleEvent(widget),
        );
      }
    }
  }

  @override
  Widget buildWidget(BuildContext context) {
    Widget rtn;
    if (widget._controller.autoComplete == false) {
      // if not overrode, decrease the default theme's vertical contentPadding
      // slightly so the dropdown is the same height as other input widgets
      EdgeInsetsGeometry? adjustedContentPadding;
      if (widget._controller.contentPadding == null) {
        InputDecorationTheme themeDecoration =
            Theme.of(context).inputDecorationTheme;
        if (themeDecoration.contentPadding != null) {
          adjustedContentPadding = themeDecoration.contentPadding!
              .subtract(const EdgeInsets.only(top: 2, bottom: 3));
        }
      }

      rtn = DropdownButtonFormField<dynamic>(
          key: validatorKey,
          validator: (value) {
            if (widget._controller.required && widget.getValue() == null) {
              return Utils.translateWithFallback(
                  'ensemble.input.required', 'This field is required');
            }
            return null;
          },
          hint: widget._controller.hintText == null
              ? null
              : Text(widget._controller.hintText!),
          value: widget.getValue(),
          items: buildItems(widget._controller.items),
          dropdownColor: Colors.white,
          onChanged: isEnabled() ? (item) => onSelectionChanged(item) : null,
          focusNode: focusNode,
          icon: const Icon(Icons.keyboard_arrow_down, size: 20),
          decoration:
              inputDecoration.copyWith(contentPadding: adjustedContentPadding));
    } else {
      rtn = LayoutBuilder(
          builder: (context, constraints) => RawAutocomplete<SelectOneItem>(
                focusNode: focusNode,
                textEditingController: textEditingController,
                optionsBuilder: (TextEditingValue textEditingValue) =>
                    buildAutoCompleteOptions(textEditingValue),
                displayStringForOption: (SelectOneItem option) =>
                    option.label ?? option.value,
                fieldViewBuilder: (BuildContext context,
                    TextEditingController fieldTextEditingController,
                    FocusNode fieldFocusNode,
                    VoidCallback onFieldSubmitted) {
                  return TextField(
                      enabled: isEnabled(),
                      showCursor: true,
                      style: const TextStyle(
                          color: Colors.black, fontWeight: FontWeight.w500),
                      controller: fieldTextEditingController,
                      focusNode: fieldFocusNode,
                      decoration: inputDecoration);
                },
                onSelected: (SelectOneItem selection) {
                  onSelectionChanged(selection.value);
                  if (kDebugMode) {
                    print('Selected: ${selection.value}');
                  }
                },
                optionsViewBuilder: (BuildContext context,
                    AutocompleteOnSelected<SelectOneItem> onSelected,
                    Iterable<SelectOneItem> options) {
                  return buildAutoCompleteItems(
                      constraints, options, onSelected);
                },
              ));
    }
    return InputWrapper(
        type: Dropdown.type, controller: widget._controller, widget: rtn);
  }

  // ---------------------- Search From the List if [AUTOCOMPLETE] is true ---------------------------------
  List<SelectOneItem> buildAutoCompleteOptions(
      TextEditingValue textEditingValue) {
    return widget._controller.items!
        .where(
          (SelectOneItem options) => options.label == null
              ? options.value
                  .toString()
                  .toLowerCase()
                  .startsWith(textEditingValue.text.toLowerCase())
              : options.label
                  .toString()
                  .toLowerCase()
                  .startsWith(textEditingValue.text.toLowerCase()),
        )
        .toList();
  }

// ---------------------------------- Build Items ListTile if [AUTOCOMPLETE] is true ---------------------------------
  Widget buildAutoCompleteItems(
    BoxConstraints constraints,
    Iterable<SelectOneItem> options,
    AutocompleteOnSelected<SelectOneItem> onSelected,
  ) {
    return Align(
        alignment: Alignment.topLeft,
        child: Material(
          shadowColor: EnsembleTheme.grey,
          elevation: 2.0,
          type: MaterialType.card,
          child: SizedBox(
              width: constraints.biggest.width,
              height: options.length < 5 ? 52.0 * options.length : 52.0 * 5,
              child: ListView.builder(
                itemCount: options.length,
                shrinkWrap: true,
                padding: const EdgeInsets.only(left: 10),
                itemBuilder: (BuildContext c, i) {
                  final SelectOneItem option = options.elementAt(i);
                  return GestureDetector(
                      onTap: () {
                        onSelected(option);
                      },
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(0),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            option.icon != null
                                ? iconframework.Icon.fromModel(option.icon!)
                                : SizedBox(
                                    width: widget._controller.gap.toDouble(),
                                  ),
                            SizedBox(
                              width: option.icon != null
                                  ? option.isIcon && option.icon!.size == null
                                      ? paddingifIconSizeNull()
                                      : option.icon!.size != null
                                          ? option.icon!.size ==
                                                  widget._controller.gap
                                              ? 10
                                              : checkDifference(
                                                  option.icon!.size!)
                                          : widget._controller.gap.toDouble() +
                                              10.0
                                  : 10.0,
                            ),
                            Text(
                              Utils.optionalString(option.label) ??
                                  option.value,
                            ),
                          ],
                        ),
                      ));
                },
              )),
        ));
  }

// ---------------------------------- Build Items ListTile if [AUTOCOMPLETE] is false ---------------------------------
  List<DropdownMenuItem<dynamic>>? buildItems(List<SelectOneItem>? items) {
    List<DropdownMenuItem<dynamic>>? results;
    if (items != null) {
      results = [];
      for (SelectOneItem item in items) {
        item.isIcon == true
            ? results.add(
                DropdownMenuItem(
                  child: Row(
                    children: [
                      item.icon != null
                          ? iconframework.Icon.fromModel(item.icon!)
                          : SizedBox(
                              width: widget._controller.gap.toDouble(),
                            ),
                      SizedBox(
                        width: item.icon != null
                            ? item.isIcon && item.icon!.size == null
                                ? paddingifIconSizeNull()
                                : item.icon!.size != null
                                    ? item.icon!.size == widget._controller.gap
                                        ? 10
                                        : checkDifference(item.icon!.size!)
                                    : widget._controller.gap.toDouble() + 10.0
                            : 10.0,
                      ),
                      Text(
                        Utils.optionalString(item.label) ?? item.value,
                      ),
                    ],
                  ),
                  value: item.value,
                ),
              )
            : results.add(
                DropdownMenuItem(
                  value: item.value,
                  child: Text(Utils.optionalString(item.label) ?? item.value),
                ),
              );
      }
    }
    return results;
  }

  double checkDifference(int s) {
    int i = widget._controller.gap - s;
    return (10 + i).toDouble();
  }

  // -------------- Returns the padding if icon size is not defined in YAML it will give space between [Icons] and [Text] -----------------
  double paddingifIconSizeNull() {
    int i = widget._controller.gap - 23;
    if (i < 0) {
      return (i.abs() - 10).abs().toDouble();
    } else {
      return (i + 10).toDouble();
    }
  }

  @override
  void clear() {
    onSelectionChanged(null);
    textEditingController.clear();
  }

  @override
  void focusInputField() {
    if (!focusNode.hasFocus) {
      focusNode.requestFocus();
    }
  }

  @override
  void unfocusInputField() {
    if (focusNode.hasFocus) {
      focusNode.unfocus();
    }
  }
}

/// Data Object for a SelectOne's item
class SelectOneItem {
  SelectOneItem(
      {required this.value, this.label, this.icon, this.isIcon = false});

  final dynamic value;
  final String? label;
  IconModel? icon;
  final bool isIcon;
}
