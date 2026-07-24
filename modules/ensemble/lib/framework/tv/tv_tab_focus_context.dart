import 'package:flutter/widgets.dart';

/// Focus coordinates supplied by a TV TabBar to its currently displayed body.
///
/// A non-interactive ListView can use this to make its fallback scrollbar the
/// next focus target below the selected tab and return to that exact tab.
class TVTabFocusContext extends InheritedWidget {
  const TVTabFocusContext({
    super.key,
    required this.tabRow,
    required this.selectedTabOrder,
    required super.child,
  });

  final double tabRow;
  final double selectedTabOrder;

  static TVTabFocusContext? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TVTabFocusContext>();

  @override
  bool updateShouldNotify(TVTabFocusContext oldWidget) =>
      tabRow != oldWidget.tabRow ||
      selectedTabOrder != oldWidget.selectedTabOrder;
}
