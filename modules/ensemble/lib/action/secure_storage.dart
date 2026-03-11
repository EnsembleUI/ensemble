import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/encrypted_storage_manager.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:flutter/material.dart';

class SetSecureStorage extends EnsembleAction {
  SetSecureStorage({
    required this.key,
    this.value,
    this.algorithm,
    this.mode,
    this.onComplete,
    this.onError,
  });

  final String key;
  final dynamic value;
   // Optional encryption configuration
  final String? algorithm;
  final String? mode;
  final EnsembleAction? onComplete;
  final EnsembleAction? onError;

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

class GetSecureStorage extends EnsembleAction {
  GetSecureStorage({
    required this.key,
    this.algorithm,
    this.mode,
    this.onComplete,
    this.onError,
  });

  final String key;
  final String? algorithm;
  final String? mode;
  final EnsembleAction? onComplete;
  final EnsembleAction? onError;

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

class ClearSecureStorage extends EnsembleAction {
  ClearSecureStorage({
    required this.key,
    this.algorithm,
    this.mode,
    this.onComplete,
    this.onError,
  });

  final String key;
  final String? algorithm;
  final String? mode;
  final EnsembleAction? onComplete;
  final EnsembleAction? onError;

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