import 'dart:convert';
import 'dart:io';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:ensemble/framework/definition_providers/cdn_provider.dart';
import 'package:ensemble/framework/tv/apple_tv.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/path_provider');
  final key = enc.Key.fromSecureRandom(32);
  late Directory cacheDir;

  setUp(() async {
    cacheDir = await Directory.systemTemp.createTemp('ensemble-cdn-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => cacheDir.path);
    debugIsAppleTVOverride = true;
    dotenv.loadFromString(envString: 'ENSEMBLE_ENCRYPTION_KEY=${key.base64}');
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    debugIsAppleTVOverride = null;
    dotenv.loadFromString(isOptional: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await cacheDir.delete(recursive: true);
  });

  File manifestFile(String appId) =>
      File('${cacheDir.path}/ensemble_cdn/$appId/manifest.json');

  test('stores the encrypted envelope and loads it back', () async {
    const appId = 'apple-tv-encrypted';
    final provider = CdnDefinitionProvider(appId);
    await provider.saveCachedStateForTesting(
      _manifestJson,
      etag: 'etag-a',
      lastUpdatedAt: 100,
      encryptedEnvelope: _envelope(_manifestJson, key),
    );

    final onDisk = manifestFile(appId).readAsStringSync();
    expect(onDisk, isNot(contains(_secretMarker)));
    expect(jsonDecode(onDisk), containsPair('ciphertext', isA<String>()));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('cdn_provider_state_$appId'),
        ['etag-a', '100', '']);

    final reloaded = CdnDefinitionProvider(appId);
    await reloaded.loadCachedStateForTesting();
    expect(reloaded.lastUpdatedAtForTesting, 100);
  });

  test('drops a plain cached copy when a key is configured', () async {
    const appId = 'apple-tv-plain';
    final provider = CdnDefinitionProvider(appId);
    await provider.saveCachedStateForTesting(
      _manifestJson,
      etag: 'etag-a',
      lastUpdatedAt: 100,
    );
    expect(manifestFile(appId).readAsStringSync(), contains(_secretMarker));

    final reloaded = CdnDefinitionProvider(appId);
    await reloaded.loadCachedStateForTesting();
    expect(reloaded.lastUpdatedAtForTesting, isNull);
    expect(manifestFile(appId).existsSync(), isFalse);
  });

  test('treats an envelope it cannot decrypt as no cache', () async {
    const appId = 'apple-tv-wrong-key';
    final provider = CdnDefinitionProvider(appId);
    await provider.saveCachedStateForTesting(
      _manifestJson,
      etag: 'etag-a',
      lastUpdatedAt: 100,
      encryptedEnvelope: _envelope(_manifestJson, enc.Key.fromSecureRandom(32)),
    );

    final reloaded = CdnDefinitionProvider(appId);
    await reloaded.loadCachedStateForTesting();
    expect(reloaded.lastUpdatedAtForTesting, isNull);
  });
}

const _secretMarker = 'not-a-real-secret-value';

final _manifestJson = jsonEncode({
  'artifacts': {
    'config': <String, dynamic>{},
    'screens': <dynamic>[],
    'theme': '',
    'widgets': <String, dynamic>{},
    'scripts': <String, dynamic>{},
    'actions': <dynamic>[],
    'translations': <dynamic>[],
    'secrets': {'SOME_KEY': _secretMarker},
  }
});

/// Builds an envelope in the CDN's encrypted-manifest format.
String _envelope(String plain, enc.Key key) {
  final iv = enc.IV.fromSecureRandom(12);
  final sealed = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm))
      .encryptBytes(utf8.encode(plain), iv: iv)
      .bytes;
  final cipher = sealed.sublist(0, sealed.length - 16);
  final tag = sealed.sublist(sealed.length - 16);
  return jsonEncode({
    'iv': base64.encode(iv.bytes),
    'tag': base64.encode(tag),
    'ciphertext': base64.encode(cipher),
  });
}
