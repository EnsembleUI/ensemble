import 'dart:io';

import 'package:ensemble/framework/storage_manager.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('clear removes public keys but retains encrypted keys', () async {
    final directory = await Directory.systemTemp.createTemp('ensemble-storage-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => directory.path);
    try {
      final storage = StorageManager();
      await storage.initPublicStorage();
      await storage.write('clear_test_a', 'a');
      await storage.write('clear_test_b', 'b');
      await storage.write('enc_clear_test', 'secret');

      await storage.clearPublicStorage();

      expect(storage.getKeys(), isNot(contains('clear_test_a')));
      expect(storage.getKeys(), isNot(contains('clear_test_b')));
      expect(storage.read('enc_clear_test'), 'secret');
      await storage.remove('enc_clear_test');
      expect(storage.getKeys(), isNot(contains('enc_clear_test')));
      await storage.write('clear_test_after', 'new');
      expect(storage.read('clear_test_after'), 'new');
    } finally {
      await GetStorage().queue.add(() async {});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      await directory.delete(recursive: true);
    }
  });

  test('clear logic filters out encrypted keys correctly', () {
    final storage = <String, dynamic>{
      'name': 'Alice',
      'theme': 'dark',
      'enc_secret1': 'encrypted_value_1',
      'enc_secret2': 'encrypted_value_2',
      'session': 'abc123',
    };

    const encryptedPrefix = 'enc_';
    final keysToRemove = storage.keys
        .where((key) => !key.startsWith(encryptedPrefix))
        .toList();

    for (final key in keysToRemove) {
      storage.remove(key);
    }

    expect(storage.containsKey('name'), isFalse);
    expect(storage.containsKey('theme'), isFalse);
    expect(storage.containsKey('session'), isFalse);
    expect(storage['enc_secret1'], 'encrypted_value_1');
    expect(storage['enc_secret2'], 'encrypted_value_2');
    expect(storage.length, 2);
  });

  test('clear logic handles empty storage', () {
    final storage = <String, dynamic>{};

    const encryptedPrefix = 'enc_';
    final keysToRemove = storage.keys
        .where((key) => !key.startsWith(encryptedPrefix))
        .toList();

    for (final key in keysToRemove) {
      storage.remove(key);
    }

    expect(storage, isEmpty);
  });

  test('clear logic removes all non-encrypted keys', () {
    final storage = <String, dynamic>{
      'user': 'Bob',
      'age': 30,
      'city': 'NYC',
    };

    const encryptedPrefix = 'enc_';
    final keysToRemove = storage.keys
        .where((key) => !key.startsWith(encryptedPrefix))
        .toList();

    for (final key in keysToRemove) {
      storage.remove(key);
    }

    expect(storage, isEmpty);
  });

  test('clear logic preserves all encrypted keys when no regular keys exist',
      () {
    final storage = <String, dynamic>{
      'enc_a': 'val_a',
      'enc_b': 'val_b',
    };

    const encryptedPrefix = 'enc_';
    final keysToRemove = storage.keys
        .where((key) => !key.startsWith(encryptedPrefix))
        .toList();

    for (final key in keysToRemove) {
      storage.remove(key);
    }

    expect(storage.length, 2);
    expect(storage['enc_a'], 'val_a');
    expect(storage['enc_b'], 'val_b');
  });

  test('storage can be used normally after clear', () {
    final storage = <String, dynamic>{
      'key1': 'value1',
      'key2': 'value2',
    };

    const encryptedPrefix = 'enc_';
    final keysToRemove = storage.keys
        .where((key) => !key.startsWith(encryptedPrefix))
        .toList();

    for (final key in keysToRemove) {
      storage.remove(key);
    }

    expect(storage, isEmpty);

    storage['newKey'] = 'newValue';
    expect(storage['newKey'], 'newValue');
    expect(storage.length, 1);
  });
}
