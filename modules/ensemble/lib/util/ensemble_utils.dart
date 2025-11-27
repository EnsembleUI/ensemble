import 'package:ensemble/ensemble.dart';
import 'package:flutter/material.dart';

class EnsembleUtils {
  /// dismiss any Dialog that is currently the top-most Route
  ///
  /// Accepts an optional [context] for more reliable dismissal when called from within a dialog.
  /// If [context] is provided, it will first try to use the context's Navigator directly.
  /// Falls back to using the RouteObserver if context is not provided or direct method fails.
  static Future<bool> dismissDialog([Map? payload, BuildContext? context]) {
    // Try using context's Navigator first (more reliable when inside a dialog)
    if (context != null) {
      final navigator = Navigator.maybeOf(context);
      if (navigator != null && navigator.canPop()) {
        // Verify it's actually a PopupRoute (Dialog) before popping
        final ModalRoute? currentRoute = ModalRoute.of(context);
        if (currentRoute is PopupRoute) {
          navigator.pop(payload);
          return Future.value(true);
        }
      }
    }

    // Fallback to RouteObserver method
    final route = Ensemble().getCurrentRoute();
    if (route is PopupRoute && route.isCurrent && route.navigator != null) {
      return route.navigator!.maybePop(payload);
    }
    return Future.value(false);
  }

  /// dismiss the Bottom Sheet if it is currently the top-most Route
  ///
  /// Accepts an optional [context] for more reliable dismissal when called from within a modal.
  /// If [context] is provided, it will first try to use the context's Navigator directly.
  /// Falls back to using the RouteObserver if context is not provided or direct method fails.
  static Future<bool> dismissBottomSheet([Map? payload, BuildContext? context]) {
    // Try using context's Navigator first (more reliable when inside a modal)
    if (context != null) {
      final navigator = Navigator.maybeOf(context);
      if (navigator != null && navigator.canPop()) {
        // Verify it's actually a ModalBottomSheetRoute before popping
        final ModalRoute? currentRoute = ModalRoute.of(context);
        if (currentRoute is ModalBottomSheetRoute) {
          navigator.pop(payload);
          return Future.value(true);
        }
      }
    }

    // Fallback to RouteObserver method
    final route = Ensemble().getCurrentRoute();
    if (route is ModalBottomSheetRoute &&
        route.isCurrent &&
        route.navigator != null) {
      return route.navigator!.maybePop(payload);
    }
    return Future.value(false);
  }
}
