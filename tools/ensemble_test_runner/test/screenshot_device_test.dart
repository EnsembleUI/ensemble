import 'package:ensemble_test_runner/actions/screenshot_device.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolves screenshot model by platform and model name', () {
    final device = resolveScreenshotDevice({
      'platform': 'android',
      'model': 'Samsung Galaxy S20',
    });

    expect(device.name, 'Samsung Galaxy S20');
  });

  test('defaults screenshot device to iPhone 15 Pro', () {
    final device = resolveScreenshotDevice({});

    expect(device.name, 'iPhone 15 Pro');
  });

  test('uses suite devices when screenshots enabled', () {
    final device = screenshotDeviceForTestCase(
      const EnsembleTestCase(
        id: 'screenshots',
        startScreen: 'Home',
        steps: [
          TestStep(type: 'tap', args: {'id': 'button'}),
        ],
      ),
      const EnsembleTestConfig(
        screenshots: ScreenshotConfig(enabled: true),
        devices: [
          TestDeviceTarget(
            id: 'android',
            platform: 'android',
            model: 'Samsung Galaxy S20',
          ),
        ],
      ),
    );

    expect(device?.name, 'Samsung Galaxy S20');
  });

  test('uses per-test deviceTarget over suite devices', () {
    final device = screenshotDeviceForTestCase(
      const EnsembleTestCase(
        id: 'screenshots[android_nl]',
        startScreen: 'Home',
        steps: [
          TestStep(type: 'tap', args: {'id': 'button'}),
        ],
        deviceTarget: TestDeviceTarget(
          id: 'android_nl',
          platform: 'android',
          model: 'Samsung Galaxy S20',
          locale: 'nl',
        ),
      ),
      const EnsembleTestConfig(
        screenshots: ScreenshotConfig(enabled: true),
        devices: [
          TestDeviceTarget(
            id: 'iphone',
            platform: 'ios',
            model: 'iPhone 15 Pro',
          ),
        ],
      ),
    );

    expect(device?.name, 'Samsung Galaxy S20');
  });
}
