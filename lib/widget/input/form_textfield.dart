
import 'dart:developer';

import 'package:ensemble/ensemble_theme.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/theme/theme_manager.dart';
import 'package:ensemble/framework/widget/icon.dart' as framework;
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/input_validator.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/input/form_helper.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble_ts_interpreter/invokables/invokablecontroller.dart';
import 'package:flutter/material.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:email_validator/email_validator.dart';
import 'package:ensemble/framework/model.dart' as model;
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:form_validator/form_validator.dart';

/// TextInput
class TextInput extends BaseTextInput {
  static const type = 'TextInput';
  TextInput({Key? key}) : super(key: key);

  @override
  Map<String, Function> setters() {
    Map<String, Function> setters = super.setters();
    setters.addAll({
      'value': (newValue) => textController.text = Utils.getString(newValue, fallback: ''),
      'obscureText': (obscure) => _controller.obscureText = Utils.optionalBool(obscure),
      'inputType': (type) => _controller.inputType = Utils.optionalString(type),
    });
    return setters;
  }

  @override
  bool isPassword() {
    return false;
  }

  @override
  TextInputType? get keyboardType {
    // set the best keyboard type based on the input type
    if (_controller.inputType == InputType.email.name) {
      return TextInputType.emailAddress;
    } else if (_controller.inputType == InputType.phone.name) {
      return TextInputType.phone;
    }
    return null;
  }

}

/// PasswordInput
class PasswordInput extends BaseTextInput {
  static const type = 'PasswordInput';
  PasswordInput({Key? key}) : super(key: key);

  @override
  bool isPassword() {
    return true;
  }

  @override
  TextInputType? get keyboardType => null;

  @override
  Map<String, Function> setters() {
    Map<String, Function> setters = super.setters();
    setters.addAll({
      'value': (newValue) => textController.text = Utils.getString(newValue, fallback: '')
    });
    return setters;
  }
}

/// Base StatefulWidget for both TextInput and Password
abstract class BaseTextInput extends StatefulWidget with Invokable, HasController<TextInputController, TextInputState> {
  BaseTextInput({Key? key}) : super(key: key);

  // textController manages 'value', while _controller manages the rest
  final TextEditingController textController = TextEditingController();
  final TextInputController _controller = TextInputController();
  @override
  TextInputController get controller => _controller;

  @override
  Map<String, Function> getters() {
    return {
      'value': () => textController.text,
    };
  }

  @override
  Map<String, Function> setters() {
    // set value is not specified here for safety in case of PasswordInput
    return {
      'onKeyPress': (function) => _controller.onKeyPress = Utils.getAction(function, initiator: this),
      'onChange': (definition) => _controller.onChange = Utils.getAction(definition, initiator: this),
      'borderRadius': (value) => _controller.borderRadius = Utils.optionalInt(value),
      'validator': (value) => _controller.validator = Utils.getValidator(value),
      'obscureToggle': (value) => _controller.obscureToggle = Utils.optionalBool(value),
      'keyboardAction': (value) => _controller.keyboardAction = _getKeyboardAction(value),
      'maxLines' : (value) =>  _controller.maxLines = Utils.getInt(value, min: 1, fallback: _controller.maxLines),
    };
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  TextInputAction? _getKeyboardAction(dynamic value) {
    switch(value) {
      case 'done':
        return TextInputAction.done;
      case 'go':
        return TextInputAction.go;
      case 'search':
        return TextInputAction.search;
      case 'send':
        return TextInputAction.send;
      case 'next':
        return TextInputAction.next;
      case 'previous':
        return TextInputAction.previous;
    }
    return null;
  }

  @override
  TextInputState createState() => TextInputState();

  bool isPassword();
  TextInputType? get keyboardType;

}

/// controller for both TextField and Password
class TextInputController extends FormFieldController {
  EnsembleAction? onChange;
  EnsembleAction? onKeyPress;
  TextInputAction? keyboardAction;

  // applicable only for TextInput
  bool? obscureText;

  // applicable only for Password or obscure TextInput, to toggle between plain and secure text
  bool? obscureToggle;

  model.InputValidator? validator;
  String? inputType;
  int? borderRadius;
  int maxLines = 1;
}

class TextInputState extends FormFieldWidgetState<BaseTextInput> {
  final focusNode = FocusNode();

  // for this widget we will implement onChange if the text changes AND:
  // 1. the field loses focus next (tabbing out, ...)
  // 2. upon onEditingComplete (e.g click Done on keyboard)
  // This is so we can be consistent with the other input widgets' onChange
  String previousText = '';
  bool didItChange = false;
  void evaluateChanges() {
    if (didItChange) {
      // trigger binding
      widget.setProperty('value', widget.textController.text);

      // call onChange
      if (widget._controller.onChange != null) {
        ScreenController().executeAction(context, widget._controller.onChange!,event: EnsembleEvent(widget));
      }
      didItChange = false;
    }
  }

