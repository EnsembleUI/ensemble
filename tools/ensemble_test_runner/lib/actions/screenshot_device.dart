import 'package:ensemble_device_preview/ensemble_device_preview.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';

DeviceInfo? firstScreenshotDevice(List<TestStep> steps) {
  for (final step in steps) {
    final device = screenshotDeviceForStep(step);
    if (device != null) return device;

    final nestedDevice = firstScreenshotDevice(step.nestedSteps);
    if (nestedDevice != null) return nestedDevice;
  }
  return null;
}

DeviceInfo? screenshotDeviceForStep(TestStep step) {
  if (step.type != 'screenshot' || step.args['deviceFrame'] != true) {
    return null;
  }
  return resolveScreenshotDevice(step.args);
}

DeviceInfo resolveScreenshotDevice(Map<String, dynamic> args) {
  final platform = args['platform']?.toString();
  final model = args['model']?.toString();
  final platformKey = normalizeScreenshotDeviceName(platform);
  final candidates = switch (platformKey) {
    'android' => Devices.android.all,
    'ios' || 'iphone' || 'ipad' => Devices.ios.all,
    _ => Devices.all,
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

  if (platformKey == 'android') return Devices.android.all.first;
  return Devices.ios.iPhone13;
}

String normalizeScreenshotDeviceName(String? value) =>
    (value ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
