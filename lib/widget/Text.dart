import 'package:ensemble/util/utils.dart';
import 'package:ensemble/framework/widget/widget.dart' as framework;
import 'package:ensemble/widget/widget_util.dart';
import 'package:ensemble/widget/widget_util.dart' as util;
import 'package:flutter/material.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';

class Text extends StatefulWidget
    with Invokable, HasController<TextController, TextState> {
  static const type = 'Text';

  Text({Key? key}) : super(key: key);

  final TextController _controller = TextController();

  @override
  TextController get controller => _controller;

  @override
  Map<String, Function> getters() {
    return {'text': () => _controller.text};
  }

  @override
  Map<String, Function> setters() {
    Map<String, Function> setters = TextUtils.styleSetters(_controller);
    setters.addAll({
      'text': (newValue) => _controller.text = Utils.optionalString(newValue),
      'overflow': (value) => _controller.overflow = Utils.optionalString(value),
      'textAlign': (value) =>
          _controller.textAlign = Utils.optionalString(value),
    });
    return setters;
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  TextState createState() => TextState();
}

class TextState extends framework.WidgetState<Text> {
  @override
  Widget buildWidget(BuildContext context) {
    return util.TextUtils.buildText(widget.controller);
  }
}
