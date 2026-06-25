import 'dart:convert';
import 'dart:typed_data';

import 'package:ensemble/framework/assets_service.dart';
import 'package:ensemble/framework/dotenv_bundle.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
    LocalAssetsService.localAssets = [];
  });

  group('LocalAssetsService.mergeAssetEnvVariables', () {
    test('keeps app config env variables when there are no asset env sources',
        () {
      expect(
        LocalAssetsService.mergeAssetEnvVariables(
          {
            'remoteLogo': 'https://example.com/logo.png',
            'emptyPrefix': null,
          },
          const [],
        ),
        {
          'remoteLogo': 'https://example.com/logo.png',
          'emptyPrefix': null,
        },
      );
    });

    test('asset env sources override app config env variables', () {
      expect(
        LocalAssetsService.mergeAssetEnvVariables(
          {'logo': 'https://example.com/logo.png'},
          [
            {'logo': 'logo.png'},
          ],
        ),
        {'logo': 'logo.png'},
      );
    });

    test('later asset env sources override earlier ones', () {
      expect(
        LocalAssetsService.mergeAssetEnvVariables(
          {'logo': 'https://example.com/logo.png'},
          [
            {'logo': 'local-logo.png'},
            {'logo': 'bundled-logo.png'},
            {'icon': 'icon.png'},
          ],
        ),
        {
          'logo': 'bundled-logo.png',
          'icon': 'icon.png',
        },
      );
    });

    test('merges parsed dotenv asset content', () {
      expect(
        LocalAssetsService.mergeAssetEnvVariables(
          {'logo': 'https://example.com/logo.png'},
          [
            parseDotEnvBundleContent('''
logo=local-logo.png
icon="icons/app icon.png"
'''),
          ],
        ),
        {
          'logo': 'local-logo.png',
          'icon': 'icons/app icon.png',
        },
      );
    });
  });

  group('LocalAssetsService.initialize', () {
    test('loads .env.assets into provided env variables', () async {
      const String path = 'ensemble/apps/helloApp';
      final Map<String, String> assets = {
        '$path/.env.assets': '''
assets=
logo_svg=logo.svg
''',
        '$path/assets/logo.svg': '<svg></svg>',
      };

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (ByteData? message) async {
        final String key = utf8.decode(message!.buffer.asUint8List());
        final String? asset = assets[key];
        if (asset == null) {
          return null;
        }
        final Uint8List encoded = Uint8List.fromList(utf8.encode(asset));
        return ByteData.sublistView(encoded);
      });

      final Map<String, dynamic> envVariables = {
        'apiURL': 'https://dummyjson.com',
      };
      final YamlMap definitions = loadYaml('''
definitions:
  from: local
  local:
    path: $path
''');

      await LocalAssetsService.initialize(envVariables, definitions);

      expect(envVariables, {
        'apiURL': 'https://dummyjson.com',
        'assets': '',
        'logo_svg': 'logo.svg',
      });
      expect(LocalAssetsService.localAssets, contains('logo.svg'));
    });

    test('does not mutate env variables when .env.assets is missing', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (_) async => null);

      final Map<String, dynamic> envVariables = {
        'apiURL': 'https://dummyjson.com',
      };
      final YamlMap definitions = loadYaml('''
definitions:
  from: local
  local:
    path: ensemble/apps/missingAssetsApp
''');

      await LocalAssetsService.initialize(envVariables, definitions);

      expect(envVariables, {'apiURL': 'https://dummyjson.com'});
      expect(LocalAssetsService.localAssets, isEmpty);
    });
  });
}
