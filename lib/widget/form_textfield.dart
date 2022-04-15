
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/widgets.dart';
import 'package:flutter/material.dart';

class TextField extends StatefulWidget with UpdatableWidget<TextFieldController, TextFieldState> {
  static const type = 'TextInput';
  TextField({Key? key}) : super(key: key);

  // textController manages 'value', while _controller manages the rest
  final TextEditingController textController = TextEditingController();
  final TextFieldController _controller = TextFieldController();
  @override
  TextFieldController get controller => _controller;

  @override
  Map<String, Function> getters() {
    Map<String, Function> myGetters = _controller.getters();
    myGetters['value'] = () => textController.text;
    return myGetters;
  }

  @override
  Map<String, Function> setters() {
    Map<String, Function> mySetters = _controller.setters();
    mySetters['value'] = (newValue) => textController.text = newValue;
    return mySetters;
  }

  @override
  State<StatefulWidget> createState() => TextFieldState();



}

class TextFieldController extends FormFieldController {
  int? fontSize;

  @override
  Map<String, Function> getters() {
    Map<String, Function> myGetters = super.getters();
    myGetters.addAll({
      'fontSize': () => fontSize,
    });
    return myGetters;
  }

  @override
  Map<String, Function> setters() {
    Map<String, Function> mySetters = super.setters();
    mySetters.addAll({
    'fontSize': (value) => fontSize = Utils.optionalInt(value),
    });
    return mySetters;
  }

}

class TextFieldState extends EnsembleWidgetState<TextField> {
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
          errorText: errorText
      ),
    );

  }

}

