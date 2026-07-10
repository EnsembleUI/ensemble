import 'package:ensemble_test_runner/actions/screenshot_device.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolves screenshot model by platform and model name', () {
    final device = resolveScreenshotDevice({
      'deviceFrame': true,
      'platform': 'android',
      'model': 'Samsung Galaxy S20',
    });

    expect(device.name, 'Samsung Galaxy S20');
  });

  test('finds the first framed screenshot in test steps', () {
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
              'deviceFrame': true,
              'platform': 'ios',
              'model': 'iPhone 15 Pro',
            },
          ),
        ],
      ),
    ]);

    expect(device?.name, 'iPhone 15 Pro');
  });

  test('ignores screenshots without a device frame', () {
    final device = firstScreenshotDevice([
      const TestStep(
        type: 'screenshot',
        args: {'name': 'plain'},
      ),
    ]);

    expect(device, isNull);
  });
}
