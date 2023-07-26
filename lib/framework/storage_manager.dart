import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_storage/get_storage.dart';

/// managing 3 different storage solution
/// 1. secure storage (used by the framework for secure storage)
/// 2. system storage (used by the framework for non-sensitive storage)
/// 3. public storage (public storage for AppDevs)
class StorageManager with SystemStorage, PublicStorage, SecureStorage {
  static final StorageManager _instance = StorageManager._internal();
  StorageManager._internal();
  factory StorageManager() {
    return _instance;
  }

  /// initialize storage
  Future<void> init() async {
    await initSystemStorage();
    await initPublicStorage();
  }

}

/// These are non-secure system-level storage e.g. Authenticated User Info
mixin SystemStorage {
  static const _systemStorageId = 'system';
  late final GetStorage _systemStorage;

  initSystemStorage() async {
    await GetStorage.init(_systemStorageId);
    _systemStorage = GetStorage(_systemStorageId);
  }

  bool hasDataFromSystemStorage(String key) => _systemStorage.hasData(key);

  /// read from system storage
  T? readFromSystemStorage<T>(String key) => _systemStorage.read<T>(key);

  /// write to system storage
  Future<void> writeToSystemStorage(String key, dynamic value) =>
      _systemStorage.write(key, value);

  Future<void> removeFromSystemStorage(String key) => _systemStorage.remove(key);

  // for Preview mode or regular
  static const systemPreviewKey = 'system.preview';
  bool? isPreview() => _systemStorage.read<bool?>(systemPreviewKey);
  void setIsPreview(bool value) => _systemStorage.write(systemPreviewKey, value);


}

/// non-secure storage available to AppDevs
mixin PublicStorage {
  initPublicStorage() async {
    await GetStorage.init();
  }

  /// read from public storage
  T? read<T>(String key) => GetStorage().read<T>(key);

  /// write to public storage
  Future<void> write(String key, dynamic value) =>
      GetStorage().write(key, value);
}

/// secure storage. These are async so really only use-able
/// at the system-level (all our Javascript are synchronous)
mixin SecureStorage {
  static const secureStorage = FlutterSecureStorage();

  /// write to secure storage
  Future<void> writeSecurely({required String key, required String value}) =>
      secureStorage.write(key: key, value: value);

  /// read from secure storage
  Future<String?> readSecurely(String key) => secureStorage.read(key: key);
}