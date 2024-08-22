import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/view/has_selectable_text.dart';
import 'package:ensemble/model/text_scale.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/framework/widget/widget.dart' as framework;
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble/widget/text/expandable_text.dart';
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
      'text': () => _controller.text ?? '',
      'textAlign': () => _controller.textAlign,
      'textStyle': () => _controller.textStyle,
      'selectable': () => _controller.selectable,
      'maxLines': () => _controller.maxLines,
      'expandable': () => _controller.expandable,
      'expandLabel': () => _controller.expandLabel,
      'collapseLabel': () => _controller.collapseLabel,
      'expandTextStyle': () => _controller.expandTextStyle,
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
          _controller.selectable = Utils.optionalBool(value),
      'textScale': (value) => _controller.textScale = TextScale.from(value),
      'expandable': (value) =>
          _controller.expandable = Utils.optionalBool(value),
      'expandLabel': (value) =>
          _controller.expandLabel = Utils.optionalString(value),
      'collapseLabel': (value) =>
          _controller.collapseLabel = Utils.optionalString(value),
      'expandTextStyle': (style) => _controller.expandTextStyle =
          Utils.getTextStyleAsComposite(_controller, style: style),
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
  TextScale? textScale;
  bool? expandable;
  String? expandLabel, collapseLabel;
  TextStyleComposite? expandTextStyle;
  TextStyleComposite? _textStyle;

  TextStyleComposite get textStyle => _textStyle ??= TextStyleComposite(this);

  set textStyle(TextStyleComposite style) => _textStyle = style;
}

class EnsembleTextState extends framework.EWidgetState<EnsembleText> {
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
    Widget textWidget;
    if (controller.expandable == true) {
      textWidget = ExpandableText(
        text: controller.text ?? '',
        maxLines: controller.maxLines ?? 3,
        textAlign: controller.textAlign,
        style: controller.textStyle.getTextStyle(),
        textScaler: _getTextScaler(),
        selectable: shouldBeSelectable,
        textOverflow: controller.textStyle.overflow,
        expandLabel: controller.expandLabel ?? '...show more',
        collapseLabel: controller.collapseLabel ?? ' show less',
        expandTextStyle: controller.expandTextStyle != null
            ? controller.expandTextStyle?.getTextStyle()
            : null,
      );
    } else {
      textWidget = shouldBeSelectable
          ? SelectableText(controller.text ?? '',
              textAlign: controller.textAlign,
              maxLines: controller.maxLines,
              style: controller.textStyle.getTextStyle(),
              textScaler: _getTextScaler())
          : Text(controller.text ?? '',
              textAlign: controller.textAlign,
              maxLines: controller.maxLines,
              style: controller.textStyle.getTextStyle(),
              textScaler: _getTextScaler());
    }

    return gradientStyle != null
        ? _GradientText(gradient: gradientStyle, child: textWidget)
        : textWidget;
  }

  TextScaler? _getTextScaler() {
    if (widget.controller.textScale?.enabled == false) {
      return TextScaler.noScaling;
    } else if (widget.controller.textScale?.minFactor != null ||
        widget.controller.textScale?.maxFactor != null) {
      return MediaQuery.of(context).textScaler.clamp(
          minScaleFactor: widget.controller.textScale?.minFactor ?? 0,
          maxScaleFactor:
              widget.controller.textScale?.maxFactor ?? double.infinity);
    }
    return null;
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
