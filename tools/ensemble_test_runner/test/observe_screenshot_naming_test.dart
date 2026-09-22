import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/session/observation/observe_screenshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inspectUiScreenshotBasename uses screen_theme_language', () {
    expect(
      inspectUiScreenshotBasename(
        screen: 'Hello Home',
        theme: 'light',
        locale: 'nl',
      ),
      'Hello_Home_light_nl',
    );
    expect(
      inspectUiScreenshotBasename(screen: 'Login'),
      'Login_default_default',
    );
    expect(
      inspectUiScreenshotBasename(
        screen: 'Login',
        theme: 'Dark',
        locale: 'en_US',
        deviceId: 'iphone_dark',
        includeDeviceId: true,
      ),
      'Login_Dark_en_US_iphone_dark',
    );
  });

  test('resolveInspectUiDevices skips matrix without screenshots', () {
    const configured = [
      TestDeviceTarget(id: 'a', platform: 'ios', model: 'iPhone 15 Pro'),
      TestDeviceTarget(id: 'b', platform: 'ios', model: 'iPhone 15 Pro'),
    ];
    expect(
      resolveInspectUiDevices(configured).map((d) => d.id),
      ['a'],
    );
    expect(
      resolveInspectUiDevices(configured, forScreenshots: true)
          .map((d) => d.id),
      ['a', 'b'],
    );
  });
}
