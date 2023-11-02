import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

class HeavyImpactHaptic extends EnsembleAction {
  @override
  Future<dynamic> execute(BuildContext context, ScopeManager scopeManager) {
    return HapticFeedback.heavyImpact();
  }
}

class MediumImpactHaptic extends EnsembleAction {
  @override
  Future<dynamic> execute(BuildContext context, ScopeManager scopeManager) {
    return HapticFeedback.mediumImpact();
  }
}

class LightImpactHaptic extends EnsembleAction {
  @override
  Future<dynamic> execute(BuildContext context, ScopeManager scopeManager) {
    return HapticFeedback.lightImpact();
  }
}

class SelectionClickHaptic extends EnsembleAction {
  @override
  Future<dynamic> execute(BuildContext context, ScopeManager scopeManager) {
    return HapticFeedback.selectionClick();
  }
}

class VibrateHaptic extends EnsembleAction {
  @override
  Future<dynamic> execute(BuildContext context, ScopeManager scopeManager) {
    return HapticFeedback.vibrate();
  }
}
