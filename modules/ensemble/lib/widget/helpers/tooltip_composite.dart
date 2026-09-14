/// This class contains helper controllers for our widgets.
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:flutter/material.dart';

class TooltipData {
  final String message;
  final TooltipStyleComposite? styles;

  /// Action run when the tooltip is triggered.
  ///
  /// On TV, where a declarative [widget] renders as a focusable tooltip, this
  /// runs on both open and close and receives the state as `event.data.isOpen`
  /// so a definition can mirror it into a flag. It still runs on open only for
  /// the non-TV Flutter tooltip, which has no close callback.
  final EnsembleAction? onTriggered;
  final dynamic widget;
  final TooltipOptions options;

  TooltipData({
    required this.message,
    this.styles,
    this.onTriggered,
    this.widget,
    this.options = const TooltipOptions(),
  });

  static TooltipData? from(Map<String, dynamic>? data, ChangeNotifier controller) {
    if (data == null) return null;
    
    return TooltipData(
      message: Utils.getString(data['message'], fallback: ''),
      styles: data['styles'] != null ? 
        TooltipStyleComposite(controller, inputs: data['styles']) : null,
      onTriggered: data['onTriggered'] != null ? 
        EnsembleAction.from(data['onTriggered']) : null,
      widget: data['widget'],
      options: TooltipOptions.from(data['options']),
    );
  }
}

class TooltipOptions {
  const TooltipOptions({
    this.enabled = true,
    this.position = TooltipPosition.below,
    this.alignment = TooltipAlignment.center,
    this.offset = Offset.zero,
    this.dismissOnFocusLoss = true,
    this.dismissOnBack = true,
    this.restoreFocus = true,
    this.animation = const TooltipAnimation(),
  });

  factory TooltipOptions.from(dynamic value) {
    if (value is! Map) return const TooltipOptions();
    return TooltipOptions(
      enabled: value['enabled'] ?? true,
      position: TooltipPosition.from(value['position']),
      alignment: TooltipAlignment.from(value['alignment']),
      offset: _getOffset(value['offset']),
      dismissOnFocusLoss:
          Utils.getBool(value['dismissOnFocusLoss'], fallback: true),
      dismissOnBack: Utils.getBool(value['dismissOnBack'], fallback: true),
      restoreFocus: Utils.getBool(value['restoreFocus'], fallback: true),
      animation: TooltipAnimation.from(value['animation']),
    );
  }

  /// Whether focusing the anchor is allowed to open the tooltip.
  ///
  /// A literal `true`/`false` is used directly. A binding expression is left
  /// unresolved here (the tooltip map is not eagerly evaluated) and resolved
  /// against the anchor's data scope each time the trigger fires, so a
  /// condition such as `${!ensemble.storage.seen}` stays current and can gate
  /// the tooltip to a single first-time view. When false the trigger is inert;
  /// an already-open tooltip is unaffected and closes through its normal
  /// dismiss paths (Back, focus loss, or `dismissTooltip`).
  ///
  /// TV-only: the non-TV Flutter tooltip ignores [TooltipOptions].
  final dynamic enabled;
  final TooltipPosition position;
  final TooltipAlignment alignment;
  final Offset offset;
  final bool dismissOnFocusLoss;
  final bool dismissOnBack;
  final bool restoreFocus;
  final TooltipAnimation animation;

  static Offset _getOffset(dynamic value) {
    if (value is List && value.length >= 2) {
      final x = Utils.optionalDouble(value[0]);
      final y = Utils.optionalDouble(value[1]);
      if (x != null && y != null && x.isFinite && y.isFinite) {
        return Offset(x, y);
      }
    }
    if (value is String) {
      final values = Utils.stringToDoubles(value);
      if (values.length >= 2) return Offset(values[0], values[1]);
    }
    return Offset.zero;
  }
}

enum TooltipPosition {
  below,
  above,
  left,
  right;

  static TooltipPosition from(dynamic value) =>
      TooltipPosition.values.firstWhere(
        (position) => position.name == value,
        orElse: () => TooltipPosition.below,
      );
}

enum TooltipAlignment {
  start,
  center,
  end;

  static TooltipAlignment from(dynamic value) =>
      TooltipAlignment.values.firstWhere(
        (alignment) => alignment.name == value,
        orElse: () => TooltipAlignment.center,
      );
}

