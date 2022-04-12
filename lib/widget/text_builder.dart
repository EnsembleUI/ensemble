import 'dart:math';

import 'package:ensemble/ensemble_theme.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/ensemble_widget.dart';
import 'package:ensemble/widget/widget_builder.dart' as ensemble;
import 'package:ensemble/widget/widget_registry.dart';
import 'package:flutter/material.dart';

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
    this.textStyle,
    this.lineHeight,
    styles,
  }) : super(styles: styles);
  String? text;
  String? font;
  int? fontSize;
  String? fontWeight;
  int? color;
  String? overflow;
  String? textAlign;
  String? textStyle;
  String? lineHeight;

  static TextBuilder fromDynamic(Map<String, dynamic> props, Map<String, dynamic> styles, {WidgetRegistry? registry})
  {
    return TextBuilder(
      // props
      text: Utils.optionalString(props['text']),

      // styles
      font: styles['font'],
      fontSize: Utils.optionalInt(styles['fontSize']),
      fontWeight: styles['fontWeight'],
      color: Utils.optionalInt(styles['color']),
      overflow: styles['overflow'],
      textAlign: styles['textAlign'],
      textStyle: styles['textStyle'],
      lineHeight: Utils.optionalString(styles['lineHeight']),

      styles: styles,
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

class EnsembleText extends UpdatableStatefulWidget {
  EnsembleText({
    required this.builder,
    Key? key
  }) : super(builder: builder, key: key);

  final TextBuilder builder;

  @override
  State<StatefulWidget> createState() => TextState();

  @override
  Map<String, Function> getters() {
    return {
      'text': () => builder.text ?? ''
    };
  }

  @override
  Map<String, Function> setters() {
    return {
      'text': (newValue) => builder.text = newValue,
      'fontSize': (newInt) => updateFontSize(newInt)
    };
  }

  void updateFontSize(dynamic newValue) {
    if (newValue is int) {
      builder.fontSize = newValue;
    }
  }
}

class TextState extends EnsembleWidgetState<EnsembleText> {

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

    FontStyle? fontStyle;
    TextDecoration? textDecoration;
    switch (widget.builder.textStyle) {
      case 'italic':
        fontStyle = FontStyle.italic;
        break;
      case 'underline':
        textDecoration = TextDecoration.underline;
        break;
      case 'strikethrough':
        textDecoration = TextDecoration.lineThrough;
        break;
      case 'italic_underline':
        fontStyle = FontStyle.italic;
        textDecoration = TextDecoration.underline;
        break;
      case 'italic_strikethrough':
        fontStyle = FontStyle.italic;
        textDecoration = TextDecoration.lineThrough;
        break;
    }

    // Note: default should be null, as it may not be 1.0 depending on fonts
    double? lineHeight;
    switch (widget.builder.lineHeight) {
      case '1.0':
        lineHeight = 1;
        break;
      case '1.15':
        lineHeight = 1.15;
        break;
      case '1.25':
        lineHeight = 1.25;
        break;
      case '1.5':
        lineHeight = 1.5;
        break;
      case '2.0':
        lineHeight = 2;
        break;
      case '2.5':
        lineHeight = 2.5;
        break;
    }


    Widget rtn = Text(
      widget.builder.text ?? '',
      textAlign: textAlign,
      maxLines: maxLine,
      softWrap: softWrap,
      style: TextStyle(
          decorationColor: Colors.blue,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
          decoration: textDecoration,
          fontSize: fontSize,
          color: fontColor,
          height: lineHeight,),
      overflow: textOverflow,
    );

    /*return Column(
      children: [
        rtn,
        ElevatedButton(
            onPressed: () => updateMytext(),
            child: const Text("Click to update")
        )
      ],
    );*/
    return rtn;



  }

  void updateMytext() {
    widget.setProperty('text', 'Hello');
    widget.setProperty('fontSize', 40);
  }

}