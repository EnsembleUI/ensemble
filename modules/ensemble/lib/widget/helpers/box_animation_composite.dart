import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:flutter/animation.dart';

class BoxAnimationComposite extends WidgetCompositeProperty {
  BoxAnimationComposite._(super.widgetController,
      {this.enabled, Duration? duration, this.curve})
      : this.duration = duration ?? defaultDuration;

  static final defaultDuration = const Duration(milliseconds: 400);
  bool? enabled;
  Duration duration;
  Curve? curve;

  factory BoxAnimationComposite.from(
      BoxController controller, dynamic payload) {
    if (payload is Map) {
      return BoxAnimationComposite._(
        controller,
        enabled: Utils.optionalBool(payload["enabled"]),
        duration: Utils.getDurationMs(payload['duration']),
        curve: getCurve(payload['curve']),
      );
    }
    return BoxAnimationComposite._(controller);
  }

  @override
  Map<String, Function> getters() => {
        'enabled': () => enabled,
      };

  @override
  Map<String, Function> methods() => {};

  @override
  Map<String, Function> setters() => {
        'enabled': (value) => enabled = Utils.optionalBool(value),
        'duration': (value) =>
            duration = Utils.getDurationMs(value) ?? duration,
        'curve': (value) => curve = getCurve(value),
      };

  static Curve? getCurve(dynamic curveName) {
    if (curveName is! String) return null;
    switch (curveName) {
      case 'linear':
        return Curves.linear;
      case 'decelerate':
        return Curves.decelerate;
      case 'fastLinearToSlowEaseIn':
        return Curves.fastLinearToSlowEaseIn;
      case 'fastEaseInToSlowEaseOut':
        return Curves.fastEaseInToSlowEaseOut;
      case 'ease':
        return Curves.ease;
      case 'easeIn':
        return Curves.easeIn;
      case 'easeInToLinear':
        return Curves.easeInToLinear;
      case 'easeInSine':
        return Curves.easeInSine;
      case 'easeInQuad':
        return Curves.easeInQuad;
      case 'easeInCubic':
        return Curves.easeInCubic;
      case 'easeInQuart':
        return Curves.easeInQuart;
      case 'easeInQuint':
        return Curves.easeInQuint;
      case 'easeInExpo':
        return Curves.easeInExpo;
      case 'easeInCirc':
        return Curves.easeInCirc;
      case 'easeInBack':
        return Curves.easeInBack;
      case 'easeOut':
        return Curves.easeOut;
      case 'linearToEaseOut':
        return Curves.linearToEaseOut;
      case 'easeOutSine':
        return Curves.easeOutSine;
      case 'easeOutQuad':
        return Curves.easeOutQuad;
      case 'easeOutCubic':
        return Curves.easeOutCubic;
      case 'easeOutQuart':
        return Curves.easeOutQuart;
      case 'easeOutQuint':
        return Curves.easeOutQuint;
      case 'easeOutExpo':
        return Curves.easeOutExpo;
      case 'easeOutCirc':
        return Curves.easeOutCirc;
      case 'easeOutBack':
        return Curves.easeOutBack;
      case 'easeInOut':
        return Curves.easeInOut;
      case 'easeInOutSine':
        return Curves.easeInOutSine;
      case 'easeInOutQuad':
        return Curves.easeInOutQuad;
      case 'easeInOutCubic':
        return Curves.easeInOutCubic;
      case 'easeInOutCubicEmphasized':
        return Curves.easeInOutCubicEmphasized;
      case 'easeInOutQuart':
        return Curves.easeInOutQuart;
      case 'easeInOutQuint':
        return Curves.easeInOutQuint;
      case 'easeInOutExpo':
        return Curves.easeInOutExpo;
      case 'easeInOutCirc':
        return Curves.easeInOutCirc;
      case 'easeInOutBack':
        return Curves.easeInOutBack;
      case 'fastOutSlowIn':
        return Curves.fastOutSlowIn;
      case 'slowMiddle':
        return Curves.slowMiddle;
      case 'bounceIn':
        return Curves.bounceIn;
      case 'bounceOut':
        return Curves.bounceOut;
      case 'bounceInOut':
        return Curves.bounceInOut;
      case 'elasticIn':
        return Curves.elasticIn;
      case 'elasticOut':
        return Curves.elasticOut;
      case 'elasticInOut':
        return Curves.elasticInOut;
      default:
        return null;
    }
  }
}
