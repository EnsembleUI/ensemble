import 'package:ensemble/framework/extensions.dart';
import 'package:flutter/material.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';

class ValueIndicatorStyleComposite extends WidgetCompositeProperty {
  ValueIndicatorStyleComposite(ChangeNotifier widgetController)
      : super(widgetController);

  ShowValueIndicator visibility = ShowValueIndicator.onlyForDiscrete;
  ValueIndicatorShape shape = ValueIndicatorShape.drop;
  Color? color;
  TextStyle? textStyle;

  factory ValueIndicatorStyleComposite.from(
      ChangeNotifier widgetController, dynamic payload) {
    ValueIndicatorStyleComposite composite =
        ValueIndicatorStyleComposite(widgetController);
    if (payload is Map) {
      composite.visibility =
          ShowValueIndicator.values.from(payload['visibility']) ??
              ShowValueIndicator.onlyForDiscrete;

      composite.shape = ValueIndicatorShape.values.from(payload['shape']) ??
          ValueIndicatorShape.drop;

      composite.color = Utils.getColor(payload['color']);
      composite.textStyle = Utils.getTextStyle(payload['textStyle']);
    }
    return composite;
  }

  @override
  Map<String, Function> setters() => {
        'visibility': (value) => visibility =
            ShowValueIndicator.values.from(value) ??
                ShowValueIndicator.onlyForDiscrete,
        'shape': (value) => shape =
            ValueIndicatorShape.values.from(value) ?? ValueIndicatorShape.drop,
        'color': (value) => color = Utils.getColor(value),
        'textStyle': (value) => textStyle = Utils.getTextStyle(value),
      };

  @override
  Map<String, Function> getters() => {
        'visibility': () => visibility.toString().split('.').last,
        'shape': () => shape.toString().split('.').last,
        'color': () => color,
        'textStyle': () => textStyle,
      };

  @override
  Map<String, Function> methods() => {};

  SliderComponentShape? getIndicatorShape() {
    switch (shape) {
      case ValueIndicatorShape.rectangular:
        return RectangularSliderValueIndicatorShape();
      case ValueIndicatorShape.paddle:
        return PaddleSliderValueIndicatorShape();
      case ValueIndicatorShape.drop:
        return DropSliderValueIndicatorShape();
      default:
        return DropSliderValueIndicatorShape();
    }
  }

  RangeSliderValueIndicatorShape? getRangeIndicatorShape() {
    switch (shape) {
      case ValueIndicatorShape.rectangular:
        return RectangularRangeSliderValueIndicatorShape();
      case ValueIndicatorShape.paddle:
        return PaddleRangeSliderValueIndicatorShape();
      default:
        return RectangularRangeSliderValueIndicatorShape();
    }
  }
}

enum ValueIndicatorShape { drop, paddle, rectangular }
