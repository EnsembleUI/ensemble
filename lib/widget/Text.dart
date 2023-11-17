import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/view/has_selectable_text.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/framework/widget/widget.dart' as framework;
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble/widget/widget_util.dart' as util;
import 'package:flutter/foundation.dart';
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
    return {
      'text': () => _controller.text,
      'textStyle': () => _controller.textStyle
    };
  }

  @override
  Map<String, Function> setters() {
    return {
      'text': (newValue) => _controller.text = Utils.optionalString(newValue),
      'textAlign': (value) =>
          _controller.textAlign = TextAlign.values.from(value),
      'maxLines': (value) =>
          _controller.maxLines = Utils.optionalInt(value, min: 1),
      'textStyle': (style) => _controller.textStyle =
          Utils.getTextStyleAsComposite(_controller, style: style),
      'selectable': (value) =>
          _controller.selectable = Utils.optionalBool(value)
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
  bool? selectable;

  TextStyleComposite? _textStyle;

  TextStyleComposite get textStyle => _textStyle ??= TextStyleComposite(this);

  set textStyle(TextStyleComposite style) => _textStyle = style;
}

class EnsembleTextState extends framework.WidgetState<EnsembleText> {
  @override
  Widget buildWidget(BuildContext context) {
    return BoxWrapper(
      widget: buildText(widget.controller),
      boxController: widget.controller,
    );
  }

  Widget buildText(TextController controller) {
    final gradientStyle = controller.textStyle.gradient;

    bool shouldBeSelectable = controller.selectable == true ||
        (controller.selectable != false &&
            context.dependOnInheritedWidgetOfExactType<HasSelectableText>() !=
                null);

    Widget textWidget = shouldBeSelectable
        ? SelectableText(
            controller.text ?? '',
            textAlign: controller.textAlign,
            maxLines: controller.maxLines,
            style: controller.textStyle.getTextStyle(),
          )
        : Text(
            controller.text ?? '',
            textAlign: controller.textAlign,
            maxLines: controller.maxLines,
            style: controller.textStyle.getTextStyle(),
          );

    return gradientStyle != null
        ? _GradientText(gradient: gradientStyle, child: textWidget)
        : textWidget;
  }
}

class _GradientText extends StatelessWidget {
  const _GradientText({
    required this.gradient,
    required this.child,
  });

  final Gradient gradient;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(bounds),
      child: child,
    );
  }
}
