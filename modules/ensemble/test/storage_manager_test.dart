import 'package:flutter_test/flutter_test.dart';

void main() {
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
