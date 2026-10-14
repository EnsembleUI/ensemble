import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/screenshot_device_target.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the report default when screenshots are enabled', () {
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'device', steps: []),
      config: const EnsembleTestConfig(
        screenshots: ScreenshotConfig(enabled: true),
      ),
    );

    expect(screenshotDeviceTargetFor(context)?.id, 'ios');
  });

  test('prefers an explicit test device', () {
    const device = TestDeviceTarget(
      id: 'android',
      platform: 'android',
      model: 'Pixel',
    );
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'device', deviceTarget: device, steps: []),
      config: const EnsembleTestConfig(),
    );

    expect(screenshotDeviceTargetFor(context), same(device));
  });
}
