
import 'package:ensemble/framework/action.dart' as framework;
import 'package:ensemble/framework/widget/icon.dart' as ensemble;
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/widget/form_helper.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
//import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class EnsembleCheckbox extends OnOffWidget {
  static const type = 'Checkbox';
  EnsembleCheckbox({Key? key}) : super(key: key);

  @override
  OnOffType getType() {
    return OnOffType.checkbox;
  }
}

class EnsembleSwitch extends OnOffWidget {
  static const type = 'Switch';
  EnsembleSwitch({Key? key}) : super(key: key);

  @override
  OnOffType getType() {
    return OnOffType.toggle;
  }
}


abstract class OnOffWidget extends StatefulWidget with Invokable, HasController<OnOffController, OnOffState> {
  OnOffWidget({Key? key}) : super(key: key);

  final OnOffController _controller = OnOffController();
  @override
  OnOffController get controller => _controller;

  @override
  State<StatefulWidget> createState() => OnOffState();

  @override
  Map<String, Function> getters() {
    return {
      'value': () => _controller.value
    };
  }

  @override
  Map<String, Function> setters() {
    return {
      'value': (value) => _controller.value = Utils.getBool(value, fallback: false),
      'leadingText': (text) => _controller.leadingText = Utils.optionalString(text),
      'trailingText': (text) => _controller.trailingText = Utils.optionalString(text),

      'onChange': (definition) => _controller.onChange = Utils.getAction(definition, this)
    };
  }


  @override
  Map<String, Function> methods() {
    return {};
  }

  void onToggle(bool newValue) {
    setProperty('value', newValue);
  }

  OnOffType getType();
}

enum OnOffType {
  checkbox, toggle
}

class OnOffController extends FormFieldController {
  bool value = false;
  String? leadingText;
  String? trailingText;

  framework.Action? onChange;
}

class OnOffState extends FormFieldWidgetState<OnOffWidget> {

  void onToggle(bool newValue) {
    widget.onToggle(newValue);
    validatorKey.currentState!.validate();

    if (widget._controller.onChange != null) {
      ScreenController().executeAction(context, widget._controller.onChange!);
    }

  }

  @override
  Widget build(BuildContext context) {
    // add leading/trailing text + the actual widget
    List<Widget> children = [];
    if (widget._controller.leadingText != null) {
      children.add(Text(widget._controller.leadingText!));
    }
    children.add(widget.getType() == OnOffType.toggle ?
        Switch(
          value: widget._controller.value,
          onChanged: isEnabled() ? (value) => onToggle(value) : null) :
        Checkbox(
          value: widget._controller.value,
          onChanged: isEnabled() ? (bool? value) => onToggle(value ?? false) : null)
    );
    if (widget._controller.trailingText != null) {
      children.add(Text(widget._controller.trailingText!));
    }

    // wraps around FormField to get all the form effects
    return FormField<bool>(
      key: validatorKey,
      validator: (value) {
        if (widget._controller.required && !widget._controller.value) {
          //return AppLocalizations.of(context)!.widget_form_required;
          return "This field is required";
        }
        return null;
      },
      builder: (FormFieldState<bool> field) {
        return InputDecorator(
            decoration: inputDecoration.copyWith(
              border: InputBorder.none,
              errorText: field.errorText),
            child: Row (
              mainAxisAlignment: MainAxisAlignment.start,
              children: children
            ),

        );
      }
    );
  }
}

