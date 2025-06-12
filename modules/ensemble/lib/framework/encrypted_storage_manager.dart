import 'dart:convert';
import 'package:encrypt/encrypt.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble/framework/secrets.dart';
import 'package:ensemble/util/utils.dart';

class EncryptedStorageManager {
  static final EncryptedStorageManager _instance =
      EncryptedStorageManager._internal();
  static Key? _key;
  static Encrypter? _encrypter;
  static const String PREFIX = 'enc_';

  EncryptedStorageManager._internal();

  factory EncryptedStorageManager() => _instance;

  static void _ensureInitialized() {
    if (_encrypter != null) return;

    final keyString = SecretsStore().getProperty('encryptionKey');

    if (keyString == null) {
      throw LanguageError(
          'Encryption key not found in secrets. Please add "encryptionKey" to your secrets configuration.');
    }

    if (keyString.length != 32) {
      throw LanguageError(
          'Encryption key must be exactly 32 characters. Current length: ${keyString.length}');
    }

    _key = Key.fromUtf8(keyString);
    _encrypter = Encrypter(AES(_key!, mode: AESMode.cbc));
  }

  static void setSecureStorage(dynamic inputs) {
    String key;
    dynamic val;

    // Handle different input formats
    if (inputs is Map) {
      key = _extractKey(inputs, 'setSecureStorage');
      val = inputs['value'];

    } else if (inputs is String) {
      key = inputs;
      val = null;
    } else {
      throw LanguageError(
          'Invalid inputs for setSecureStorage. Expected Map or String.');
    }

    if (val == null) {
      StorageManager().remove(PREFIX + key);
      return;
    }



    try {
      final encryptedValue = _encryptValue(val);
      StorageManager().write(PREFIX + key, encryptedValue);
    } catch (e) {
      throw LanguageError('Failed to encrypt and store value: ${e.toString()}');
    }
  }

  static dynamic getSecureStorage(dynamic inputs) {
    final key = _extractKey(inputs, 'getSecureStorage');
    try {
      final storedValue = StorageManager().read(PREFIX + key);
      if (storedValue == null) return null;

      return _decryptValue(storedValue);
    } catch (e) {
      // Log error for debugging but return null to avoid breaking the app
      print('Error getting secure storage for key $key: $e');
      return null;
    }
  }

  static void clearSecureStorage(dynamic inputs) {
    final key = _extractKey(inputs, 'clearSecureStorage');
    StorageManager().remove(PREFIX + key);
  }

  // Utility function to extract key from various input formats
  static String _extractKey(dynamic inputs, String functionName) {
    String key;

    if (inputs is Map) {
      key = Utils.optionalString(inputs['key']) ?? '';
    } else if (inputs is String) {
      key = inputs;
    } else {
      throw LanguageError(
          'Invalid inputs for $functionName. Expected Map or String.');
    }

    if (key.isEmpty) {
      throw LanguageError('Storage key cannot be empty');
    }

    return key;
  }

  // Utility function to convert value to encrypted string
  static String _encryptValue(dynamic value) {
    _ensureInitialized();

    String plainText;
    if (value is String) {
      plainText = value;
    } else if (value is Map || value is List) {
      plainText = json.encode(value);
    } else {
      plainText = value.toString();
    }

    if (plainText.isEmpty) {
      plainText = " "; // Handle empty strings
    }

    final iv = IV.fromSecureRandom(16);
    final encrypted = _encrypter!.encrypt(plainText, iv: iv);
    return iv.base64 + ':' + encrypted.base64;
  }

  // Utility function to decrypt value from stored string
  static dynamic _decryptValue(String storedValue) {
    _ensureInitialized();

    final parts = storedValue.split(':');
    if (parts.length != 2) {
      // Invalid format, possibly corrupted data
      return null;
    }

    final iv = IV.fromBase64(parts[0]);
    final encrypted = Encrypted.fromBase64(parts[1]);

    final decrypted = _encrypter!.decrypt(encrypted, iv: iv);

    // Handle empty string placeholder
    if (decrypted == " ") {
      return "";
    }

    // Try to parse as JSON if it looks like JSON
    if ((decrypted.startsWith('{') && decrypted.endsWith('}')) ||
        (decrypted.startsWith('[') && decrypted.endsWith(']'))) {
      try {
        return json.decode(decrypted);
      } catch (e) {
        // Not valid JSON, return as string
      }
    }

    return decrypted;
  }
}
