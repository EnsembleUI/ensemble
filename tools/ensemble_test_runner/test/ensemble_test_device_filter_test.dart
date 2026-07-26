import 'package:ensemble_test_runner/discovery/ensemble_test_discovery.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const android = TestDeviceTarget(
    id: 'android_nl',
    platform: 'android',
    model: 'Samsung Galaxy S20',
    locale: 'nl',
  );
  const iphone = TestDeviceTarget(
    id: 'iphone_en',
    platform: 'ios',
    model: 'iPhone 15 Pro',
    locale: 'en',
  );
  const config = EnsembleTestConfig(devices: [android, iphone]);

  test('empty selection keeps all devices', () {
    final filtered = EnsembleTestDiscovery.applyDeviceFilter(config, {});
    expect(filtered.devices.map((d) => d.id), ['android_nl', 'iphone_en']);
  });

  test('filters to a single device id', () {
    final filtered = EnsembleTestDiscovery.applyDeviceFilter(
      config,
      {'android_nl'},
    );
    expect(filtered.devices.map((d) => d.id), ['android_nl']);
  });

  test('preserves config order for multiple selected devices', () {
    final filtered = EnsembleTestDiscovery.applyDeviceFilter(
      config,
      {'iphone_en', 'android_nl'},
    );
    expect(filtered.devices.map((d) => d.id), ['android_nl', 'iphone_en']);
  });

  test('rejects unknown device ids', () {
    expect(
      () => EnsembleTestDiscovery.applyDeviceFilter(config, {'tablet'}),
      throwsA(
        isA<EnsembleTestFailure>().having(
          (e) => e.message,
          'message',
          contains('Unknown device id(s): tablet'),
        ),
      ),
    );
  });

  test('rejects --device when suite has no devices', () {
    expect(
      () => EnsembleTestDiscovery.applyDeviceFilter(
        const EnsembleTestConfig(),
        {'android_nl'},
      ),
      throwsA(isA<EnsembleTestFailure>()),
    );
  });
}
