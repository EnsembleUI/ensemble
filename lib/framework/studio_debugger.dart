import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/view/footer.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/layout/box/box_layout.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
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
      const bool.fromEnvironment('studio', defaultValue: true);

  /// assert that the widget's constraints does not have infinite height
  /// This usually happen when the widget is scrollable and:
  /// 1. The parent is a Column which gives its child as much height as it needs
  /// 2. The parent is scrollable
  void assertScrollableHasBoundedHeight(BoxConstraints constraints,
      String widgetName, BuildContext context, BoxController controller) {
    if (!constraints.hasBoundedHeight) {
      if (!(FooterScope.of(context) != null &&
          ScrollableColumn.of(context) != null &&
          controller.expanded == false)) {
        throw LanguageError(
            "$widgetName cannot be inside a parent with infinite height.",
            recovery:
                "1. If the parent is a Column, consider setting the $widgetName's expanded to true or give the $widgetName a height.\n2. If the parent is scrollable, make the parent not scrollable as this widget is already itself scrollable.");
      }
    }
  }

  /// wrap the widget inside a LayoutBuilder so we can assert unbounded height
  /// This should be used only when debugMode=true to minimize performance impact
  Widget assertScrollableHasBoundedHeightWrapper(Widget widget,
      String widgetName, BuildContext context, BoxController controller) {
    if (FooterScope.of(context) != null &&
        ScrollableColumn.of(context) != null &&
        controller.expanded == true) {
      throw LanguageError(
          "Within footer, $widgetName cannot have expanded true with scrollable Column as Parent",
          recovery:
              "1. Make the scrollable property of Column as false. \n2.If Listview does not respond to draggable scroller, this means that there is a $widgetName as parent who is already using the property \n If that is the case then, put scrollaBehaviour of footer inside the controller property of $widgetName");
    }
    if (FooterScope.of(context) == null &&
        ScrollableColumn.of(context) != null &&
        controller.expanded == true) {
      throw LanguageError("$widgetName cannot be inside a scrollable column.",
          recovery:
              "If the parent is scrollable, make the parent not scrollable as this widget is already itself scrollable.");
    }
    return LayoutBuilder(builder: (context, constraints) {
      assertScrollableHasBoundedHeight(
          constraints, widgetName, context, controller);
      return widget;
    });
  }

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

  Widget assertHasColumnRowFlexWrapper(Widget widget, BuildContext context) {
    RequiresRowColumnFlexWidget? requiresRowColumnFlexWidget = context
        .dependOnInheritedWidgetOfExactType<RequiresRowColumnFlexWidget>();
    if (requiresRowColumnFlexWidget == null) {
      throw LanguageError("expanded is true with incorrect parent widget ",
          recovery:
              "Expanded widgets must be placed directly inside some form of flex widget.\n Please place the widget under the parent of flex or column or row");
    }
    return widget;
  }

  Widget assertHasStackWrapper(Widget widget, BuildContext context) {
    RequireStackWidget? requireStackWidget =
        context.dependOnInheritedWidgetOfExactType<RequireStackWidget>();
    if (requireStackWidget == null) {
      throw LanguageError(
          "stackPosition* is applicable only with Stack as the parent widget",
          recovery:
              "Please remove stackPosition* or put your widget inside a Stack to position it");
    }
    return widget;
  }
}
