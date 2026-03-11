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
  static const String PREFIX = 'enc_';

  EncryptedStorageManager._internal();

  factory EncryptedStorageManager() => _instance;

  static void _ensureInitialized() {
    if (_key != null) return;

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
  }

  static void setSecureStorage(dynamic inputs) {
    String key;
    dynamic val;
    String? algorithm;
    String? mode;

    // Handle different input formats
    if (inputs is Map) {
      key = _extractKey(inputs, 'setSecureStorage');
      val = inputs['value'];
      algorithm = Utils.optionalString(inputs['algorithm']);
      mode = Utils.optionalString(inputs['mode']);
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
      final encryptedValue =
          _encryptValue(val, algorithm: algorithm, mode: mode);
      StorageManager().write(PREFIX + key, encryptedValue);
    } catch (e) {
      throw LanguageError('Failed to encrypt and store value: ${e.toString()}');
    }
  }

  static dynamic getSecureStorage(dynamic inputs) {
    String? algorithm;
    String? mode;
    final key = _extractKey(inputs, 'getSecureStorage');
    if (inputs is Map) {
      algorithm = Utils.optionalString(inputs['algorithm']);
      mode = Utils.optionalString(inputs['mode']);
    }
    try {
      final storedValue = StorageManager().read(PREFIX + key);
      if (storedValue == null) return null;

      return _decryptValue(storedValue, algorithm: algorithm, mode: mode);
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

  // Utility function to convert value to encrypted string.
  //
  // Supported algorithms (case-insensitive):
  // - "aes"     (default; supports modes below)
  // - "salsa20"
  // - "fernet"
  //
  // Supported AES modes (case-insensitive, defaults to "cbc"):
  // - cbc
  // - cfb64
  // - ctr
  // - ecb
  // - ofb64gctr
  // - ofb64
  // - sic
  // - gcm
  static String _encryptValue(dynamic value,
      {String? algorithm, String? mode}) {
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

    final selectedAlgorithm = (algorithm ?? 'aes').toLowerCase();

    Encrypted encrypted;
    String modeString = '';
    String ivBase64 = '';

    if (selectedAlgorithm == 'aes') {
      final aesMode = _parseAesMode(mode);
      final iv = IV.fromSecureRandom(16);
      final encrypter = Encrypter(AES(_key!, mode: aesMode));
      encrypted = encrypter.encrypt(plainText, iv: iv);
      modeString = _aesModeToConfigString(aesMode);
      ivBase64 = iv.base64;
    } else if (selectedAlgorithm == 'salsa20') {
      // Salsa20 uses an 8-byte IV/nonce.
      final iv = IV.fromSecureRandom(8);
      final encrypter = Encrypter(Salsa20(_key!));
      encrypted = encrypter.encrypt(plainText, iv: iv);
      modeString = 'default';
      ivBase64 = iv.base64;
    } else if (selectedAlgorithm == 'fernet') {
      // Fernet manages IV internally; we don't need to store an IV.
      final encrypter = Encrypter(Fernet(_key!));
      encrypted = encrypter.encrypt(plainText);
      modeString = 'default';
      ivBase64 = '';
    } else {
      throw LanguageError(
          'Unsupported encryption algorithm. Supported algorithms are: aes, salsa20, fernet.');
    }

    // New self-describing format:
    // enc:v1:<algorithm>:<mode>:<ivBase64>:<cipherBase64>
    return 'enc:v1:$selectedAlgorithm:$modeString:$ivBase64:${encrypted.base64}';
  }

  // Utility function to decrypt value from stored string
  static dynamic _decryptValue(String storedValue,
      {String? algorithm, String? mode}) {
    _ensureInitialized();

    String decrypted;

    if (storedValue.startsWith('enc:v1:')) {
      // New-format value: enc:v1:<algorithm>:<mode>:<ivBase64>:<cipherBase64>
      final parts = storedValue.split(':');
      if (parts.length != 6) {
        // Invalid format, possibly corrupted data
        return null;
      }

      final storedAlgorithm = parts[2];
      final storedMode = parts[3];
      final ivBase64 = parts[4];
      final cipherBase64 = parts[5];

      // Decide which algorithm to use for decryption:
      // - If the value carries an algorithm, that is the source of truth.
      // - If the caller also passed an algorithm and it conflicts, fail fast.
      // - If the value does not carry an algorithm (shouldn't happen for v1),
      //   fall back to the caller's algorithm or "aes".
      String selectedAlgorithm;
      if (storedAlgorithm.isNotEmpty) {
        selectedAlgorithm = storedAlgorithm.toLowerCase();
        if (algorithm != null && algorithm.toLowerCase() != selectedAlgorithm) {
          throw LanguageError(
              'Configured algorithm does not match stored algorithm for this value.');
        }
      } else {
        selectedAlgorithm = (algorithm ?? 'aes').toLowerCase();
      }
      final effectiveMode = storedMode.isNotEmpty ? storedMode : mode;

      final encrypted = Encrypted.fromBase64(cipherBase64);

      if (selectedAlgorithm == 'aes') {
        final aesMode = _parseAesMode(effectiveMode);
        if (ivBase64.isEmpty) {
          // Missing IV for AES is invalid.
          return null;
        }
        final iv = IV.fromBase64(ivBase64);
        final encrypter = Encrypter(AES(_key!, mode: aesMode));
        decrypted = encrypter.decrypt(encrypted, iv: iv);
      } else if (selectedAlgorithm == 'salsa20') {
        if (ivBase64.isEmpty) {
          // Missing IV/nonce for Salsa20 is invalid.
          return null;
        }
        final iv = IV.fromBase64(ivBase64);
        final encrypter = Encrypter(Salsa20(_key!));
        decrypted = encrypter.decrypt(encrypted, iv: iv);
      } else if (selectedAlgorithm == 'fernet') {
        final encrypter = Encrypter(Fernet(_key!));
        decrypted = encrypter.decrypt(encrypted);
      } else {
        // Unknown algorithm for secure storage
        return null;
      }
    } else {
      // Legacy format: <ivBase64>:<cipherBase64>, assumed AES-CBC
      final parts = storedValue.split(':');
      if (parts.length != 2) {
        // Invalid format, possibly corrupted data
        return null;
      }

      final iv = IV.fromBase64(parts[0]);
      final encrypted = Encrypted.fromBase64(parts[1]);
      final encrypter = Encrypter(AES(_key!, mode: AESMode.cbc));
      decrypted = encrypter.decrypt(encrypted, iv: iv);
    }

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

  static AESMode _parseAesMode(String? input) {
    final value = (input ?? 'cbc').toLowerCase();
    switch (value) {
      case 'cbc':
        return AESMode.cbc;
      case 'cfb64':
        return AESMode.cfb64;
      case 'ctr':
        return AESMode.ctr;
      case 'ecb':
        return AESMode.ecb;
      case 'ofb64gctr':
      case 'ofb-64/gctr':
        return AESMode.ofb64Gctr;
      case 'ofb64':
      case 'ofb-64':
        return AESMode.ofb64;
      case 'sic':
        return AESMode.sic;
      case 'gcm':
        return AESMode.gcm;
      default:
        throw LanguageError(
            'Unsupported AES mode "$input". Supported modes are: cbc, cfb64, ctr, ecb, ofb64gctr, ofb64, sic, gcm.');
    }
  }

  static String _aesModeToConfigString(AESMode mode) {
    switch (mode) {
      case AESMode.cbc:
        return 'cbc';
      case AESMode.cfb64:
        return 'cfb64';
      case AESMode.ctr:
        return 'ctr';
      case AESMode.ecb:
        return 'ecb';
      case AESMode.ofb64Gctr:
        return 'ofb64gctr';
      case AESMode.ofb64:
        return 'ofb64';
      case AESMode.sic:
        return 'sic';
      case AESMode.gcm:
        return 'gcm';
    }
  }
}
