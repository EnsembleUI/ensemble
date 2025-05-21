import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/theme/theme_manager.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/layout/form.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/debouncer.dart';
import 'package:ensemble/util/input_formatter.dart';
import 'package:ensemble/util/input_validator.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/form_helper.dart';
import 'package:ensemble/widget/helpers/input_field_helper.dart';
import 'package:ensemble/widget/helpers/input_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:email_validator/email_validator.dart';
import 'package:flutter/services.dart';
import 'package:form_validator/form_validator.dart';

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
      'dismissOnTapOutside': (value) =>
          _controller.dismissOnTapOutside = Utils.optionalBool(value),
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
  TextInputType? get keyboardType =>
      InputFieldHelper.getKeyboardType(_controller.inputType);
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

    // Add common setters from helper
    setters.addAll(InputFieldHelper.getCommonSetters(this, _controller));

    // Add TextInput/PasswordInput specific setters
    setters.addAll({
      'obscureToggle': (value) =>
          _controller.obscureToggle = Utils.optionalBool(value),
      'obscured': (widget) => _controller.obscureText == true,
      'obscureTextWidget': (widget) => _controller.obscureTextWidget = widget,
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

  @override
  TextInputState createState() => TextInputState();

  bool isPassword();

  TextInputType? get keyboardType;
}

mixin TextInputFieldAction on FormFieldWidgetState<BaseTextInput>
    implements InputFieldAction {
  @override
  void focusInputField();

  @override
  void unfocusInputField();
}

/// controller for both TextField and Password
class TextInputController extends BaseInputController {
  // applicable only for TextInput
  bool? obscureText;
  bool? dismissOnTapOutside;

  // applicable only for Password or obscure TextInput, to toggle between plain and secure text
  bool? obscured;
  bool? obscureToggle;
  dynamic obscureTextWidget;
}

class TextInputState extends FormFieldWidgetState<BaseTextInput>
    with TextInputFieldAction {
  final focusNode = FocusNode();
  VoidCallback? _propertyListener;

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
        child: InputFieldHelper.createInputDoneButton(context),
      );
    });

    overlayState.insert(overlayEntry!);
  }

  void removeOverlayAndUnfocus() {
    if (overlayEntry != null) {
      overlayEntry!.remove();
      overlayEntry = null;
    }
    if (widget.controller.dismissOnTapOutside == true)
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

    // Remove any existing listener first
    if (_propertyListener != null) {
      widget.controller.removeListener(_propertyListener!);
    }

    // Create and store new listener
    _propertyListener = () {
      if (mounted) {
        // Check if widget is still mounted
        final formState = EnsembleForm.of(context);
        formState?.widget.controller.notifyFormChanged();
      }
    };

    widget.controller.addListener(_propertyListener!);
  }

  @override
  void didUpdateWidget(covariant BaseTextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.controller.inputFieldAction = this;

    // Making sure to move cursor to end when widget rebuild
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
    // Remove listener
    if (_propertyListener != null) {
      widget.controller.removeListener(_propertyListener!);
    }
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

    // Add ending widget if provided
    decoration = InputFieldHelper.addEndingWidget(
        decoration, widget.controller.endingWidget, scopeManager);

    return InputWrapper(
      type: TextInput.type,
      controller: widget._controller,
      widget: InputFieldHelper.createTextFormField(
        key: validatorKey,
        controller: widget.textController,
        focusNode: focusNode,
        validateOnUserInteraction: widget._controller.validateOnUserInteraction,
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
          // only applicable for TextInput
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
        inputFormatters: _inputFormatter,
        multiline: widget._controller.multiline,
        minLines: widget._controller.minLines,
        maxLines: widget._controller.maxLines,
        maxLength: widget._controller.maxLength,
        maxLengthEnforcement: widget._controller.maxLengthEnforcement,
        enabled: isEnabled(),
        readOnly: widget._controller.readOnly,
        selectable: widget._controller.selectable,
        onTap: () => showOverlay(context),
        onTapOutside: (_) => removeOverlayAndUnfocus(),
        onFieldSubmitted: (value) => widget.controller.submitForm(context),
        onChanged: (String txt) {
          // If text suddenly increased by more than one character,
          // it could indicate a paste operation
          if (txt != previousText &&
              (txt.length > previousText.length + 1 ||
                  previousText.length > txt.length + 1) &&
              !widget._controller.selectable) {
            widget.textController.text = previousText;
            widget.textController.selection = TextSelection.fromPosition(
              TextPosition(offset: previousText.length),
            );
            // Early return to prevent further processing
            return;
          }
          if (txt != previousText) {
            // for performance reason, we dispatch onChange (as well as binding to value)
            // upon EditingComplete (select Done on virtual keyboard) or Focus Out
            didItChange = true;
            previousText = widget.textController.text;

            // we dispatch onKeyPress here
            if (widget._controller.onKeyPress != null) {
              ScreenController().executeAction(
                  context, widget._controller.onKeyPress!,
                  event: EnsembleEvent(widget));
            }

            if (widget._controller.onDelayedKeyPress != null) {
              InputFieldHelper.executeDelayedAction(
                  context,
                  widget._controller.onDelayedKeyPress!,
                  widget,
                  getKeyPressDebouncer());
            }
          }
          setState(() {});
        },
        textStyle: isEnabled()
            ? widget._controller.textStyle
            : widget._controller.textStyle?.copyWith(
                color: Theme.of(context).disabledColor,
              ),
        autofillHints: widget._controller.autofillHints,
        decoration: decoration,
        keyboardAction: widget._controller.keyboardAction,
        keyboardType: widget.keyboardType,
        obscureText: isObscureOrPlainText(),
        enableSuggestions: !widget.isPassword(),
        autocorrect: !widget.isPassword(),
      ),
    );
  }

  /// multi-line if specified or if maxLine is more than 1
  bool isMultiline() => InputFieldHelper.isMultiline(
      widget._controller.multiline, widget._controller.maxLines);

  void _clearSelection() {
    widget.textController.clear();
    focusNode.unfocus();
  }

  void executeDelayedAction(EnsembleAction action) {
    InputFieldHelper.executeDelayedAction(
        context, action, widget, getKeyPressDebouncer());
  }

  Debouncer? _delayedKeyPressDebouncer;
  Duration? _lastDelayedKeyPressDuration;

  Debouncer getKeyPressDebouncer() {
    return InputFieldHelper.getKeyPressDebouncer(
        _delayedKeyPressDebouncer,
        _lastDelayedKeyPressDuration,
        widget._controller.delayedKeyPressDuration);
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
