/// This class contains common widgets for use with Ensemble widgets.

import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/widget/input/form_helper.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/framework/theme/theme_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// wraps around a widget and gives it common box attributes
class BoxWrapper extends StatelessWidget {
  const BoxWrapper(
      {super.key,
      required this.widget,
      required this.boxController,

      // internal widget may want to handle padding itself (e.g. ListView so
      // its scrollbar lays on top of the padding and not the content)
      this.ignoresPadding = false,

      // sometimes our widget may register a gesture. Such gesture should not
      // include the margin. This allows it to handle the margin on its own.
      this.ignoresMargin = false,

      // width/height maybe applied at the child, or not applicable
      this.ignoresDimension = false});
  final Widget widget;
  final BoxController boxController;

  // child widget may want to control these themselves
  final bool ignoresPadding;
  final bool ignoresMargin;
  final bool ignoresDimension;

  @override
  Widget build(BuildContext context) {
    if (!boxController.requiresBox(
        ignoresMargin: ignoresMargin,
        ignoresPadding: ignoresPadding,
        ignoresDimension: ignoresDimension)) {
      return widget;
    }
    // when we have a border radius, we may need to clip the child (e.g. image)
    // so it doesn't bleed through the border. This really only applies for
    // the actual child widget, as the backgroundColor/backgroundImage will already
    // be clipped properly. For simplicity just apply it and take a small
    // performance hit.
    Clip clip = Clip.none;
    if (boxController.borderRadius != null &&
        boxController.hasBoxDecoration()) {
      clip = Clip.hardEdge;
    }

    return Container(
        width: ignoresDimension ? null : boxController.width?.toDouble(),
        height: ignoresDimension ? null : boxController.height?.toDouble(),
        margin: ignoresMargin ? null : boxController.margin,
        padding: ignoresPadding ? null : boxController.padding,
        clipBehavior: clip,
        child: widget,
        decoration: !boxController.hasBoxDecoration()
            ? null
            : BoxDecoration(
                color: boxController.backgroundColor,
                image: boxController.backgroundImage?.asDecorationImage,
                gradient: boxController.backgroundGradient,
                border: !boxController.hasBorder()
                    ? null
                    : boxController.borderGradient != null
                        ? GradientBorder(
                            gradient: boxController.borderGradient!,
                            width: boxController.borderWidth?.toDouble() ??
                                ThemeManager().getBorderThickness(context))
                        : Border.all(
                            color: boxController.borderColor ??
                                ThemeManager().getBorderColor(context),
                            width: boxController.borderWidth?.toDouble() ??
                                ThemeManager().getBorderThickness(context)),
                borderRadius: boxController.borderRadius?.getValue(),
                boxShadow: !boxController.hasBoxShadow()
                    ? null
                    : <BoxShadow>[
                        BoxShadow(
                            color: boxController.shadowColor ??
                                ThemeManager().getShadowColor(context),
                            blurRadius:
                                boxController.shadowRadius?.toDouble() ??
                                    ThemeManager().getShadowRadius(context),
                            offset: boxController.shadowOffset ??
                                ThemeManager().getShadowOffset(context),
                            blurStyle: boxController.shadowStyle ??
                                ThemeManager().getShadowStyle(context))
                      ]));
  }
}

/// wrap the input widget (which stretches 100% to its parent) to guard against
/// the case where it is put inside a Row without expanded flag.
class InputWrapper extends StatelessWidget {
  const InputWrapper(
      {super.key,
      required this.type,
      required this.widget,
      required this.controller});
  final String type;
  final Widget widget;
  final FormFieldController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // inside a e.g. Row but not wrapping inside Expanded.
      // This is the error condition we need to advise the user
      if (!constraints.hasBoundedWidth && !controller.expanded) {
        // throw Error when input widgets (which stretch to their parent) are
        // inside a Row (which allow its child to have as much space as it wants)
        // without using expanded flag.
        throw LanguageError(
            "${type} widget requires a width when used inside a parent like Row.",
            recovery:
                "Consider using 'expanded: true' on the ${type} to fill the parent's available width.");
      }

      return controller.maxWidth == null
          ? widget
          : ConstrainedBox(
              constraints:
                  BoxConstraints(maxWidth: controller.maxWidth!.toDouble()),
              child: widget);
    });
  }
}

/// Display a Text content followed by a clear icon.
/// Clicking the icon will invoke the callback.
/// Note that this is a StatelessWidget, so clearing out the value
/// is the responsibility of the parent widget who uses this.
class ClearableInput extends StatelessWidget {
  const ClearableInput(
      {super.key, required this.text, required this.onCleared, this.textStyle});
  final String text;
  final TextStyle? textStyle;
  final dynamic onCleared;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Flexible(child: Text(text, maxLines: 1, style: textStyle)),
      const SizedBox(width: 4),
      InkWell(onTap: onCleared, child: const Icon(Icons.close, size: 20))
    ]);
  }
}

class GradientBorder extends BoxBorder {
  const GradientBorder({required this.gradient, required this.width});

  final LinearGradient gradient;

  final double width;

  @override
  BorderSide get bottom => BorderSide.none;

  @override
  BorderSide get top => BorderSide.none;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(width);

  @override
  bool get isUniform => true;

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    TextDirection? textDirection,
    BoxShape shape = BoxShape.rectangle,
    BorderRadius? borderRadius,
  }) {
    if (borderRadius != null) {
      _paintRRect(canvas, rect, borderRadius);
      return;
    }
    _paintRect(canvas, rect);
  }

  void _paintRect(Canvas canvas, Rect rect) {
    canvas.drawRect(rect.deflate(width / 2), _getPaint(rect));
  }

  void _paintRRect(Canvas canvas, Rect rect, BorderRadius borderRadius) {
    final rrect = borderRadius.toRRect(rect).deflate(width / 2);
    canvas.drawRRect(rrect, _getPaint(rect));
  }

  @override
  ShapeBorder scale(double t) {
    return this;
  }

  Paint _getPaint(Rect rect) {
    return Paint()
      ..strokeWidth = width
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke;
  }
}
