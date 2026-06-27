import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

/// Haptic feedback patterns supported by the haptic action.
enum HapticType {
  /// Triggers a strong impact haptic feedback.
  heavyImpact,
  /// Triggers a medium impact haptic feedback.
  mediumImpact,
  /// Triggers a light impact haptic feedback.
  lightImpact,
  /// Triggers the platform selection-click feedback.
  selectionClick,
  /// Triggers the generic platform vibration feedback.
  vibrate
}

/// Ensemble action that triggers platform haptic feedback.
class HapticAction extends EnsembleAction {
  /// Creates a [HapticAction] action.
  HapticAction({required this.type, required this.onComplete});

  /// Action-specific type such as toast style, haptic type, or file type.
  final String type;
  /// Action executed after the operation completes successfully.
  final EnsembleAction? onComplete;

  /// Creates a [HapticAction] from a YAML or map action payload.
  factory HapticAction.from(dynamic inputs) {
    Map? payload;

    if (inputs is! Map) payload = Utils.getYamlMap(inputs);
    if (inputs is Map) payload = inputs;

    if (payload == null || payload['type'] == null) {
      throw LanguageError("${ActionType.invokeHaptic.name} requires 'type'");
    }

    return HapticAction(
      type: payload['type'],
      onComplete: EnsembleAction.from(payload['onComplete']),
    );
  }

  /// Runs this action and performs the haptic operation.
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
