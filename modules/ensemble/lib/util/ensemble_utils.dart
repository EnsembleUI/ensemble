import 'package:ensemble/ensemble.dart';
import 'package:flutter/material.dart';

class EnsembleUtils {
  /// dismiss any Dialog that is currently the top-most Route
  static Future<bool> dismissDialog([Map? payload]) {
    final route = Ensemble().getCurrentRoute();
    if (route is PopupRoute && route.isCurrent && route.navigator != null) {
      return route.navigator!.maybePop(payload);
    }
    return Future.value(false);
  }

  /// dismiss the Bottom Sheet if it is currently the top-most Route
  static Future<bool> dismissBottomSheet([Map? payload]) {
    final route = Ensemble().getCurrentRoute();
    if (route is ModalBottomSheetRoute &&
        route.isCurrent &&
        route.navigator != null) {
      return route.navigator!.maybePop(payload);
    }
    return Future.value(false);
  }
}
