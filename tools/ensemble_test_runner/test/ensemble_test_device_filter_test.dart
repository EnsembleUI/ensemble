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

  test('integration keeps locale/theme rows for the connected platform', () {
    final matrix = EnsembleTestDiscovery.resolveIntegrationDeviceMatrix(
      config,
      platform: 'ios',
    );
    expect(matrix.config.devices.map((d) => d.id), ['iphone_en']);
    expect(matrix.skipped.map((d) => d.id), ['android_nl']);
    expect(
      matrix.warnings.single,
      contains('Skipping suite device(s) that do not match the connected ios'),
    );
    expect(matrix.warnings.single, contains('android_nl'));
    expect(matrix.warnings.single, contains('iphone_en'));
  });

  test('integration treats iphone platform aliases as ios', () {
    const alias = TestDeviceTarget(
      id: 'phone',
      platform: 'iPhone',
      model: 'iPhone 15 Pro',
      locale: 'en',
    );
    final matrix = EnsembleTestDiscovery.resolveIntegrationDeviceMatrix(
      const EnsembleTestConfig(devices: [alias, android]),
      platform: 'ios',
    );
    expect(matrix.config.devices.map((d) => d.id), ['phone']);
  });

  test('integration drops the matrix when no devices match the target', () {
    final matrix = EnsembleTestDiscovery.resolveIntegrationDeviceMatrix(
      const EnsembleTestConfig(devices: [android]),
      platform: 'ios',
    );
    expect(matrix.config.devices, isEmpty);
    expect(
      matrix.warnings.single,
      contains('No suite devices match the connected ios target'),
    );
  });

  test('integration --device on the wrong platform fails', () {
    expect(
      () => EnsembleTestDiscovery.resolveIntegrationDeviceMatrix(
        config,
        platform: 'ios',
        selectedIds: {'android_nl'},
      ),
      throwsA(
        isA<EnsembleTestFailure>().having(
          (e) => e.message,
          'message',
          contains('--device did not match the connected ios target'),
        ),
      ),
    );
  });

  test('integration --device keeps matching ids and skips the rest', () {
    final matrix = EnsembleTestDiscovery.resolveIntegrationDeviceMatrix(
      config,
      platform: 'ios',
      selectedIds: {'iphone_en', 'android_nl'},
    );
    expect(matrix.config.devices.map((d) => d.id), ['iphone_en']);
    expect(matrix.skipped.map((d) => d.id), ['android_nl']);
  });
}
