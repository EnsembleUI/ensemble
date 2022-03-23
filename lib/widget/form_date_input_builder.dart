import 'package:ensemble/ensemble_theme.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/widget/input_builder.dart';
import 'package:ensemble/widget/widget_builder.dart' as ensemble;
import 'package:ensemble/widget/widget_registry.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

class DateInputBuilder extends FormInputBuilder {
  static const type = 'DateRange';
  DateInputBuilder ({
    required this.controller,
    enabled,
    required,
    label,
    hintText,
    fontSize,
    expanded,
  }) : super (enabled: enabled, required: required, label: label, hintText: hintText, fontSize: fontSize, expanded: expanded);

  final TextEditingController controller;

  static DateInputBuilder fromDynamic(Map<String, dynamic> props, Map<String, dynamic> styles, {WidgetRegistry? registry})
  {
      return DateInputBuilder(
        controller: TextEditingController(),

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
    return DateInput(
      builder: this
    );
  }
}


class DateInput extends StatefulWidget {
  const DateInput({required this.builder, Key? key})
      : super(key: key);

  final DateInputBuilder builder;

  @override
  _DateInputState createState() => _DateInputState();
}

class _DateInputState extends State<DateInput> {

  InputDecoration? _decoration;
  DateTime? start;
  DateTime? end;

  //DateTime? selectedDate;
  String? validationText;
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
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    Widget rtn = TextFormField(
        focusNode: focusNode,
        controller: widget.builder.controller,
        enabled: widget.builder.enabled,
        readOnly: true,
        onChanged: (String txt) {
        },
        onEditingComplete: () {
        },
        style: widget.builder.fontSize != null ?
          TextStyle(fontSize: widget.builder.fontSize!.toDouble()) :
          null,
        cursorColor: EnsembleTheme.buildLightTheme().primaryColor,
        decoration: InputDecoration(
            floatingLabelBehavior: FloatingLabelBehavior.always,
            labelText: widget.builder.label,
            hintText: widget.builder.hintText,
            errorText: validationText,
            suffixIcon: IconButton(
                icon: const Icon(FontAwesomeIcons.calendarAlt),
                onPressed: () {
                  _selectDate(context);
                }
            )
        ),
    );

    if (widget.builder.expanded) {
      return Expanded(child: rtn);
    }
    return rtn;
  }


  void _selectDate(BuildContext context) async {
    final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime.now(),
        lastDate: DateTime(2030));
    if (picked != null) {
      setState(() {
        start = picked.start;
        end = picked.end;
        setState(() {
          final df = DateFormat('MMM dd');
          if (start != null && end != null) {
            widget.builder.controller.text =
                df.format(picked.start) + " - " + df.format(picked.end);
          }
        });
        onDateChange();
      });
    }
  }

  void onDateChange() {
    /*if (widget.widgetData['events'] != null) {
      for (int i=0; i<(widget.widgetData['events'] as List).length; i++) {
        var event = widget.widgetData['events'][i];
        if (event['event'] == 'onchange') {
          for (int j=0; j<(event['expressions'] as List).length; j++) {
            String expression = event['expressions'][i];
            setState(() {

            });
          }
        }
      }
    }*/
  }

  String formatDate(DateTime? selectedDate) {
    if (selectedDate != null) {
      return (selectedDate.month < 10 ? "0" + selectedDate.month.toString() : selectedDate.month.toString()) + "/" +
          (selectedDate.day < 10 ? "0" + selectedDate.day.toString() : selectedDate.day.toString()) + "/" +
          (selectedDate.year.toString());
    }
    return '';
  }

  void validate() {
    bool hasValidation = false;

    // required
    if (widget.builder.required ?? false) {
      if (widget.builder.controller.text.isEmpty) {
        validationText = "This field is required";
      } else {
        validationText = null;
      }
      hasValidation = true;
    }

    if (hasValidation) {
      setState(() {});
    }
  }


}