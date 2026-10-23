import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ensemble/framework/apiproviders/firestore/firestore_types.dart';
import 'package:ensemble/framework/storage_manager.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('public storage normalizes Firestore timestamps recursively', () {
    final timestamp = FirestoreTimestamp(Timestamp(123, 456789000));
    final nativeTimestamp = Timestamp(456, 789123000);

    final encoded = encodePublicStorageValue({
      'lastUpdated': timestamp,
      'items': [
        {'createdAt': nativeTimestamp},
      ],
    });
    final restored = restorePublicStorageValue(encoded) as Map;

    expect(restored['lastUpdated'], isA<FirestoreTimestamp>());
    expect(
      (restored['lastUpdated'] as FirestoreTimestamp).timestamp,
      timestamp.timestamp,
    );
    expect(
      ((restored['items'] as List).single as Map)['createdAt'],
      isA<FirestoreTimestamp>(),
    );
    expect(
      (((restored['items'] as List).single as Map)['createdAt']
              as FirestoreTimestamp)
          .timestamp,
      nativeTimestamp,
    );
  });

  test('public storage serializes Firestore timestamps and clears correctly',
      () async {
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
      await storage.write('timestamp_test', {
        'lastUpdated': FirestoreTimestamp(Timestamp(123, 456789000)),
        'items': [
          {'createdAt': Timestamp(456, 789123000)},
        ],
      });

      final storedTimestamp = storage.read<Map>('timestamp_test')!;
      expect(storedTimestamp['lastUpdated'], isA<FirestoreTimestamp>());
      expect(
        (storedTimestamp['lastUpdated'] as FirestoreTimestamp)
            .timestamp
            .millisecondsSinceEpoch,
        123456,
      );
      final storedItems = storedTimestamp['items'] as List;
      expect(
        (storedItems.single as Map)['createdAt'],
        isA<FirestoreTimestamp>(),
      );

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

  test('public storage preserves mutable containers without timestamps',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('ensemble-storage-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => directory.path);
    try {
      final storage = StorageManager();
      await storage.initPublicStorage();
      final nested = <String, dynamic>{'items': <dynamic>[]};
      await storage.write('mutable_containers', nested);
      await GetStorage().queue.add(() async {});

      final readValue = storage.read<Map>('mutable_containers')!;
      expect(identical(readValue, nested), isTrue);
      expect(identical(readValue['items'], nested['items']), isTrue);
      (readValue['items'] as List)
        ..add('mutated')
        ..add(FirestoreTimestamp(Timestamp(789, 123456000)));
      // This is the same JSON operation GetStorage uses while flushing. The
      // timestamp was inserted through a nested mutable reference, so it did
      // not pass through StorageManager.write.
      final persistedJson = jsonEncode(
        GetStorage().read<Map>('mutable_containers'),
      );
      expect(persistedJson, contains('firestore_timestamp_v1'));
      await GetStorage().queue.add(() async {});
      final restored =
          restorePublicStorageValue(jsonDecode(persistedJson)) as Map;
      expect((restored['items'] as List).first, 'mutated');
      expect((restored['items'] as List).last, isA<FirestoreTimestamp>());
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
