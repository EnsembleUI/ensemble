import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/keychain_manager.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/widgets.dart';

class SaveKeychain extends EnsembleAction {
  SaveKeychain({
    required this.key,
    this.value,
    this.onComplete,
    this.onError,
  });

  final String key;
  final dynamic value;
  final EnsembleAction? onComplete;
  final EnsembleAction? onError;

  factory SaveKeychain.fromYaml({Map? payload}) {
    if (payload == null || payload['key'] == null) {
      throw ConfigError('${ActionType.saveKeychain} requires a key.');
    }
    return SaveKeychain(
      key: payload['key'],
      value: payload['value'],
      onComplete: EnsembleAction.from(payload['onComplete']),
      onError: EnsembleAction.from(payload['onError']),
    );
  }

  @override
  Future execute(BuildContext context, ScopeManager scopeManager,
      {DataContext? dataContext}) async {
    String? storageKey =
        Utils.optionalString(scopeManager.dataContext.eval(key));
    dynamic evaluatedValue = scopeManager.dataContext.eval(value);
    String? errorReason;

    if (storageKey != null) {
      try {
        final datas = {'key': storageKey, 'value': evaluatedValue};
        print('Saving to keychain: $datas');
        await KeychainManager().saveToKeychain(datas);
        // dispatch onComplete
        if (onComplete != null) {
          ScreenController().executeAction(context, onComplete!);
        }
      } catch (e) {
        errorReason = e.toString();
      }
    } else {
      errorReason = '${ActionType.saveKeychain} requires a key.';
    }

    if (onError != null && errorReason != null) {
      ScreenController().executeAction(context, onError!,
          event: EnsembleEvent(null, error: errorReason));
    }
    return Future.value(null);
  }
}

// The ReadKeychain action retrieves a value from the keychain using the provided key.
// It is only available in YAML, as this calls a async function whose return type is Future and we use callbacks to handle the result.
// Our JS is sync and we cannot use async/await in JS. 
class ReadKeychain extends EnsembleAction {
  ReadKeychain({
    required this.key,
    this.onComplete,
    this.onError,
  });

  final String key;
  final EnsembleAction? onComplete;
  final EnsembleAction? onError;

  factory ReadKeychain.fromYaml({Map? payload}) {
    if (payload == null || payload['key'] == null) {
      throw ConfigError('${ActionType.readKeychain} requires a key.');
    }
    return ReadKeychain(
      key: payload['key'],
      onComplete: EnsembleAction.from(payload['onComplete']),
      onError: EnsembleAction.from(payload['onError']),
    );
  }

  @override
  Future execute(BuildContext context, ScopeManager scopeManager,
      {DataContext? dataContext}) async {
    String? storageKey =
        Utils.optionalString(scopeManager.dataContext.eval(key));
    String? errorReason;

    if (storageKey != null) {
      try {
        dynamic value = await StorageManager().readSecurely(storageKey);
        // dispatch onComplete with the retrieved value
        if (onComplete != null && value != null) {
          ScreenController().executeAction(context, onComplete!,
              event: EnsembleEvent(null, data: value));
        } else if (onComplete != null && value == null) {
          // Key exists but value is null
          errorReason = 'No value found for key: $storageKey';
        }
      } catch (e) {
        errorReason = e.toString();
      }
    } else {
      errorReason = '${ActionType.readKeychain} requires a key.';
    }

    if (onError != null && errorReason != null) {
      ScreenController().executeAction(context, onError!,
          event: EnsembleEvent(null, error: errorReason));
    }
    return Future.value(null);
  }
}


class ClearKeychain extends EnsembleAction {
  ClearKeychain({
    required this.key,
    this.onComplete,
    this.onError,
  });

  final String key;
  final EnsembleAction? onComplete;
  final EnsembleAction? onError;

  factory ClearKeychain.fromYaml({Map? payload}) {
    if (payload == null || payload['key'] == null) {
      throw ConfigError('${ActionType.clearKeychain} requires a key.');
    }
    return ClearKeychain(
      key: payload['key'],
      onComplete: EnsembleAction.from(payload['onComplete']),
      onError: EnsembleAction.from(payload['onError']),
    );
  }

  @override
  Future execute(BuildContext context, ScopeManager scopeManager,
      {DataContext? dataContext}) async {
    String? storageKey =
        Utils.optionalString(scopeManager.dataContext.eval(key));
    String? errorReason;

    if (storageKey != null) {
      try {
        final datas = {'key': storageKey};
        await KeychainManager().clearKeychain(datas);
        // dispatch onComplete
        if (onComplete != null) {
          ScreenController().executeAction(context, onComplete!);
        }
      } catch (e) {
        errorReason = e.toString();
      }
    } else {
      errorReason = '${ActionType.clearKeychain} requires a key.';
    }

    if (onError != null && errorReason != null) {
      ScreenController().executeAction(context, onError!,
          event: EnsembleEvent(null, error: errorReason));
    }
    return Future.value(null);
  }
}