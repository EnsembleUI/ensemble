import 'package:flutter/material.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';

class TrackStyleComposite extends WidgetCompositeProperty {
  TrackStyleComposite(ChangeNotifier widgetController)
      : super(widgetController);

  // Track Shape Properties
  String shape = 'rectangular'; // Default shape
  double? trackHeight;
  double? borderRadius;

  // Track Colors
  Color? activeTrackColor;
  Color? inactiveTrackColor;
  Color? secondaryActiveTrackColor;
  Color? disabledActiveTrackColor;
  Color? disabledInactiveTrackColor;
  Color? disabledSecondaryActiveTrackColor;

  factory TrackStyleComposite.from(
      ChangeNotifier widgetController, dynamic payload) {
    TrackStyleComposite composite = TrackStyleComposite(widgetController);
    if (payload is Map) {
      composite.shape =
          Utils.getString(payload['shape'], fallback: 'rectangular');
      composite.trackHeight = Utils.optionalDouble(payload['trackHeight']);
      composite.borderRadius = Utils.optionalDouble(payload['borderRadius']);

      composite.activeTrackColor = Utils.getColor(payload['activeColor']);
      composite.inactiveTrackColor = Utils.getColor(payload['inactiveColor']);
      composite.secondaryActiveTrackColor =
          Utils.getColor(payload['secondaryActiveColor']);
      composite.disabledActiveTrackColor =
          Utils.getColor(payload['disabledActiveColor']);
      composite.disabledInactiveTrackColor =
          Utils.getColor(payload['disabledInactiveColor']);
      composite.disabledSecondaryActiveTrackColor =
          Utils.getColor(payload['disabledSecondaryActiveColor']);
    }
    return composite;
  }

  @override
  Map<String, Function> setters() => {
        'shape': (value) =>
            shape = Utils.getString(value, fallback: 'rectangular'),
        'trackHeight': (value) => trackHeight = Utils.optionalDouble(value),
        'borderRadius': (value) => borderRadius = Utils.optionalDouble(value),
        'activeColor': (value) => activeTrackColor = Utils.getColor(value),
        'inactiveColor': (value) => inactiveTrackColor = Utils.getColor(value),
        'secondaryActiveColor': (value) =>
            secondaryActiveTrackColor = Utils.getColor(value),
        'disabledActiveColor': (value) =>
            disabledActiveTrackColor = Utils.getColor(value),
        'disabledInactiveColor': (value) =>
            disabledInactiveTrackColor = Utils.getColor(value),
        'disabledSecondaryActiveColor': (value) =>
            disabledSecondaryActiveTrackColor = Utils.getColor(value),
      };

  @override
  Map<String, Function> getters() => {
        'shape': () => shape,
        'trackHeight': () => trackHeight,
        'borderRadius': () => borderRadius,
        'activeColor': () => activeTrackColor,
        'inactiveColor': () => inactiveTrackColor,
        'secondaryActiveColor': () => secondaryActiveTrackColor,
        'disabledActiveColor': () => disabledActiveTrackColor,
        'disabledInactiveColor': () => disabledInactiveTrackColor,
        'disabledSecondaryActiveColor': () => disabledSecondaryActiveTrackColor,
      };

  @override
  Map<String, Function> methods() => {};

  SliderTrackShape getTrackShape() {
    switch (shape) {
      case 'rectangular':
        return RectangularSliderTrackShape();
      case 'circle':
        return RoundedRectSliderTrackShape();
      default:
        return RectangularSliderTrackShape();
    }
  }

  RangeSliderTrackShape getRangeTrackShape() {
    switch (shape) {
      case 'rectangular':
        return RectangularRangeSliderTrackShape();
      case 'circle':
        return RoundedRectRangeSliderTrackShape();
      default:
        return RectangularRangeSliderTrackShape();
    }
  }
}
