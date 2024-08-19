import 'package:ensemble/action/haptic_action.dart';
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
      'value': (value) => controller.maybeValue = value,
      'items': (values) => updateItems(values),
      'spacing': (value) => _controller.spacing = Utils.optionalInt(value),
      'runSpacing': (value) =>
          _controller.runSpacing = Utils.optionalInt(value),
      'color': (value) => _controller.color = Utils.getColor(value),
      'selectedColor': (value) =>
          _controller.selectedColor = Utils.getColor(value),
      'backgroundColor': (value) =>
          _controller.backgroundColor = Utils.getColor(value),
      'selectedBackgroundColor': (value) =>
          _controller.selectedBackgroundColor = Utils.getColor(value),
      'borderColor': (value) => _controller.borderColor = Utils.getColor(value),
      'selectedBorderColor': (value) =>
          _controller.selectedBorderColor = Utils.getColor(value),
      'shadowColor': (value) => _controller.shadowColor = Utils.getColor(value),
      'onChange': (definition) => _controller.onChange =
          framework.EnsembleAction.from(definition, initiator: this),
      'onChangeHaptic': (value) =>
          _controller.onChangeHaptic = Utils.optionalString(value),
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

  void onSelectionChanged(dynamic value) {
    setProperty('value', value);
  }
}

class EnsembleToggleButtonState extends EWidgetState<EnsembleToggleButton> {
  List<ToggleItem>? _items = [];
  int _selectedIndex = -1;

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
      _selectedIndex = valueIndex ?? -1;

      widget.controller.items!.asMap().forEach((index, value) {
        _items!.add(
          ToggleItem(
            label: value.label,
            value: value.value,
            icon: value.icon,
            isIcon: value.isIcon,
            isSelected:
                (_selectedIndex != -1) ? index == _selectedIndex : false,
          ),
        );
      });
    }
  }

  @override
  Widget buildWidget(BuildContext context) {
    if (_items == null || _items!.isEmpty) return const SizedBox.shrink();

    final controller = widget.controller;

    Widget? rtn = _CustomToggleButtons(
      borderRadius: 8,
      color: controller.color,
      selectedColor: controller.selectedColor,
      fillColor: controller.selectedBackgroundColor,
      unselectedFillColor: controller.backgroundColor,
      shadowColor: controller.shadowColor,
      borderColor: controller.borderColor,
      selectedBorderColor: controller.selectedBorderColor,
      spacing: widget.controller.spacing?.toDouble() ?? 0,
      runSpacing: widget.controller.runSpacing?.toDouble() ?? 0,
      isExpanded: widget.controller.expanded,
      constraints: const BoxConstraints(
        minHeight: 40.0,
        minWidth: 80.0,
      ),
      isSelected: [
        ..._items!.map((e) => e.isSelected).toList(),
      ],
      onPressed: (index) {
        _selectedIndex = index;
        onSelectionChanged(_items![_selectedIndex].value);
        _updateSelectedState(isToReload: true);
        if (kDebugMode) {
          print('Selected: ${_items![_selectedIndex].value}');
        }
      },
      children: _getChildren(),
    );

    // add margin if specified
    return widget._controller.margin != null
        ? Padding(padding: widget._controller.margin!, child: rtn)
        : rtn;
  }

  List<Widget> _getChildren() {
    _updateSelectedState();
    return List.generate(
      _items!.length,
      (index) => _buildWidget(_items![index]),
    );
  }

  Widget _buildWidget(ToggleItem item) {
    String title = item.label ?? item.value;
    Widget child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (item.icon != null) iconframework.Icon.fromModel(item.icon!),
        Text(title),
      ],
    );
    return child;
  }

  void _updateSelectedState({bool isToReload = false}) {
    final value = widget.getValue();
    final valueIndex = widget.controller.items
        ?.indexWhere((element) => element.value == value);
    _selectedIndex = valueIndex ?? -1;
    if (_selectedIndex != -1) {
      List<ToggleItem> _temp = [];
      _items!.asMap().forEach((itemIndex, item) {
        _temp.add(
          ToggleItem(
            label: item.label,
            value: item.value,
            icon: item.icon,
            isIcon: item.isIcon,
            isSelected: itemIndex == _selectedIndex,
          ),
        );
      });
      _items = _temp;

      if (isToReload) {
        setState(() {});
      }
    }
  }

  void onSelectionChanged(dynamic value) {
    widget.onSelectionChanged(value);
    if (widget._controller.onChange != null) {
      if (widget._controller.onChangeHaptic != null) {
        ScreenController().executeAction(
          context,
          HapticAction(
            type: widget._controller.onChangeHaptic!,
            onComplete: null,
          ),
        );
      }

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
  int? spacing;
  int? runSpacing;

  framework.EnsembleAction? onChange;
  String? onChangeHaptic;
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

class _CustomToggleButtons extends StatelessWidget {
  const _CustomToggleButtons({
    Key? key,
    required this.children,
    required this.isSelected,
    this.onPressed,
    this.constraints,
    this.color,
    this.selectedColor,
    this.fillColor,
    this.unselectedFillColor,
    this.shadowColor,
    this.borderColor,
    this.selectedBorderColor,
    this.borderRadius,
    this.spacing = 0,
    this.runSpacing = 0,
    this.isExpanded = false,
  })  : assert(children.length == isSelected.length),
        super(key: key);

  final List<Widget> children;
  final List<bool> isSelected;
  final void Function(int index)? onPressed;
  final BoxConstraints? constraints;
  final Color? color;
  final Color? selectedColor;
  final Color? fillColor;
  final Color? unselectedFillColor;
  final Color? shadowColor;
  final Color? borderColor;
  final Color? selectedBorderColor;
  final double? borderRadius;
  final double spacing;
  final double runSpacing;
  final bool isExpanded;

  Border _getBorder(index) {
    Color? _borderColor = borderColor;
    if (isSelected[index]) {
      _borderColor = selectedBorderColor;
    }

    return Border.all(color: _borderColor ?? Colors.transparent);
  }

  @override
  Widget build(BuildContext context) {
    if (isExpanded) {
      return Row(
        children: List<Widget>.generate(children.length, (index) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing),
              child: getChild(index),
            ),
          );
        }),
      );
    }

    return Wrap(
      alignment: WrapAlignment.spaceEvenly,
      spacing: spacing,
      runSpacing: runSpacing,
      direction: Axis.horizontal,
      children: List<Widget>.generate(
        children.length,
        (index) => getChild(index),
      ),
    );
  }

  _CustomToggleButton getChild(int index) {
    return _CustomToggleButton(
      onPressed: onPressed == null ? null : () => onPressed!(index),
      constraints: constraints,
      isSelected: isSelected[index],
      color: color,
      selectedColor: selectedColor,
      fillColor: fillColor,
      unselectedFillColor: unselectedFillColor,
      shadowColor: shadowColor,
      border: _getBorder(index),
      borderRadius: borderRadius,
      child: children[index],
    );
  }
}

