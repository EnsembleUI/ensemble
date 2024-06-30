import 'dart:developer';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/host_platform_manager.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/cupertino.dart';

/// Call a native methods (defined in Host Platform) from inside Ensemble
class CallNativeMethod extends EnsembleAction {
  CallNativeMethod(this._name, this._payload, {this.onComplete, this.onError});

  final dynamic _name;
  final Map? _payload;
  final EnsembleAction? onComplete;
  final EnsembleAction? onError;

  factory CallNativeMethod.from({Map? payload}) {
    dynamic name = payload?['name'];
    if (name == null) {
      throw LanguageError(
          "${ActionType.callExternalMethod.name} requires the method name");
    }
    return CallNativeMethod(
        name, payload?['payload'] is Map ? payload!['payload'] : null,
        onComplete: EnsembleAction.from(payload?['onComplete']),
        onError: EnsembleAction.from(payload?['onError']));
  }

  @override
  Future execute(BuildContext context, ScopeManager scopeManager) async {
    String? name = Utils.optionalString(scopeManager.dataContext.eval(_name));

    String? errorReason;
    if (name == null) {
      errorReason = 'Invalid method name';
    } else {
      try {
        Map<String, dynamic>? payload;
        _payload?.forEach((key, value) {
          (payload ??= {})[key] = scopeManager.dataContext.eval(value);
        });
        // execute the external function. Always await in case it's async
        HostPlatformManager().callNativeMethod(name, payload).then((_) {
          // dispatch onComplete
          if (onComplete != null) {
            ScreenController().executeAction(context, onComplete!);
          }
        }).catchError((error) {
          if (onError != null) {
            ScreenController().executeAction(context, onError!,
                event: EnsembleEvent(initiator, error: error));
          }
        });
        return Future.value(null);
      } catch (e) {
        errorReason = e.toString();
      }
    }

    if (onError != null) {
      ScreenController().executeAction(context, onError!,
          event: EnsembleEvent(initiator, error: errorReason));
    }

    return Future.value(null);
  }
}
