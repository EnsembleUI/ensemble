import 'dart:math';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:cryptography/cryptography.dart';
import 'package:ensemble_walletconnect/src/crypto/cipher_box.dart';
import 'package:ensemble_walletconnect/src/crypto/encrypted_payload.dart';
import 'package:ensemble_walletconnect/src/exceptions/wallet_connect_exception.dart';

/// WalletConnect protocol implementation of the encryption/decryption
/// algorithms
class WalletConnectCipher implements CipherBox {
  /// Encrypt the data with the given key, and an optional nonce.
  @override
  Future<EncryptedPayload> encrypt({
    required Uint8List data,
    required Uint8List key,
    Uint8List? iv,
  }) async {
    // AES-CBC with 265 bit keys and HMAC-SHA256 authentication.
    final algorithm = AesCbc.with256bits(macAlgorithm: MacAlgorithm.empty);
    final secretKey = SecretKey(List<int>.unmodifiable(key));
    final nonce = Uint8List.fromList(iv ?? algorithm.newNonce());

    // Encrypt the data
    final box = await algorithm.encrypt(
      data,
      secretKey: secretKey,
      nonce: nonce,
    );

    final hmac = Hmac.sha256();
    final payload = Uint8List.fromList([...box.cipherText, ...box.nonce]);
    final mac = await hmac.calculateMac(payload, secretKey: secretKey);

    return EncryptedPayload(
      data: hex.encode(box.cipherText),
      hmac: hex.encode(mac.bytes),
      iv: hex.encode(box.nonce),
    );
  }

  /// Decrypt the payload with the given key.
  /// This also verifies the hmac.
  @override
  Future<Uint8List> decrypt({
    required EncryptedPayload payload,
    required Uint8List key,
  }) async {
    // Verify hmac
    final verified = await verifyHmac(payload: payload, key: key);
    if (!verified) {
      throw WalletConnectException('Invalid HMAC');
    }

    final cipherText = hex.decode(payload.data);
    final nonce = hex.decode(payload.iv);

    // Decrypt the payload
    final algorithm = AesCbc.with256bits(macAlgorithm: MacAlgorithm.empty);
    final box = SecretBox(cipherText, nonce: nonce, mac: Mac.empty);
    final secretKey = SecretKey(List<int>.unmodifiable(key));
    final data = await algorithm.decrypt(box, secretKey: secretKey);
    return Uint8List.fromList(data);
  }

  /// Verify the hmac and returns true if valid.
  @override
  Future<bool> verifyHmac({
    required EncryptedPayload payload,
    required Uint8List key,
  }) async {
    final cipherText = Uint8List.fromList(hex.decode(payload.data));
    final iv = Uint8List.fromList(hex.decode(payload.iv));
    final unsigned = Uint8List.fromList([...cipherText, ...iv]);

    final hmacsha256 = Hmac.sha256();
    final secretKey = SecretKey(List<int>.unmodifiable(key));
    final chmac = await hmacsha256.calculateMac(unsigned, secretKey: secretKey);

    return hex.encode(chmac.bytes) == payload.hmac;
  }

  /// Generate a new random, cryptographically secure key.
  @override
  Future<Uint8List> generateKey({int length = 32, Random? random}) async {
    var r = random ?? Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (i) => r.nextInt(256)),
    );
  }
}
