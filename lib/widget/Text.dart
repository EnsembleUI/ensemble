import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/framework/widget/widget.dart' as framework;
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble/widget/widget_util.dart' as util;
import 'package:flutter/material.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:google_fonts/google_fonts.dart';

class EnsembleText extends StatefulWidget
    with Invokable, HasController<TextController, EnsembleTextState> {
  static const type = 'Text';
  EnsembleText({Key? key}) : super(key: key);

  final TextController _controller = TextController();
  @override
  TextController get controller => _controller;

  @override
  Map<String, Function> getters() {
    return {'text': () => _controller.text};
  }

  @override
  Map<String, Function> setters() {
    return {
      'text': (newValue) => _controller.text = Utils.optionalString(newValue),
      'textAlign': (value) =>
          _controller.textAlign = TextAlign.values.from(value),
      'maxLines': (value) =>
          _controller.maxLines = Utils.optionalInt(value, min: 1),
      'textStyle': (style) =>
          _controller.textStyle = Utils.getTextStyleAsComposite(_controller, style: style),
    };
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  EnsembleTextState createState() => EnsembleTextState();
}

class TextController extends BoxController {
  String? text;
  TextAlign? textAlign;
  int? maxLines;

  TextStyleComposite? _textStyle;
  TextStyleComposite get textStyle => _textStyle ??= TextStyleComposite(this);
  set textStyle(TextStyleComposite style) => _textStyle = style;
}

class EnsembleTextState extends framework.WidgetState<EnsembleText> {
  @override
  Widget buildWidget(BuildContext context) {
    return BoxWrapper(
        widget: buildText(widget.controller), boxController: widget.controller);
  }

  Text buildText(TextController controller) {
    return Text(controller.text ?? '',
        textAlign: controller.textAlign,
        maxLines: controller.maxLines,
        style: controller.textStyle?.getTextStyle());
  }
}
