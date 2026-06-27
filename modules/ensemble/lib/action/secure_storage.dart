import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/encrypted_storage_manager.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:flutter/material.dart';

/// Ensemble action that writes an encrypted value to secure storage.
class SetSecureStorage extends EnsembleAction {
  /// Creates a [SetSecureStorage] action.
  SetSecureStorage({
    required this.key,
    this.value,
    this.algorithm,
    this.mode,
    this.onComplete,
    this.onError,
  });

  /// Storage key used by keychain or secure storage actions.
  final String key;
  /// Value written, logged, or passed to the target integration.
  final dynamic value;
  /// Encryption algorithm used for secure storage, when configured.
  final String? algorithm;
  /// Encryption mode used for secure storage, when configured.
  final String? mode;
  /// Action executed after the operation completes successfully.
  final EnsembleAction? onComplete;
  /// Action executed when the operation fails.
  final EnsembleAction? onError;

  /// Creates a [SetSecureStorage] from a YAML or map action payload.
  factory SetSecureStorage.fromYaml({Map? payload}) {
    if (payload == null || payload['key'] == null) {
      throw ConfigError('setSecureStorage requires a key.');
    }
    return SetSecureStorage(
      key: payload['key'],
      value: payload['value'],
      algorithm: payload['algorithm'],
      mode: payload['mode'],
      onComplete: EnsembleAction.from(payload['onComplete']),
      onError: EnsembleAction.from(payload['onError']),
    );
  }

  /// Runs this action and performs the set secure storage operation.
  @override
  Future execute(BuildContext context, ScopeManager scopeManager,
      {DataContext? dataContext}) async {
    try {
      final evaluatedKey = scopeManager.dataContext.eval(key);
      final evaluatedValue = scopeManager.dataContext.eval(value);
      final evaluatedAlgorithm =
          algorithm != null ? scopeManager.dataContext.eval(algorithm) : null;
      final evaluatedMode =
          mode != null ? scopeManager.dataContext.eval(mode) : null;
      
      // Create inputs in the format expected by EncryptedStorageManager
      final inputs = <String, dynamic>{
        'key': evaluatedKey,
        'value': evaluatedValue,
      };
      if (evaluatedAlgorithm != null) {
        inputs['algorithm'] = evaluatedAlgorithm;
      }
      if (evaluatedMode != null) {
        inputs['mode'] = evaluatedMode;
      }
      
      EncryptedStorageManager.setSecureStorage(inputs);
      
      if (onComplete != null) {
        ScreenController().executeAction(context, onComplete!);
      }
    } catch (e) {
      if (onError != null) {
        ScreenController().executeAction(context, onError!,
            event: EnsembleEvent(null, error: e.toString()));
      }
    }
    return Future.value(null);
  }
}

/// Ensemble action that reads an encrypted value from secure storage.
class GetSecureStorage extends EnsembleAction {
  /// Creates a [GetSecureStorage] action.
  GetSecureStorage({
    required this.key,
    this.algorithm,
    this.mode,
    this.onComplete,
    this.onError,
  });

  /// Storage key used by keychain or secure storage actions.
  final String key;
  /// Encryption algorithm used for secure storage, when configured.
  final String? algorithm;
  /// Encryption mode used for secure storage, when configured.
  final String? mode;
  /// Action executed after the operation completes successfully.
  final EnsembleAction? onComplete;
  /// Action executed when the operation fails.
  final EnsembleAction? onError;

  /// Creates a [GetSecureStorage] from a YAML or map action payload.
  factory GetSecureStorage.fromYaml({Map? payload}) {
    if (payload == null || payload['key'] == null) {
      throw ConfigError('getSecureStorage requires a key.');
    }
    return GetSecureStorage(
      key: payload['key'],
      algorithm: payload['algorithm'],
      mode: payload['mode'],
      onComplete: EnsembleAction.from(payload['onComplete']),
      onError: EnsembleAction.from(payload['onError']),
    );
  }

  /// Runs this action and performs the get secure storage operation.
  @override
  Future execute(BuildContext context, ScopeManager scopeManager,
      {DataContext? dataContext}) async {
    var value;
    try {
      final evaluatedKey = scopeManager.dataContext.eval(key);
      final evaluatedAlgorithm =
          algorithm != null ? scopeManager.dataContext.eval(algorithm) : null;
      final evaluatedMode =
          mode != null ? scopeManager.dataContext.eval(mode) : null;
      
      // Create inputs in the format expected by EncryptedStorageManager
      final inputs = <String, dynamic>{'key': evaluatedKey};
      if (evaluatedAlgorithm != null) {
        inputs['algorithm'] = evaluatedAlgorithm;
      }
      if (evaluatedMode != null) {
        inputs['mode'] = evaluatedMode;
      }
      
      value = EncryptedStorageManager.getSecureStorage(inputs);
      
      if (onComplete != null) {
        ScreenController().executeAction(context, onComplete!,
            event: EnsembleEvent(null, data: value));
      }
    } catch (e) {
      if (onError != null) {
        ScreenController().executeAction(context, onError!,
            event: EnsembleEvent(null, error: e.toString()));
      }
    }
    return Future.value(value);
  }
}

/// Ensemble action that removes an encrypted value from secure storage.
class ClearSecureStorage extends EnsembleAction {
  /// Creates a [ClearSecureStorage] action.
  ClearSecureStorage({
    required this.key,
    this.algorithm,
    this.mode,
    this.onComplete,
    this.onError,
  });

  /// Storage key used by keychain or secure storage actions.
  final String key;
  /// Encryption algorithm used for secure storage, when configured.
  final String? algorithm;
  /// Encryption mode used for secure storage, when configured.
  final String? mode;
  /// Action executed after the operation completes successfully.
  final EnsembleAction? onComplete;
  /// Action executed when the operation fails.
  final EnsembleAction? onError;

  /// Creates a [ClearSecureStorage] from a YAML or map action payload.
  factory ClearSecureStorage.fromYaml({Map? payload}) {
    if (payload == null || payload['key'] == null) {
      throw ConfigError('clearSecureStorage requires a key.');
    }
    return ClearSecureStorage(
      key: payload['key'],
      algorithm: payload['algorithm'],
      mode: payload['mode'],
      onComplete: EnsembleAction.from(payload['onComplete']),
      onError: EnsembleAction.from(payload['onError']),
    );
  }

  /// Runs this action and performs the clear secure storage operation.
  @override
  Future execute(BuildContext context, ScopeManager scopeManager,
      {DataContext? dataContext}) async {
    try {
      final evaluatedKey = scopeManager.dataContext.eval(key);
      final evaluatedAlgorithm =
          algorithm != null ? scopeManager.dataContext.eval(algorithm) : null;
      final evaluatedMode =
          mode != null ? scopeManager.dataContext.eval(mode) : null;
      
      // Create inputs in the format expected by EncryptedStorageManager
      final inputs = <String, dynamic>{'key': evaluatedKey};
      if (evaluatedAlgorithm != null) {
        inputs['algorithm'] = evaluatedAlgorithm;
      }
      if (evaluatedMode != null) {
        inputs['mode'] = evaluatedMode;
      }
      
      EncryptedStorageManager.clearSecureStorage(inputs);
      
      if (onComplete != null) {
        ScreenController().executeAction(context, onComplete!);
      }
    } catch (e) {
      if (onError != null) {
        ScreenController().executeAction(context, onError!,
            event: EnsembleEvent(null, error: e.toString()));
      }
    }
    return Future.value(null);
  }
}