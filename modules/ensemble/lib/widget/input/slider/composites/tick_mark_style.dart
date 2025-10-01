import 'package:flutter/material.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';

abstract class TickMarkShape {
  const TickMarkShape();
  SliderTickMarkShape createShape(double offset, double trackHeight);
}

class CircleTickMarkShape extends TickMarkShape {
  final double? radius;

  const CircleTickMarkShape({this.radius});

  @override
  SliderTickMarkShape createShape(double offset, double trackHeight) {
    final defaultRadius = trackHeight / 2;
    return PositionedCircleSliderTickMarkShape(
      tickMarkRadius: radius ?? defaultRadius,
      verticalOffset: offset,
    );
  }
}

class rectangularTickMarkShape extends TickMarkShape {
  final double? width;
  final double? height;

  const rectangularTickMarkShape({this.width, this.height});

  @override
  SliderTickMarkShape createShape(double offset, double trackHeight) {
    return RectangularSliderTickMarkShape(
      width: width ?? trackHeight * 2,
      height: height ?? trackHeight,
      verticalOffset: offset,
    );
  }
}

class PositionedCircleSliderTickMarkShape extends SliderTickMarkShape {
  final double tickMarkRadius;
  final double verticalOffset;

  const PositionedCircleSliderTickMarkShape({
    required this.tickMarkRadius,
    this.verticalOffset = 0.0,
  });

  @override
  Size getPreferredSize({
    required SliderThemeData sliderTheme,
    required bool isEnabled,
  }) {
    return Size.fromRadius(tickMarkRadius);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    bool isEnabled = true,
  }) {
    final adjustedCenter = center.translate(0, verticalOffset);

    final Color? color = isEnabled
        ? (center.dx < thumbCenter.dx
            ? sliderTheme.activeTickMarkColor
            : sliderTheme.inactiveTickMarkColor)
        : (center.dx < thumbCenter.dx
            ? sliderTheme.disabledActiveTickMarkColor
            : sliderTheme.disabledInactiveTickMarkColor);

    if (color == null) return;

    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    context.canvas.drawCircle(adjustedCenter, tickMarkRadius, paint);
  }
}

class RectangularSliderTickMarkShape extends SliderTickMarkShape {
  final double width;
  final double height;
  final double verticalOffset;

  const RectangularSliderTickMarkShape({
    required this.width,
    required this.height,
    this.verticalOffset = 0.0,
  });

  @override
  Size getPreferredSize({
    required SliderThemeData sliderTheme,
    required bool isEnabled,
  }) {
    return Size(width, height);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    bool isEnabled = true,
  }) {
    final adjustedCenter = center.translate(0, verticalOffset);

    final Color? color = isEnabled
        ? (center.dx < thumbCenter.dx
            ? sliderTheme.activeTickMarkColor
            : sliderTheme.inactiveTickMarkColor)
        : (center.dx < thumbCenter.dx
            ? sliderTheme.disabledActiveTickMarkColor
            : sliderTheme.disabledInactiveTickMarkColor);

    if (color == null) return;

    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final Rect rect = Rect.fromCenter(
      center: adjustedCenter,
      width: width,
      height: height,
    );

    context.canvas.drawRect(rect, paint);
  }
}

class TickMarkStyleComposite extends WidgetCompositeProperty {
  TickMarkStyleComposite(ChangeNotifier widgetController)
      : super(widgetController);

  // Shape and position
  TickMarkShape? shape;
  double offset = 0.0;

  // Behavior
  bool showTicks = true;

  // Colors with defaults
  Color activeColor = Colors.white;
  Color inactiveColor = Colors.white.withValues(alpha: 0.5);
  Color disabledActiveColor = Colors.grey.shade400;
  Color disabledInactiveColor = Colors.grey.shade300;

  factory TickMarkStyleComposite.from(
      ChangeNotifier widgetController, dynamic payload) {
    TickMarkStyleComposite composite = TickMarkStyleComposite(widgetController);
    if (payload is Map) {
      if (payload['shape'] is Map) {
        var shapeConfig = payload['shape'];
        if (shapeConfig['circle'] is Map) {
          composite.shape = CircleTickMarkShape(
            radius: Utils.optionalDouble(shapeConfig['circle']['radius']),
          );
        } else if (shapeConfig['rectangular'] is Map) {
          composite.shape = rectangularTickMarkShape(
            width: Utils.optionalDouble(shapeConfig['rectangular']['width']),
            height: Utils.optionalDouble(shapeConfig['rectangular']['height']),
          );
        }
      }

      composite.offset = Utils.getDouble(payload['offset'], fallback: 0.0);
      composite.showTicks = Utils.getBool(payload['showTicks'], fallback: true);

      composite.activeColor =
          Utils.getColor(payload['activeColor']) ?? composite.activeColor;
      composite.inactiveColor =
          Utils.getColor(payload['inactiveColor']) ?? composite.inactiveColor;
      composite.disabledActiveColor =
          Utils.getColor(payload['disabledActiveColor']) ??
              composite.disabledActiveColor;
      composite.disabledInactiveColor =
          Utils.getColor(payload['disabledInactiveColor']) ??
              composite.disabledInactiveColor;
    }
    return composite;
  }

  @override
  Map<String, Function> setters() => {
        'shape': (value) {
          if (value is Map) {
            if (value['circle'] is Map) {
              shape = CircleTickMarkShape(
                radius: Utils.optionalDouble(value['circle']['radius']),
              );
            } else if (value['rectangular'] is Map) {
              shape = rectangularTickMarkShape(
                width: Utils.optionalDouble(value['rectangular']['width']),
                height: Utils.optionalDouble(value['rectangular']['height']),
              );
            }
          }
        },
        'offset': (value) => offset = Utils.getDouble(value, fallback: 0.0),
        'showTicks': (value) =>
            showTicks = Utils.getBool(value, fallback: true),
        'activeColor': (value) =>
            activeColor = Utils.getColor(value) ?? Colors.white,
        'inactiveColor': (value) => inactiveColor =
            Utils.getColor(value) ?? Colors.white.withValues(alpha: 0.5),
        'disabledActiveColor': (value) =>
            disabledActiveColor = Utils.getColor(value) ?? Colors.grey.shade400,
        'disabledInactiveColor': (value) => disabledInactiveColor =
            Utils.getColor(value) ?? Colors.grey.shade300,
      };

  @override
  Map<String, Function> getters() => {
        'shape': () => shape,
        'offset': () => offset,
        'showTicks': () => showTicks,
        'activeColor': () => activeColor,
        'inactiveColor': () => inactiveColor,
        'disabledActiveColor': () => disabledActiveColor,
        'disabledInactiveColor': () => disabledInactiveColor,
      };

  @override
  Map<String, Function> methods() => {};

   SliderTickMarkShape? getTickMarkShape(double trackHeight) {
    if (!showTicks) return null;
    return shape?.createShape(offset, trackHeight) ?? 
           CircleTickMarkShape().createShape(offset, trackHeight);
  }
}