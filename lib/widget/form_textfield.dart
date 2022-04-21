
import 'package:ensemble/framework/icon.dart' as ensemble;
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/widget.dart';
import 'package:flutter/material.dart';
import 'package:sdui/invokables/invokable.dart';



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

class TextFieldState extends WidgetState<BaseTextField> {
  final focusNode = FocusNode();

  // error to show the user
  String? errorText;

  @override
  void initState() {
    // validate on blur
    focusNode.addListener(() {
      if (!focusNode.hasFocus) {
        validate();
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  void validate() {
    if (widget.controller.required) {
      setState(() {
        errorText =
        widget.textController.text.isEmpty || widget.textController.text.trim().isEmpty ?
        "This field is required" :
        null;
      });
    }
  }



  @override
  Widget build(BuildContext context) {
    return TextFormField(
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
      decoration: InputDecoration(
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelText: widget.controller.label,
        hintText: widget.controller.hintText,
        errorText: errorText,
        icon: widget.controller.icon == null ? null :
          ensemble.Icon(
            widget.controller.icon!,
            library: widget.controller.iconLibrary,
            size: widget.controller.iconSize,
            color: widget._controller.iconColor != null ?
              Color(widget.controller.iconColor!) :
              null)
      ),
    );

  }

}

