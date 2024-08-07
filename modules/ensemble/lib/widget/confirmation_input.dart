import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/framework/widget/widget.dart' as framework;
import 'package:ensemble/framework/widget/icon.dart' as ensembleIcon;
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble/widget/input/form_textfield.dart';
import 'package:flutter/material.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/widgets.dart';
import 'package:otp_pin_field/otp_pin_field.dart';

class ConfirmationInput extends StatefulWidget
    with
        Invokable,
        HasController<ConfirmationInputController, ConfirmationInputState> {
  static const type = 'ConfirmationInput';
  ConfirmationInput({Key? key}) : super(key: key);

  final ConfirmationInputController _controller = ConfirmationInputController();
  @override
  ConfirmationInputController get controller => _controller;

  @override
  Map<String, Function> getters() {
    return {
      'text': () => _controller.text,
    };
  }

  @override
  Map<String, Function> setters() {
    return {
      'text': (value) => _controller.text = Utils.optionalString(value),
      'fieldType': (input) =>
          _controller.fieldType = Utils.optionalString(input),
      'inputType': (type) => _controller.inputType = Utils.optionalString(type),
      'obscureText': (type) => _controller.obscureText = Utils.optionalString(type),
      'obscureSymbol': (typeCustom) => _controller.obscureSymbol = typeCustom,
      'autoComplete': (newValue) =>
          _controller.autoComplete = Utils.getBool(newValue, fallback: true),
      'spaceEvenly': (newValue) =>
          _controller.spaceEvenly = Utils.getBool(newValue, fallback: true),
      'enableCursor': (newValue) =>
          _controller.enableCursor = Utils.getBool(newValue, fallback: true),
      'length': (newValue) =>
          _controller.length = Utils.getInt(newValue, fallback: 4),
      'fieldWidth': (value) =>
          _controller.fieldWidth = Utils.optionalDouble(value),
      'fieldHeight': (value) =>
          _controller.fieldHeight = Utils.optionalDouble(value),
      'gap': (value) =>
          _controller.fieldGap = Utils.getDouble(value, fallback: 10.0),
      'borderRadius': (value) =>
          _controller.fieldBorderRadius = Utils.getDouble(value, fallback: 2.0),
      'borderWidth': (value) =>
          _controller.fieldBorderWidth = Utils.getDouble(value, fallback: 2.0),
      'textStyle': (style) => _controller.textStyle =
          Utils.getTextStyleAsComposite(_controller, style: style),
      'defaultFieldBorderColor': (newValue) =>
          _controller.defaultFieldBorderColor = Utils.getColor(newValue),
      'activeFieldBorderColor': (newValue) =>
          _controller.activeFieldBorderColor = Utils.getColor(newValue),
      'defaultFieldBackgroundColor': (newValue) =>
          _controller.defaultFieldBackgroundColor = Utils.getColor(newValue),
      'activeFieldBackgroundColor': (newValue) =>
          _controller.activeFieldBackgroundColor = Utils.getColor(newValue),
      'filledFieldBackgroundColor': (newValue) =>
          _controller.filledFieldBackgroundColor = Utils.getColor(newValue),
      'filledFieldBorderColor': (newValue) =>
          _controller.filledFieldBorderColor = Utils.getColor(newValue),
      'cursorColor': (newValue) =>
          _controller.cursorColor = Utils.getColor(newValue),
      'onChange': (funcDefinition) => _controller.onChange =
          EnsembleAction.from(funcDefinition, initiator: this),
      'onComplete': (funcDefinition) => _controller.onComplete =
          EnsembleAction.from(funcDefinition, initiator: this),
      'autofillEnabled': (value) =>
          _controller.autofillEnabled = Utils.optionalBool(value),
    };
  }

  @override
  Map<String, Function> methods() {
    return {
      'clear': () => controller.inputFieldAction?.clear(),
      'focus': () => controller.inputFieldAction?.focusInputField(),
      'unfocus': () => controller.inputFieldAction?.unfocusInputField(),
    };
  }

  @override
  ConfirmationInputState createState() => ConfirmationInputState();

  TextInputType get keyboardType {
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
    return TextInputType.number;
  }
}

class ConfirmationInputController extends BoxController {
  InputFieldAction? inputFieldAction;
  String? text;
  late int length;
  bool? autoComplete;
  bool? spaceEvenly;
  bool? enableCursor;
  bool? autofillEnabled;
  String? obscureText;
  dynamic obscureSymbol;
  String? fieldType;
  String? inputType;
  double? fieldWidth;
  double? fieldHeight;
  double? fieldGap;
  double? fieldBorderRadius;
  double? fieldBorderWidth;
  Color? defaultFieldBorderColor;
  Color? activeFieldBorderColor;
  Color? defaultFieldBackgroundColor;
  Color? activeFieldBackgroundColor;
  Color? filledFieldBackgroundColor;
  Color? filledFieldBorderColor;
  Color? cursorColor;
  EnsembleAction? onChange;
  EnsembleAction? onComplete;

