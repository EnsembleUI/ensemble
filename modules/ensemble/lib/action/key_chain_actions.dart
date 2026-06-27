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

/// Ensemble action that writes a value to the platform keychain.
class SaveKeychain extends EnsembleAction {
  /// Creates a [SaveKeychain] action.
  SaveKeychain({
    required this.key,
    this.value,
    this.onComplete,
    this.onError,
  });

  /// Storage key used by keychain or secure storage actions.
  final String key;
  /// Value written, logged, or passed to the target integration.
  final dynamic value;
  /// Action executed after the operation completes successfully.
  final EnsembleAction? onComplete;
  /// Action executed when the operation fails.
  final EnsembleAction? onError;

  /// Creates a [SaveKeychain] from a YAML or map action payload.
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

  /// Runs this action and performs the save keychain operation.
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

/// Ensemble action that reads a value from the platform keychain.
class ReadKeychain extends EnsembleAction {
  /// Creates a [ReadKeychain] action.
  ReadKeychain({
    required this.key,
    this.onComplete,
    this.onError,
  });

  /// Storage key used by keychain or secure storage actions.
  final String key;
  /// Action executed after the operation completes successfully.
  final EnsembleAction? onComplete;
  /// Action executed when the operation fails.
  final EnsembleAction? onError;

  /// Creates a [ReadKeychain] from a YAML or map action payload.
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

  /// Runs this action and performs the read keychain operation.
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


/// Ensemble action that removes a value from the platform keychain.
class ClearKeychain extends EnsembleAction {
  /// Creates a [ClearKeychain] action.
  ClearKeychain({
    required this.key,
    this.onComplete,
    this.onError,
  });

  /// Storage key used by keychain or secure storage actions.
  final String key;
  /// Action executed after the operation completes successfully.
  final EnsembleAction? onComplete;
  /// Action executed when the operation fails.
  final EnsembleAction? onError;

  /// Creates a [ClearKeychain] from a YAML or map action payload.
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

  /// Runs this action and performs the clear keychain operation.
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