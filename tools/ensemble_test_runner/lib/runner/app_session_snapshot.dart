import 'dart:convert';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/storage_manager.dart';
import 'package:flutter/widgets.dart';

/// In-memory app state captured from a successful session-producing test.
class AppSessionSnapshot {
  final Map<String, dynamic> publicStorage;
  final Map<String, dynamic> secureStorage;
  final Map<String, dynamic> keychain;
  final Locale? locale;

  const AppSessionSnapshot({
    required this.publicStorage,
    required this.secureStorage,
    required this.keychain,
    this.locale,
  });

  static Future<AppSessionSnapshot> capture() async {
    final storage = StorageManager();
    final publicStorage = <String, dynamic>{};
    final secureStorage = <String, dynamic>{};
    for (final key in storage.getKeys()) {
      if (key.startsWith('enc_')) {
        secureStorage[key] = _copy(storage.read(key));
      } else {
        publicStorage[key] = _copy(storage.read(key));
      }
    }
    final keychain = await storage.getAllFromKeychain();
    return AppSessionSnapshot(
      publicStorage: publicStorage,
      secureStorage: secureStorage,
      keychain: {
        for (final entry in keychain.entries) entry.key: _copy(entry.value),
      },
      locale: Ensemble().getLocale(),
    );
  }

  Future<void> restore() async {
    await restoreOnto(StorageManager());
  }

  /// Replaces current storage with this snapshot's contents.
  ///
  /// Failures after the clear phase rethrow a [StateError] naming which phase
  /// failed (`clear` vs `rewrite`) so callers never see a half-restored device.
  Future<void> restoreOnto(StorageManager storage) async {
    await runRestorePhases(
      clear: () async {
        await storage.clearPublicStorage();
        for (final key in storage
            .getKeys()
            .where((key) => key.startsWith('enc_'))
            .toList()) {
          await storage.remove(key);
        }
        final currentKeychain = await storage.getAllFromKeychain();
        for (final key in currentKeychain.keys) {
          await storage.removeSecurely(key);
        }
      },
      rewrite: () async {
        for (final entry in publicStorage.entries) {
          await storage.write(entry.key, _copy(entry.value));
        }
        for (final entry in secureStorage.entries) {
          await storage.write(entry.key, _copy(entry.value));
        }
        for (final entry in keychain.entries) {
          await storage.writeSecurely(
            key: entry.key,
            value: _copy(entry.value),
          );
        }
      },
    );
  }

  /// Runs clear then rewrite, wrapping failures with a phase-named [StateError].
  @visibleForTesting
  static Future<void> runRestorePhases({
    required Future<void> Function() clear,
    required Future<void> Function() rewrite,
  }) async {
    try {
      await clear();
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        StateError(
          'AppSessionSnapshot restore failed during clear phase: $error',
        ),
        stackTrace,
      );
    }
    try {
      await rewrite();
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        StateError(
          'AppSessionSnapshot restore failed during rewrite phase: $error',
        ),
        stackTrace,
      );
    }
  }

  static dynamic _copy(dynamic value) {
    if (value == null || value is num || value is bool || value is String) {
      return value;
    }
    return jsonDecode(jsonEncode(value));
  }
}
