import 'package:ensemble/framework/action.dart' as ensemble;
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/view/has_selectable_text.dart';
import 'package:ensemble/model/text_scale.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/framework/widget/widget.dart' as framework;
import 'package:ensemble/widget/helpers/ColorFilter_Composite.dart';
import 'package:ensemble/widget/helpers/box_wrapper.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble/widget/text/expandable_text.dart';
import 'package:ensemble/widget/text/span_definition.dart';
import 'package:ensemble/widget/widget_util.dart' as util;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter_html/flutter_html.dart';
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
      'colorFilter': () => _controller.colorFilter,
      'spans': () => _controller.spans,
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
      'colorFilter': (value) =>
        _controller.colorFilter = ColorFilterComposite.from( value),
      'spans': (value) => _controller.spans = value,
    };
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  /// spans contains nested YAML (widget definitions, action definitions) that
  /// must not be evaluated by the framework's auto-binding. We handle
  /// expression evaluation and widget building ourselves in State.
  @override
  List<String> passthroughSetters() => ['spans'];

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

  ColorFilterComposite? colorFilter;

  /// Raw YAML spans list. Stored as-is from the setter (passthrough) and
  /// parsed into SpanDefinition objects at render time in EnsembleTextState,
  /// where scopeManager is available for building widget spans.
  dynamic spans;

  TextStyleComposite get textStyle => _textStyle ??= TextStyleComposite(this);

  set textStyle(TextStyleComposite style) => _textStyle = style;
}

class EnsembleTextState extends framework.EWidgetState<EnsembleText> {
  List<TapGestureRecognizer> _tapRecognizers = [];

  @override
  void dispose() {
    _disposeTapRecognizers();
    super.dispose();
  }

  void _disposeTapRecognizers() {
    for (final recognizer in _tapRecognizers) {
      recognizer.dispose();
    }
    _tapRecognizers = [];
  }

  @override
  Widget buildWidget(BuildContext context) {
    return BoxWrapper(
      widget: buildText(widget.controller),
      boxController: widget.controller,
    );
  }

  Widget buildText(TextController controller) {
    final gradientStyle = controller.textStyle.gradient;
    final colorFilter = controller.colorFilter;

    // Spans path: when spans is provided, use rich text rendering
    if (controller.spans != null) {
      Widget textWidget = _buildSpansWidget(controller);
      if (colorFilter?.color != null) {
        textWidget = ColorFiltered(
          colorFilter: colorFilter!.getColorFilter()!,
          child: textWidget,
        );
      }
      return gradientStyle != null
          ? _GradientText(gradient: gradientStyle, child: textWidget)
          : textWidget;
    }

    // Existing plain text path (unchanged)
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
    if (colorFilter?.color != null) {
        textWidget = ColorFiltered(
          colorFilter: colorFilter!.getColorFilter()!,
          child: textWidget,
        );
    }
    return gradientStyle != null
        ? _GradientText(gradient: gradientStyle, child: textWidget)
        : textWidget;
  }

  Widget _buildSpansWidget(TextController controller) {
    _disposeTapRecognizers();

    final spans = SpanDefinition.parseAll(controller.spans);
    final bool hasWidgetSpans = spans.any((s) => s.isWidgetSpan);
    final defaultStyle = controller.textStyle.getTextStyle();

    List<InlineSpan> inlineSpans = [];
    for (final spanDef in spans) {
      if (spanDef.isTextSpan) {
        inlineSpans.add(_buildTextSpan(spanDef, defaultStyle));
      } else if (spanDef.isWidgetSpan) {
        final widgetSpan = _buildWidgetSpan(spanDef);
        if (widgetSpan != null) {
          inlineSpans.add(widgetSpan);
        }
      }
    }

    // SelectableText.rich doesn't support WidgetSpan;
    // fall back to Text.rich when WidgetSpans are present
    bool shouldBeSelectable = !hasWidgetSpans &&
        (controller.selectable == true ||
            (controller.selectable != false &&
                context.dependOnInheritedWidgetOfExactType<
                        HasSelectableText>() !=
                    null));

    if (shouldBeSelectable) {
      return SelectableText.rich(
        TextSpan(
          style: defaultStyle,
          children: inlineSpans.cast<TextSpan>(),
        ),
        textAlign: controller.textAlign,
        maxLines: controller.maxLines,
        textScaler: _getTextScaler(),
      );
    }

    return Text.rich(
      TextSpan(
        style: defaultStyle,
        children: inlineSpans,
      ),
      textAlign: controller.textAlign,
      maxLines: controller.maxLines,
      overflow: controller.textStyle.overflow ?? TextOverflow.clip,
      textScaler: _getTextScaler(),
    );
  }

  TextSpan _buildTextSpan(SpanDefinition spanDef, TextStyle defaultStyle) {
    // Evaluate text expressions (e.g., "${variable}")
    String? text = spanDef.text;
    if (text != null && scopeManager != null) {
      try {
        final evaluated = scopeManager!.dataContext.eval(text);
        if (evaluated != null) {
          text = evaluated.toString();
        }
      } catch (e) {
        // Keep original text if expression evaluation fails
        debugPrint('Text span expression eval failed for "$text": $e');
      }
    }

    // Build per-span style override
    TextStyle? spanStyle;
    if (spanDef.textStyle != null) {
      spanStyle = Utils.getTextStyle(spanDef.textStyle);
    }

    // Build tap recognizer if onTap is defined
    TapGestureRecognizer? recognizer;
    if (spanDef.onTap != null) {
      final action =
          ensemble.EnsembleAction.from(spanDef.onTap, initiator: widget);
      if (action != null) {
        recognizer = TapGestureRecognizer()
          ..onTap = () {
            ScreenController().executeAction(
              context,
              action,
              event: EnsembleEvent(widget),
            );
          };
        _tapRecognizers.add(recognizer);
      }
    }

    return TextSpan(
      text: text ?? '',
      style: spanStyle,
      recognizer: recognizer,
    );
  }

  WidgetSpan? _buildWidgetSpan(SpanDefinition spanDef) {
    if (scopeManager == null) return null;
    try {
      final childWidget =
          scopeManager!.buildWidgetFromDefinition(spanDef.widgetDefinition);
      return WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: childWidget,
      );
    } catch (e) {
      debugPrint('Failed to build widget span: $e');
      return null;
    }
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
