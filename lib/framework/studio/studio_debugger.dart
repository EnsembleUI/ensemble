import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/view/footer.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/layout/box/box_layout.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

class StudioDebugger {
  static final StudioDebugger _instance = StudioDebugger._internal();

  StudioDebugger._internal();

  factory StudioDebugger() {
    return _instance;
  }

  final logger = Logger();

  /// studio mode will enable extra friendly debugging information
  /// to enable this add --dart-define=studio=true
  final bool debugMode =
      const bool.fromEnvironment('studio', defaultValue: false);

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

  /// for widgets that have no width/height and rely to the parent for sizing. e.g. Google Maps
  Widget assertHasBoundedWidthHeight(Widget widget, String widgetName,
      {bool warningOnly = false}) {
    return _assertHasBoundedDimension(widget, widgetName,
        assertBoundedWidth: true,
        assertBoundedHeight: true,
        warningOnly: warningOnly);
  }

  Widget assertHasBoundedWidth(Widget widget, String widgetName,
      {bool warningOnly = false}) {
    return _assertHasBoundedDimension(widget, widgetName,
        assertBoundedWidth: true, warningOnly: warningOnly);
  }

  Widget assertHasBoundedHeight(Widget widget, String widgetName,
      {bool warningOnly = false}) {
    return _assertHasBoundedDimension(widget, widgetName,
        assertBoundedHeight: true, warningOnly: warningOnly);
  }

  Widget _assertHasBoundedDimension(
    Widget widget,
    String widgetName, {
    bool assertBoundedWidth = false,
    bool assertBoundedHeight = false,
    bool warningOnly = false,
  }) {
    if (!debugMode) return widget;

    return LayoutBuilder(builder: (context, constraints) {
      if (!constraints.hasBoundedWidth && assertBoundedWidth) {
        if (warningOnly) {
          logger.w(
              "'$widgetName' requires a width. See ${StudioError.getDocUrl('no-bounded-width')}");
        } else {
          throw StudioError("'$widgetName' requires a width.",
              errorId: 'no-bounded-width');
        }
      }
      if (!constraints.hasBoundedHeight && assertBoundedHeight) {
        if (warningOnly) {
          logger.w(
              "'$widgetName' requires a height. See ${StudioError.getDocUrl('no-bounded-height')}");
        } else {
          throw StudioError("'$widgetName' requires a height.",
              errorId: 'no-bounded-height');
        }
      }
      return widget;
    });
  }

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
    bool isStack = false;
    context.visitAncestorElements((element) {
      if (element.widget.runtimeType == Stack) {
        isStack = true;
      }

      // This will ensure that it doesnt check for any other parent widgets
      return false;
    });

    print(isStack);
    if (!isStack) {
      throw LanguageError(
          "stackPosition* is applicable only with Stack as the parent widget",
          recovery:
              "Please remove stackPosition* or put your widget inside a Stack to position it");
    }
    return widget;
  }

  /// assert FlexRow / FlexColumn either have a width/height or the parent constrain their dimension
  Widget assertFlexBoxHasBoundedDimension(Widget flexBox, bool isVertical) {
    if (!StudioDebugger().debugMode) return flexBox;

    // wrap the FlexBox so its children can assure they are being used inside the Flexbox only
    // Note that this is for the children to assert correct-ness, not for the Flexbox itself (but we use this function for both purposes)
    Widget rtn = HasFlexBox(child: flexBox);

    return LayoutBuilder(builder: (context, constraints) {
      if (!constraints.hasBoundedHeight && isVertical) {
        throw StudioError(
            "FlexColumn requires a height for child distribution.",
            errorId: 'flexcolumn-no-bounded-height');
      }
      if (!constraints.hasBoundedWidth && !isVertical) {
        throw StudioError("FlexRow requires a width for child distribution",
            errorId: 'flexrow-no-bounded-width');
      }
      return rtn;
    });
  }

  // make sure that this widget has a FlexBox parent
  Widget assertHasFlexBoxParent(BuildContext context, Widget widget) {
    if (StudioDebugger().debugMode) {
      HasFlexBox? flexBox =
          context.dependOnInheritedWidgetOfExactType<HasFlexBox>();
      if (flexBox == null) {
        throw LanguageError(
            "Usage of 'flex' or 'flexMode' requires this widget to be inside a FlexColumn or a FlexRow.");
      }
    }
    return widget;
  }
}

class HasFlexBox extends InheritedWidget {
  const HasFlexBox({super.key, required super.child});

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) => false;
}
