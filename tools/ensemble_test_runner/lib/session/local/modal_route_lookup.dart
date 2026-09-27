import 'package:flutter/widgets.dart';

/// Whether [element] sits under the navigator's **current** [ModalRoute].
///
/// Unlike [ModalRoute.of], this does **not** register an [InheritedWidget]
/// dependency. Calling [ModalRoute.of] from observe / assert hot paths wires
/// every visited element into `_ModalScopeStatus`, so the next
/// `replaceCurrentScreen` mass-rebuilds those dependents and can poison a
/// shared Live-binding worker (Duplicate GlobalKey / ErrorWidget cascades).
bool isUnderCurrentModalRoute(Element element) {
  var foundRouteScope = false;
  var underCurrentRoutes = true;
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    // `_ModalScopeStatus` is private to flutter/widgets; match by runtime type.
    if (widget.runtimeType.toString() != '_ModalScopeStatus') return true;
    try {
      final route = (widget as dynamic).route;
      if (route is ModalRoute) {
        foundRouteScope = true;
        // Nested navigators can have a current inner route under an inactive
        // outer route. The element is visible only when every enclosing route
        // is current.
        if (!route.isCurrent) underCurrentRoutes = false;
      }
    } catch (_) {
      // Keep the prior permissive behavior if Flutter's private shape changes.
    }
    return true;
  });
  return !foundRouteScope || underCurrentRoutes;
}

/// Returns the nearest route scope for [element] without registering an
/// inherited-widget dependency. `null` means the element is outside a route.
ModalRoute<dynamic>? modalRouteForElement(Element element) {
  ModalRoute<dynamic>? found;
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    // `_ModalScopeStatus` is private to flutter/widgets; match by runtime type.
    if (widget.runtimeType.toString() != '_ModalScopeStatus') return true;
    try {
      final route = (widget as dynamic).route;
      if (route is ModalRoute) {
        found ??= route;
      }
    } catch (_) {
      // Keep default — treat as current if the private shape changed.
    }
    return true;
  });
  return found;
}
