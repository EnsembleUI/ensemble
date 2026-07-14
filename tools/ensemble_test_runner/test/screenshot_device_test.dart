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

  test('uses suite screenshot config device when enabled', () {
    final device = screenshotDeviceForTestCase(
      const EnsembleTestCase(
        id: 'screenshots',
        startScreen: 'Home',
        steps: [
          TestStep(type: 'tap', args: {'id': 'button'}),
        ],
      ),
      const EnsembleTestConfig(
        screenshots: ScreenshotConfig(
          enabled: true,
          platform: 'android',
          model: 'Samsung Galaxy S20',
        ),
      ),
    );

    expect(device?.name, 'Samsung Galaxy S20');
  });

  test('uses suite record config device when enabled', () {
    final device = screenshotDeviceForTestCase(
      const EnsembleTestCase(
        id: 'recording',
        startScreen: 'Home',
        steps: [
          TestStep(type: 'tap', args: {'id': 'button'}),
        ],
      ),
      const EnsembleTestConfig(
        record: RecordConfig(
          enabled: true,
          platform: 'android',
          model: 'Samsung Galaxy S20',
        ),
      ),
    );

    expect(device?.name, 'Samsung Galaxy S20');
  });
}
