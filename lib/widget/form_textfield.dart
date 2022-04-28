
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/widget.dart';
import 'package:flutter/material.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
//import 'package:flutter_gen/gen_l10n/app_localizations.dart';


class TextField extends BaseTextField {
  static const type = 'TextInput';
  TextField({Key? key}) : super(key: key);

  @override
  Map<String, Function> getters() {
    return {
      'value': () => textController.text,
    };
  }
  @override
  Map<String, Function> setters() {
    return {
      'value': (newValue) => textController.text = newValue,
    };
  }
  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  bool isPassword() {
    return false;
  }

}

class PasswordField extends BaseTextField {
  static const type = 'Password';
  PasswordField({Key? key}) : super(key: key);

  @override
  Map<String, Function> getters() {
    return {
      'value': () => textController.text,
    };
  }
  @override
  Map<String, Function> setters() {
    return {};
  }
  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  bool isPassword() {
    return true;
  }

}

abstract class BaseTextField extends StatefulWidget with Invokable, HasController<TextFieldController, TextFieldState> {
  BaseTextField({Key? key}) : super(key: key);

  // textController manages 'value', while _controller manages the rest
  final TextEditingController textController = TextEditingController();
  final TextFieldController _controller = TextFieldController();
  @override
  TextFieldController get controller => _controller;

  @override
  TextFieldState createState() => TextFieldState();

  bool isPassword();

}

/// controller for both TextField and Password
class TextFieldController extends FormFieldController {
  int? fontSize;

  @override
  Map<String, Function> getBaseGetters() {
    Map<String, Function> myGetters = super.getBaseGetters();
    myGetters.addAll({
      'fontSize': () => fontSize,
    });
    return myGetters;
  }

  @override
  Map<String, Function> getBaseSetters() {
    Map<String, Function> mySetters = super.getBaseSetters();
    mySetters.addAll({
      'fontSize': (value) => fontSize = Utils.optionalInt(value),
    });
    return mySetters;
  }

}

class TextFieldState extends FormFieldWidgetState<BaseTextField> {
  final focusNode = FocusNode();

  @override
  void initState() {
    // validate on blur
    focusNode.addListener(() {
      if (!focusNode.hasFocus && validatorKey.currentState != null) {
        validatorKey.currentState!.validate();
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: validatorKey,
      validator: (value) {
        if (widget._controller.required) {
          if (value == null || value.isEmpty) {
            //eturn AppLocalizations.of(context)!.widget_form_required;
            return "This field is required";
          }
        }
        return null;
      },
      obscureText: widget.isPassword(),
      enableSuggestions: !widget.isPassword(),
      autocorrect: !widget.isPassword(),
      controller: widget.textController,
      focusNode: focusNode,
      enabled: widget.controller.enabled,
      onChanged: (String txt) {
      },
      onEditingComplete: () {
      },
      style: widget.controller.fontSize != null ?
        TextStyle(fontSize: widget.controller.fontSize!.toDouble()) :
        null,
      decoration: inputDecoration);

  }

}

