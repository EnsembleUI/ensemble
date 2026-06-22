import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:ensemble/framework/cdn_asset_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  group('CdnAssetCache', () {
    test('ignores assets that are not listed in asset manifest', () async {
      final tempDir = await Directory.systemTemp.createTemp('cdn_asset_cache_');
      var requestCount = 0;
      final cache = CdnAssetCache(
        storageDirectoryProvider: () async => tempDir,
        httpGet: (uri, {headers}) async {
          requestCount++;
          return http.Response.bytes(const [], 404);
        },
      );

      try {
        await cache.initialize(
          appId: 'app-id',
          baseUrl: 'https://cdn.example.com/manifests/apps',
          headersProvider: () async => const {},
        );
        await cache.saveAssetManifest(_assetManifest({}));

        final file = await cache.resolve('https://cdn.example.com/logo.png');

        expect(file, isNull);
        expect(requestCount, 0);
      } finally {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });

    test('dedupes downloads and reuses valid cached files', () async {
      final tempDir = await Directory.systemTemp.createTemp('cdn_asset_cache_');
      final bytes = utf8.encode('cached image bytes');
      final hash = sha256.convert(bytes).toString();
      var requestCount = 0;
      final cache = CdnAssetCache(
        storageDirectoryProvider: () async => tempDir,
        httpGet: (uri, {headers}) async {
          requestCount++;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return http.Response.bytes(bytes, 200);
        },
      );

      try {
        await cache.initialize(
          appId: 'app-id',
          baseUrl: 'https://cdn.example.com/manifests/apps',
          headersProvider: () async => const {'X-Test': '1'},
        );
        await cache.saveAssetManifest(_assetManifest({
          'logo.png': {'hash': hash, 'size': bytes.length},
        }));
        expect(_cacheFile(tempDir).existsSync(), isTrue);

        final files = await Future.wait([
          cache.resolve('https://cdn.example.com/assets/logo.png'),
          cache.resolve('https://cdn.example.com/assets/logo.png'),
          cache.resolve('https://cdn.example.com/assets/logo.png'),
        ]);

        expect(files.whereType<File>(), hasLength(3));
        expect(files.map((file) => file?.path).toSet(), hasLength(1));
        expect(requestCount, 1);
        expect(await files.first!.readAsBytes(), bytes);
        final cacheJson = jsonDecode(await _cacheFile(tempDir).readAsString());
        expect(cacheJson['assets']['logo.png']['hash'], hash);
        expect(cacheJson['assets']['logo.png']['cache']['downloadedAt'],
            isA<int>());

        final cachedFile = cache
            .getCachedFileIfValid('https://cdn.example.com/assets/logo.png');
        expect(cachedFile, isNotNull);

        final secondResolve =
            await cache.resolve('https://cdn.example.com/assets/logo.png');
        expect(secondResolve?.path, files.first?.path);
        expect(requestCount, 1);
      } finally {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });

    test('resolves assets by file name for shared Utils callers', () async {
      final tempDir = await Directory.systemTemp.createTemp('cdn_asset_cache_');
      final bytes = utf8.encode('filename lookup bytes');
      final hash = sha256.convert(bytes).toString();
      var requestedUri = '';
      final cache = CdnAssetCache(
        storageDirectoryProvider: () async => tempDir,
        httpGet: (uri, {headers}) async {
          requestedUri = uri.toString();
          return http.Response.bytes(bytes, 200);
        },
      );

      try {
        await cache.initialize(
          appId: 'app-id',
          baseUrl: 'https://cdn.example.com/manifests/apps',
          headersProvider: () async => const {},
        );
        await cache.saveAssetManifest(_assetManifest({
          'logo.png': {'hash': hash, 'size': bytes.length},
        }));

        expect(cache.isEligible('logo.png'), isTrue);

        final file = await cache.resolve('logo.png');

        expect(file, isNotNull);
        expect(requestedUri,
            'https://cdn.example.com/manifests/apps/app-id/assets/logo.png');
        expect(cache.getCachedFileIfValid('logo.png')?.path, file?.path);
        expect(cache.getCachedFileForBundleKey(file!.path)?.path, file.path);
      } finally {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });

    test('loads saved manifest on initialize', () async {
      final tempDir = await Directory.systemTemp.createTemp('cdn_asset_cache_');
      final bytes = utf8.encode('saved manifest bytes');
      final hash = sha256.convert(bytes).toString();

      try {
        final firstCache = CdnAssetCache(
          storageDirectoryProvider: () async => tempDir,
          httpGet: (uri, {headers}) async => http.Response.bytes(bytes, 200),
        );
        await firstCache.initialize(
          appId: 'app-id',
          baseUrl: 'https://cdn.example.com/manifests/apps',
          headersProvider: () async => const {},
        );
        await firstCache.saveAssetManifest(_assetManifest({
          'logo.png': {'hash': hash, 'size': bytes.length},
        }));

        final secondCache = CdnAssetCache(
          storageDirectoryProvider: () async => tempDir,
          httpGet: (uri, {headers}) async => http.Response.bytes(bytes, 200),
        );
        await secondCache.initialize(
          appId: 'app-id',
          baseUrl: 'https://cdn.example.com/manifests/apps',
          headersProvider: () async => const {},
        );

        expect(secondCache.hasAssetManifest, isTrue);
        expect(secondCache.isEligible('logo.png'), isTrue);
      } finally {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });

    test('removes stale cache temp files on initialize', () async {
      final tempDir = await Directory.systemTemp.createTemp('cdn_asset_cache_');
      final staleTempFile = File(
        '${tempDir.path}/asset_cache/asset-cache.json.tmp-123',
      );
      final cache = CdnAssetCache(
        storageDirectoryProvider: () async => tempDir,
        httpGet: (uri, {headers}) async => http.Response.bytes(const [], 404),
      );

      try {
        await staleTempFile.parent.create(recursive: true);
        await staleTempFile.writeAsString('{}');
        expect(await staleTempFile.exists(), isTrue);

        await cache.initialize(
          appId: 'app-id',
          baseUrl: 'https://cdn.example.com/manifests/apps',
          headersProvider: () async => const {},
        );

        expect(await staleTempFile.exists(), isFalse);
      } finally {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });

    test('accepts numeric manifest fields encoded as strings', () async {
      final manifest = CdnAssetManifest.fromJsonString(jsonEncode({
        'updatedAt': '1718380800000',
        'assets': {
          'logo.png': {
            'hash': 'abc123',
            'contentType': 'image/png',
            'size': '42',
            'updatedAt': '1718370000000',
          },
        },
      }));

      expect(manifest.assets.keys, contains('logo.png'));
      expect(manifest.assets['logo.png']?.size, 42);
      expect(manifest.assets['logo.png']?.updatedAt, 1718370000000);
    });

    test('caches asset when manifest size is stale but hash matches', () async {
      final tempDir = await Directory.systemTemp.createTemp('cdn_asset_cache_');
      final bytes = utf8.encode('asset bytes with stale manifest size');
      final hash = sha256.convert(bytes).toString();
      var requestCount = 0;
      final cache = CdnAssetCache(
        storageDirectoryProvider: () async => tempDir,
        httpGet: (uri, {headers}) async {
          requestCount++;
          return http.Response.bytes(bytes, 200);
        },
      );

      try {
        await cache.initialize(
          appId: 'app-id',
          baseUrl: 'https://cdn.example.com/manifests/apps',
          headersProvider: () async => const {},
        );
        await cache.saveAssetManifest(_assetManifest({
          'logo.png': {'hash': hash, 'size': bytes.length + 100},
        }));

        final file = await cache.resolve('logo.png');

        expect(file, isNotNull);
        expect(await file!.readAsBytes(), bytes);
        expect(cache.getCachedFileIfValid('logo.png')?.path, file.path);

        final secondResolve = await cache.resolve('logo.png');
        expect(secondResolve?.path, file.path);
        expect(requestCount, 1);
      } finally {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });

    test('caches served asset when manifest size and hash are stale', () async {
      final tempDir = await Directory.systemTemp.createTemp('cdn_asset_cache_');
      final bytes = utf8.encode('served CDN bytes');
      final staleManifestHash =
          sha256.convert(utf8.encode('old bytes')).toString();
      var requestCount = 0;
      final cache = CdnAssetCache(
        storageDirectoryProvider: () async => tempDir,
        httpGet: (uri, {headers}) async {
          requestCount++;
          return http.Response.bytes(bytes, 200);
        },
      );

      try {
        await cache.initialize(
          appId: 'app-id',
          baseUrl: 'https://cdn.example.com/manifests/apps',
          headersProvider: () async => const {},
        );
        await cache.saveAssetManifest(_assetManifest({
          'logo.png': {'hash': staleManifestHash, 'size': bytes.length + 100},
        }));

        final file = await cache.resolve('logo.png');

        expect(file, isNotNull);
        expect(await file!.readAsBytes(), bytes);
        expect(cache.getCachedFileIfValid('logo.png')?.path, file.path);

        final secondResolve = await cache.resolve('logo.png');
        expect(secondResolve?.path, file.path);
        expect(requestCount, 1);
      } finally {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });

    test('removes cached files when manifest hash changes', () async {
      final tempDir = await Directory.systemTemp.createTemp('cdn_asset_cache_');
      final originalBytes = utf8.encode('original bytes');
      final originalHash = sha256.convert(originalBytes).toString();
      final updatedHash =
          sha256.convert(utf8.encode('updated bytes')).toString();
      final cache = CdnAssetCache(
        storageDirectoryProvider: () async => tempDir,
        httpGet: (uri, {headers}) async =>
            http.Response.bytes(originalBytes, 200),
      );

      try {
        await cache.initialize(
          appId: 'app-id',
          baseUrl: 'https://cdn.example.com/manifests/apps',
          headersProvider: () async => const {},
        );
        await cache.saveAssetManifest(_assetManifest({
          'logo.png': {'hash': originalHash, 'size': originalBytes.length},
        }));

        final file =
            await cache.resolve('https://cdn.example.com/assets/logo.png');
        expect(await file!.exists(), isTrue);

        await cache.saveAssetManifest(_assetManifest({
          'logo.png': {'hash': updatedHash, 'size': originalBytes.length},
        }));

        expect(await file.exists(), isFalse);
        expect(
          cache.getCachedFileIfValid('https://cdn.example.com/assets/logo.png'),
          isNull,
        );
      } finally {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });
  });
}

String _assetManifest(Map<String, Map<String, Object>> assets) {
  return jsonEncode({
    'updatedAt': 1718380800000,
    'assets': assets.map(
      (key, value) => MapEntry(key, {
        'hash': value['hash'],
        'contentType': 'image/png',
        'size': value['size'],
        'updatedAt': 1718370000000,
      }),
    ),
  });
}

File _cacheFile(Directory root) =>
    File('${root.path}/asset_cache/asset-cache.json');
