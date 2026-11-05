import 'dart:convert';
import 'dart:typed_data';

import 'package:ensemble/ensemble.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const appPath = 'ensemble/apps/sample';
  final assets = <String, String>{};

  setUp(() {
    assets.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (ByteData? message) async {
      final key = utf8.decode(message!.buffer.asUint8List());
      final value = assets[key];
      return value == null
          ? null
          : ByteData.sublistView(Uint8List.fromList(utf8.encode(value)));
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });

  test('loads appConfig.json when local path has no trailing slash', () async {
    assets['$appPath/config/appConfig.json'] = json.encode({
      'envVariables': {'assetPrefix': 'from-json'},
    });
    assets['$appPath/.env.config'] = 'apiUrl=https://from-env.invalid';

    final config = loadYaml('''
definitions:
  from: local
  local:
    path: $appPath
''') as YamlMap;

    final overrides = await Ensemble().loadEnvironmentOverrides(config);

    expect(overrides['assetPrefix'], 'from-json');
    expect(overrides['apiUrl'], 'https://from-env.invalid');
  });
}
