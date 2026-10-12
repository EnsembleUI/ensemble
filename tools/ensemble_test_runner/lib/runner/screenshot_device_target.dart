import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';

/// Resolves the device descriptor used by screenshot reports across runner
/// and application-host execution paths.
TestDeviceTarget? screenshotDeviceTargetFor(EnsembleTestContext context) {
  final target = context.testCase.deviceTarget;
  if (target != null) return target;
  if (context.config.devices.length == 1) return context.config.devices.single;
  if (!context.config.screenshots.enabled) return null;
  return const TestDeviceTarget(
    id: 'ios',
    platform: 'ios',
    model: 'iPhone 15 Pro',
  );
}