  // password is obscure by default
  late bool currentlyObscured;

  @override
  void initState() {
    currentlyObscured = widget.isPassword() || widget._controller.obscureText == true;

    focusNode.addListener(() {
      // on focus lost
      if (!focusNode.hasFocus) {
        evaluateChanges();

        // validate
        /*if (validatorKey.currentState != null) {
          validatorKey.currentState!.validate();
        }*/
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  /// whether to show the content as plain text or obscure
  bool isObscureOrPlainText() {
    if (widget.isPassword()) {
      return currentlyObscured;
    } else {
      return widget._controller.obscureText == true && currentlyObscured;
    }
  }

  @override
  Widget buildWidget(BuildContext context) {

    // TextField doesn't take the global disabled color for some reason,
    // so we have to account for it here
    TextStyle textStyle;
    if (isEnabled()) {
      textStyle = TextStyle(
          fontSize: widget.controller.fontSize?.toDouble());
    } else {
      textStyle = TextStyle(
        color: Theme.of(context).disabledColor,
        fontSize: widget.controller.fontSize?.toDouble());
    }

    // for password, show the toggle plain text/obscure text
    InputDecoration decoration = inputDecoration;
    if ((widget.isPassword() || widget._controller.obscureText == true) && widget._controller.obscureToggle == true) {
      decoration = decoration.copyWith(
        suffixIcon: IconButton(
          icon: Icon(
              currentlyObscured ? Icons.visibility : Icons.visibility_off,
              size: ThemeManager().getInputIconSize(context).toDouble()),
          onPressed: () {
            setState(() {
              currentlyObscured = !currentlyObscured;
            });
          },

        )
      );
    }

    return InputWrapper(
        controller: widget._controller,
        widget: TextFormField(
            key: validatorKey,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return widget._controller.required ?
                Utils.translateWithFallback('ensemble.input.required', 'This field is required') :
                null;
              }
              // only applicable for TextInput
              if (!widget.isPassword() && value != null) {
                if (widget._controller.inputType == InputType.email.name) {
                  if (!EmailValidator.validate(value)) {
                    return Utils.translateWithFallback(
                        'ensemble.input.validation.invalidEmailType',
                        'Please enter a valid email address');
                  }
                } else if (widget._controller.inputType == InputType.ipAddress.name) {
                  if (!InputValidator.ipAddress(value)) {
                    return Utils.translateWithFallback(
                        'ensemble.input.validation.invalidIPAddressType',
                        'Please enter a valid IP Address');
                  }
                } else if (widget._controller.inputType == InputType.phone.name) {
                  if (!InputValidator.phone(value)) {
                    return Utils.translateWithFallback(
                        'ensemble.input.validation.invalidPhoneType',
                        "Please enter a valid Phone Number");
                  }
                }
              }
              if (widget._controller.validator != null) {
                ValidationBuilder? builder;
                if (widget._controller.validator?.minLength != null) {
                  builder = ValidationBuilder().minLength(
                      widget._controller.validator!.minLength!,
                      Utils.translateOrNull('ensemble.input.validation.minimumLength'));
                }
                if (widget._controller.validator?.maxLength != null) {
                  builder = (builder ?? ValidationBuilder()).maxLength(
                      widget._controller.validator!.maxLength!,
                      Utils.translateOrNull('ensemble.input.validation.maximumLength'));
                }
                if (widget._controller.validator?.regex != null) {
                  builder = (builder ?? ValidationBuilder()).regExp(
                      RegExp(widget._controller.validator!.regex!),
                      widget._controller.validator!.regexError ??
                          Utils.translateWithFallback(
                              'ensemble.input.validation.invalidInput',
                              'This field has invalid value'));
                }
                if (builder != null) {
                  return builder.build().call(value);
                }
              }
              return null;
            },
            textInputAction: widget._controller.keyboardAction,
            keyboardType: widget.keyboardType,
            maxLines: widget._controller.maxLines,
            obscureText: isObscureOrPlainText(),
            enableSuggestions: !widget.isPassword(),
            autocorrect: !widget.isPassword(),
            controller: widget.textController,
            focusNode: focusNode,
            enabled: isEnabled(),
            onFieldSubmitted: (value) => widget.controller.submitForm(context),
            onChanged: (String txt) {
              if (txt != previousText) {
                // for performance reason, we dispatch onChange (as well as binding to value)
                // upon EditingComplete (select Done on virtual keyboard) or Focus Out
                didItChange = true;
                previousText = txt;

                // we dispatch onKeyPress here
                if (widget._controller.onKeyPress != null) {
                  ScreenController().executeAction(
                      context, widget._controller.onKeyPress!,
                      event: EnsembleEvent(widget));
                }
              }
            },
            style: textStyle,
            decoration: decoration));
    
  }

}

enum InputType {
  email,
  phone,
  ipAddress
}

