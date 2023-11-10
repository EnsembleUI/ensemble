import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/scope.dart';
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
  HapticAction(this.type);

  final HapticType type;

  // factory HapticAction.fromMap(dynamic inputs) =>
  //     HapticAction.fromYaml(payload: Utils.getYamlMap(inputs));

  // factory HapticAction.fromYaml({Map? payload}) {
  //   if (payload == null || payload['type'] == null) {
  //     throw LanguageError("${ActionType.invokeHaptic.name} requires 'type'");
  //   }

  //   return HapticAction(hapticType);
  // }

  factory HapticAction.from(dynamic inputs) {
    Map? payload;

    if (inputs is! Map) payload = Utils.getYamlMap(inputs);
    if (inputs is Map) payload = inputs;

    if (payload == null || payload['type'] == null) {
      throw LanguageError("${ActionType.invokeHaptic.name} requires 'type'");
    }

    // payload['type'] = ScopeManager.eval(payload['type']); // TODO: Continue from here

    final hapticType = HapticType //
        .values
        .firstWhere(
      (element) => element.name == payload!['type'],
      orElse: () => HapticType.heavyImpact,
    );

    return HapticAction(hapticType);
  }

  @override
  Future<dynamic> execute(BuildContext context, ScopeManager scopeManager) {
    return switch (type) {
      HapticType.heavyImpact => HapticFeedback.heavyImpact(),
      HapticType.mediumImpact => HapticFeedback.mediumImpact(),
      HapticType.lightImpact => HapticFeedback.lightImpact(),
      HapticType.selectionClick => HapticFeedback.selectionClick(),
      HapticType.vibrate => HapticFeedback.vibrate(),
    };
  }
}
