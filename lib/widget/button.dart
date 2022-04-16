
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/widgets.dart';
import 'package:flutter/material.dart';

class Button extends StatefulWidget with UpdatableWidget<ButtonController, ButtonState> {
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
      'label': (value) => _controller.label = value,
      'onTap': (funcDefinition) => _controller.onTap = funcDefinition,

      'outline': (value) => _controller.outline = value is bool ? value : null,
      'backgroundColor': (value) => _controller.backgroundColor = Utils.optionalInt(value),
      'color': (value) => _controller.color = Utils.optionalInt(value),
      'borderRadius': (value) => _controller.borderRadius = Utils.optionalInt(value),
      'padding': (value) => _controller.padding = Utils.optionalInt(value),
    };
  }

  @override
  State<StatefulWidget> createState() => ButtonState();

}

class ButtonController extends WidgetController {
  late String label;
  dynamic onTap;

  bool? outline;
  int? backgroundColor;
  int? color;
  int? borderRadius;
  int? padding;
}


class ButtonState extends EnsembleWidgetState<Button> {
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
          side: BorderSide(
            color:
              widget._controller.backgroundColor is int ?
              Color(widget._controller.backgroundColor as int) :
              Theme.of(context).colorScheme.primary)
        )
      )
    );

    Text label = Text(widget._controller.label);

    if (widget._controller.outline is bool && widget._controller.outline as bool) {
      return TextButton(
        onPressed: () => onPressed(context),
        style: buttonStyle,
        child: label);
    } else {
      return ElevatedButton(
        onPressed: () => onPressed(context),
        style: buttonStyle,
        child: label);
    }

  }

  void onPressed(BuildContext context) {
    if (widget._controller.onTap != null) {
      ScreenController().executeAction(context, widget._controller.onTap);
    }
  }



}