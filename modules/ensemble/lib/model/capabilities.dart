import 'package:ensemble/framework/action.dart';
import 'package:flutter/services.dart';

// enable a widget to be tap-able
mixin TapEnabled {
  EnsembleAction? onTap;

  // by default disable splash feedback for historical reason
  bool enableSplashFeedback = false;
  Color? splashColor;
  Duration? splashDuration;
  Duration? splashFadeDuration;
  Duration? unconfirmedSplashDuration;

  // for Desktop/Web or accessibility on Native
  Color? focusColor;

  // these are applicable on Desktop/Web only
  Color? hoverColor;
  SystemMouseCursor? mouseCursor = SystemMouseCursors.click;
}
