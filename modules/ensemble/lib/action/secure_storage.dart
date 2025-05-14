import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/encrypted_storage_manager.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:flutter/material.dart';
import 'package:ensemble/util/utils.dart';

class SetSecureStorage extends EnsembleAction {
  SetSecureStorage({
    required this.key,
    this.value,
    this.onComplete,
    this.onError,
  });

  final String key;
  final dynamic value;
  final EnsembleAction? onComplete;
  final EnsembleAction? onError;

  factory SetSecureStorage.fromYaml({Map? payload}) {
    if (payload == null || payload['key'] == null) {
      throw ConfigError('setSecureStorage requires a key.');
    }
    return SetSecureStorage(
      key: payload['key'],
      value: payload['value'],
      onComplete: EnsembleAction.from(payload['onComplete']),
      onError: EnsembleAction.from(payload['onError']),
    );
  }

  @override
  Future execute(BuildContext context, ScopeManager scopeManager,
      {DataContext? dataContext}) async {
    try {
      final evaluatedKey = scopeManager.dataContext.eval(key);
      final evaluatedValue = scopeManager.dataContext.eval(value);
      
      // Create inputs in the format expected by EncryptedStorageManager
      final inputs = {
        'key': evaluatedKey,
        'value': evaluatedValue,
      };
      
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

class GetSecureStorage extends EnsembleAction {
  GetSecureStorage({
    required this.key,
    this.onSuccess,
    this.onError,
  });

  final String key;
  final EnsembleAction? onSuccess;
  final EnsembleAction? onError;

  factory GetSecureStorage.fromYaml({Map? payload}) {
    if (payload == null || payload['key'] == null) {
      throw ConfigError('getSecureStorage requires a key.');
    }
    return GetSecureStorage(
      key: payload['key'],
      onSuccess: EnsembleAction.from(payload['onSuccess']),
      onError: EnsembleAction.from(payload['onError']),
    );
  }

  @override
  Future execute(BuildContext context, ScopeManager scopeManager,
      {DataContext? dataContext}) async {
    try {
      final evaluatedKey = scopeManager.dataContext.eval(key);
      
      // Create inputs in the format expected by EncryptedStorageManager
      final inputs = {'key': evaluatedKey};
      
      final value = EncryptedStorageManager.getSecureStorage(inputs);
      
      if (onSuccess != null) {
        ScreenController().executeAction(context, onSuccess!,
            event: EnsembleEvent(null, data: value));
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

class ClearSecureStorage extends EnsembleAction {
  ClearSecureStorage({
    required this.key,
    this.onComplete,
    this.onError,
  });

  final String key;
  final EnsembleAction? onComplete;
  final EnsembleAction? onError;

  factory ClearSecureStorage.fromYaml({Map? payload}) {
    if (payload == null || payload['key'] == null) {
      throw ConfigError('clearSecureStorage requires a key.');
    }
    return ClearSecureStorage(
      key: payload['key'],
      onComplete: EnsembleAction.from(payload['onComplete']),
      onError: EnsembleAction.from(payload['onError']),
    );
  }

  @override
  Future execute(BuildContext context, ScopeManager scopeManager,
      {DataContext? dataContext}) async {
    try {
      final evaluatedKey = scopeManager.dataContext.eval(key);
      
      // Create inputs in the format expected by EncryptedStorageManager
      final inputs = {'key': evaluatedKey};
      
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