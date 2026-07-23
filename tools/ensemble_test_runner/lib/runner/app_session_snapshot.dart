import 'dart:convert';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/storage_manager.dart';
import 'package:flutter/widgets.dart';

/// In-memory app state captured from a successful session-producing test.
class AppSessionSnapshot {
  final Map<String, dynamic> publicStorage;
  final Map<String, dynamic> keychain;
  final Locale? locale;

  const AppSessionSnapshot({
    required this.publicStorage,
    required this.keychain,
    this.locale,
  });

  static Future<AppSessionSnapshot> capture() async {
    final storage = StorageManager();
    final publicStorage = <String, dynamic>{};
    for (final key in storage.getKeys()) {
      publicStorage[key] = _copy(storage.read(key));
    }
    final keychain = await storage.getAllFromKeychain();
    return AppSessionSnapshot(
      publicStorage: publicStorage,
      keychain: {
        for (final entry in keychain.entries) entry.key: _copy(entry.value),
      },
      locale: Ensemble().getLocale(),
    );
  }

  Future<void> restore() async {
    final storage = StorageManager();
    await storage.clearPublicStorage();
    final currentKeychain = await storage.getAllFromKeychain();
    for (final key in currentKeychain.keys) {
      await storage.removeSecurely(key);
    }
    for (final entry in publicStorage.entries) {
      await storage.write(entry.key, _copy(entry.value));
    }
    for (final entry in keychain.entries) {
      await storage.writeSecurely(key: entry.key, value: _copy(entry.value));
    }
  }

  static dynamic _copy(dynamic value) {
    if (value == null || value is num || value is bool || value is String) {
      return value;
    }
    return jsonDecode(jsonEncode(value));
  }
}
