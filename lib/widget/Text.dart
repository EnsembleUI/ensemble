
import 'package:ensemble/ensemble_theme.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/widget.dart' as w;
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as material;
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';

class Text extends StatefulWidget with Invokable, HasController<TextController, TextState> {
  static const type = 'Text';
  Text({Key? key}) : super(key: key);

  final TextController _controller = TextController();
  @override
  TextController get controller => _controller;

  @override
  Map<String, Function> getters() {
    return {
      'text': () => _controller.text
    };
  }

  @override
  Map<String, Function> setters() {
    return {
      'text': (newValue) => _controller.text = Utils.optionalString(newValue),

      'font': (value) => _controller.font = Utils.optionalString(value),
      'fontSize': (value) => _controller.fontSize = Utils.optionalInt(value),
      'fontWeight': (value) => _controller.fontWeight = Utils.optionalString(value),
      'color': (value) => _controller.color = Utils.optionalInt(value),
      'overflow': (value) => _controller.overflow = Utils.optionalString(value),
      'textAlign': (value) => _controller.textAlign = Utils.optionalString(value),
      'textStyle': (value) => _controller.textStyle = Utils.optionalString(value),
      'lineHeight': (value) => _controller.lineHeight = Utils.optionalString(value),

    };
  }

  @override
  Map<String, Function> methods() {
    return {};
  }


  @override
  TextState createState() => TextState();

}

class TextController extends w.WidgetController {
  String? text;
  String? font;
  int? fontSize;
  String? fontWeight;
  int? color;
  String? overflow;
  String? textAlign;
  String? textStyle;
  String? lineHeight;
}

class TextState extends WidgetState<Text> {
  @override
  Widget build(BuildContext context) {
    FontWeight? fontWeight;
    double? fontSize;
    Color? fontColor;

    // built-in font
    if (widget.controller.font == 'heading') {
      fontWeight = FontWeight.w600;
      fontSize = 24;
      fontColor = EnsembleTheme.darkerText;
    } else if (widget.controller.font == 'title') {
      fontWeight = FontWeight.w600;
      fontSize = 22;
      fontColor = EnsembleTheme.darkerText;
    } else if (widget.controller.font == 'subtitle') {
      fontWeight = FontWeight.w500;
      fontSize = 16;
      fontColor = EnsembleTheme.grey;
    }

    if (widget.controller.fontSize != null) {
      fontSize = widget.controller.fontSize!.toDouble();
    }
    if (widget.controller.fontWeight != null) {
      switch (widget.controller.fontWeight) {
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
    if (widget.controller.color != null) {
      fontColor = Color(widget.controller.color!);
    }

    TextOverflow? textOverflow;
    int? maxLine = 1;
    bool? softWrap = false;
    switch(widget.controller.overflow) {
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
    switch (widget.controller.textAlign) {
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
    switch (widget.controller.textStyle) {
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
    switch (widget.controller.lineHeight) {
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
    return material.Text(
      widget.controller.text ?? '',
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

  }


}