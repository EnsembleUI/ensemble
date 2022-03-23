import 'package:ensemble/ensemble_theme.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/widget/widget_builder.dart' as ensemble;
import 'package:ensemble/widget/widget_registry.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class TextBuilder extends ensemble.WidgetBuilder {
  static const type = 'Text';
  TextBuilder({
    this.text,
    this.font,
    this.fontSize,
    this.fontWeight,
    this.color,
    this.padding,
    this.overflow,
  });
  String? text;
  int? padding;
  String? overflow;

  String? font;
  int? fontSize;
  String? fontWeight;
  int? color;

  static TextBuilder fromDynamic(Map<String, dynamic> props, Map<String, dynamic> styles, {WidgetRegistry? registry})
  {
    return TextBuilder(
      // props
      text: props['text']?.toString(),

      // styles
      font: styles['font'],
      fontSize: styles['fontSize'] is int ? styles['fontSize'] : null,
      fontWeight: styles['fontWeight'],
      color: styles['color'] is int ? styles['color'] : null,
      padding: styles['padding'] is int ? styles['padding'] : null,
      overflow: styles['overflow'],
    );
  }


  @override
  Widget buildWidget({
    required BuildContext context,
    List<Widget>? children,
    ItemTemplate? itemTemplate}) {
    return EnsembleText(builder: this);
  }

}

class EnsembleText extends StatefulWidget {
  const EnsembleText({
    required this.builder,
    Key? key
  }) : super(key: key);

  final TextBuilder builder;

  @override
  State<StatefulWidget> createState() => TextState();


}

class TextState extends State<EnsembleText> {
  @override
  Widget build(BuildContext context) {

    FontWeight? fontWeight;
    double? fontSize;
    Color? fontColor;

    if (widget.builder.font == '.title') {
      fontWeight = FontWeight.w600;
      fontSize = 22;
      fontColor = EnsembleTheme.darkerText;
    } else if (widget.builder.font == '.subtitle') {
      fontWeight = FontWeight.w400;
      fontSize = 16;
      fontColor = EnsembleTheme.grey;
    } else if (widget.builder.font == '.caption') {
      fontWeight = FontWeight.w400;
      fontSize = 14;
      fontColor = EnsembleTheme.lightText;
    }


    if (widget.builder.fontWeight != null) {
      switch (widget.builder.fontWeight) {
        case 'light':
          fontWeight = FontWeight.w200;
          break;
        case 'medium':
        case 'normal':
          fontWeight = FontWeight.normal;
          break;
        case 'bold':
          fontWeight = FontWeight.bold;
          break;
      }
    }

    if (widget.builder.fontSize != null) {
      fontSize = widget.builder.fontSize!.toDouble();
    }
    if (widget.builder.color != null) {
      fontColor = Color(widget.builder.color!);
    }

    TextOverflow? textOverflow;
    switch(widget.builder.overflow) {
      case 'wrap':
        textOverflow = TextOverflow.visible;
        break;
      case 'ellipsis':
      case 'dotdotdot':
        textOverflow = TextOverflow.ellipsis;
        break;

      /* // Fade and Clip doesn't work yet. They wrap instead. Do they need a fixed width?
      case 'fade':
        textOverflow = TextOverflow.fade;
        break;
      case 'clip':
        textOverflow = TextOverflow.clip;
        break;
      */

    }

    Widget textWidget = Padding(
        padding: EdgeInsets.all((widget.builder.padding ?? 0).toDouble()),
        child: Text(
          widget.builder.text ?? '',
          style: TextStyle(
              fontWeight: fontWeight,
              fontSize: fontSize,
              color: fontColor,
              letterSpacing: 0.27),
          overflow: textOverflow,
        )
    );


    return textOverflow != null ?
          Expanded(child: textWidget) :
          textWidget;


  }


}