import 'package:flutter/material.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';

class OverlayStyleComposite extends WidgetCompositeProperty {
  OverlayStyleComposite(ChangeNotifier widgetController)
      : super(widgetController);

  double radius = 24.0;
  Color? color;
  double opacity = 0.12;

  factory OverlayStyleComposite.from(
      ChangeNotifier widgetController, dynamic payload) {
    OverlayStyleComposite composite = OverlayStyleComposite(widgetController);
    if (payload is Map) {
      composite.radius = Utils.getDouble(payload['radius'], fallback: 24.0);
      composite.color = Utils.getColor(payload['color']);
      composite.opacity = Utils.getDouble(payload['opacity'], fallback: 0.12);
    }
    return composite;
  }

  @override
  Map<String, Function> setters() => {
        'radius': (value) => radius = Utils.getDouble(value, fallback: 24.0),
        'color': (value) => color = Utils.getColor(value),
        'opacity': (value) => opacity = Utils.getDouble(value, fallback: 0.12),
      };

  @override
  Map<String, Function> getters() => {
        'radius': () => radius,
        'color': () => color,
        'opacity': () => opacity,
      };

  @override
  Map<String, Function> methods() => {};

  SliderComponentShape getOverlayShape() {
    return RoundSliderOverlayShape(
      overlayRadius: radius,
    );
  }

  Color? getOverlayColor() {
    if (color == null) return null;
    return color!.withValues(alpha: opacity);
  }
}