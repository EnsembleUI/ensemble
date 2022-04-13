
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/widgets.dart';
import 'package:flutter/material.dart';

class EnsembleText extends StatefulWidget with UpdatableWidget<TextController> {
  static const type = 'EnsembleText';
  EnsembleText({Key? key}) : super(key: key);

  final TextController _controller = TextController();
  @override
  TextController get payload => _controller;


  @override
  TextState createState() => TextState();


  @override
  Map<String, Function> getters() {
    return {
      'text': () => _controller.text
    };
  }

  @override
  Map<String, Function> setters() {
    return {
      'text': (newValue) => _controller.text = newValue?.toString(),
      'fontSize': (newFontSize) => _controller.fontSize = Utils.optionalInt(newFontSize)
    };
  }


}

class TextController extends Payload {
  String? text;
  int? fontSize;
}

class TextState extends EnsembleWidgetState<EnsembleText> {
  @override
  Widget build(BuildContext context) {
    Widget rtn = Text(
      widget.payload.text ?? '',
      style: TextStyle(
        fontSize: widget.payload.fontSize?.toDouble()
      ),
    );

    return Column(
      children: [
        rtn,
        TextFormField(
          onChanged: (newText) => widget.setProperty('text', newText),
        )
      ],
    );



  }


}