import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

enum HapticType {
  heavyImpact,
  mediumImpact,
  lightImpact,
  selectionClick,
  vibrate
}

class HapticAction extends EnsembleAction {
  HapticAction({required this.type, required this.onComplete});

  final String type;
  final EnsembleAction? onComplete;

  factory HapticAction.from(dynamic inputs) {
    Map? payload;

    if (inputs is! Map) payload = Utils.getYamlMap(inputs);
    if (inputs is Map) payload = inputs;

    if (payload == null || payload['type'] == null) {
      throw LanguageError("${ActionType.invokeHaptic.name} requires 'type'");
    }

    return HapticAction(
      type: payload['type'],
      onComplete: EnsembleAction.fromYaml(payload['onComplete']),
    );
  }

  @override
  Future<dynamic> execute(BuildContext context, ScopeManager scopeManager) {
    final evaluatedString = scopeManager.dataContext.eval(type);
    final hapticType = HapticType //
        .values
        .firstWhere(
      (e) => e.name == evaluatedString,
      orElse: () => HapticType.heavyImpact,
    );

    switch (hapticType) {
      case HapticType.heavyImpact:
        HapticFeedback.heavyImpact();
      case HapticType.mediumImpact:
        HapticFeedback.mediumImpact();
      case HapticType.lightImpact:
        HapticFeedback.lightImpact();
      case HapticType.selectionClick:
        HapticFeedback.selectionClick();
      case HapticType.vibrate:
        HapticFeedback.vibrate();
    }

    if (onComplete != null) {
      ScreenController().executeActionWithScope(
        context,
        scopeManager,
        onComplete!,
      );
    }

    return Future.value(null);
  }
}
