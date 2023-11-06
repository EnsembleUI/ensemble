import 'dart:convert';

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

  bool initialized = false;

  /// initialize storage
  Future<void> init() async {
    if (!initialized) {
      await initSystemStorage();
      await initPublicStorage();
      initialized = true;
    }
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

  Future<void> removeFromSystemStorage(String key) =>
      _systemStorage.remove(key);

  // for Preview mode or regular
  static const systemPreviewKey = 'system.preview';

  bool? isPreview() => _systemStorage.read<bool?>(systemPreviewKey);

  void setIsPreview(bool value) =>
      _systemStorage.write(systemPreviewKey, value);
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

  Future<void> remove(String key) => GetStorage().remove(key);
}

/// secure storage. These are async so really only use-able
/// at the system-level (all our Javascript are synchronous)
/// Note that secure storage operates on String, but we automatically
/// encode/decode to support different types
mixin SecureStorage {
  static const secureStorage = FlutterSecureStorage();

  /// write to secure storage
  Future<void> writeSecurely({required String key, required dynamic value}) {
    String actualValue = value is Map ? json.encode(value) : value.toString();
    return secureStorage.write(key: key, value: actualValue);
  }

  /// remove from secure storage
  Future<void> removeSecurely(String key) => secureStorage.delete(key: key);

  /// read from secure storage
  Future<dynamic> readSecurely(String key) async {
    String? value = await secureStorage.read(key: key);
    return value != null ? _decode(value) : null;
  }

  dynamic _decode(String value) {
    // decode json
    if ((value.startsWith('{') && value.endsWith('}')) ||
        (value.startsWith('[')) && value.endsWith(']')) {
      try {
        return json.decode(value);
      } catch (e) {
        // do nothing
      }
    }
    return value;
  }
}
