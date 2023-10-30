import 'dart:developer';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/cupertino.dart';

/// Call an external methods (defined in Flutter) from inside Ensemble
class CallExternalMethod extends EnsembleAction {
  CallExternalMethod(this._name, this._payload,
      {this.onComplete, this.onError});

  final dynamic _name;
  final Map? _payload;
  final EnsembleAction? onComplete;
  final EnsembleAction? onError;

  factory CallExternalMethod.from({Map? payload}) {
    dynamic name = payload?['name'];
    if (name == null) {
      throw LanguageError(
          "${ActionType.callExternalMethod.name} requires the method name");
    }
    return CallExternalMethod(
        name, payload?['payload'] is Map ? payload!['payload'] : null,
        onComplete: EnsembleAction.fromYaml(payload?['onComplete']),
        onError: EnsembleAction.fromYaml(payload?['onError']));
  }

  @override
  Future execute(BuildContext context, ScopeManager scopeManager) async {
    String? name = Utils.optionalString(scopeManager.dataContext.eval(_name));

    String? errorReason;
    if (name == null) {
      errorReason = 'Invalid method name';
    } else if (Ensemble().externalMethods[name] == null) {
      errorReason = "Method '$name' has not been defined";
    } else {
      try {
        Map<Symbol, dynamic>? payload;
        _payload?.forEach((key, value) {
          (payload ??= {})[Symbol(key)] = scopeManager.dataContext.eval(value);
        });
        // execute the external function. Always await in case it's async
        dynamic rtnValue = await Function.apply(
            Ensemble().externalMethods[name]!, null, payload);

        // dispatch onComplete
        if (onComplete != null) {
          ScreenController().executeAction(context, onComplete!,
              event: EnsembleEvent(null, data: rtnValue));
        }
        return rtnValue;
      } catch (e) {
        errorReason = e.toString();
      }
    }

    if (onError != null) {
      ScreenController().executeAction(context, onError!,
          event: EnsembleEvent(null,
              error: errorReason ?? 'Error executing method'));
    }
    return Future.value(null);
  }
}
