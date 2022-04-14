
import 'package:ensemble/ensemble_theme.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/widgets.dart';
import 'package:flutter/material.dart';

class EnsembleText extends StatefulWidget with UpdatableWidget<TextPayload> {
  static const type = 'Text';
  EnsembleText({Key? key}) : super(key: key);

  final TextPayload _payload = TextPayload();
  @override
  TextPayload get payload => _payload;

  @override
  TextState createState() => TextState();

  @override
  Map<String, Function> getters() {
    return {
      'text': () => _payload.text
    };
  }

  @override
  Map<String, Function> setters() {
    return {
      // props
      'text': (newValue) => _payload.text = Utils.optionalString(newValue),

      // styles
      'font': (value) => _payload.font = value,
      'fontSize': (value) => _payload.fontSize = Utils.optionalInt(value),
      'fontWeight': (value) => _payload.fontWeight = value,
      'color': (value) => _payload.color = Utils.optionalInt(value),
      'overflow': (value) => _payload.overflow = value,
      'textAlign': (value) => _payload.textAlign = value,
      'textStyle': (value) => _payload.textStyle = value,
      'lineHeight': (value) => _payload.lineHeight = Utils.optionalString(value),

    };
  }

  void setProp(String key, dynamic value) {
    switch(key) {
      case 'text': _payload.text = Utils.optionalString(value); break;
      case 'font':
        _payload.font = value;
        break;
      case 'fontSize':
        _payload.fontSize = Utils.optionalInt(value);
        break;
      case 'fontWeight':
        _payload.fontWeight = value;
        break;
      case 'color':
        _payload.color = Utils.optionalInt(value);
        break;
      case 'overflow':
        _payload.overflow = value;
        break;
      case 'textAlign':
        _payload.textAlign = value;
        break;
      case 'textStyle':
        _payload.textStyle = value;
        break;
      case 'lineHeight':
        _payload.lineHeight = Utils.optionalString(value);
        break;
    }
  }


}

class TextPayload extends Payload {
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

class TextState extends EnsembleWidgetState<EnsembleText> {
  @override
  Widget build(BuildContext context) {
    FontWeight? fontWeight;
    double? fontSize;
    Color? fontColor;

    // built-in font
    if (widget.payload.font == 'title') {
      fontWeight = FontWeight.w600;
      fontSize = 22;
      fontColor = EnsembleTheme.darkerText;
    } else if (widget.payload.font == 'subtitle') {
      fontWeight = FontWeight.w500;
      fontSize = 16;
      fontColor = EnsembleTheme.grey;
    }

    if (widget.payload.fontSize != null) {
      fontSize = widget.payload.fontSize!.toDouble();
    }
    if (widget.payload.fontWeight != null) {
      switch (widget.payload.fontWeight) {
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
    if (widget.payload.color != null) {
      fontColor = Color(widget.payload.color!);
    }

    TextOverflow? textOverflow;
    int? maxLine = 1;
    bool? softWrap = false;
    switch(widget.payload.overflow) {
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
    switch (widget.payload.textAlign) {
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
    switch (widget.payload.textStyle) {
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
    switch (widget.payload.lineHeight) {
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
      widget.payload.text ?? '',
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

    return Column(
      children: [
        rtn,
        TextFormField(
            onChanged: (newText) => widget.setProperty('text', newText)
        )
      ],
    );
    //return rtn;



  }


}