class _CustomToggleButton extends StatelessWidget {
  const _CustomToggleButton({
    this.child,
    this.onPressed,
    this.constraints = const BoxConstraints(),
    this.isSelected,
    this.color,
    this.selectedColor,
    this.fillColor,
    this.unselectedFillColor,
    this.shadowColor,
    this.border,
    this.borderRadius,
  });

  final Widget? child;
  final VoidCallback? onPressed;
  final bool? isSelected;

  final Color? color;
  final Color? selectedColor;
  final Color? fillColor;
  final Color? unselectedFillColor;
  final Color? shadowColor;

  final BoxConstraints? constraints;

  final double? borderRadius;
  final BoxBorder? border;

  Color? _getTextColor(context) {
    if (isSelected!) {
      if (selectedColor == null) {
        return Theme.of(context).colorScheme.primary;
      }
      return selectedColor;
    }
    if (color == null) {
      return Theme.of(context).colorScheme.onSurface;
    }
    return color;
  }

  Color? _getFillColor(context) {
    if (isSelected!) {
      if (fillColor == null) {
        return Colors.transparent;
      }
      return fillColor;
    }
    if (unselectedFillColor == null) {
      return Colors.transparent;
    }
    return unselectedFillColor;
  }

  Color? _getContainerColor(context) {
    if (fillColor == null) {
      return Theme.of(context).scaffoldBackgroundColor;
    }
    return fillColor;
  }

  List<BoxShadow>? _getShadow() {
    if (shadowColor == null) return null;
    return [
      BoxShadow(
        color: shadowColor!,
        blurRadius: 5.0,
        spreadRadius: 2.0,
        offset: const Offset(
          2.0,
          4.0,
        ),
      )
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _getContainerColor(context),
        border: border,
        borderRadius: borderRadius != null
            ? BorderRadius.circular(borderRadius!)
            : BorderRadius.circular(0),
        boxShadow: _getShadow(),
      ),
      child: ClipRRect(
        borderRadius: borderRadius != null
            ? BorderRadius.all(Radius.circular(borderRadius!))
            : const BorderRadius.all(Radius.circular(0)),
        child: RawMaterialButton(
          textStyle: TextStyle(
            color: _getTextColor(context),
          ),
          constraints: constraints ??
              const BoxConstraints(
                minHeight: 40.0,
                minWidth: 80.0,
              ),
          elevation: 0.0,
          fillColor: _getFillColor(context),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.all(0),
          onPressed: onPressed,
          child: child,
        ),
      ),
    );
  }
}
