import 'package:ensemble/framework/error_handling.dart';
import 'package:flutter/cupertino.dart';

class StudioDebugger {
  static final StudioDebugger _instance = StudioDebugger._internal();

  StudioDebugger._internal();

  factory StudioDebugger() {
    return _instance;
  }

  /// studio mode will enable extra friendly debugging information
  /// to enable this add --dart-define=studio=true
  final bool debugMode =
      const bool.fromEnvironment('studio', defaultValue: false);

  /// assert that the widget's constraints does not have infinite height
  /// This usually happen when the widget is scrollable and:
  /// 1. The parent is a Column which gives its child as much height as it needs
  /// 2. The parent is scrollable
  void assertScrollableHasBoundedHeight(
      BoxConstraints constraints, String widgetName) {
    if (!constraints.hasBoundedHeight) {
      throw LanguageError(
          "$widgetName cannot be inside a parent with infinite height.",
          recovery:
              "1. If the parent is a Column, consider setting the $widgetName's expanded to true or give the $widgetName a height.\n2. If the parent is scrollable, make the parent not scrollable as this widget is already itself scrollable.");
    }
  }

  /// wrap the widget inside a LayoutBuilder so we can assert unbounded height
  /// This should be used only when debugMode=true to minimize performance impact
  Widget assertScrollableHasBoundedHeightWrapper(
          Widget widget, String widgetName) =>
      LayoutBuilder(builder: (context, constraints) {
        assertScrollableHasBoundedHeight(constraints, widgetName);
        return widget;
      });

  /// wrap the widget inside a LayoutBuilder to assert unbounded height
  /// Use this only when debugMode=true
  Widget assertHasBoundedWidthWrapper(Widget widget, String widgetName) =>
      LayoutBuilder(builder: (context, constraints) {
        if (!constraints.hasBoundedWidth) {
          throw LanguageError(
              "$widgetName cannot be inside a parent with infinite width.",
              recovery:
                  "1. If the parent is a Row, consider setting the $widgetName's expanded to true or give the $widgetName a width.\n2. If the parent is a Stack, use stackPosition's attributes to constraint the width.");
        }
        return widget;
      });
}
