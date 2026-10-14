import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/parser/config_target_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('parses device ids from platform and locale', () {
    final devices = ConfigTargetParser.parseDevices(loadYaml('''
- platform: ios
  model: iPhone 15
  locale: en-US
- platform: android
  model: Pixel 8
'''));

    expect(devices.map((device) => device.id), ['ios_en_us', 'android_1']);
    expect(devices.first.theme, isNull);
  });

  test('parses service defaults and environment', () {
    final services = ConfigTargetParser.parseServices(loadYaml('''
- name: api
  command: node
  arguments: [server.js]
  environment:
    PORT: 8080
'''));

    expect(services.single, isA<TestServiceConfig>());
    expect(services.single.readyTimeoutMs, 10000);
    expect(services.single.environment['PORT'], '8080');
  });

  test('rejects duplicate device ids', () {
    expect(
      () => ConfigTargetParser.parseDevices(loadYaml('''
- id: phone
  platform: ios
  model: iPhone 15
- id: phone
  platform: android
  model: Pixel 8
''')),
      throwsA(isA<EnsembleTestFailure>()),
    );
  });
}
