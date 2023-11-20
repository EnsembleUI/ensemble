import 'package:ensemble/framework/event.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble/widget/input/form_helper.dart';
import 'package:ensemble/framework/action.dart' as framework;
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';

class EnsembleSwitch extends StatefulWidget
    with Invokable, HasController<SwitchController, SwitchState> {
  static const type = 'Switch';
  EnsembleSwitch({Key? key}) : super(key: key);

  final SwitchController _controller = SwitchController();
  @override
  SwitchController get controller => _controller;

  @override
  State<StatefulWidget> createState() => SwitchState();

  @override
  Map<String, Function> getters() {
    return {'value': () => _controller.value};
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {
      'value': (value) =>
          _controller.value = Utils.getBool(value, fallback: false),
      'leadingText': (text) =>
          _controller.leadingText = Utils.optionalString(text),
      'trailingText': (text) =>
          _controller.trailingText = Utils.optionalString(text),
      'activeColor': (color) => _controller.activeColor = Utils.getColor(color),
      'inactiveColor': (color) =>
          _controller.inactiveColor = Utils.getColor(color),
      'activeThumbColor': (color) =>
          _controller.activeThumbColor = Utils.getColor(color),
      'inactiveThumbColor': (color) =>
          _controller.inactiveThumbColor = Utils.getColor(color),
      'onChange': (definition) => _controller.onChange =
          framework.EnsembleAction.fromYaml(definition, initiator: this)
    };
  }

  void onToggle(bool newValue) {
    setProperty('value', newValue);
  }
}

class SwitchController extends FormFieldController {
  bool value = false;
  String? leadingText;
  String? trailingText;
  Color? activeColor;
  Color? activeThumbColor;
  Color? inactiveColor;
  Color? inactiveThumbColor;

  framework.EnsembleAction? onChange;
}

class SwitchState extends FormFieldWidgetState<EnsembleSwitch> {
  void onToggle(bool newValue) {
    widget.onToggle(newValue);
    //validatorKey.currentState!.validate();

    if (widget._controller.onChange != null) {
      ScreenController().executeAction(context, widget._controller.onChange!,
          event: EnsembleEvent(widget));
    }
  }

  @override
  Widget buildWidget(BuildContext context) {
    // add leading/trailing text + the actual widget
    List<Widget> children = [];
    if (widget._controller.leadingText != null) {
      children.add(Flexible(
          child: Text(
        widget._controller.leadingText!,
        style: formFieldTextStyle,
      )));
    }

    children.add(switchWidget);

    if (widget._controller.trailingText != null) {
      children.add(Expanded(
          child: Text(
        widget._controller.trailingText!,
        style: formFieldTextStyle,
      )));
    }

    // wraps around FormField to get all the form effects
    return InputWrapper(
      type: EnsembleSwitch.type,
      controller: widget._controller,
      widget: FormField<bool>(
        key: validatorKey,
        validator: (value) {
          if (widget._controller.required && !widget._controller.value) {
            return Utils.translateWithFallback(
                'ensemble.input.required', 'This field is required');
          }
          return null;
        },
        builder: (FormFieldState<bool> field) {
          return InputDecorator(
            decoration: inputDecoration.copyWith(
                contentPadding: EdgeInsets.zero,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorText: field.errorText),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.start, children: children),
          );
        },
      ),
    );
  }

  Widget get switchWidget {
    final MaterialStateProperty<Color?> trackColor =
        MaterialStateProperty.resolveWith<Color?>(
      (Set<MaterialState> states) {
        // Track color when the switch is selected.
        if (states.contains(MaterialState.selected)) {
          return widget._controller.activeColor;
        }

        // Track color for other states.
        return widget._controller.inactiveColor;
      },
    );

    final MaterialStateProperty<Color?> thumbColor =
        MaterialStateProperty.resolveWith<Color?>(
      (Set<MaterialState> states) {
        // Thumb color when the switch is selected.
        if (states.contains(MaterialState.selected)) {
          return widget._controller.activeThumbColor;
        }

        // Thumb color for other states.
        return widget._controller.inactiveThumbColor;
      },
    );
    return Switch(
        trackColor: trackColor,
        thumbColor: thumbColor,
        value: widget._controller.value,
        onChanged: isEnabled() ? (value) => onToggle(value) : null);
  }
}
