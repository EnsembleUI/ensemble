import 'dart:io';

import 'package:ensemble/framework/cdn_asset_cache.dart';
import 'package:ensemble/framework/tv/apple_tv.dart';
import 'package:ensemble/framework/tv/apple_tv_cache_info_repository.dart';
import 'package:ensemble/widget/image.dart' show EnsembleImageCacheManager;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory support;
  late Directory caches;

  setUp(() async {
    support = await Directory.systemTemp.createTemp('ensemble-support-');
    caches = await Directory.systemTemp.createTemp('ensemble-caches-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      return call.method == 'getApplicationCacheDirectory'
          ? caches.path
          : support.path;
    });
  });

  tearDown(() async {
    debugIsAppleTVOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await support.delete(recursive: true);
    await caches.delete(recursive: true);
  });

  Future<void> initAssetCache() => CdnAssetCache().initialize(
        appId: 'app',
        baseUrl: 'https://cdn.example.com',
        headersProvider: () async => const {},
      );

  test('Apple TV keeps the CDN asset cache in Caches', () async {
    debugIsAppleTVOverride = true;
    await initAssetCache();

    expect(Directory('${caches.path}/asset_cache/assets').existsSync(), isTrue);
    expect(support.listSync(), isEmpty);
  });

  test('other platforms keep the CDN asset cache in Application Support',
      () async {
    debugIsAppleTVOverride = false;
    await initAssetCache();

    expect(
        Directory('${support.path}/asset_cache/assets').existsSync(), isTrue);
    expect(caches.listSync(), isEmpty);
  });

  // Creating a CacheManager opens its database, which needs sqflite, so this
  // checks the selection only.
  test('image cache database moves only on Apple TV', () {
    debugIsAppleTVOverride = false;
    expect(AppleTVCacheInfoRepository.forPlatform('key'), isNull);
    expect(EnsembleImageCacheManager.forPlatform, isNull);

    debugIsAppleTVOverride = true;
    expect(AppleTVCacheInfoRepository.forPlatform('key')?.databaseName, 'key');
  });
}
