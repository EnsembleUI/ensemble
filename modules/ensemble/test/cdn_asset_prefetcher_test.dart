import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:ensemble/framework/cdn_asset_cache.dart';
import 'package:ensemble/framework/cdn_asset_prefetcher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:yaml/yaml.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CdnAssetPrefetcher', () {
    test('prefetches static next-screen assets only', () async {
      final tempDir =
          await Directory.systemTemp.createTemp('cdn_asset_prefetcher_');
      final requestedAssets = <String>[];
      final assetBytes = {
        'current.png': utf8.encode('current screen asset'),
        'details.png': utf8.encode('details screen asset'),
        'sheet.png': utf8.encode('sheet screen asset'),
        'dynamic.png': utf8.encode('dynamic screen asset'),
      };
      final cache = CdnAssetCache(
        storageDirectoryProvider: () async => tempDir,
        httpGet: (uri, {headers}) async {
          final assetName = uri.pathSegments.last;
          requestedAssets.add(assetName);
          return http.Response.bytes(assetBytes[assetName]!, 200);
        },
      );

      try {
        await cache.initialize(
          appId: 'app-id',
          baseUrl: 'https://cdn.example.com/manifests/apps',
          headersProvider: () async => const {},
        );
        await cache.saveAssetManifest(_assetManifest({
          for (final entry in assetBytes.entries)
            entry.key: {
              'hash': sha256.convert(entry.value).toString(),
              'size': entry.value.length,
              'screens': switch (entry.key) {
                'current.png' => ['Home'],
                'details.png' => ['Details'],
                'sheet.png' => ['Sheet'],
                _ => ['Dynamic'],
              },
            },
        }));
        final prefetcher = CdnAssetPrefetcher(cache: cache);

        await prefetcher.prefetchNextScreenAssets(loadYaml(r'''
View:
  body:
    Column:
      children:
        - Button:
            onTap:
              navigateScreen: Details
        - Button:
            onTap:
              navigateModalScreen:
                name: Sheet
        - Button:
            onTap:
              navigateScreen:
                name: ${dynamicScreen}
''') as YamlMap);

        expect(requestedAssets, unorderedEquals(['details.png', 'sheet.png']));
        final cacheJson = jsonDecode(await _cacheFile(tempDir).readAsString());
        expect(
          cacheJson['assets']['details.png']['cache']['lastUsedAt'],
          isNull,
        );
        expect(
          cacheJson['assets']['sheet.png']['cache']['lastUsedAt'],
          isNull,
        );
        expect(
          cache.getCachedFileIfValid('details.png', updateLastUsed: false),
          isNotNull,
        );
        expect(
          cache.getCachedFileIfValid('sheet.png', updateLastUsed: false),
          isNotNull,
        );
        expect(cache.getCachedFileIfValid('current.png'), isNull);
        expect(cache.getCachedFileIfValid('dynamic.png'), isNull);
      } finally {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });

    test('waits for cache downloads to settle before prefetching', () async {
      final tempDir =
          await Directory.systemTemp.createTemp('cdn_asset_prefetcher_');
      final requestedAssets = <String>[];
      final busyDownload = Completer<void>();
      final secondBusyDownload = Completer<void>();
      final assetBytes = {
        'busy.png': utf8.encode('foreground asset'),
        'second_busy.png': utf8.encode('second foreground asset'),
        'details.png': utf8.encode('details screen asset'),
      };
      final cache = CdnAssetCache(
        storageDirectoryProvider: () async => tempDir,
        httpGet: (uri, {headers}) async {
          final assetName = uri.pathSegments.last;
          requestedAssets.add(assetName);
          if (assetName == 'busy.png') {
            await busyDownload.future;
          } else if (assetName == 'second_busy.png') {
            await secondBusyDownload.future;
          }
          return http.Response.bytes(assetBytes[assetName]!, 200);
        },
      );

      try {
        await cache.initialize(
          appId: 'app-id',
          baseUrl: 'https://cdn.example.com/manifests/apps',
          headersProvider: () async => const {},
        );
        await cache.saveAssetManifest(_assetManifest({
          for (final entry in assetBytes.entries)
            entry.key: {
              'hash': sha256.convert(entry.value).toString(),
              'size': entry.value.length,
              'screens': entry.key == 'details.png' ? ['Details'] : [],
            },
        }));

        final foregroundDownload = cache.resolve('busy.png');
        expect(cache.hasActiveDownloads, isTrue);

        final prefetcher = CdnAssetPrefetcher(cache: cache);
        final prefetch = prefetcher.prefetchNextScreenAssets(loadYaml('''
View:
  body:
    Button:
      onTap:
        navigateScreen: Details
''') as YamlMap);

        await Future<void>.delayed(Duration.zero);
        expect(requestedAssets, isNot(contains('details.png')));
        expect(cache.getCachedFileIfValid('details.png'), isNull);

        busyDownload.complete();
        final secondForegroundDownload = cache.resolve('second_busy.png');
        await foregroundDownload;

        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(requestedAssets, isNot(contains('details.png')));
        expect(cache.getCachedFileIfValid('details.png'), isNull);

        secondBusyDownload.complete();
        await secondForegroundDownload;
        await prefetch;

        expect(requestedAssets, contains('details.png'));
        expect(
          cache.getCachedFileIfValid('details.png', updateLastUsed: false),
          isNotNull,
        );
      } finally {
        if (!busyDownload.isCompleted) {
          busyDownload.complete();
        }
        if (!secondBusyDownload.isCompleted) {
          secondBusyDownload.complete();
        }
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });

    test('prefetches at most five discovered next screens', () async {
      final tempDir =
          await Directory.systemTemp.createTemp('cdn_asset_prefetcher_');
      final requestedAssets = <String>[];
      final assetBytes = {
        for (var index = 1; index <= 6; index++)
          'screen$index.png': utf8.encode('screen $index asset'),
      };
      final cache = CdnAssetCache(
        storageDirectoryProvider: () async => tempDir,
        httpGet: (uri, {headers}) async {
          final assetName = uri.pathSegments.last;
          requestedAssets.add(assetName);
          return http.Response.bytes(assetBytes[assetName]!, 200);
        },
      );

      try {
        await cache.initialize(
          appId: 'app-id',
          baseUrl: 'https://cdn.example.com/manifests/apps',
          headersProvider: () async => const {},
        );
        await cache.saveAssetManifest(_assetManifest({
          for (var index = 1; index <= 6; index++)
            'screen$index.png': {
              'hash':
                  sha256.convert(assetBytes['screen$index.png']!).toString(),
              'size': assetBytes['screen$index.png']!.length,
              'screens': ['Screen$index'],
            },
        }));
        final prefetcher = CdnAssetPrefetcher(cache: cache);

        await prefetcher.prefetchNextScreenAssets(loadYaml('''
View:
  body:
    Column:
      children:
${List.generate(6, (index) => '''
        - Button:
            onTap:
              navigateScreen: Screen${index + 1}
''').join()}
''') as YamlMap);

        expect(requestedAssets, hasLength(5));
        expect(requestedAssets, isNot(contains('screen6.png')));
      } finally {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });

    test('stops prefetching after the asset budget is exhausted', () async {
      final tempDir =
          await Directory.systemTemp.createTemp('cdn_asset_prefetcher_');
      final requestedAssets = <String>[];
      final assetBytes = {
        for (var index = 1; index <= 12; index++)
          'asset$index.png': utf8.encode('asset $index'),
      };
      final cache = CdnAssetCache(
        storageDirectoryProvider: () async => tempDir,
        httpGet: (uri, {headers}) async {
          final assetName = uri.pathSegments.last;
          requestedAssets.add(assetName);
          return http.Response.bytes(assetBytes[assetName]!, 200);
        },
      );

      try {
        await cache.initialize(
          appId: 'app-id',
          baseUrl: 'https://cdn.example.com/manifests/apps',
          headersProvider: () async => const {},
        );
        await cache.saveAssetManifest(_assetManifest({
          for (var index = 1; index <= 12; index++)
            'asset$index.png': {
              'hash': sha256.convert(assetBytes['asset$index.png']!).toString(),
              'size': assetBytes['asset$index.png']!.length,
              'screens': ['Details'],
            },
        }));
        final prefetcher = CdnAssetPrefetcher(cache: cache);

        await prefetcher.prefetchNextScreenAssets(loadYaml('''
View:
  body:
    Button:
      onTap:
        navigateScreen: Details
''') as YamlMap);

        expect(requestedAssets, hasLength(10));
        expect(requestedAssets, isNot(contains('asset11.png')));
        expect(requestedAssets, isNot(contains('asset12.png')));
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
        'screens': value['screens'],
      }),
    ),
  });
}

File _cacheFile(Directory root) =>
    File('${root.path}/asset_cache/asset-cache.json');
