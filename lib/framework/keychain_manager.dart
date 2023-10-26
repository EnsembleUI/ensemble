import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/storage_manager.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class KeychainManager {
  static final KeychainManager _instance = KeychainManager._internal();

  KeychainManager._internal();

  factory KeychainManager() {
    return _instance;
  }

  Future<void> saveToKeychain(String key, dynamic value,
      {Map<dynamic, dynamic>? inputs}) async {
    try {
      final groupId = inputs?['groupId'] as String?;
      final iOSOptions = groupId != null ? IOSOptions(groupId: groupId) : null;
      await StorageManager().writeSecurely(
          key: key, value: value.toString(), iosOptions: iOSOptions);
    } catch (e) {
      throw LanguageError('Failed to store value. Reason: ${e.toString()}');
    }
  }

  Future<void> clearKeychain(String key,
      {Map<dynamic, dynamic>? inputs}) async {
    try {
      final groupId = inputs?['groupId'] as String?;
      final iOSOptions = groupId != null ? IOSOptions(groupId: groupId) : null;
      await StorageManager().remove(key, iosOptions: iOSOptions);
    } catch (e) {
      throw LanguageError(
          'Failed to remove value with the key - $key. Reason: ${e.toString()}');
    }
  }
}
