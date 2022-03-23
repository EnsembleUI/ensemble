import 'package:ensemble/page_model.dart';
import 'package:ensemble/widget/input_builder.dart';
import 'package:ensemble/widget/widget_builder.dart' as ensemble;
import 'package:ensemble/widget/widget_registry.dart';
import 'package:flutter/material.dart';

class TextInputBuilder extends FormInputBuilder {
  static const type = 'TextInput';
  TextInputBuilder ({
    enabled,
    required,
    label,
    hintText,
    fontSize,
    expanded,
  }) : super (enabled: enabled, required: required, label: label, hintText: hintText, fontSize: fontSize, expanded: expanded);

  static TextInputBuilder fromDynamic(Map<String, dynamic> props, Map<String, dynamic> styles, {WidgetRegistry? registry})
  {
    return TextInputBuilder(
      // props
      enabled: props['enabled'],
      required: props['required'],
      label: props['label'],
      hintText: props['hintText'],

      // styles
      fontSize: styles['fontSize'],
      expanded: styles['expanded'] is bool ? styles['expanded'] : false,

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

class TextInput extends StatefulWidget {
  const TextInput({
    required this.builder,
    Key? key
  }) : super(key: key);

  final TextInputBuilder builder;

  @override
  State<StatefulWidget> createState() => TextInputState();
}

class TextInputState extends State<TextInput> {
  String? validationText;
  final TextEditingController textController = TextEditingController();
  final focusNode = FocusNode();

  @override
  void initState() {
    // on blur
    focusNode.addListener(() {
      if (!focusNode.hasFocus) {
        validate();
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  void validate() {
    bool hasValidation = false;

    // required
    if (widget.builder.required ?? false) {
      if (textController.text.isEmpty) {
        validationText = "This field is required";
      } else {
        validationText = null;
      }
      hasValidation = true;
    }

    if (hasValidation)
      setState(() {});

  }



  @override
  Widget build(BuildContext context) {
    Widget rtn = TextFormField(
        focusNode: focusNode,
        controller: textController,
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
            errorText: validationText
        ),
    );

    if (widget.builder.expanded) {
      return Expanded(child: rtn);
    }
    return rtn;

  }
}
