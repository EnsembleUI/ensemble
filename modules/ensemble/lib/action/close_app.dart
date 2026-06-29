import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';

/// Ensemble action that performs the close app operation.
class CloseAppAction extends EnsembleAction {
  /// Creates a [CloseAppAction] action.
  CloseAppAction({
    super.initiator,
  });

  /// Creates a [CloseAppAction] from a YAML or map action payload.
  factory CloseAppAction.from({Invokable? initiator, Map? payload}) {
    return CloseAppAction(
      initiator: initiator,
    );
  }

  /// Runs this action and performs the close app operation.
  @override
  Future execute(BuildContext context, ScopeManager scopeManager) {
    SystemNavigator.pop();
    return Future.value(null);
  }
}
