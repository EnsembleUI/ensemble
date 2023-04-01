import 'package:ensemble/framework/action.dart' as framework;
import 'package:ensemble/framework/widget/icon.dart' as iconframework;
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../layout/box/base_box_layout.dart';
import '../layout/form.dart';
import 'input/dropdown.dart';

class EnsembleToggleButton extends StatefulWidget
    with
        Invokable,
        HasController<ToggleButtonController, EnsembleToggleButtonState> {
  static const type = 'ToggleButton';

  EnsembleToggleButton({Key? key}) : super(key: key);

  final ToggleButtonController _controller = ToggleButtonController();
  @override
  ToggleButtonController get controller => _controller;

  @override
  State<StatefulWidget> createState() => EnsembleToggleButtonState();

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
      'items': (values) => updateItems(values),
      'color': (value) => _controller.color = Utils.getColor(value),
      'selectedColor': (value) =>
          _controller.selectedColor = Utils.getColor(value),
      'selectedBackgroundColor': (value) =>
          _controller.selectedBackgroundColor = Utils.getColor(value),
      'borderColor': (value) => _controller.borderColor = Utils.getColor(value),
      'selectedBorderColor': (value) =>
          _controller.selectedBorderColor = Utils.getColor(value),
      'onChange': (definition) => _controller.onChange =
          framework.EnsembleAction.fromYaml(definition, initiator: this),
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
}

class EnsembleToggleButtonState extends WidgetState<EnsembleToggleButton> {
  List<ToggleItem>? _items = [];

  @override
  void initState() {
    super.initState();
    _setValue();
  }

  void _setValue() {
    if (widget.controller.items != null) {
      final value = widget.getValue();
      final valueIndex = widget.controller.items
          ?.indexWhere((element) => element.value == value);
      widget.controller.items!.asMap().forEach((index, value) {
        _items!.add(
          ToggleItem(
            label: value.label,
            value: value.value,
            icon: value.icon,
            isIcon: value.isIcon,
            isSelected: (valueIndex != null && valueIndex != -1)
                ? index == valueIndex
                : false,
          ),
        );
      });
    }
  }

  @override
  Widget buildWidget(BuildContext context) {
    if (_items == null || _items!.isEmpty) return const SizedBox.shrink();

    final controller = widget.controller;

    Widget? rtn = ToggleButtons(
      borderRadius: const BorderRadius.all(Radius.circular(8)),
      color: controller.color,
      selectedColor: controller.selectedColor,
      fillColor: controller.selectedBackgroundColor,
      borderColor: controller.borderColor,
      selectedBorderColor: controller.selectedBorderColor,
      constraints: const BoxConstraints(
        minHeight: 40.0,
        minWidth: 80.0,
      ),
      children: List.generate(
        _items!.length,
        (index) => _buildWidget(_items![index]),
      ),
      isSelected: [
        ..._items!.map((e) => e.isSelected).toList(),
      ],
      onPressed: (index) {
        onSelectionChanged(_items![index].value);
        _updateSelectedState(index);
        if (kDebugMode) {
          print('Selected: ${_items![index].value}');
        }
      },
    );

    // add margin if specified
    return widget._controller.margin != null
        ? Padding(padding: widget._controller.margin!, child: rtn)
        : rtn;
  }

  Widget _buildWidget(ToggleItem item) {
    String title = item.label ?? item.value;
    Widget child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (item.icon != null) iconframework.Icon.fromModel(item.icon!),
        Text(title),
      ],
    );
    if (widget.controller.gap != null) {
      child = Padding(
        padding: EdgeInsets.symmetric(
          horizontal: widget.controller.gap!.toDouble(),
        ),
        child: child,
      );
    }
    return child;
  }

  void _updateSelectedState(int index) {
    List<ToggleItem> _temp = [];
    _items!.asMap().forEach((itemIndex, item) {
      _temp.add(
        ToggleItem(
          label: item.label,
          value: item.value,
          icon: item.icon,
          isIcon: item.isIcon,
          isSelected: itemIndex == index,
        ),
      );
    });
    setState(() {
      _items = _temp;
    });
  }

  void onSelectionChanged(dynamic value) {
    widget.onSelectionChanged(value);
    if (widget._controller.onChange != null) {
      ScreenController().executeAction(context, widget._controller.onChange!,
          event: EnsembleEvent(widget));
    }
  }

  bool isEnabled() {
    return widget._controller.enabled ??
        EnsembleForm.of(context)?.widget.controller.enabled ??
        true;
  }
}

class ToggleButtonController extends BoxController {
  List<SelectOneItem>? items;

  Color? color;
  Color? selectedColor;
  Color? selectedBorderColor;
  Color? selectedBackgroundColor;
  bool? enabled;

  // this is our value but it can be in an invalid state.
  // Since user can set items/value in any order and at anytime, the value may
  // not be one of the items, hence it could be in an incorrect state
  dynamic maybeValue;
  int? gap;

  framework.EnsembleAction? onChange;

  @override
  Map<String, Function> getBaseSetters() {
    Map<String, Function> setters = super.getBaseSetters();
    setters.addAll({
      'gap': (value) => gap = Utils.optionalInt(value),
    });
    return setters;
  }
}

class ToggleItem extends SelectOneItem {
  ToggleItem({
    required super.label,
    required super.value,
    required super.icon,
    required super.isIcon,
    this.isSelected = false,
  });

  bool isSelected;
}
