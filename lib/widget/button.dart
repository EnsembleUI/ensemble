
import 'package:ensemble/framework/action.dart' as ensemble;
import 'package:ensemble/layout/form.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:flutter/material.dart';
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
      'onTap': (funcDefinition) => _controller.onTap = Utils.getAction(funcDefinition, this),

      'enabled': (value) => _controller.enabled = Utils.optionalBool(value),
      'outline': (value) => _controller.outline = Utils.optionalBool(value),
      'backgroundColor': (value) => _controller.backgroundColor = Utils.optionalInt(value),
      'color': (value) => _controller.color = Utils.optionalInt(value),
      'borderRadius': (value) => _controller.borderRadius = Utils.optionalInt(value),
      'padding': (value) => _controller.padding = Utils.optionalInt(value),
    };
  }
  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  State<StatefulWidget> createState() => ButtonState();

}

class ButtonController extends WidgetController {
  late String label;
  ensemble.EnsembleAction? onTap;

  bool? enabled;
  bool? outline;
  int? backgroundColor;
  int? color;
  int? borderRadius;
  int? padding;
}


class ButtonState extends WidgetState<Button> {
  @override
  Widget build(BuildContext context) {

    ButtonStyle buttonStyle = ButtonStyle(
      padding: MaterialStateProperty.all<EdgeInsetsGeometry>(
        widget._controller.padding != null ?
        EdgeInsets.all((widget._controller.padding!).toDouble()) :
        const EdgeInsets.only(left: 15, top: 3, right: 15, bottom: 3)),
      foregroundColor:
        widget._controller.color is int ?
        MaterialStateProperty.all<Color>(Color(widget._controller.color as int)) :
        null,
      backgroundColor:
        (widget._controller.outline is bool && widget._controller.outline as bool) || widget._controller.backgroundColor is! int ?
        null :
        MaterialStateProperty.all<Color>(Color(widget._controller.backgroundColor as int)),
      shape: MaterialStateProperty.all<RoundedRectangleBorder>(
        RoundedRectangleBorder(
          borderRadius:
            widget._controller.borderRadius is int ?
            BorderRadius.circular((widget._controller.borderRadius as int).toDouble()) :
            BorderRadius.zero,
          side: !isEnabled() ? BorderSide.none : BorderSide(color:
              widget._controller.backgroundColor is int ?
              Color(widget._controller.backgroundColor as int) :
              Theme.of(context).colorScheme.primary)
        )
      )
    );

    Text label = Text(Utils.translate(widget._controller.label, context));

    if (widget._controller.outline is bool && widget._controller.outline as bool) {
      return TextButton(
        onPressed: isEnabled() ? () => onPressed(context) : null,
        style: buttonStyle,
        child: label);
    } else {
      return ElevatedButton(
        onPressed: isEnabled() ? () => onPressed(context) : null,
        style: buttonStyle,
        child: label);
    }

  }

  void onPressed(BuildContext context) {
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