
import 'package:ensemble/page_model.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/widget/widget_builder.dart' as ensemble;
import 'package:ensemble/widget/widget_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:yaml/yaml.dart';

class ButtonBuilder extends ensemble.WidgetBuilder {
  static const type = 'Button';
  ButtonBuilder({
    required this.id,
    required this.label,
    this.outline=false,
    this.backgroundColor,
    this.color,
    this.borderRadius,
    this.padding,

    this.onTap,
    styles
  }): super(styles: styles);

  final String? id;
  final String label;
  final dynamic onTap;

  final int? padding;
  final bool? outline;
  final int? backgroundColor;
  final int? color;
  final int? borderRadius;


  static ButtonBuilder fromDynamic(Map<String, dynamic> props, Map<String, dynamic> styles, {WidgetRegistry? registry})
  {
    return ButtonBuilder(
      // props
      id: props['id'],
      label: props['label'],
      onTap: props['onTap'],

      // styles
      outline: styles['outline'] is bool ? styles['outline'] : null,
      backgroundColor: styles['backgroundColor'] is int ? styles['backgroundColor'] : null,
      color: styles['color'] is int ? styles['color'] : null,
      borderRadius: styles['borderRadius'] is int ? styles['borderRadius'] : null,
      padding: styles['padding'] is int ? styles['padding'] : null,
      styles: styles
    );
  }

  @override
  Widget buildWidget({
    required BuildContext context,
    List<Widget>? children,
    ItemTemplate? itemTemplate}) {
    return Button(
      builder: this
    );
  }

}


class Button extends StatefulWidget {
  const Button({required this.builder, Key? key})
      : super(key: key);

  final ButtonBuilder builder;

  @override
  ButtonState createState() => ButtonState();
}


class ButtonState extends State<Button> {
  @override
  Widget build(BuildContext context) {

    ButtonStyle buttonStyle = ButtonStyle(
      padding: MaterialStateProperty.all<EdgeInsetsGeometry>(
        widget.builder.padding != null ?
        EdgeInsets.all((widget.builder.padding!).toDouble()) :
        const EdgeInsets.only(left: 15, top: 3, right: 15, bottom: 3)),
      foregroundColor:
        widget.builder.color is int ?
        MaterialStateProperty.all<Color>(Color(widget.builder.color as int)) :
        null,
      backgroundColor:
        (widget.builder.outline is bool && widget.builder.outline as bool) || widget.builder.backgroundColor is! int ?
        null :
        MaterialStateProperty.all<Color>(Color(widget.builder.backgroundColor as int)),
      shape: MaterialStateProperty.all<RoundedRectangleBorder>(
        RoundedRectangleBorder(
          borderRadius:
            widget.builder.borderRadius is int ?
            BorderRadius.circular((widget.builder.borderRadius as int).toDouble()) :
            BorderRadius.zero,
          side: BorderSide(
            color:
              widget.builder.backgroundColor is int ?
              Color(widget.builder.backgroundColor as int) :
              Theme.of(context).colorScheme.primary)
        )
      )
    );

    Text label = Text(widget.builder.label);

    if (widget.builder.outline is bool && widget.builder.outline as bool) {
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

        /*
    return ElevatedButton(
        onPressed: () => widget.builder.onTap == null ? null : ScreenController().executeAction(context, widget.builder.onTap),
        style: ButtonStyle(
            backgroundColor: MaterialStateProperty.all<Color>(Colors.red),
          //foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
          shape: MaterialStateProperty.all<RoundedRectangleBorder>(
            RoundedRectangleBorder(
              //borderRadius: BorderRadius.circular(10),
              //side: BorderSide(color: Colors.red)
            )
          )

        ),
        child: Text(widget.builder.label));*/
  }

  void onPressed(BuildContext context) {
    if (widget.builder.onTap != null) {
      ScreenController().executeAction(context, widget.builder.onTap);
    }
  }



}