/// This class contains common widgets for use with Ensemble widgets.

import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/helpers/theme_manager.dart';
import 'package:flutter/cupertino.dart';

/// wraps around a widget and gives it common box attributes
class BoxWrapper extends StatelessWidget {
  const BoxWrapper({
    super.key,
    required this.widget,
    required this.boxController,

    // sometimes our widget may register a gesture. Such gesture should not
    // include the margin. This allows it to handle the margin on its own.
    this.ignoresMargin = false,

    // width/height maybe applied at the child, or not applicable
    this.ignoresDimension = false
  });
  final Widget widget;
  final BoxController boxController;

  // child widget may want to control these themselves
  final bool ignoresMargin;
  final bool ignoresDimension;

  @override
  Widget build(BuildContext context) {
    if (!boxController.requiresBox(ignoresMargin, ignoresDimension)) {
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
      padding: boxController.padding,
      clipBehavior: clip,
      child: widget,
      decoration: !boxController.hasBoxDecoration()
          ? null
          : BoxDecoration(
              color: boxController.backgroundColor,
              image: boxController.backgroundImage?.image,
              gradient: boxController.backgroundGradient,
              border: !boxController.hasBorder() 
              ? null 
              : boxController.borderGradient !=null
                  ? GradientBorder(
                    gradient: boxController.borderGradient,
                    width: boxController.borderWidth?.toDouble() ??
                          ThemeManager.getBorderThickness(context)
                  )
                  : Border.all(
                      color: boxController.borderColor ??
                          ThemeManager.getBorderColor(context),
                      width: boxController.borderWidth?.toDouble() ??
                          ThemeManager.getBorderThickness(context)),
              borderRadius: boxController.borderRadius?.getValue(),
              boxShadow: !boxController.hasBoxShadow()
                  ? null
                  : <BoxShadow>[
                      BoxShadow(
                        color: boxController.shadowColor ??
                            ThemeManager.getShadowColor(context),
                        blurRadius:
                            boxController.shadowRadius?.toDouble() ??
                                ThemeManager.getShadowRadius(context),
                        offset: boxController.shadowOffset ??
                            ThemeManager.getShadowOffset(context),
                        blurStyle: boxController.shadowStyle ??
                            ThemeManager.getShadowStyle(context))
                    ]));
  }

}


class GradientBorder extends BoxBorder {
  const GradientBorder({this.gradient, this.width});

  final Gradient? gradient;

  final double? width;

  @override
  BorderSide get bottom => BorderSide.none;

  @override
  BorderSide get top => BorderSide.none;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(width!);

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
    canvas.drawRect(rect.deflate(width! / 2), _getPaint(rect));
  }

  void _paintRRect(Canvas canvas, Rect rect, BorderRadius borderRadius) {
    final rrect = borderRadius.toRRect(rect).deflate(width! / 2);
    canvas.drawRRect(rrect, _getPaint(rect));
  }

  @override
  ShapeBorder scale(double t) {
    return this;
  }

  Paint _getPaint(Rect rect) {
    return Paint()
      ..strokeWidth = width!
      ..shader = gradient!.createShader(rect)
      ..style = PaintingStyle.stroke;
  }
}