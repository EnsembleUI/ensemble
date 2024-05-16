import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:ensemble/ensemble_theme.dart';
import 'package:ensemble/framework/action.dart' as framework;
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/theme/theme_manager.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/framework/widget/icon.dart' as iconframework;
import 'package:ensemble/layout/templated.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/HasTextPlaceholder.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble/widget/helpers/form_helper.dart';
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
  List<String> passthroughSetters() => ['itemTemplate', 'createNewItem'];

  @override
  Map<String, Function> getters() {
    var getters = _controller.textPlaceholderGetters;
    getters.addAll({
      'value': () => getValue(),
    });
    return getters;
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
    var setters = _controller.textPlaceholderSetters;
    setters.addAll({
      'value': (value) => _controller.maybeValue = value,
      'items': (values) => updateItems(values),
      'onChange': (definition) => _controller.onChange =
          framework.EnsembleAction.fromYaml(definition, initiator: this),
      'itemsFromString': (dynamic strValues) => setItemsFromString(strValues),
      'itemsFromArray': (dynamic arrValues) => setItemsFromArray(arrValues),
      'autoComplete': (value) =>
          _controller.autoComplete = Utils.getBool(value, fallback: false),
      'dropdownOffsetX': (value) =>
          _controller.dropdownOffsetX = Utils.optionalInt(value),
      'dropdownOffsetY': (value) =>
          _controller.dropdownOffsetY = Utils.optionalInt(value),
      'dropdownBackgroundColor': (color) =>
          _controller.dropdownBackgroundColor = Utils.getColor(color),
      'dropdownBorderRadius': (value) =>
          _controller.dropdownBorderRadius = Utils.getBorderRadius(value),
      'dropdownBorderColor': (value) =>
          _controller.dropdownBorderColor = Utils.getColor(value),
      'dropdownBorderWidth': (value) =>
          _controller.dropdownBorderWidth = Utils.optionalInt(value),
      'dropdownMaxHeight': (value) =>
          _controller.dropdownMaxHeight = Utils.optionalInt(value, min: 0),
      'itemTemplate': (itemTemplate) => _setItemTemplate(itemTemplate),
      'createNewItem': (value) => _setCreateNewItem(value),
    });
    return setters;
  }

  void _setCreateNewItem(dynamic input) {
    if (input is! Map) return;
    _controller.onCreateItemTap =
        framework.EnsembleAction.fromYaml(input['onTap']);

    _controller.createNewItemIcon = Utils.getIcon(input['icon']);
    _controller.createNewItemLabel = Utils.optionalString(input['label']);
  }

  void _setItemTemplate(dynamic input) {
    if (input is Map) {
      dynamic data = input['data'];
      String? name = input['name'];
      dynamic template = input['template'];
      dynamic value = input['value'];
      if (data != null && name != null && template != null && value != null) {
        _controller.itemTemplate =
            DropdownItemTemplate(data, name, template, value);
      }
    }
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
    if (_controller.maybeValue != null) {
      // check for match in the item list
      if (_controller.items != null) {
        for (SelectOneItem item in _controller.items!) {
          if (_controller.maybeValue == item.value) {
            return true;
          }
        }
      }
      // check for match in the item template
      if (_controller.itemTemplate != null) {
        // TODO: we have no way to look into the itemTemplate to see
        // if the value matches one of them. Return true for now
        return true;
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

class SelectOneController extends FormFieldController with HasTextPlaceholder {
  SelectOneInputFieldAction? inputFieldAction;
  List<SelectOneItem>? items;

  // this is our value but it can be in an invalid state.
  // Since user can set items/value in any order and at anytime, the value may
  // not be one of the items, hence it could be in an incorrect state
  dynamic maybeValue;
  int gap = 0;
  bool autoComplete = false;

  // dropdown styles
  int? dropdownOffsetX;
  int? dropdownOffsetY;
  Color? dropdownBackgroundColor;
  EBorderRadius? dropdownBorderRadius;
  int? dropdownBorderWidth;
  Color? dropdownBorderColor;
  int? dropdownMaxHeight;

  DropdownItemTemplate? itemTemplate;

  framework.EnsembleAction? clear;
  framework.EnsembleAction? onChange;
  framework.EnsembleAction? onCreateItemTap;
  IconModel? createNewItemIcon;
  String? createNewItemLabel;
}

class SelectOneState extends FormFieldWidgetState<SelectOne>
    with SelectOneInputFieldAction, TemplatedWidgetState {
  FocusNode focusNode = FocusNode();
  TextEditingController textEditingController = TextEditingController();
  List? dataList;

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

    if (widget._controller.itemTemplate != null) {
      registerItemTemplate(context, widget._controller.itemTemplate!,
          onDataChanged: (data) {
        setState(() {
          dataList = data;
        });
      }, evaluateInitialValue: true);
    }
  }

  @override
  void didUpdateWidget(covariant SelectOne oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.controller.inputFieldAction = this;
  }

  @override
  void dispose() {
    focusNode.dispose();
    dataList = null;
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
          event: EnsembleEvent(widget, data: {'value': value}),
        );
      }
    }
  }

  /// build the standard Dropdown
  Widget _buildDropdown(BuildContext context) {
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

    String? placeholder =
        widget._controller.placeholder ?? widget._controller.hintText;

    return DropdownButtonFormField2<dynamic>(
        key: validatorKey,
        validator: (value) {
          if (widget._controller.required && widget.getValue() == null) {
            return Utils.translateWithFallback(
                'ensemble.input.required', 'This field is required');
          }
          return null;
        },
        hint: placeholder == null
            ? null
            : Text(placeholder, style: widget._controller.placeholderStyle),
        value: widget.getValue(),
        items: buildItems(widget._controller.items,
            widget._controller.itemTemplate, dataList),
        onChanged: isEnabled() ? (item) => onSelectionChanged(item) : null,
        focusNode: focusNode,
        iconStyleData: const IconStyleData(
            icon: Icon(Icons.keyboard_arrow_down, size: 20),
            openMenuIcon: Icon(Icons.keyboard_arrow_up, size: 20)),
        dropdownStyleData: DropdownStyleData(
            decoration: BoxDecoration(
                color: widget._controller.dropdownBackgroundColor,
                borderRadius:
                    widget._controller.dropdownBorderRadius?.getValue(),
                border: widget._controller.borderColor != null ||
                        widget._controller.borderWidth != null
                    ? Border.all(
                        color: widget._controller.borderColor ??
                            ThemeManager().getBorderColor(context),
                        width: widget._controller.borderWidth?.toDouble() ??
                            ThemeManager().getBorderThickness(context),
                      )
                    : null),
            maxHeight: widget._controller.dropdownMaxHeight?.toDouble(),
            offset: Offset(
              widget._controller.dropdownOffsetX?.toDouble() ?? 0,
              widget._controller.dropdownOffsetY?.toDouble() ?? 0,
            )),
        decoration: inputDecoration.copyWith(
          contentPadding: adjustedContentPadding,
          labelText: widget.controller.floatLabel == true
              ? widget.controller.label
              : null,
        ));
  }

  /// build the auto-complete Dropdown
  Widget _buildAutoComplete(BuildContext context) {
    return LayoutBuilder(
        builder: (context, constraints) => RawAutocomplete<SelectOneItem>(
              focusNode: focusNode,
              textEditingController: textEditingController,
              optionsBuilder: (TextEditingValue textEditingValue) =>
                  buildAutoCompleteOptions(
                      textEditingValue, textEditingController),
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
                  decoration: inputDecoration.copyWith(
                    labelText: widget.controller.floatLabel == true
                        ? widget.controller.label
                        : null,
                  ),
                  onChanged: (value) {
                    final oldValue = widget._controller.maybeValue;
                    if (oldValue != value) {
                      widget._controller.maybeValue = value;
                      widget.onSelectionChanged(value);
                    }
                  },
                );
              },
              onSelected: (SelectOneItem selection) {
                if (selection is CreateSelectOneItem) {
                  if (widget.controller.onCreateItemTap == null) return;
                  scopeManager?.dataContext
                      .addDataContext({'newValue': selection.value});
                  ScreenController().executeAction(
                      context, widget.controller.onCreateItemTap!);
                }
                onSelectionChanged(selection.value);
                if (kDebugMode) {
                  print('Selected: ${selection.value}');
                }
              },
              optionsViewBuilder: (BuildContext context,
                  AutocompleteOnSelected<SelectOneItem> onSelected,
                  Iterable<SelectOneItem> options) {
                return buildAutoCompleteItems(constraints, options, onSelected);
              },
            ));
  }

  @override
  Widget buildWidget(BuildContext context) {
    return InputWrapper(
        type: Dropdown.type,
        controller: widget._controller,
        widget: widget._controller.autoComplete
            ? _buildAutoComplete(context)
            : _buildDropdown(context));
  }

  // ---------------------- Search From the List if [AUTOCOMPLETE] is true ---------------------------------
  List<SelectOneItem> buildAutoCompleteOptions(
    TextEditingValue textEditingValue,
    TextEditingController textEditingController,
  ) {
    final items = widget._controller.items!
        .where(
          (SelectOneItem options) => options.label == null
              ? options.value
                  .toString()
                  .toLowerCase()
                  .contains(textEditingValue.text.toLowerCase())
              : options.label
                  .toString()
                  .toLowerCase()
                  .contains(textEditingValue.text.toLowerCase()),
        )
        .toList();

    if (widget.controller.onCreateItemTap == null ||
        textEditingController.text.isEmpty) {
      return items;
    }

    items.add(CreateSelectOneItem(
      value: textEditingController.text.trim(),
      icon: widget._controller.createNewItemIcon,
      label: textEditingController.text.trim(),
    ));

    return items;
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
                            option is CreateSelectOneItem
                                ? Text(
                                    replaceValue(
                                      widget._controller.createNewItemLabel,
                                      option.value,
                                    ),
                                  )
                                : Text(
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

  String replaceValue(String? text, String newValue) {
    const String pattern = "\${newValue}";
    if (text != null && text.contains(pattern)) {
      return text.replaceAll(pattern, newValue);
    }
    return newValue;
  }

// ---------------------------------- Build Items ListTile if [AUTOCOMPLETE] is false ---------------------------------
  List<DropdownMenuItem<dynamic>>? buildItems(List<SelectOneItem>? items,
      DropdownItemTemplate? itemTemplate, List? dataList) {
    List<DropdownMenuItem<dynamic>>? results;
    // first add the static list
    if (items != null) {
      results = [];
      for (SelectOneItem item in items) {
        item.isIcon == true
            ? results.add(
                DropdownMenuItem(
                  value: item.value,
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
    // then add the templated list
    if (itemTemplate != null && dataList != null) {
      ScopeManager? parentScope = DataScopeWidget.getScope(context);
      if (parentScope != null) {
        results ??= [];
        for (var itemData in dataList) {
          ScopeManager templatedScope = parentScope.createChildScope();
          templatedScope.dataContext
              .addDataContextById(itemTemplate.name, itemData);

          var labelWidget = DataScopeWidget(
              scopeManager: templatedScope,
              child: templatedScope
                  .buildWidgetFromDefinition(itemTemplate.template));
          results.add(DropdownMenuItem(
              value: templatedScope.dataContext.eval(itemTemplate.value),
              child: labelWidget));
        }
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

class CreateSelectOneItem extends SelectOneItem {
  CreateSelectOneItem({
    required super.value,
    super.icon,
    super.isIcon,
    super.label,
  });
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

class DropdownItemTemplate extends ItemTemplate {
  DropdownItemTemplate(
      super.data,
      super.name,
      super.template, // label widget template
      this.value); // the value when the item is selected
  dynamic value;
}
