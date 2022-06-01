
import 'package:ensemble/framework/action.dart' as ensemble;
import 'package:ensemble/layout/form.dart';
import 'package:ensemble/layout/layout_helper.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:flutter/material.dart';
import 'package:ensemble/layout/form.dart' as ensembleForm;
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';

class Button extends StatefulWidget with Invokable, HasController<ButtonController, ButtonState> {
  static const type = 'Button';
  Button({Key? key}) : super(key: key);

  final ButtonController _controller = ButtonController();
  @override
  ButtonController get controller => _controller;

  @override
  Map<String, Function> getters() {
    return {};
  }
  @override
  Map<String, Function> setters() {
    return {
      'label': (value) => _controller.label = Utils.getString(value, fallback: ''),
      'onTap': (funcDefinition) => _controller.onTap = Utils.getAction(funcDefinition, initiator: this),
      'validateForm': (value) => _controller.validateForm = Utils.optionalBool(value),
      'validateFields': (items) => _controller.validateFields = Utils.getList(items),

      'enabled': (value) => _controller.enabled = Utils.optionalBool(value),
      'outline': (value) => _controller.outline = Utils.optionalBool(value),
      'backgroundColor': (value) => _controller.backgroundColor = Utils.getColor(value),
      'color': (value) => _controller.color = Utils.getColor(value),
    };
  }
  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  State<StatefulWidget> createState() => ButtonState();

}

class ButtonController extends BoxController {
  late String label;
  ensemble.EnsembleAction? onTap;

  // whether this button will invoke form validation or not
  // this has no effect if the button is not inside a form
  bool? validateForm;

  // a list of field IDs to validate. TODO: implement this
  List<dynamic>? validateFields;

  bool? enabled;
  bool? outline;
  Color? backgroundColor;
  Color? color;
}


class ButtonState extends WidgetState<Button> {
  @override
  Widget build(BuildContext context) {
    // keep it simple, if border color is not set, use the backgroundColor.
    // For outline button it makes sense, for solid button it doesn't matter.
    Color borderColor =
        widget._controller.borderColor ??
        widget._controller.backgroundColor ??
        Theme.of(context).colorScheme.primary;

    ButtonStyle buttonStyle = ButtonStyle(
      padding: MaterialStateProperty.all<EdgeInsetsGeometry>(
          Utils.getInsets(
              widget._controller.padding,
              fallback: const EdgeInsets.only(left: 15, top: 3, right: 15, bottom: 3))),
      foregroundColor:
        widget._controller.color != null ?
        MaterialStateProperty.all<Color>(widget._controller.color!) :
        null,
      backgroundColor:
        (widget._controller.outline is bool && widget._controller.outline as bool) || widget._controller.backgroundColor == null ?
        null :
        MaterialStateProperty.all<Color>(widget._controller.backgroundColor!),
      shape: MaterialStateProperty.all<RoundedRectangleBorder>(
        RoundedRectangleBorder(
          borderRadius:
            widget._controller.borderRadius is int ?
            BorderRadius.circular((widget._controller.borderRadius as int).toDouble()) :
            BorderRadius.zero,
          side: !isEnabled() ? BorderSide.none : BorderSide(
              color: borderColor,
              width: (widget._controller.borderWidth ?? 1).toDouble())
        )
      )
    );

    Text label = Text(Utils.translate(widget._controller.label, context));

    Widget? rtn;
    if (widget._controller.outline is bool && widget._controller.outline as bool) {
      rtn = TextButton(
        onPressed: isEnabled() ? () => onPressed(context) : null,
        style: buttonStyle,
        child: label);
    } else {
      rtn = ElevatedButton(
        onPressed: isEnabled() ? () => onPressed(context) : null,
        style: buttonStyle,
        child: label);
    }

    // add margin if specified
    EdgeInsets? margin = Utils.optionalInsets(widget._controller.margin);
    return margin != null ?
      Padding(padding: margin, child: rtn) :
        rtn;
  }

  void onPressed(BuildContext context) {
    // validate if we are inside a Form
    if (widget._controller.validateForm != null && widget._controller.validateForm!) {
      ensembleForm.FormState? formState = EnsembleForm.of(context);
      if (formState != null) {
        // don't continue if validation fails
        if (!formState.validate()) {
          return;
        }
      }
    }
    // else validate specified fields
    else if (widget._controller.validateFields != null) {

    }

    // execute the onTap action
    if (widget._controller.onTap != null) {
      ScreenController().executeAction(context, widget._controller.onTap!);
    }
  }

  bool isEnabled() {
    return widget._controller.enabled
        ?? EnsembleForm.of(context)?.widget.controller.enabled
        ?? true;
  }

}