import 'package:ensemble/framework/event.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble/widget/input/form_helper.dart';
import 'package:ensemble/framework/action.dart' as framework;
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';

class EnsembleCheckbox extends StatefulWidget
    with Invokable, HasController<CheckboxController, CheckboxState> {
  static const type = 'Checkbox';
  EnsembleCheckbox({Key? key}) : super(key: key);

  final CheckboxController _controller = CheckboxController();
  @override
  CheckboxController get controller => _controller;

  @override
  State<StatefulWidget> createState() => CheckboxState();

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
      'unselectedColor': (color) =>
          _controller.unselectedColor = Utils.getColor(color),
      'selectedColor': (color) =>
          _controller.selectedColor = Utils.getColor(color),
      'checkColor': (color) => _controller.checkColor = Utils.getColor(color),
      'onChange': (definition) => _controller.onChange =
          framework.EnsembleAction.fromYaml(definition, initiator: this)
    };
  }

  void onToggle(bool newValue) {
    setProperty('value', newValue);
  }
}

class CheckboxController extends FormFieldController {
  bool value = false;
  String? leadingText;
  String? trailingText;
  Color? unselectedColor;
  Color? selectedColor;
  Color? checkColor;

  framework.EnsembleAction? onChange;
}

class CheckboxState extends FormFieldWidgetState<EnsembleCheckbox> {
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

    children.add(checkboxWidget);

    if (widget._controller.trailingText != null) {
      children.add(Expanded(
          child: Text(
        widget._controller.trailingText!,
        style: formFieldTextStyle,
      )));
    }

    // wraps around FormField to get all the form effects
    return InputWrapper(
      type: EnsembleCheckbox.type,
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

  Widget get checkboxWidget {
    return SizedBox(
        width: 40,
        height: 40,
        child: Checkbox(
            side: widget._controller.unselectedColor != null
                ? BorderSide(
                    width: 2.0, color: widget._controller.unselectedColor!)
                : null,
            value: widget._controller.value,
            activeColor: widget._controller.selectedColor,
            checkColor: widget._controller.checkColor,
            onChanged: isEnabled()
                ? (bool? value) => onToggle(value ?? false)
                : null));
  }
}
