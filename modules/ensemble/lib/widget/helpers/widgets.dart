/// This class contains common widgets for use with Ensemble widgets.
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:flutter/material.dart';

/// Display a Text content followed by a clear icon.
/// Clicking the icon will invoke the callback.
/// Note that this is a StatelessWidget, so clearing out the value
/// is the responsibility of the parent widget who uses this.
class ClearableInput extends StatelessWidget {
  const ClearableInput(
      {super.key,
      required this.text,
      required this.onCleared,
      this.textStyle,
      this.enabled = false});

  final String text;
  final TextStyle? textStyle;
  final bool enabled;
  final void Function()? onCleared;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Flexible(child: Text(text, maxLines: 1, style: textStyle)),
      const SizedBox(width: 4),
      InkWell(
        onTap: enabled ? onCleared : null,
        child: const Icon(Icons.close, size: 20),
      )
    ]);
  }
}

mixin GradientBorder {
  BorderSide get bottom => BorderSide.none;

  BorderSide get top => BorderSide.none;

  bool get isUniform => true;

  void paintRect(
      Canvas canvas, Rect rect, LinearGradient gradient, double width) {
    canvas.drawRect(rect.deflate(width / 2), _getPaint(rect, gradient, width));
  }

  void paintRRect(Canvas canvas, Rect rect, BorderRadius borderRadius,
      LinearGradient gradient, double width) {
    final rrect = borderRadius.toRRect(rect).deflate(width / 2);
    canvas.drawRRect(rrect, _getPaint(rect, gradient, width));
  }

  Paint _getPaint(Rect rect, LinearGradient gradient, double width) {
    return Paint()
      ..strokeWidth = width
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke;
  }
}

class GradientBoxBorder extends BoxBorder with GradientBorder {
  const GradientBoxBorder({required this.gradient, required this.width});

  final LinearGradient gradient;
  final double width;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(width);

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    TextDirection? textDirection,
    BoxShape shape = BoxShape.rectangle,
    BorderRadius? borderRadius,
  }) {
    if (borderRadius != null) {
      paintRRect(canvas, rect, borderRadius, gradient, width);
      return;
    }
    paintRect(canvas, rect, gradient, width);
  }

  @override
  ShapeBorder scale(double t) {
    return this;
  }
}

/// Draws dashed or dotted borders for container box styles.
class DashedBoxBorder extends BoxBorder {
  const DashedBoxBorder({
    required this.color,
    required this.width,
    required this.style,
    this.dashLength = BorderStyleComposite.defaultLength,
    this.gap = BorderStyleComposite.defaultGap,
  });

  final Color color;
  final double width;
  final BoxBorderStyle style;
  final double dashLength;
  final double gap;

  @override
  BorderSide get bottom => BorderSide.none;

  @override
  BorderSide get top => BorderSide.none;

  @override
  bool get isUniform => true;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(width);

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    TextDirection? textDirection,
    BoxShape shape = BoxShape.rectangle,
    BorderRadius? borderRadius,
  }) {
    final path = Path();
    if (borderRadius != null) {
      path.addRRect(borderRadius.toRRect(rect).deflate(width / 2));
    } else {
      path.addRect(rect.deflate(width / 2));
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..strokeCap =
          style == BoxBorderStyle.dotted ? StrokeCap.round : StrokeCap.butt;

    final dash =
        style == BoxBorderStyle.dotted ? width : dashLength;
    final gapLength = style == BoxBorderStyle.dotted
        ? (gap < width ? width : gap)
        : gap;

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final segment = draw ? dash : gapLength;
        final next = distance + segment;
        if (draw) {
          canvas.drawPath(
              metric.extractPath(distance, next.clamp(0, metric.length)),
              paint);
        }
        distance = next;
        draw = !draw;
      }
    }
  }

  @override
  ShapeBorder scale(double t) {
    return DashedBoxBorder(
      color: color,
      width: width * t,
      style: style,
      dashLength: dashLength * t,
      gap: gap * t,
    );
  }
}

/// a wrapper around a widget and enable Tap action.
class TapOverlay extends StatelessWidget {
  const TapOverlay({super.key, required this.widget, required this.onTap});

  final Widget widget;
  final TapOverlayFunc onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(children: <Widget>[
      widget,
      Positioned.fill(
          child:
              Material(color: Colors.transparent, child: InkWell(onTap: onTap)))
    ]);
  }
}

typedef TapOverlayFunc = void Function();
