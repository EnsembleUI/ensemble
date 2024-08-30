import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';

/// execute a group of actions, either in porallel or in order.
class ExecuteActionGroupAction extends EnsembleAction {
  ExecuteActionGroupAction(
      {super.initiator, this.executeInOrder, required this.actions});

  List<EnsembleAction> actions;
  dynamic executeInOrder;

  factory ExecuteActionGroupAction.from({Invokable? initiator, Map? payload}) {
    if (payload == null || payload['actions'] == null) {
      throw LanguageError(
          "${ActionType.executeActionGroup.name} requires a 'actions' list.");
    }

    if (payload['actions'] is! List<dynamic>) {
      throw LanguageError(
          "${ActionType.executeActionGroup.name} requires a 'actions' list.");
    }
    List<dynamic> actions = payload['actions'] as List<dynamic>;
    if (actions == null || actions.isEmpty) {
      throw LanguageError(
          "${ActionType.executeActionGroup.name} requires a 'actions' list.");
    }
    List<EnsembleAction> ensembleActions = [];
    for (var action in actions) {
      EnsembleAction? ensembleAction =
          EnsembleAction.from(action, initiator: initiator);
      if (ensembleAction == null) {
        throw LanguageError(
            "$action under ${ActionType.executeActionGroup.name} is not a valid action");
      }
      if (ensembleAction != null) {
        ensembleActions.add(ensembleAction);
      }
    }
    return ExecuteActionGroupAction(
        initiator: initiator,
        actions: ensembleActions,
        executeInOrder: payload['executeInOrder']);
  }

  @override
  Future<void> execute(BuildContext context, ScopeManager scopeManager) async {
    final _executeInOrder =
        Utils.optionalBool(scopeManager.dataContext.eval(executeInOrder));
    // wait for each action to complete before the next one
    if (_executeInOrder == true) {
      for (final action in actions) {
        await ScreenController()
            .executeActionWithScope(context, scopeManager, action);
      }
    }
    // execute all actions in parallel
    else {
      Future.wait(actions.map((action) => ScreenController()
          .executeActionWithScope(context, scopeManager, action)));
    }
    return;
  }
}
