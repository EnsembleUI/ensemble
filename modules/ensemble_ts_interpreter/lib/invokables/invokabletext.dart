import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';

class InvokableText extends StatefulWidget with Invokable, HasController<TextController, InvokableTextWidgetState> {
  @override
  final TextController controller;
  InvokableText(this.controller, {Key? key}) : super(key:key);

  @override
  State<StatefulWidget> createState() => InvokableTextWidgetState();

  void toUppercase() {
    setters()['text']!(getters()['text']!().toString().toUpperCase());
  }
  int random(int seed,int max) {
    return Random(seed).nextInt(max);
  }

  @override
  Map<String, Function> getters() {
    return {
      'text': () => controller.text
    };
  }

  @override
  Map<String, Function> setters() {
    return {
      'text': (newValue) => controller.text = newValue,
    };
  }

  @override
  Map<String, Function> methods() {
    return {
      'random': (int seed,int max) { return random(seed,max);},
      'toUpperCase': () => toUppercase(),
      'indexOf': (String str) { return controller.text.indexOf(str);}
    };
  }


}

class TextController extends Controller {
  String text;
  TextController(this.text);
}

class InvokableTextWidgetState extends BaseWidgetState<InvokableText> {
  @override
  Widget build(BuildContext context) {
    return Text(widget.controller.text);
  }
}
