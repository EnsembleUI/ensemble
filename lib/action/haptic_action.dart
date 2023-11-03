import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

enum HapticTypes {
  heavyImpact,
  mediumImpact,
  lightImpact,
  selectionClick,
  vibrate
}

class HapticAction extends EnsembleAction {
  HapticAction(this.type);

  final HapticTypes type;

  factory HapticAction.fromMap(dynamic inputs) =>
      HapticAction.fromYaml(payload: Utils.getYamlMap(inputs));

  factory HapticAction.fromYaml({Map? payload}) {
    if (payload == null || payload['type'] == null) {
      throw LanguageError("${ActionType.share.name} requires 'type'");
    }

    final hapticType = HapticTypes //
        .values
        .byName(payload['type']);

    return HapticAction(hapticType);
  }

  @override
  Future<dynamic> execute(BuildContext context, ScopeManager scopeManager) {
    return switch (type) {
      HapticTypes.heavyImpact => HapticFeedback.heavyImpact(),
      HapticTypes.mediumImpact => HapticFeedback.mediumImpact(),
      HapticTypes.lightImpact => HapticFeedback.lightImpact(),
      HapticTypes.selectionClick => HapticFeedback.selectionClick(),
      HapticTypes.vibrate => HapticFeedback.vibrate(),
    };
  }
}
