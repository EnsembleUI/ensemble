import 'dart:convert';
import 'dart:developer';
import "package:universal_html/html.dart";
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ensemble/framework/apiproviders/firestore/firestore_types.dart';
import 'package:flutter/foundation.dart';
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
  T? read<T>(String key) =>
      restorePublicStorageValue(GetStorage().read<dynamic>(key)) as T?;

  /// write to public storage
  Future<void> write(String key, dynamic value) =>
      GetStorage().write(key, encodePublicStorageValue(value));

  Future<void> remove(String key) => GetStorage().remove(key);

  /// get all keys in public storage
  Iterable<String> getKeys() => GetStorage().getKeys();

  /// remove all public storage entries except those with the encrypted prefix
  Future<void> clearPublicStorage() async {
    const encryptedPrefix = 'enc_';
    final keys = GetStorage().getKeys().toList();
    await Future.wait([
      for (final key in keys)
        if (!key.startsWith(encryptedPrefix)) GetStorage().remove(key),
    ]);
  }
}

const String _storageValueTypeKey = '__ensemble_storage_value_type__';
const String _firestoreTimestampStorageType = 'firestore_timestamp_v1';

/// Encodes Firestore timestamps as tagged JSON maps so persistent storage can
/// serialize them without losing their type. Maps and lists are copied
/// recursively because Firestore values are commonly nested in cached data.
dynamic encodePublicStorageValue(dynamic value) {
  if (value is FirestoreTimestamp) {
    return _encodeFirestoreTimestamp(value.timestamp);
  }
  if (value is Timestamp) {
    return _encodeFirestoreTimestamp(value);
  }
  if (value is Map) {
    return value.map<dynamic, dynamic>(
      (key, nestedValue) => MapEntry<dynamic, dynamic>(
        key,
        encodePublicStorageValue(nestedValue),
      ),
    );
  }
  if (value is List) {
    return value.map(encodePublicStorageValue).toList();
  }
  return value;
}

/// Restores tagged Firestore timestamps whenever data is read from public
/// storage, including timestamps nested in maps and lists.
dynamic restorePublicStorageValue(dynamic value) {
  if (value is Map) {
    if (value.length == 3 &&
        value[_storageValueTypeKey] == _firestoreTimestampStorageType &&
        value['seconds'] is int &&
        value['nanoseconds'] is int) {
      return FirestoreTimestamp(
        Timestamp(value['seconds'] as int, value['nanoseconds'] as int),
      );
    }
    return value.map<dynamic, dynamic>(
      (key, nestedValue) => MapEntry<dynamic, dynamic>(
        key,
        restorePublicStorageValue(nestedValue),
      ),
    );
  }
  if (value is List) {
    return value.map(restorePublicStorageValue).toList();
  }
  return value;
}

Map<String, dynamic> _encodeFirestoreTimestamp(Timestamp timestamp) => {
      _storageValueTypeKey: _firestoreTimestampStorageType,
      'seconds': timestamp.seconds,
      'nanoseconds': timestamp.nanoseconds,
    };

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

Future<Map<String, dynamic>> getAllFromKeychain() async {
  Map<String, dynamic> result = {};

  if (kIsWeb) {
    try {
      // Get all localStorage keys that start with FlutterSecureStorage

      final storage = window.localStorage;
      final allKeys = storage.keys.where((key) => 
        key.startsWith('FlutterSecureStorage.') && 
        key != 'FlutterSecureStorage'
      );

      // Read each key using your working readSecurely method
      for (String fullKey in allKeys) {

        String actualKey = fullKey.replaceFirst('FlutterSecureStorage.', '');
        try {
          String? value = await secureStorage.read(key: actualKey);
          if (value != null) {
            result[actualKey] = value;
          }
        } catch (e) {
        }
      }
      
      return result;
    } catch (e) {
      log('Error reading from localStorage: $e');
      return result;
    }
  } else {
    // Mobile - use the original approach
    try {
      final allKeys = await secureStorage.readAll();
      for (String key in allKeys.keys) {
        dynamic value = await readSecurely(key);
        if (value != null) {
          result[key] = value;
        }
      }
      return result;
    } catch (e) {
      log('Error: $e');
      return result;
    }
  }
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
