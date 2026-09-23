import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble_test_runner/actions/extended_step_handlers.dart';
import 'package:ensemble_test_runner/actions/screenshot_device.dart';
import 'package:ensemble_test_runner/mocks/test_logger.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/reporters/step_outline_format.dart';
import 'package:ensemble_test_runner/runner/debug_artifact_logs.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/live_async_call.dart';
import 'package:ensemble_test_runner/runner/screenshot_sheet_aggregator.dart';
import 'package:ensemble_test_runner/runner/storage_step_diff.dart';
import 'package:ensemble_test_runner/runner/test_runtime_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// True when a screenshot diagnostic should never fail the host test.
bool isHostScreenshotDiagnostic(Object? error) {
  final text = error?.toString() ?? '';
  return text
          .contains('Screenshot skipped because secure content is visible') ||
      text.contains('screenshot requires a painted render view');
}

/// Raster / encode failures from host screenshot capture (not app crashes).
bool isHostScreenshotCaptureFailure(Object? error) {
  final text = error?.toString() ?? '';
  return text.contains('toImageSync') ||
      text.contains('RenderRepaintBoundary') ||
      text.contains('debugNeedsPaint') ||
      text.contains('Cannot capture screenshot');
}

/// Captures one report frame for a host YAML step.
///
/// Failures here must not change the test result — the HTML gallery is
/// diagnostic, not an assertion. [SecureScreenshotPolicy.skip] throws when a
/// password field is on screen; that is swallowed here.
Future<void> captureHostStepScreenshot({
  required WidgetTester tester,
  required EnsembleTestContext context,
  required TestStep step,
  required int stepIndex,
}) async {
  if (!context.config.screenshots.shouldCaptureStep(step.type)) return;
  try {
    await tester.pump();
    // One more frame so a newly mounted theme (EnsembleApp after login)
    // can apply preloaded fallback fonts before we rasterize.
    await tester.pump();
    // Capture is synchronous (`toImageSync`). Do not wrap in `runAsync`:
    // `secureContent: skip` throws, and runAsync would report that as a
    // FlutterError and fail the test.
    final image = ExtendedStepHandlers.captureScreenshotImage(
      tester,
      secureContent: context.config.screenshots.secureContent,
    );
    final device = hostScreenshotDevice(context);
    context.runtime.addScreenshotSheetFrame(
      ScreenshotSheetFrame(
        stepIndex: stepIndex,
        label: '${stepIndex + 1}. ${formatStepBrief(step)}',
        image: image,
        deviceId: device?.id,
        deviceLabel: device?.displayLabel,
        platform: device?.platform,
        model: device?.model,
      ),
    );
  } catch (error) {
    if (!isHostScreenshotDiagnostic(error) &&
        !isHostScreenshotCaptureFailure(error)) {
      rethrow;
    }
    // Do not call tester.takeException() — that would drain unrelated
    // application FlutterErrors recorded for the host attempt.
  }
}

/// One last frame when a host test dies before any step screenshot landed.
Future<void> captureHostEmergencyScreenshot({
  required WidgetTester tester,
  required EnsembleTestContext context,
}) async {
  if (!context.config.screenshots.enabled) return;
  try {
    await tester.pump();
    final image = ExtendedStepHandlers.captureScreenshotImage(
      tester,
      secureContent: context.config.screenshots.secureContent,
    );
    final device = hostScreenshotDevice(context);
    context.runtime.addScreenshotSheetFrame(
      ScreenshotSheetFrame(
        stepIndex: 0,
        label: 'Runner failure',
        image: image,
        deviceId: device?.id,
        deviceLabel: device?.displayLabel,
        platform: device?.platform,
        model: device?.model,
      ),
    );
  } catch (error) {
    if (!isHostScreenshotDiagnostic(error) &&
        !isHostScreenshotCaptureFailure(error)) {
      rethrow;
    }
  }
}

TestDeviceTarget? hostScreenshotDevice(EnsembleTestContext ctx) {
  final target = ctx.testCase.deviceTarget;
  if (target != null) return target;
  if (ctx.config.devices.length == 1) return ctx.config.devices.single;
  if (!ctx.config.screenshots.enabled) return null;
  return const TestDeviceTarget(
    id: 'ios',
    platform: 'ios',
    model: 'iPhone 15 Pro',
  );
}

