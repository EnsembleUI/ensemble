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

  test('finds the first screenshot in test steps', () {
    final device = firstScreenshotDevice([
      const TestStep(type: 'tap', args: {'id': 'open'}),
      const TestStep(
        type: 'group',
        args: {},
        nestedSteps: [
          TestStep(
            type: 'screenshot',
            args: {
              'name': 'home',
            },
          ),
        ],
      ),
    ]);

    expect(device?.name, 'iPhone 15 Pro');
  });

  test('ignores tests without screenshots', () {
    final device = firstScreenshotDevice([
      const TestStep(
        type: 'tap',
        args: {'id': 'button'},
      ),
    ]);

    expect(device, isNull);
  });

  test('uses screenshot options device when enabled', () {
    final device = screenshotDeviceForTestCase(
      const EnsembleTestCase(
        id: 'screenshots',
        startScreen: 'Home',
        steps: [
          TestStep(type: 'tap', args: {'id': 'button'}),
        ],
        options: EnsembleTestOptions(
          screenshots: ScreenshotOptions(
            enabled: true,
            platform: 'android',
            model: 'Samsung Galaxy S20',
          ),
        ),
      ),
    );

    expect(device?.name, 'Samsung Galaxy S20');
  });
}
