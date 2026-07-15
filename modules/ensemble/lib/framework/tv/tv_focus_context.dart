import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:flutter/widgets.dart';

/// Inherited TV focus defaults for a subtree.
///
/// A parent widget can provide a [focusGroup] and edge targets without becoming
/// focusable itself. Descendant focusable widgets inherit these values unless
/// they define their own tvOptions values.
class TVFocusContext extends InheritedWidget {
  const TVFocusContext({
    super.key,
    required super.child,
    this.focusGroup,
    this.rightEdge,
    this.leftEdge,
    this.topEdge,
    this.bottomEdge,
  });

  final String? focusGroup;
  final TVFocusEdgeTargetComposite? rightEdge;
  final TVFocusEdgeTargetComposite? leftEdge;
  final TVFocusEdgeTargetComposite? topEdge;
  final TVFocusEdgeTargetComposite? bottomEdge;

  static TVFocusContext? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<TVFocusContext>();
  }

  @override
  bool updateShouldNotify(TVFocusContext oldWidget) {
    return focusGroup != oldWidget.focusGroup ||
        rightEdge != oldWidget.rightEdge ||
        leftEdge != oldWidget.leftEdge ||
        topEdge != oldWidget.topEdge ||
        bottomEdge != oldWidget.bottomEdge;
  }
}
