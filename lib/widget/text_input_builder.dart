import 'package:ensemble/page_model.dart';
import 'package:ensemble/widget/widget_builder.dart' as ensemble;
import 'package:ensemble/widget/widget_registry.dart';
import 'package:flutter/material.dart';

class TextInputBuilder extends ensemble.WidgetBuilder {
  static const type = 'TextInput';
  TextInputBuilder ({
    this.enabled = true,
    this.required = false,
    this.label,
    this.hintText
  });

  final bool? enabled;
  final bool? required;
  final String? label;
  final String? hintText;

  static TextInputBuilder fromDynamic(Map<String, dynamic> props, Map<String, dynamic> styles, {WidgetRegistry? registry})
  {
    return TextInputBuilder(
      enabled: props['enabled'],
      required: props['required'],
      label: props['label'],
      hintText: props['hintText']
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
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 8),
      child: TextFormField(
        focusNode: focusNode,
        controller: textController,
        enabled: widget.builder.enabled,
        onChanged: (String txt) {
        },
        onEditingComplete: () {
        },
        style: const TextStyle(
          fontSize: 18,
        ),
        decoration: InputDecoration(
            floatingLabelBehavior: FloatingLabelBehavior.always,
            labelText: widget.builder.label,
            hintText: widget.builder.hintText,
            errorText: validationText
        ),
      ),

    );
  }
}
