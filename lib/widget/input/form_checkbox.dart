
import 'package:ensemble/framework/action.dart' as framework;
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/widget/icon.dart' as ensemble;
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/widget/input/form_helper.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:ensemble_ts_interpreter/invokables/invokablecontroller.dart';
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

      'onChange': (definition) => _controller.onChange = Utils.getAction(definition, initiator: this)
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

  framework.EnsembleAction? onChange;
}

class OnOffState extends FormFieldWidgetState<OnOffWidget> {

  void onToggle(bool newValue) {
    widget.onToggle(newValue);
    //validatorKey.currentState!.validate();

    if (widget._controller.onChange != null) {
      ScreenController().executeAction(context, widget._controller.onChange!,event: EnsembleEvent(widget));
    }

  }

  @override
  Widget buildWidget(BuildContext context) {
    // add leading/trailing text + the actual widget
    List<Widget> children = [];
    if (widget._controller.leadingText != null) {
      children.add(
        Flexible(
          child: Text(
            widget._controller.leadingText!,
            style: formFieldTextStyle,
          )
        )
      );
    }
    children.add(widget.getType() == OnOffType.toggle
        ? aSwitch
        : aCheckbox
    );
    if (widget._controller.trailingText != null) {
      children.add(
        Expanded(
          child: Text(
            widget._controller.trailingText!,
            style: formFieldTextStyle,
          )
        )
      );
    }

    // wraps around FormField to get all the form effects
    return InputWrapper(
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
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: children),
              );
            }));
  }

  /// we adjust the hit area of the checkbox here. 40px is smaller than the default (48px)
  /// but it seem to be reasonable for touch device, plus the alignment inside
  /// form is much better (align well with the rest of the input widgets)
  Widget get aCheckbox {
    return SizedBox(
        width: 40,
        height: 40,
        child: Checkbox(
            value: widget._controller.value,
            onChanged: isEnabled() ? (bool? value) => onToggle(value ?? false) : null
        )
    );
  }
  Widget get aSwitch {
    return Switch(
      value: widget._controller.value,
      onChanged: isEnabled() ? (value) => onToggle(value) : null
    );
  }
}

