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
      'textStyle': (style) => _controller.textStyle = Utils.getTextStyle(style),

      // legacy
      'fontFamily': (value) =>
          _controller.fontFamily = Utils.optionalString(value),
      'fontSize': (value) => _controller.fontSize = Utils.optionalInt(value),
      'fontWeight': (value) =>
          _controller.fontWeight = Utils.getFontWeight(value),
      'color': (value) => _controller.color = Utils.getColor(value),
      'gradient': (value) =>
          _controller.gradient = Utils.getBackgroundGradient(value),
      'overflow': (value) =>
          _controller.overflow = TextOverflow.values.from(value),
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
  TextStyle? textStyle;

  // legacy, for backward compatible
  String? fontFamily;
  int? fontSize;
  FontWeight? fontWeight;
  Color? color;
  LinearGradient? gradient;
  TextOverflow? overflow;
}

class EnsembleTextState extends framework.WidgetState<EnsembleText> {
  @override
  Widget buildWidget(BuildContext context) {
    return BoxWrapper(
        widget: buildText(widget.controller), boxController: widget.controller);
  }

  Widget buildText(TextController controller) {
    var textStyle = const TextStyle();

    // also fallback to legacy
    var fontFamily = controller.textStyle?.fontFamily ?? controller.fontFamily;
    var fontSize =
        (controller.textStyle?.fontSize ?? controller.fontSize)?.toDouble();
    var fontWeight = controller.textStyle?.fontWeight ?? controller.fontWeight;
    var color = controller.textStyle?.color ?? controller.color;
    var overflow = controller.textStyle?.overflow ?? controller.overflow;

    if (fontFamily != null) {
      try {
        textStyle = GoogleFonts.getFont(fontFamily.trim(), color: Colors.black);
      } catch (_) {
        textStyle.copyWith(fontFamily: fontFamily.trim());
      }
    }

    Widget rtn = Text(controller.text ?? '',
        textAlign: controller.textAlign,
        maxLines: controller.maxLines,
        style: textStyle.copyWith(
            fontSize: fontSize,
            height: controller.textStyle?.height,
            fontWeight: fontWeight,
            fontStyle: controller.textStyle?.fontStyle,
            color: controller.gradient == null ? color : null,
            backgroundColor: controller.textStyle?.backgroundColor,
            decoration: controller.textStyle?.decoration,
            decorationStyle: controller.textStyle?.decorationStyle,
            overflow: overflow,
            letterSpacing: controller.textStyle?.letterSpacing,
            wordSpacing: controller.textStyle?.wordSpacing));

    if (controller.gradient != null) {
      return _GradientText(
        gradient: controller.gradient!,
        child: rtn,
      );
    }

    return rtn;
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
