import 'package:flutter/widgets.dart';

/// Whether [element] sits under the navigator's **current** [ModalRoute].
///
/// Unlike [ModalRoute.of], this does **not** register an [InheritedWidget]
/// dependency. Calling [ModalRoute.of] from observe / assert hot paths wires
/// every visited element into `_ModalScopeStatus`, so the next
/// `replaceCurrentScreen` mass-rebuilds those dependents and can poison a
/// shared Live-binding worker (Duplicate GlobalKey / ErrorWidget cascades).
bool isUnderCurrentModalRoute(Element element) {
  var underCurrent = true;
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    // `_ModalScopeStatus` is private to flutter/widgets; match by runtime type.
    if (widget.runtimeType.toString() != '_ModalScopeStatus') return true;
    try {
      final route = (widget as dynamic).route;
      if (route is ModalRoute) {
        underCurrent = route.isCurrent;
      }
    } catch (_) {
      // Keep default — treat as current if the private shape changed.
    }
    return false;
  });
  return underCurrent;
}
