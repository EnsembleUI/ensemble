import 'package:ensemble/action/call_external_method.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';

/// expose Ensemble Actions as Invokables
abstract class ActionInvokable with Invokable {
  ActionInvokable(this.buildContext);

  final BuildContext buildContext;

  @override
  Map<String, Function> methods() {
    return _generateFromActionTypes([
      ActionType.callExternalMethod,
      ActionType.share,
      ActionType.rateApp,
      ActionType.copyToClipboard,
      ActionType.getDeviceToken
    ]);
  }

  Map<String, Function> _generateFromActionTypes(List<ActionType> actionTypes) {
    Map<String, Function> functions = {};
    for (ActionType actionType in actionTypes) {
      functions[actionType.name] = (payload) {
        if (payload != null && payload is! Map) {
          throw LanguageError("${actionType.name} has an invalid payload.");
        }
        EnsembleAction? action =
            EnsembleAction.fromActionType(actionType, payload: payload);
        return action?.execute(buildContext, _getScopeManager(buildContext));
      };
    }
    return functions;
  }

  ScopeManager _getScopeManager(BuildContext context) {
    ScopeManager? scopeManager = ScreenController().getScopeManager(context);
    if (scopeManager == null) {
      throw LanguageError("Cannot look up ScopeManager");
    }
    return scopeManager;
  }
}
