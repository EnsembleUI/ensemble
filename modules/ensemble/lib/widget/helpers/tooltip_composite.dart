/// This class contains helper controllers for our widgets.
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:flutter/material.dart';

class TooltipData {
  final String message;
  final TooltipStyleComposite? styles;
  final EnsembleAction? onTriggered;

  TooltipData({
    required this.message,
    this.styles,
    this.onTriggered,
  });

  static TooltipData? from(Map<String, dynamic>? data, ChangeNotifier controller) {
    if (data == null) return null;
    
    return TooltipData(
      message: Utils.getString(data['message'], fallback: ''),
      styles: data['styles'] != null ? 
        TooltipStyleComposite(controller, inputs: data['styles']) : null,
      onTriggered: data['onTriggered'] != null ? 
        EnsembleAction.from(data['onTriggered']) : null,
    );
  }
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
    borderWidth = Utils.optionalInt(inputs['borderWidth']);
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
  int? borderWidth;

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
      'borderWidth': (value) => borderWidth = Utils.optionalInt(value),
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