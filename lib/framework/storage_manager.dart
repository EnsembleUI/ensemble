

import 'package:ensemble/OAuthController.dart';
import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_storage/get_storage.dart';

/// managing non-secure storage
/// TODO: consolidate secure storage
class StorageManager {
  static const systemStorageId = 'system';
  static const userProviderKey = 'user.provider';
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
  Future<void> updateAuthenticatedUser(BuildContext context, {required AuthenticatedUser user}) async {
    var systemStorage = GetStorage(systemStorageId);

    await systemStorage.write(userIdKey, user.id);
    await systemStorage.write(userProviderKey, user.provider);

    if (user.name != null) {
      await systemStorage.write(userNameKey, user.name);
      ScreenController().dispatchSystemStorageChanges(context, 'name', user.name,
          storagePrefix: 'user');
    } else if (systemStorage.hasData(userNameKey)) {
      await systemStorage.remove(userNameKey);
      ScreenController().dispatchSystemStorageChanges(context, 'name', null,
          storagePrefix: 'user');
    }

    if (user.email != null) {
      await systemStorage.write(userEmailKey, user.email);
      ScreenController().dispatchSystemStorageChanges(context, 'email', user.email,
          storagePrefix: 'user');
    } else if (systemStorage.hasData(userEmailKey)) {
      await systemStorage.remove(userEmailKey);
      ScreenController().dispatchSystemStorageChanges(context, 'email', null,
          storagePrefix: 'user');
    }

    if (user.photo != null) {
      await systemStorage.write(userPhotoKey, user.photo);
      ScreenController().dispatchSystemStorageChanges(context, 'photo', user.photo,
          storagePrefix: 'user');
    } else if (systemStorage.hasData(userPhotoKey)) {
      await systemStorage.remove(userPhotoKey);
      ScreenController().dispatchSystemStorageChanges(context, 'photo', null,
          storagePrefix: 'user');
    }
  }

  Future<void> clearAuthenticatedUser(BuildContext context) async {
    var systemStorage = GetStorage(systemStorageId);
    await systemStorage.remove(userIdKey);

    await systemStorage.remove(userNameKey);
    ScreenController().dispatchSystemStorageChanges(context, 'name', null,
        storagePrefix: 'user');

    await systemStorage.remove(userEmailKey);
    ScreenController().dispatchSystemStorageChanges(context, 'email', null,
        storagePrefix: 'user');

    await systemStorage.remove(userPhotoKey);
    ScreenController().dispatchSystemStorageChanges(context, 'photo', null,
        storagePrefix: 'user');
  }

  bool hasAuthenticatedUser() {
    return GetStorage(systemStorageId).hasData(userIdKey);
  }

  AuthenticatedUser? getAuthenticatedUser() {
    if (hasAuthenticatedUser()) {
      var systemStorage = GetStorage(systemStorageId);
      return AuthenticatedUser(
          provider: AuthProvider.values.from(systemStorage.read(userProviderKey)),
          id: systemStorage.read(userIdKey),
          name: systemStorage.read(userNameKey),
          email: systemStorage.read(userEmailKey),
          photo: systemStorage.read(userPhotoKey));
    }
    return null;
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

/// when a User is authenticated by one of the providers
class AuthenticatedUser with Invokable {
  AuthenticatedUser(
      {required provider, required this.id, this.name, this.email, this.photo})
      : _provider = provider;

  final AuthProvider _provider;

  String get provider => _provider.name;

  String? id;
  String? name;
  String? email;
  String? photo;

  @override
  Map<String, Function> getters() {
    return {
      'provider': () => provider,
      'id': () => id,
      'name': () => name,
      'email': () => email,
      'photo': () => photo
    };
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {};
  }
}


enum AuthProvider { google, apple, microsoft, custom }