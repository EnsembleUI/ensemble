import 'package:ensemble_device_preview/ensemble_device_preview.dart';
import 'package:ensemble_test_runner/actions/screenshot_device.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'integration mode keeps the physical display when screenshots are enabled',
    (tester) async {
      final originalSize = tester.view.physicalSize;
      final originalDpr = tester.view.devicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.binding.setSurfaceSize(null);
      });

      final harness = EnsembleTestHarness(
        appPath: 'unused',
        appHome: 'Home',
        executionMode: ExecutionMode.integration,
      );
      final ctx = EnsembleTestContext.fromTestCase(
        const EnsembleTestCase(
          id: 'hello',
          startScreen: 'Hello Home',
          steps: [],
        ),
        config: const EnsembleTestConfig(
          screenshots: ScreenshotConfig(enabled: true),
        ),
      );

      await harness.applyViewport(
        tester,
        ctx,
        screenshotDevice: screenshotDeviceForTestCase(
          ctx.testCase,
          ctx.config,
        ),
      );

      expect(tester.view.physicalSize, originalSize);
      expect(tester.view.devicePixelRatio, originalDpr);
      expect(
        ctx.runtime.deviceSize,
        Size(
          originalSize.width / originalDpr,
          originalSize.height / originalDpr,
        ),
      );
    },
  );

  testWidgets(
    'integration mode ignores suite device viewports',
    (tester) async {
      final originalSize = tester.view.physicalSize;
      final originalDpr = tester.view.devicePixelRatio;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.binding.setSurfaceSize(null);
      });

      const iphone = TestDeviceTarget(
        id: 'iphone',
        platform: 'ios',
        model: 'iPhone 15 Pro',
        locale: 'en',
        theme: 'dark',
      );
      final harness = EnsembleTestHarness(
        appPath: 'unused',
        appHome: 'Home',
        executionMode: ExecutionMode.integration,
      );
      final ctx = EnsembleTestContext.fromTestCase(
        const EnsembleTestCase(
          id: 'hello[iphone]',
          startScreen: 'Hello Home',
          steps: [],
          deviceTarget: iphone,
        ),
        config: const EnsembleTestConfig(
          devices: [iphone],
          screenshots: ScreenshotConfig(enabled: true),
        ),
      );

      await harness.applyViewport(
        tester,
        ctx,
        screenshotDevice: screenshotDeviceForTestCase(
          ctx.testCase,
          ctx.config,
        ),
      );

      expect(tester.view.physicalSize, originalSize);
      expect(tester.view.devicePixelRatio, originalDpr);
    },
  );

  testWidgets(
    'widget mode still applies the screenshot device viewport',
    (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.binding.setSurfaceSize(null);
      });

      final harness = EnsembleTestHarness(
        appPath: 'unused',
        appHome: 'Home',
      );
      final ctx = EnsembleTestContext.fromTestCase(
        const EnsembleTestCase(
          id: 'hello',
          startScreen: 'Hello Home',
          steps: [],
        ),
        config: const EnsembleTestConfig(
          screenshots: ScreenshotConfig(enabled: true),
        ),
      );
      final device = screenshotDeviceForTestCase(ctx.testCase, ctx.config);
      expect(device, isNotNull);
      expect(device!.name, Devices.ios.iPhone15Pro.name);

      await harness.applyViewport(
        tester,
        ctx,
        screenshotDevice: device,
      );

      expect(tester.view.physicalSize, device.screenSize);
      expect(tester.view.devicePixelRatio, 1.0);
      expect(ctx.runtime.deviceSize, device.screenSize);
    },
  );
}
