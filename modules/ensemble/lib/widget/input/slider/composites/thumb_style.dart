import 'package:flutter/material.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';

class CustomCircleSliderThumbShape extends SliderComponentShape {
  final double enabledThumbRadius;
  final double elevation;
  final double pressedElevation;
  final double borderWidth;
  final Color? borderColor;

  const CustomCircleSliderThumbShape({
    this.enabledThumbRadius = 10.0,
    this.elevation = 1.0,
    this.pressedElevation = 2.0,
    this.borderWidth = 0.0,
    this.borderColor,
  });

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size.fromRadius(enabledThumbRadius);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;

    if (elevation > 0) {
      final Path shadowPath = Path()
        ..addOval(Rect.fromCircle(center: center, radius: enabledThumbRadius));
      canvas.drawShadow(shadowPath, Colors.black, elevation, true);
    }

    final Paint fillPaint = Paint()
      ..color = sliderTheme.thumbColor!
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, enabledThumbRadius, fillPaint);

    if (borderWidth > 0 && borderColor != null) {
      final Paint borderPaint = Paint()
        ..color = borderColor!
        ..strokeWidth = borderWidth
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(center, enabledThumbRadius, borderPaint);
    }
  }
}

class ThumbStyleComposite extends WidgetCompositeProperty {
  ThumbStyleComposite(ChangeNotifier widgetController)
      : super(widgetController);

  double radius = 10.0;
  double elevation = 1.0;
  double pressedElevation = 2.0;
  Color? thumbColor;
  Color? disabledThumbColor;
  double borderWidth = 0.0;
  Color? borderColor;

  factory ThumbStyleComposite.from(
      ChangeNotifier widgetController, dynamic payload) {
    ThumbStyleComposite composite = ThumbStyleComposite(widgetController);
    if (payload is Map) {
      composite.radius = Utils.getDouble(payload['radius'], fallback: 10.0);
      composite.elevation =
          Utils.getDouble(payload['elevation'], fallback: 1.0);
      composite.pressedElevation =
          Utils.getDouble(payload['pressedElevation'], fallback: 2.0);
      composite.thumbColor =
          Utils.getColor(payload['thumbColor']);
      composite.disabledThumbColor =
          Utils.getColor(payload['disabledThumbColor']);
      composite.borderWidth =
          Utils.getDouble(payload['borderWidth'], fallback: 0.0);
      composite.borderColor = Utils.getColor(payload['borderColor']);
    }
    return composite;
  }

  @override
  Map<String, Function> setters() => {
        'radius': (value) =>
            radius = Utils.getDouble(value, fallback: 10.0),
        'elevation': (value) =>
            elevation = Utils.getDouble(value, fallback: 1.0),
        'pressedElevation': (value) =>
            pressedElevation = Utils.getDouble(value, fallback: 2.0),
        'thumbColor': (value) =>
            thumbColor = Utils.getColor(value),
        'disabledThumbColor': (value) =>
            disabledThumbColor = Utils.getColor(value),
        'borderWidth': (value) =>
            borderWidth = Utils.getDouble(value, fallback: 0.0),
        'borderColor': (value) => borderColor = Utils.getColor(value),
      };

  @override
  Map<String, Function> getters() => {
        'radius': () => radius,
        'elevation': () => elevation,
        'pressedElevation': () => pressedElevation,
        'thumbColor': () => thumbColor,
        'disabledThumbColor': () => disabledThumbColor,
        'borderWidth': () => borderWidth,
        'borderColor': () => borderColor,
      };

  @override
  Map<String, Function> methods() => {};

  SliderComponentShape getThumbShape() {
    return CustomCircleSliderThumbShape(
      enabledThumbRadius: radius,
      elevation: elevation,
      pressedElevation: pressedElevation,
      borderWidth: borderWidth,
      borderColor: borderColor,
    );
  }
}