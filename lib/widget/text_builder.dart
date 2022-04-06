import 'dart:math';

import 'package:ensemble/ensemble_theme.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/widget/ensemble_stateful_widget.dart';
import 'package:ensemble/widget/widget_builder.dart' as ensemble;
import 'package:ensemble/widget/widget_registry.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TextBuilder extends ensemble.WidgetBuilder {
  static const type = 'Text';
  TextBuilder({
    this.text,
    this.font,
    this.fontSize,
    this.fontWeight,
    this.color,
    this.overflow,
    this.textAlign,
  });
  String? text;
  String? font;
  int? fontSize;
  String? fontWeight;
  int? color;
  String? overflow;
  String? textAlign;

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
      overflow: styles['overflow'],
      textAlign: styles['textAlign'],
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

class EnsembleText extends EnsembleStatefulWidget{
  EnsembleText({
    required this.builder,
    Key? key
  }) : super(builder: builder, key: key);

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

    // built-in font
    if (widget.builder.font == 'title') {
      fontWeight = FontWeight.w600;
      fontSize = 22;
      fontColor = EnsembleTheme.darkerText;
    } else if (widget.builder.font == 'subtitle') {
      fontWeight = FontWeight.w500;
      fontSize = 16;
      fontColor = EnsembleTheme.grey;
    }

    if (widget.builder.fontSize != null) {
      fontSize = widget.builder.fontSize!.toDouble();
    }
    if (widget.builder.fontWeight != null) {
      switch (widget.builder.fontWeight) {
        case 'w100':
          fontWeight = FontWeight.w100;
          break;
        case 'w200':
          fontWeight = FontWeight.w200;
          break;
        case 'w300':
        case 'light':
          fontWeight = FontWeight.w300;
          break;
        case 'w400':
        case 'normal':
          fontWeight = FontWeight.w400;
          break;
        case 'w500':
          fontWeight = FontWeight.w500;
          break;
        case 'w600':
          fontWeight = FontWeight.w600;
          break;
        case 'w700':
        case 'bold':
          fontWeight = FontWeight.w700;
          break;
        case 'w800':
          fontWeight = FontWeight.w800;
          break;
        case 'w900':
          fontWeight = FontWeight.w900;
          break;
      }
    }
    if (widget.builder.color != null) {
      fontColor = Color(widget.builder.color!);
    }

    TextOverflow? textOverflow;
    int? maxLine = 1;
    bool? softWrap = false;
    switch(widget.builder.overflow) {
      case 'visible':
        textOverflow = TextOverflow.visible;
        break;
      case 'clip':
        textOverflow = TextOverflow.clip;
        break;
      case 'fade':
        textOverflow = TextOverflow.fade;
        break;
      case 'ellipsis':
      case 'dotdotdot':
        textOverflow = TextOverflow.ellipsis;
        break;
      case 'wrap':
      default:
        textOverflow = null;
        maxLine = null;
        softWrap = null;
    }

    TextAlign? textAlign;
    switch (widget.builder.textAlign) {
      case 'start':
        textAlign = TextAlign.start;
        break;
      case 'end':
        textAlign = TextAlign.end;
        break;
      case 'center':
        textAlign = TextAlign.center;
        break;
      case 'justify':
        textAlign = TextAlign.justify;
        break;
    }


    return Text(
      widget.builder.text ?? '',
      textAlign: textAlign,
      maxLines: maxLine,
      softWrap: softWrap,
      style: TextStyle(
          fontWeight: fontWeight,
          fontSize: fontSize,
          color: fontColor,
          letterSpacing: 0.27),
      overflow: textOverflow,
    );



  }


}