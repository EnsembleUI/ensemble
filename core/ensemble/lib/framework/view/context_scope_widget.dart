import 'package:flutter/cupertino.dart';

/// a wrapper InheritedWidget to look up the root scope, typically used
/// by deeply nested children to find the root context of (for ex) the
/// BottomSheetModal so it can close the modal as needed
class ContextScopeWidget extends InheritedWidget {
  const ContextScopeWidget(
      {super.key, required super.child, required this.rootContext});

  final BuildContext rootContext;

  @override
  bool updateShouldNotify(covariant ContextScopeWidget oldWidget) {
    return oldWidget.rootContext != rootContext;
  }

  static BuildContext? getRootContext(BuildContext context) {
    ContextScopeWidget? wrapperWidget =
        context.dependOnInheritedWidgetOfExactType<ContextScopeWidget>();
    return wrapperWidget?.rootContext;
  }
}
