import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';

class CloseAppAction extends EnsembleAction {
  CloseAppAction({
    super.initiator,
  });

  factory CloseAppAction.from({Invokable? initiator, Map? payload}) {
    return CloseAppAction(
      initiator: initiator,
    );
  }

  @override
  Future execute(BuildContext context, ScopeManager scopeManager) {
    SystemNavigator.pop();
    return Future.value(null);
  }
}
