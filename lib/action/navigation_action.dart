import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:flutter/cupertino.dart';

/// pop the current screen, but we abstract it as a navigate back
class NavigateBackAction extends EnsembleAction {
  NavigateBackAction({this.payload});

  Map? payload;

  factory NavigateBackAction.from({Map? payload}) =>
      NavigateBackAction(payload: payload?['payload'] ?? payload?['data']);

  @override
  Future<void> execute(BuildContext context, ScopeManager scopeManager) {
    return Navigator.of(context)
        .maybePop(scopeManager.dataContext.eval(payload));
  }
}
