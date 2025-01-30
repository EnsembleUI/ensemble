import 'dart:developer';

import 'package:ensemble/ensemble_theme.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/theme/theme_manager.dart';
import 'package:ensemble/framework/widget/icon.dart' as framework;
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/layout/form.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/debouncer.dart';
import 'package:ensemble/util/input_formatter.dart';
import 'package:ensemble/util/input_validator.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/HasTextPlaceholder.dart';
import 'package:ensemble/widget/helpers/form_helper.dart';
import 'package:ensemble/widget/helpers/input_wrapper.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble_ts_interpreter/invokables/invokablecontroller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:email_validator/email_validator.dart';
import 'package:ensemble/framework/model.dart' as model;
import 'package:flutter/services.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:form_validator/form_validator.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

/// TextInput
class TextInput extends BaseTextInput {
  static const type = 'TextInput';

  TextInput({Key? key}) : super(key: key);

  @override
  Map<String, Function> setters() {
    Map<String, Function> setters = super.setters();
    setters.addAll({
      'value': (newValue) {
        if (newValue == null) {
          textController.text = '';
          return;
        }
        textController.text = Utils.optionalString(newValue)!;
      },
      'obscureText': (obscure) =>
          _controller.obscureText = Utils.optionalBool(obscure),
      'inputType': (type) => _controller.inputType = Utils.optionalString(type),
      'mask': (type) => _controller.mask = Utils.optionalString(type),
      'onDelayedKeyPress': (function) => _controller.onDelayedKeyPress =
          EnsembleAction.from(function, initiator: this),
      'delayedKeyPressDuration': (value) =>
          _controller.delayedKeyPressDuration =
              Utils.getDurationMs(value) ?? _controller.delayedKeyPressDuration,
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
    } else if (_controller.inputType == InputType.number.name) {
      return TextInputType.number;
    } else if (_controller.inputType == InputType.text.name) {
      return TextInputType.text;
    } else if (_controller.inputType == InputType.url.name) {
      return TextInputType.url;
    } else if (_controller.inputType == InputType.datetime.name) {
      return TextInputType.datetime;
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
    setters.addAll({'value': (newValue) => textController.text = newValue});
    return setters;
  }
}

/// Base StatefulWidget for both TextInput and Password
abstract class BaseTextInput extends StatefulWidget
    with Invokable, HasController<TextInputController, TextInputState> {
  BaseTextInput({Key? key}) : super(key: key);

  // textController manages 'value', while _controller manages the rest
  final TextEditingController textController = TextEditingController();
  final TextInputController _controller = TextInputController();

  @override
  TextInputController get controller => _controller;

  @override
  Map<String, Function> getters() {
    var getters = _controller.textPlaceholderGetters;
    getters.addAll({
      'value': () => textController.text ?? '',
      'obscured': () => _controller.obscured,
    });
    return getters;
  }

  @override
  Map<String, Function> setters() {
    var setters = _controller.textPlaceholderSetters;
    // set value is not specified here for safety in case of PasswordInput
    setters.addAll({
      'validateOnUserInteraction': (value) => _controller
              .validateOnUserInteraction =
          Utils.getBool(value, fallback: _controller.validateOnUserInteraction),
      'visible': (value) {
        controller.visible = Utils.optionalBool(value);
        // Force a state change
        var formContext = controller.context;
        if (formContext != null) {
          var formState = EnsembleForm.of(formContext);
          formState?.widget.controller.notifyFormChanged();
        }
      },
      'onKeyPress': (function) => _controller.onKeyPress =
          EnsembleAction.from(function, initiator: this),
      'onChange': (definition) => _controller.onChange =
          EnsembleAction.from(definition, initiator: this),
      'onFocusReceived': (definition) => _controller.onFocusReceived =
          EnsembleAction.from(definition, initiator: this),
      'onFocusLost': (definition) => _controller.onFocusLost =
          EnsembleAction.from(definition, initiator: this),
      'validator': (value) => _controller.validator = Utils.getValidator(value),
      'enableClearText': (value) =>
          _controller.enableClearText = Utils.optionalBool(value),
      'obscureToggle': (value) =>
          _controller.obscureToggle = Utils.optionalBool(value),
      'obscured': (widget) => _controller.obscureText == true,
      'obscureTextWidget': (widget) => _controller.obscureTextWidget = widget,
      'readOnly': (value) => _controller.readOnly = Utils.optionalBool(value),
      'selectable': (value) =>
          _controller.selectable = Utils.getBool(value, fallback: true),
      'toolbarDone': (value) =>
          _controller.toolbarDoneButton = Utils.optionalBool(value),
      'keyboardAction': (value) =>
          _controller.keyboardAction = _getKeyboardAction(value),
      'multiline': (value) => _controller.multiline = Utils.optionalBool(value),
      'minLines': (value) =>
          _controller.minLines = Utils.optionalInt(value, min: 1),
      'maxLines': (value) =>
          _controller.maxLines = Utils.optionalInt(value, min: 1),
      'textStyle': (style) => _controller.textStyle = Utils.getTextStyle(style),
      'autofillHints': (value) =>
          _controller.autofillHints = Utils.getListOfStrings(value),
      'maxLength': (value) => _controller.maxLength = Utils.optionalInt(value),
      'maxLengthEnforcement': (value) =>
          _controller.maxLengthEnforcement = _getMaxLengthEnforcement(value),
    });
    return setters;
  }

  @override
  Map<String, Function> methods() {
    return {
      'focus': () => _controller.inputFieldAction?.focusInputField(),
      'unfocus': () => _controller.inputFieldAction?.unfocusInputField(),
    };
  }

  TextInputAction? _getKeyboardAction(dynamic value) {
    switch (value) {
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

mixin TextInputFieldAction on FormFieldWidgetState<BaseTextInput> {
  void focusInputField();

  void unfocusInputField();
}

/// controller for both TextField and Password
class TextInputController extends FormFieldController with HasTextPlaceholder {
  TextInputFieldAction? inputFieldAction;
  EnsembleAction? onChange;
  EnsembleAction? onKeyPress;
  TextInputAction? keyboardAction;

  EnsembleAction? onDelayedKeyPress;
  Duration delayedKeyPressDuration = const Duration(milliseconds: 300);

  EnsembleAction? onFocusReceived;
  EnsembleAction? onFocusLost;
  bool? enableClearText;

  // applicable only for TextInput
  bool? obscureText;

  // applicable only for Password or obscure TextInput, to toggle between plain and secure text
  bool? obscured;
  bool? obscureToggle;
  dynamic obscureTextWidget;
  bool? readOnly;
  bool selectable = true;
  bool? toolbarDoneButton;

  model.InputValidator? validator;
  bool validateOnUserInteraction = false;
  String? inputType;
  String? mask;
  TextStyle? textStyle;

  bool? multiline;
  int? minLines;
  int? maxLines;
  int? maxLength;
  MaxLengthEnforcement? maxLengthEnforcement;

  List<String>? autofillHints;
}

class TextInputState extends FormFieldWidgetState<BaseTextInput>
    with TextInputFieldAction {
  final focusNode = FocusNode();

  // for this widget we will implement onChange if the text changes AND:
  // 1. the field loses focus next (tabbing out, ...)
  // 2. upon onEditingComplete (e.g click Done on keyboard)
  // This is so we can be consistent with the other input widgets' onChange
  String previousText = '';
  bool didItChange = false;

  // password is obscure by default
  late List<TextInputFormatter> _inputFormatter;
  OverlayEntry? overlayEntry;

  bool get toolbarDoneStatus {
    return widget.controller.toolbarDoneButton ?? false;
  }

  void evaluateChanges() {
    if (didItChange) {
      // trigger binding
      widget.setProperty('value', widget.textController.text);

      // call onChange
      if (widget._controller.onChange != null) {
        ScreenController().executeAction(context, widget._controller.onChange!,
            event: EnsembleEvent(widget));
      }
      didItChange = false;
    }
  }

  void showOverlay(BuildContext context) {
    if (overlayEntry != null || !toolbarDoneStatus) return;
    OverlayState overlayState = Overlay.of(context);
    overlayEntry = OverlayEntry(builder: (context) {
      return Positioned(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        right: 0.0,
        left: 0.0,
        child: const _InputDoneButton(),
      );
    });

    overlayState.insert(overlayEntry!);
  }

  void removeOverlayAndUnfocus() {
    if (overlayEntry != null) {
      overlayEntry!.remove();
      overlayEntry = null;
    }
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  void initState() {
    widget._controller.obscured =
        widget.isPassword() || widget._controller.obscureText == true;
    _inputFormatter = InputFormatter.getFormatter(
        widget._controller.inputType, widget._controller.mask);
    focusNode.addListener(() {
      if (focusNode.hasFocus) {
        if (widget._controller.onFocusReceived != null) {
          ScreenController().executeAction(
              context, widget._controller.onFocusReceived!,
              event: EnsembleEvent(widget));
        }
      } else {
        evaluateChanges();

        // validate
        /*if (validatorKey.currentState != null) {
          validatorKey.currentState!.validate();
        }*/

        if (widget._controller.onFocusLost != null) {
          ScreenController().executeAction(
              context, widget._controller.onFocusLost!,
              event: EnsembleEvent(widget));
        }
      }
    });
    // Checking for readOnly from parent widget and assign the value to TextInput and PasswordInput if it's readOnly property is null
    if (widget._controller.readOnly == null) {
      final formController =
          context.findAncestorWidgetOfExactType<EnsembleForm>()?.controller;

      if (formController != null) {
        widget._controller.readOnly = formController.readOnly == true;
      }
    }

    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.controller.inputFieldAction = this;
    (widget.controller as FormFieldController).setContext(context);
  }

  @override
  void didUpdateWidget(covariant BaseTextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.controller.inputFieldAction = this;

    // Making sure to move cursor to end when widget rebuild
    // issue: https://github.com/EnsembleUI/ensemble/issues/1527

    if (focusNode.hasFocus) {
      int oldCursorPosition = oldWidget.textController.selection.baseOffset;
      int textLength = widget.textController.text.length;

      widget.textController.selection = TextSelection.fromPosition(
        TextPosition(offset: oldCursorPosition),
      );
      int cursorPosition = widget.textController.selection.baseOffset;

      if (textLength > cursorPosition) {
        widget.textController.selection = TextSelection.fromPosition(
          TextPosition(offset: textLength),
        );
      }
    }
  }

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  /// whether to show the content as plain text or obscure
  bool isObscureOrPlainText() {
    if (widget.isPassword()) {
      return widget._controller.obscured ?? true;
    } else {
      return widget._controller.obscureText == true &&
          (widget._controller.obscured ?? true);
    }
  }

  @override
  Widget buildWidget(BuildContext context) {
    InputDecoration decoration = inputDecoration;
    if (widget._controller.floatLabel == true) {
      decoration = decoration.copyWith(
        labelText: widget._controller.label,
      );
    }
    if (widget._controller.errorStyle != null) {
      decoration = decoration.copyWith(
        errorStyle: widget._controller.errorStyle,
      );
    }

    // for password, show the toggle plain text/obscure text
    if ((widget.isPassword() || widget._controller.obscureText == true) &&
        widget._controller.obscureToggle == true) {
      void toggleObscured() {
        bool newObscuredValue = !(widget._controller.obscured ?? true);
        widget._controller.obscured = newObscuredValue;
        widget.setProperty('obscured', newObscuredValue);
        setState(() {});
      }

      decoration = decoration.copyWith(
          suffixIcon: widget._controller.obscureTextWidget != null
              ? GestureDetector(
                  onTap: toggleObscured,
                  child: scopeManager!.buildWidgetFromDefinition(
                      widget._controller.obscureTextWidget),
                )
              : IconButton(
                  icon: Icon(
                    widget._controller.obscured ?? true
                        ? Icons.visibility
                        : Icons.visibility_off,
                    size: ThemeManager().getInputIconSize(context).toDouble(),
                    color: ThemeManager().getInputIconColor(context),
                  ),
                  onPressed: toggleObscured,
                ));
    } else if (!widget.isPassword() &&
        widget.textController.text.isNotEmpty &&
        widget._controller.enableClearText == true) {
      decoration = decoration.copyWith(
        suffixIcon: IconButton(
          onPressed: _clearSelection,
          icon: const Icon(Icons.close),
        ),
      );
    }

    return InputWrapper(
        type: TextInput.type,
        controller: widget._controller,
        widget: TextFormField(
          key: validatorKey,
          autofillHints: widget._controller.autofillHints,
          autovalidateMode: widget._controller.validateOnUserInteraction
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return widget._controller.required
                  ? Utils.translateWithFallback(
                      'ensemble.input.required',
                      widget._controller.requiredMessage ??
                          'This field is required')
                  : null;
            }

            // First we're using the validator to validate the TextInput Field
            if (widget._controller.validator != null) {
              ValidationBuilder? builder;
              if (widget._controller.validator?.minLength != null) {
                builder = ValidationBuilder().minLength(
                    widget._controller.validator!.minLength!,
                    Utils.translateOrNull(
                        'ensemble.input.validation.minimumLength'));
              }
              if (widget._controller.validator?.maxLength != null) {
                builder = (builder ?? ValidationBuilder()).maxLength(
                    widget._controller.validator!.maxLength!,
                    Utils.translateOrNull(
                        'ensemble.input.validation.maximumLength'));
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

            // If validator is null, we can use our own validation based on the InputType
            //only applicable for TextInput
            if (!widget.isPassword()) {
              if (widget._controller.inputType == InputType.email.name) {
                if (!EmailValidator.validate(value)) {
                  return Utils.translateWithFallback(
                      'ensemble.input.validation.invalidEmailType',
                      'Please enter a valid email address');
                }
              } else if (widget._controller.inputType ==
                  InputType.ipAddress.name) {
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
            return null;
          },
          textInputAction: widget._controller.keyboardAction,
          keyboardType: widget.keyboardType,
          inputFormatters: _inputFormatter,
          minLines: isMultiline() ? widget._controller.minLines : null,
          maxLines: isMultiline() ? widget._controller.maxLines : 1,
          maxLength: widget._controller.maxLength,
          maxLengthEnforcement: widget._controller.maxLengthEnforcement ??
              MaxLengthEnforcement.enforced,
          obscureText: isObscureOrPlainText(),
          enableSuggestions: !widget.isPassword(),
          autocorrect: !widget.isPassword(),
          controller: widget.textController,
          focusNode: focusNode,
          enabled: isEnabled(),
          readOnly: widget._controller.readOnly == true,
          enableInteractiveSelection: widget._controller.selectable,
          onTap: () => showOverlay(context),
          onTapOutside: (_) => removeOverlayAndUnfocus(),
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

              if (widget._controller.onDelayedKeyPress != null) {
                executeDelayedAction(widget._controller.onDelayedKeyPress!);
              }
            }
            setState(() {});
          },
          style: isEnabled()
              ? widget._controller.textStyle
              : widget._controller.textStyle?.copyWith(
                  color: Theme.of(context).disabledColor,
                ),
          decoration: decoration,
        ));
  }

  /// multi-line if specified or if maxLine is more than 1
  bool isMultiline() =>
      widget._controller.multiline ??
      (widget._controller.maxLines != null && widget._controller.maxLines! > 1);

  void _clearSelection() {
    widget.textController.clear();
    focusNode.unfocus();
  }

  void executeDelayedAction(EnsembleAction action) {
    getKeyPressDebouncer().run(() async {
      ScreenController()
          .executeAction(context, action, event: EnsembleEvent(widget));
    });
  }

  Debouncer? _delayedKeyPressDebouncer;
  Duration? _lastDelayedKeyPressDuration;

  Debouncer getKeyPressDebouncer() {
    if (_delayedKeyPressDebouncer == null) {
      _delayedKeyPressDebouncer =
          Debouncer(widget._controller.delayedKeyPressDuration);
      _lastDelayedKeyPressDuration = widget._controller.delayedKeyPressDuration;
    }
    // debouncer exists, but has the duration changed?
    else {
      // re-create if anything changed, but need to cancel first
      if (_lastDelayedKeyPressDuration!
              .compareTo(widget._controller.delayedKeyPressDuration) !=
          0) {
        _delayedKeyPressDebouncer!.cancel();
        _delayedKeyPressDebouncer =
            Debouncer(widget._controller.delayedKeyPressDuration);
        _lastDelayedKeyPressDuration =
            widget._controller.delayedKeyPressDuration;
      }
    }

    // here debouncer is valid
    return _delayedKeyPressDebouncer!;
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

enum InputType { email, phone, ipAddress, number, text, url, datetime }

class _InputDoneButton extends StatelessWidget {
  const _InputDoneButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.grey[200],
      alignment: Alignment.topRight,
      padding: const EdgeInsets.only(top: 1.0, bottom: 1.0),
      child: CupertinoButton(
        padding: const EdgeInsets.only(right: 24.0, top: 2.0, bottom: 2.0),
        onPressed: () => FocusScope.of(context).requestFocus(FocusNode()),
        child: const Text(
          'Done',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.normal),
        ),
      ),
    );
  }
}

MaxLengthEnforcement? _getMaxLengthEnforcement(String? value) {
  switch (value) {
    case 'none':
      return MaxLengthEnforcement.none;
    case 'enforced':
      return MaxLengthEnforcement.enforced;
    case 'truncateAfterCompositionEnds':
      return MaxLengthEnforcement.truncateAfterCompositionEnds;
  }
  return null;
}