class TooltipAnimation {
  const TooltipAnimation({
    this.type = TooltipAnimationType.none,
    this.duration = Duration.zero,
    this.curve = Curves.easeOut,
  });

  factory TooltipAnimation.from(dynamic value) {
    if (value is! Map) return const TooltipAnimation();
    return TooltipAnimation(
      type: TooltipAnimationType.from(value['type']),
      duration: Utils.getDurationMs(value['duration']) ?? Duration.zero,
      curve: _getCurve(value['curve']) ?? Curves.easeOut,
    );
  }

  final TooltipAnimationType type;
  final Duration duration;
  final Curve curve;

  static Curve? _getCurve(dynamic value) {
    if (value is! String) return null;
    switch (value) {
      case 'linear':
        return Curves.linear;
      case 'ease':
        return Curves.ease;
      case 'easeIn':
        return Curves.easeIn;
      case 'easeOut':
        return Curves.easeOut;
      case 'easeInOut':
        return Curves.easeInOut;
      case 'fastOutSlowIn':
        return Curves.fastOutSlowIn;
    }
    return null;
  }
}

enum TooltipAnimationType {
  none,
  fade,
  scale,
  slide;

  static TooltipAnimationType from(dynamic value) =>
      TooltipAnimationType.values.firstWhere(
        (type) => type.name == value,
        orElse: () => TooltipAnimationType.none,
      );
}

// Composite class to handle tooltip styling and behavior
class TooltipStyleComposite extends WidgetCompositeProperty {
  TooltipStyleComposite(super.widgetController, {required Map inputs}) {
    textStyle = Utils.getTextStyle(inputs['textStyle']);
    verticalOffset = Utils.optionalDouble(inputs['verticalOffset']);
    preferBelow = Utils.optionalBool(inputs['preferBelow']);
    waitDuration = Utils.getDuration(inputs['waitDuration']);
    showDuration = Utils.getDuration(inputs['showDuration']);
    triggerMode = TooltipTriggerMode.values.from(inputs['triggerMode']);
    backgroundColor = Utils.getColor(inputs['backgroundColor']);
    borderRadius = Utils.getBorderRadius(inputs['borderRadius'])?.getValue();
    padding = Utils.optionalInsets(inputs['padding']);
    margin = Utils.optionalInsets(inputs['margin']);
    borderColor = Utils.getColor(inputs['borderColor']);
    borderWidth = Utils.optionalDouble(inputs['borderWidth']);
  }

  TextStyle? textStyle;
  double? verticalOffset;
  bool? preferBelow;
  Duration? waitDuration;
  Duration? showDuration;
  TooltipTriggerMode? triggerMode;
  Color? backgroundColor;
  BorderRadius? borderRadius;
  EdgeInsets? padding;
  EdgeInsets? margin;
  Color? borderColor;
  double? borderWidth;

  @override
  Map<String, Function> setters() {
    return {
      'textStyle': (value) => textStyle = Utils.getTextStyle(value),
      'verticalOffset': (value) => verticalOffset = Utils.optionalDouble(value),
      'preferBelow': (value) => preferBelow = Utils.optionalBool(value),
      'waitDuration': (value) => waitDuration = Utils.getDuration(value),
      'showDuration': (value) => showDuration = Utils.getDuration(value),
      'triggerMode': (value) => triggerMode = TooltipTriggerMode.values.from(value),
      'backgroundColor': (value) => backgroundColor = Utils.getColor(value),
      'borderRadius': (value) => borderRadius = Utils.getBorderRadius(value)?.getValue(),
      'padding': (value) => padding = Utils.optionalInsets(value),
      'margin': (value) => margin = Utils.optionalInsets(value),
      'borderColor': (value) => borderColor = Utils.getColor(value),
      'borderWidth': (value) => borderWidth = Utils.optionalDouble(value),
    };
  }

  @override
  Map<String, Function> getters() => {
    'textStyle': () => textStyle,
    'verticalOffset': () => verticalOffset,
    'preferBelow': () => preferBelow,
    'waitDuration': () => waitDuration,
    'showDuration': () => showDuration,
    'triggerMode': () => triggerMode,
    'backgroundColor': () => backgroundColor,
    'borderRadius': () => borderRadius,
    'padding': () => padding,
    'margin': () => margin,
    'borderColor': () => borderColor,
    'borderWidth': () => borderWidth,
  };

  @override
  Map<String, Function> methods() => {};
}
