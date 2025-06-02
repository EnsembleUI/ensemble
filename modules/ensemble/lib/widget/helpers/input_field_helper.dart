import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/debouncer.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/HasTextPlaceholder.dart';
import 'package:ensemble/widget/helpers/form_helper.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:form_validator/form_validator.dart';
import 'package:ensemble/framework/model.dart' as model;

/// Common utilities and methods for input fields
class InputFieldHelper {
  /// Get the appropriate keyboard action based on string value
  static TextInputAction? getKeyboardAction(dynamic value) {
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

  /// Get MaxLengthEnforcement from string value
  static MaxLengthEnforcement? getMaxLengthEnforcement(String? value) {
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

  /// Set appropriate TextInputType based on input type
  static TextInputType? getKeyboardType(String? inputType) {
    if (inputType == InputType.email.name) {
      return TextInputType.emailAddress;
    } else if (inputType == InputType.phone.name) {
      return TextInputType.phone;
    } else if (inputType == InputType.number.name) {
      return TextInputType.number;
    } else if (inputType == InputType.text.name) {
      return TextInputType.text;
    } else if (inputType == InputType.url.name) {
      return TextInputType.url;
    } else if (inputType == InputType.datetime.name) {
      return TextInputType.datetime;
    }
    return null;
  }

  /// Check if input should be multiline
  static bool isMultiline(bool? multilineFlag, int? maxLines) {
    return multilineFlag ?? (maxLines != null && maxLines > 1);
  }

  /// Execute a delayed action with debouncer
  static void executeDelayedAction(
    BuildContext context,
    EnsembleAction action,
    dynamic widget,
    Debouncer debouncer,
  ) {
    debouncer.run(() async {
      ScreenController()
          .executeAction(context, action, event: EnsembleEvent(widget));
    });
  }

  /// Get or create a debouncer with the appropriate duration
  static Debouncer getKeyPressDebouncer(
    Debouncer? currentDebouncer,
    Duration? lastDuration,
    Duration newDuration,
  ) {
    if (currentDebouncer == null) {
      return Debouncer(newDuration);
    }
    // re-create if anything changed, but need to cancel first
    else if (lastDuration!.compareTo(newDuration) != 0) {
      currentDebouncer.cancel();
      return Debouncer(newDuration);
    }
    // here debouncer is valid
    return currentDebouncer;
  }

  /// Build common validator function for input fields
  static String? validateInput(
    String? value,
    bool required,
    String? requiredMessage,
    model.InputValidator? validator,
  ) {
    if (value == null || value.isEmpty) {
      return required
          ? Utils.translateWithFallback('ensemble.input.required',
              requiredMessage ?? 'This field is required')
          : null;
    }

    if (validator != null) {
      ValidationBuilder? builder;
      if (validator.minLength != null) {
        builder = ValidationBuilder().minLength(validator.minLength!,
            Utils.translateOrNull('ensemble.input.validation.minimumLength'));
      }
      if (validator.maxLength != null) {
        builder = (builder ?? ValidationBuilder()).maxLength(
            validator.maxLength!,
            Utils.translateOrNull('ensemble.input.validation.maximumLength'));
      }
      if (validator.regex != null) {
        builder = (builder ?? ValidationBuilder()).regExp(
            RegExp(validator.regex!),
            validator.regexError ??
                Utils.translateWithFallback(
                    'ensemble.input.validation.invalidInput',
                    'This field has invalid value'));
      }
      if (builder != null) {
        return builder.build().call(value);
      }
    }
    return null;
  }

  /// Create an InputDoneButton widget
  static Widget createInputDoneButton(BuildContext context) {
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

  /// Common setters for input fields
  static Map<String, Function> getCommonSetters(
      dynamic widget, BaseInputController controller) {
    return {
      'validateOnUserInteraction': (value) => controller
              .validateOnUserInteraction =
          Utils.getBool(value, fallback: controller.validateOnUserInteraction),
      'onKeyPress': (function) => controller.onKeyPress =
          EnsembleAction.from(function, initiator: widget),
      'onChange': (definition) => controller.onChange =
          EnsembleAction.from(definition, initiator: widget),
      'onFocusReceived': (definition) => controller.onFocusReceived =
          EnsembleAction.from(definition, initiator: widget),
      'onFocusLost': (definition) => controller.onFocusLost =
          EnsembleAction.from(definition, initiator: widget),
      'validator': (value) => controller.validator = Utils.getValidator(value),
      'enableClearText': (value) =>
          controller.enableClearText = Utils.optionalBool(value),
      'endingWidget': (widget) => controller.endingWidget = widget,
      'readOnly': (value) => controller.readOnly = Utils.optionalBool(value),
      'selectable': (value) =>
          controller.selectable = Utils.getBool(value, fallback: true),
      'toolbarDone': (value) =>
          controller.toolbarDoneButton = Utils.optionalBool(value),
      'keyboardAction': (value) =>
          controller.keyboardAction = InputFieldHelper.getKeyboardAction(value),
      'multiline': (value) => controller.multiline = Utils.optionalBool(value),
      'minLines': (value) =>
          controller.minLines = Utils.optionalInt(value, min: 1),
      'maxLines': (value) =>
          controller.maxLines = Utils.optionalInt(value, min: 1),
      'textStyle': (style) => controller.textStyle = Utils.getTextStyle(style),
      'autofillHints': (value) =>
          controller.autofillHints = Utils.getListOfStrings(value),
      'maxLength': (value) => controller.maxLength = Utils.optionalInt(value),
      'maxLengthEnforcement': (value) => controller.maxLengthEnforcement =
          InputFieldHelper.getMaxLengthEnforcement(value),
      'onDelayedKeyPress': (function) => controller.onDelayedKeyPress =
          EnsembleAction.from(function, initiator: widget),
      'delayedKeyPressDuration': (value) => controller.delayedKeyPressDuration =
          Utils.getDurationMs(value) ?? controller.delayedKeyPressDuration,
    };
  }

  /// Create a common TextFormField with shared configuration
  static TextFormField createTextFormField({
    required Key? key,
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool validateOnUserInteraction,
    String? Function(String?)? validator,
    required List<TextInputFormatter> inputFormatters,
    required bool? multiline,
    required int? minLines,
    required int? maxLines,
    required int? maxLength,
    required MaxLengthEnforcement? maxLengthEnforcement,
    required bool enabled,
    required bool? readOnly,
    required bool selectable,
    required Function(String)? onChanged,
    required Function(String)? onFieldSubmitted,
    required Function(PointerDownEvent)? onTapOutside,
    required TextStyle? textStyle,
    required List<String>? autofillHints,
    required InputDecoration decoration,
    required TextInputAction? keyboardAction,
    required TextInputType? keyboardType,
    Function()? onTap,
    bool obscureText = false,
    bool enableSuggestions = true,
    bool autocorrect = true,
  }) {
    return TextFormField(
      key: key,
      autofillHints: autofillHints,
      autovalidateMode: validateOnUserInteraction
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      validator: validator,
      textInputAction: keyboardAction,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      minLines: multiline == true || (maxLines != null && maxLines > 1)
          ? minLines
          : null,
      maxLines: multiline == true || (maxLines != null && maxLines > 1)
          ? maxLines
          : 1,
      maxLength: maxLength,
      maxLengthEnforcement:
          maxLengthEnforcement ?? MaxLengthEnforcement.enforced,
      obscureText: obscureText,
      enableSuggestions: enableSuggestions,
      autocorrect: autocorrect,
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      readOnly: readOnly == true,
      enableInteractiveSelection: selectable,
      onTap: onTap,
      onTapOutside: onTapOutside,
      onFieldSubmitted: onFieldSubmitted,
      onChanged: onChanged,
      style: textStyle,
      decoration: decoration,
      contextMenuBuilder: selectable
          ? (context, editableTextState) {
        return AdaptiveTextSelectionToolbar.editableText(
          editableTextState: editableTextState,
        );
      } : null,
    );
  }

  static InputDecoration addEndingWidget(
    InputDecoration decoration,
    dynamic endingWidget,
    ScopeManager? scopeManager,
  ) {
    if (endingWidget != null) {
      decoration = decoration.copyWith(
        suffixIcon: scopeManager!.buildWidgetFromDefinition(endingWidget),
      );
    }
    return decoration;
  }
}

/// Common enum for input types
enum InputType { email, phone, ipAddress, number, text, url, datetime }

/// Common mixin for input field actions
mixin InputFieldAction {
  void focusInputField();
  void unfocusInputField();
}

/// Base controller class for input fields with common properties and methods
class BaseInputController extends FormFieldController with HasTextPlaceholder {
  InputFieldAction? inputFieldAction;
  EnsembleAction? onChange;
  EnsembleAction? onKeyPress;
  TextInputAction? keyboardAction;

  EnsembleAction? onDelayedKeyPress;
  Duration delayedKeyPressDuration = const Duration(milliseconds: 300);

  EnsembleAction? onFocusReceived;
  EnsembleAction? onFocusLost;
  bool? enableClearText;

  // Ending widget for the input field
  dynamic endingWidget;

  model.InputValidator? validator;
  bool validateOnUserInteraction = false;
  String? mask;
  TextStyle? textStyle;

  bool? multiline;
  int? minLines;
  int? maxLines;
  int? maxLength;
  MaxLengthEnforcement? maxLengthEnforcement;

  List<String>? autofillHints;

  bool? readOnly;
  String? inputType;
  bool? toolbarDoneButton;

  bool selectable = true;
}