/// Matches the widget surface to the device bezel used in the HTML report.
///
/// Without this, widget tests layout at the default 800×600 (or the live
/// window) and the encoder stretches that bitmap into an iPhone frame.
///
/// Integration mode must not override the physical display — read the real
/// size into [EnsembleTestContext.runtime] for reporting only.
Future<void> applyHostScreenshotViewport(
  WidgetTester tester,
  EnsembleTestContext context, {
  ExecutionMode mode = ExecutionMode.widget,
}) async {
  if (mode == ExecutionMode.integration) {
    context.runtime.deviceSize = tester.view.physicalSize;
    return;
  }
  final device = screenshotDeviceForTestCase(context.testCase, context.config);
  if (device == null) return;
  await tester.binding.setSurfaceSize(device.screenSize);
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = device.screenSize;
  final padding = FakeViewPadding(
    left: device.safeAreas.left,
    top: device.safeAreas.top,
    right: device.safeAreas.right,
    bottom: device.safeAreas.bottom,
  );
  tester.view.padding = padding;
  tester.view.viewPadding = padding;
  context.runtime.deviceSize = device.screenSize;
}

Future<void> resetHostScreenshotViewport(WidgetTester tester) async {
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
  tester.view.resetPadding();
  tester.view.resetViewPadding();
  await tester.binding.setSurfaceSize(null);
}

/// Writes screenshot frames, dump tree, API, storage, and app console logs.
///
/// Call while the widget tree is still mounted so dump-tree and emergency
/// captures can read it. Screenshot encoding runs inside [tester.runAsync]
/// so fake-async widget tests do not deadlock on GPU/image work.
Future<void> attachHostDebugArtifacts({
  required WidgetTester tester,
  required EnsembleTestContext context,
  required TestStatus status,
  required int durationMs,
  int? failedStepIndex,
  String? failedStepLabel,
  String? failureMessage,
}) async {
  try {
    final frames = List<ScreenshotSheetFrame>.from(
      context.runtime.screenshotSheetFrames,
    );
    context.runtime.screenshotSheetFrames.clear();
    final failureObserver = context.runtime.failureObserver;
    context.runtime.failureObserver = null;
    if (context.config.screenshots.enabled &&
        (frames.isNotEmpty ||
            failureObserver != null ||
            context.config.devices.isNotEmpty)) {
      final path = await tester.runAsync(() async {
        final previousRunner = LiveAsyncCallSupport.runner;
        LiveAsyncCallSupport.runner = null;
        try {
          return await ScreenshotSheetAggregator(
            screenshots: context.config.screenshots,
            devices: context.config.devices,
          ).completeRun(
            testCase: context.testCase,
            frames: frames,
            status: status,
            durationMs: durationMs,
            failedStepIndex: failedStepIndex,
            failedStepLabel: failedStepLabel,
            failureMessage: failureMessage,
            failureObserver: failureObserver,
          );
        } finally {
          LiveAsyncCallSupport.runner = previousRunner;
        }
      });
      if (path != null) {
        context.logger.log('screenshots: $path');
        context.logger.log('screenshotFrames: $path');
      }
    } else {
      failureObserver?.dispose();
      for (final frame in frames) {
        try {
          frame.image.dispose();
        } catch (_) {}
      }
    }
  } catch (error) {
    context.logger.log('screenshotsError: $error');
  }

  if (context.config.dumpTree.enabled) {
    try {
      replaceHostArtifactLog(
        context.logger,
        'dumpTree',
        await writeDumpTreeLog(context),
      );
    } catch (error) {
      context.logger.log('dumpTreeError: $error');
    }
  }

  try {
    replaceHostArtifactLog(
      context.logger,
      'apiCalls',
      await writeApiCallsLog(context),
    );
  } catch (error) {
    context.logger.log('apiCallsError: $error');
  }
  try {
    Map<String, dynamic> keys = const {};
    if (StorageManager().initialized) {
      try {
        keys = capturePublicStorage();
      } catch (_) {}
    }
    replaceHostArtifactLog(
      context.logger,
      'storage',
      await writeStorageLogFile(
        logger: context.logger,
        filePrefix: context.testCase.id,
        keys: keys,
        stepDiffs: context.runtime.storageStepDiffs,
        secureStepDiffs: context.runtime.secureStorageStepDiffs,
        keychainStepDiffs: context.runtime.keychainStepDiffs,
      ),
    );
  } catch (error) {
    context.logger.log('storageError: $error');
  }
  try {
    replaceHostArtifactLog(
      context.logger,
      'appLogs',
      await writeAppConsoleLog(context),
    );
  } catch (error) {
    context.logger.log('appLogsError: $error');
  }
}

void replaceHostArtifactLog(TestLogger logger, String label, String path) {
  logger.logs.removeWhere((entry) {
    final separator = entry.indexOf(':');
    if (separator <= 0) return false;
    return entry.substring(0, separator).trim() == label;
  });
  logger.log('$label: $path');
}
