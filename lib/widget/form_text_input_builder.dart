import 'package:ensemble/page_model.dart';
import 'package:ensemble/widget/ensemble_widget.dart';
import 'package:ensemble/widget/form_field_builder.dart' as ensemble;
import 'package:ensemble/widget/widget_registry.dart';
import 'package:flutter/material.dart';

class FormTextInputBuilder extends ensemble.FormFieldBuilder {
  static const type = 'TextInput';
  FormTextInputBuilder ({
    enabled,
    required,
    label,
    hintText,

    fontSize,
    styles,
  }) : super (enabled: enabled, required: required, label: label, hintText: hintText, fontSize: fontSize, styles: styles);

  static FormTextInputBuilder fromDynamic(Map<String, dynamic> props, Map<String, dynamic> styles, {WidgetRegistry? registry})
  {
    return FormTextInputBuilder(
      // props
      enabled: props['enabled'] is bool ? props['enabled'] : true,
      required: props['required'] is bool ? props['required'] : false,
      label: props['label'],
      hintText: props['hintText'],

      // styles
      fontSize: styles['fontSize'],
      styles: styles
    );
  }

  @override
  Widget buildWidget({
    required BuildContext context,
    List<Widget>? children,
    ItemTemplate? itemTemplate}) {
    return TextInput(
      builder: this
    );
  }
}

class TextInput extends UpdatableStatefulWidget {
  TextInput({
    required this.builder,
    Key? key
  }) : super(builder: builder, key: key);

  final FormTextInputBuilder builder;
  final TextEditingController textController = TextEditingController();

  @override
  State<StatefulWidget> createState() => TextInputState();

  @override
  Map<String, Function> getters() {
    return {
      'value': () => textController.value
    };
  }

  @override
  Map<String, Function> setters() {
    return {
      'value': (newValue) => textController.text = newValue
    };
  }
}

class TextInputState extends EnsembleWidgetState<TextInput> {

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
    widget.textController.clear();
    focusNode.dispose();
    super.dispose();
  }

  void validate() {
    if (widget.builder.required) {
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
    Widget rtn = TextFormField(
        focusNode: focusNode,
        controller: widget.textController,
        enabled: widget.builder.enabled,
        onChanged: (String txt) {
        },
        onEditingComplete: () {
        },
        style: widget.builder.fontSize != null ?
          TextStyle(fontSize: widget.builder.fontSize!.toDouble()) :
          null,
        decoration: InputDecoration(
          floatingLabelBehavior: FloatingLabelBehavior.always,
          labelText: widget.builder.label,
          hintText: widget.builder.hintText,
          errorText: errorText
        ),
    );

    /*return Column(
      children: [
        rtn,
        TextFormField(
          onChanged: (String txt) {
            widget.setProperty('value', txt);
          },
        )
      ],
    );*/
    return rtn;

  }
}