  TextStyleComposite? _textStyle;
  TextStyleComposite get textStyle => _textStyle ??= TextStyleComposite(this);
  set textStyle(TextStyleComposite style) => _textStyle = style;
}

mixin InputFieldAction on framework.WidgetState<ConfirmationInput> {
  void focusInputField();
  void unfocusInputField();
  void clear();
}

class ConfirmationInputState extends framework.WidgetState<ConfirmationInput>
    with InputFieldAction {
  final _otpPinFieldController = GlobalKey<OtpPinFieldState>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.controller.inputFieldAction = this;
  }

  @override
  void didUpdateWidget(covariant ConfirmationInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.controller.inputFieldAction = this;
  }

  @override
  Widget buildWidget(BuildContext context) {
    return BoxWrapper(
      widget: buildTextInput(widget.controller),
      boxController: widget.controller,
    );
  }

  Widget buildTextInput(ConfirmationInputController controller) {
    return OtpPinField(
      autoFillEnable: widget._controller.autofillEnabled,
      key: _otpPinFieldController,
      value: widget._controller.text ?? '',
      otpPinFieldStyle: OtpPinFieldStyle(
        textStyle: controller.textStyle.getTextStyle(),
        defaultFieldBorderColor:
            controller.defaultFieldBorderColor ?? Colors.black45,
        activeFieldBorderColor:
            controller.activeFieldBorderColor ?? Colors.black,
        defaultFieldBackgroundColor:
            controller.defaultFieldBackgroundColor ?? Colors.transparent,
        activeFieldBackgroundColor:
            controller.activeFieldBackgroundColor ?? Colors.transparent,
        filledFieldBackgroundColor:
            controller.filledFieldBackgroundColor ?? Colors.transparent,
        filledFieldBorderColor:
            controller.filledFieldBorderColor ?? Colors.transparent,
        fieldPadding: controller.fieldGap ?? 10.0,
        fieldBorderRadius: controller.fieldBorderRadius ?? 2.0,
        fieldBorderWidth: controller.fieldBorderWidth ?? 2.0,
      ),
      fieldHeight: widget.controller.fieldHeight ?? 50,
      fieldWidth: widget.controller.fieldWidth ?? 50,
      maxLength: controller.length,
      keyboardType: widget.keyboardType,
      otpPinFieldDecoration: controller.fieldType?.otpPinField ??
          OtpPinFieldDecoration.defaultPinBoxDecoration,
      otpPinFieldInputType: OtpPinFieldInputType.values.from(controller.obscureText) ?? OtpPinFieldInputType.none,
      otpPinInputCustom: _validatePinTypeCustom(controller.obscureSymbol),
      cursorColor: controller.cursorColor,
      autoComplete: controller.autoComplete ?? true,
      spaceEvenly: controller.spaceEvenly ?? true,
      onChange: _onChange,
      onSubmit: _onComplete,
      
    );
  }

  void _onChange(String text) {
    widget._controller.text = text;
    if (widget._controller.onChange != null) {
      ScreenController().executeAction(context, widget._controller.onChange!);
    }
  }

  void _onComplete(String text) {
    widget._controller.text = text;
    if (widget._controller.onComplete != null) {
      ScreenController().executeAction(context, widget._controller.onComplete!);
    }
  }

  @override
  void clear() {
    _otpPinFieldController.currentState?.clearOtp();
  }

  @override
  void focusInputField() {
    _otpPinFieldController.currentState?.hasFocus = true;
    _otpPinFieldController.currentState?.focusNode.requestFocus();
  }

  @override
  void unfocusInputField() {
    _otpPinFieldController.currentState?.hasFocus = false;
    _otpPinFieldController.currentState?.focusNode.unfocus();
  }
}

dynamic _validatePinTypeCustom(dynamic value) {
  if ( value is String ) {
    if (  value.length != 1) {
      return "*"; // Default symbol if string length is not 1
    }
    return value;
  } else if (value is Map && value['icon'] != null) {
      final iconModel = Utils.getIcon(value['icon']);
      if (iconModel != null) {
        return ensembleIcon.Icon.fromModel(iconModel); // Return the IconModel directly
      } else {
        return "*"; 
      } // Return the IconModel directly
  }
  return "*"; // Return null if value is neither String nor IconModel
}

extension FieldTypeOtpValue on String {
  OtpPinFieldDecoration get otpPinField {
    switch (this) {
      case 'custom':
        return OtpPinFieldDecoration.custom;
      case 'rounded':
        return OtpPinFieldDecoration.roundedPinBoxDecoration;
      case 'underline':
        return OtpPinFieldDecoration.underlinedPinBoxDecoration;
      default:
        return OtpPinFieldDecoration.defaultPinBoxDecoration;
    }
  }
}
