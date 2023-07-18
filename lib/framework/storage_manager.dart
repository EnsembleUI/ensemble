import 'package:ensemble/OAuthController.dart';
import 'package:ensemble/ensemble.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_storage/get_storage.dart';

/// managing non-secure storage
/// TODO: consolidate secure storage
class StorageManager {
  static const systemStorageId = 'system';
  static const userIdKey = 'user.id';
  static const userNameKey = 'user.name';
  static const userEmailKey = 'user.email';
  static const userPhotoKey = 'user.photo';
  static const systemPreviewKey =
      'system.preview'; // for Preview mode or regular

  static final StorageManager _instance = StorageManager._internal();
  StorageManager._internal();
  factory StorageManager() {
    return _instance;
  }

  Future<void> init() async {
    // system storage - only platform can write, readonly for app developers.
    await GetStorage.init(systemStorageId);

    // public storage for app developers
    await GetStorage.init();
  }

  /// read/write will always be from public storage
  T? read<T>(String key) => GetStorage().read<T>(key);
  Future<void> write(String key, dynamic value) =>
      GetStorage().write(key, value);

  /// User object is from system storage
  /// TODO: BuildContext is used for dispatching changes. Should be refactored.
  void updateUser(BuildContext context, String id,
      {String? name, String? email, String? photo}) {
    var systemStorage = GetStorage(systemStorageId);

    systemStorage.write(userIdKey, id);

    if (name != null) {
      systemStorage.write(userNameKey, name);
      ScreenController().dispatchSystemStorageChanges(context, 'name', name,
          storagePrefix: 'user');
    } else if (systemStorage.hasData(userNameKey)) {
      systemStorage.remove(userNameKey);
      ScreenController().dispatchSystemStorageChanges(context, 'name', null,
          storagePrefix: 'user');
    }

    if (email != null) {
      systemStorage.write(userEmailKey, email);
      ScreenController().dispatchSystemStorageChanges(context, 'email', email,
          storagePrefix: 'user');
    } else if (systemStorage.hasData(userEmailKey)) {
      systemStorage.remove(userEmailKey);
      ScreenController().dispatchSystemStorageChanges(context, 'email', null,
          storagePrefix: 'user');
    }

    if (photo != null) {
      systemStorage.write(userPhotoKey, photo);
      ScreenController().dispatchSystemStorageChanges(context, 'photo', photo,
          storagePrefix: 'user');
    } else if (systemStorage.hasData(userPhotoKey)) {
      systemStorage.remove(userPhotoKey);
      ScreenController().dispatchSystemStorageChanges(context, 'photo', null,
          storagePrefix: 'user');
    }
  }

  String? getUserId() => GetStorage(systemStorageId).read(userIdKey);
  String? getUserName() => GetStorage(systemStorageId).read(userNameKey);
  String? getUserEmail() => GetStorage(systemStorageId).read(userEmailKey);
  String? getUserPhoto() => GetStorage(systemStorageId).read(userPhotoKey);

  bool? isPreview() =>
      GetStorage(systemStorageId).read<bool?>(systemPreviewKey);
  void setIsPreview(bool value) =>
      GetStorage(systemStorageId).write(systemPreviewKey, value);

  /// Secure Storage section

  Future<void> updateServiceTokens(ServiceName serviceName, String accessToken,
      {String? refreshToken}) async {
    const secureStorage = FlutterSecureStorage();
    await secureStorage.write(
        key: '${serviceName.name}_accessToken', value: accessToken);
    if (refreshToken != null) {
      await secureStorage.write(
          key: '${serviceName.name}_refreshToken', value: refreshToken);
    }
  }

  Future<OAuthServiceToken?> getServiceTokens(ServiceName serviceName) async {
    const secureStorage = FlutterSecureStorage();
    String? accessToken =
        await secureStorage.read(key: '${serviceName.name}_accessToken');
    if (accessToken != null) {
      return OAuthServiceToken(
          accessToken: accessToken,
          refreshToken: await secureStorage.read(
              key: '${serviceName.name}_refreshToken'));
    }
  }
}
