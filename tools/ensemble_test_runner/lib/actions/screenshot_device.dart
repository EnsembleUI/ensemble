// Dart 3.8 reports deprecated_member_use at RegExp construction sites even though
// the deprecation is specifically about implementing RegExp. Keep construction compatible
// with this SDK without suppressing diagnostics in unrelated files.
// ignore_for_file: deprecated_member_use
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/src/integrations/device_preview/device_preview_adapter.dart';

DeviceInfo? screenshotDeviceForTestCase(
  EnsembleTestCase testCase,
  EnsembleTestConfig config,
) {
  final target = testCase.deviceTarget ??
      (config.devices.length == 1 ? config.devices.single : null);
  if (target != null) {
    return resolveScreenshotDevice(target.toScreenshotArgs());
  }
  if (config.screenshots.enabled) {
    // No suite devices configured — frame with the default iPhone.
    return resolveScreenshotDevice(const {});
  }
  return null;
}

DeviceInfo resolveScreenshotDevice(Map<String, dynamic> args) {
  final platform = args['platform']?.toString();
  final model = args['model']?.toString();
  final platformKey = normalizeScreenshotDeviceName(platform);
  final candidates = switch (platformKey) {
    'android' => DeviceCatalog.android,
    'ios' || 'iphone' || 'ipad' => DeviceCatalog.ios,
    _ => DeviceCatalog.all,
  };

  if (model != null && model.trim().isNotEmpty) {
    final modelKey = normalizeScreenshotDeviceName(model);
    for (final device in candidates) {
      if (normalizeScreenshotDeviceName(device.name) == modelKey ||
          normalizeScreenshotDeviceName(device.identifier.name) == modelKey) {
        return device;
      }
    }
    for (final device in candidates) {
      if (normalizeScreenshotDeviceName(device.name).contains(modelKey) ||
          normalizeScreenshotDeviceName(device.identifier.name)
              .contains(modelKey)) {
        return device;
      }
    }
    throw EnsembleTestFailure(
      'Unknown screenshot device model "$model". Available models: '
      '${candidates.map((device) => device.name).join(', ')}',
    );
  }

  if (platformKey == 'android') return DeviceCatalog.defaultAndroid;
  return DeviceCatalog.defaultIos;
}

String normalizeScreenshotDeviceName(String? value) =>
    (value ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
