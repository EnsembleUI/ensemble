import 'dart:ui' as ui;

import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble_test_runner/actions/screenshot_device.dart';
import 'package:ensemble_test_runner/application/application_test_types.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/debug_artifact_logs.dart';
import 'package:ensemble_test_runner/runner/emergency_failure_screenshot.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/runner/live_async_call.dart';
import 'package:ensemble_test_runner/runner/screenshot_sheet_aggregator.dart';
import 'package:ensemble_test_runner/runner/screenshot_device_target.dart';
import 'package:ensemble_test_runner/runner/screenshot_highlight_builder.dart';
import 'package:ensemble_test_runner/runner/step_highlight_finder.dart';
import 'package:ensemble_test_runner/runner/test_artifact_coordinator.dart';
import 'package:ensemble_test_runner/session/observation/ui_observation.dart';
import 'package:ensemble_test_runner/session/observation/observation_options.dart';
import 'package:ensemble_test_runner/runner/storage_step_diff.dart';
import 'package:ensemble_test_runner/runner/step_screenshot_artifact_writer.dart';
import 'package:ensemble_test_runner/runner/test_runtime_state.dart';
import 'package:ensemble_test_runner/runner/step_visual_snapshot.dart';
import 'package:ensemble_test_runner/runner/step_policy.dart';
import 'package:ensemble_test_runner/runner/screenshot_capture_failure.dart';
import 'package:ensemble_test_runner/runner/screenshot_lottie_ready.dart'
    show kScreenshotTransitionSettleDuration;
import 'package:ensemble_test_runner/runner/test_artifacts.dart'
    show usesDeviceArtifactTransport;
import 'package:flutter_test/flutter_test.dart';

/// True when a screenshot diagnostic should never fail the host test.
bool isHostScreenshotDiagnostic(Object? error) {
  return classifyScreenshotCaptureFailure(error) ==
      ScreenshotCaptureFailureKind.unpaintedRenderView;
}

/// Raster / encode failures from host screenshot capture (not app crashes).
bool isHostScreenshotCaptureFailure(Object? error) {
  return classifyScreenshotCaptureFailure(error) ==
      ScreenshotCaptureFailureKind.renderCapture;
}

/// Captures one report frame for a host test step.
///
/// Failures here must not change the test result — the HTML gallery is
/// diagnostic, not an assertion.
Future<void> captureHostStepScreenshot({
  required WidgetTester tester,
  required EnsembleTestContext context,
  required AssertionEngine assertions,
  NavigationTestService? navigation,
  required TestStep step,
  required int stepIndex,
  bool atCurrentFrame = false,
  ObservationDetailLevel observationDetail = ObservationDetailLevel.standard,
}) async {
  if (!context.config.screenshots.shouldCaptureStep(step.type)) return;
  try {
    if (!atCurrentFrame) {
      // Live API callbacks run in real async time, but widget animations use
      // the test binding's fake frame clock. Advance it through short content
      // transitions before rasterizing (for example LoadingContainer's
      // AnimatedSwitcher), otherwise Observer can see loaded children while
      // the screenshot still captures them at zero opacity.
      await tester.pump(kScreenshotTransitionSettleDuration);
      // One more frame so a newly mounted theme (EnsembleApp after login)
      // can apply preloaded fallback fonts before we rasterize.
      await tester.pump();
    }
    // Capture is synchronous; do not wrap it in runAsync.
    final visual = captureStepVisualSnapshot(
      tester: tester,
      assertions: assertions,
      navigation: navigation,
      observationDetail: observationDetail,
    );
    final image = visual.image;
    final observerSnapshot = visual.observerSnapshot;
    final device = hostScreenshotDevice(context);
    final highlight = _hostStepHighlight(
      tester: tester,
      assertions: assertions,
      step: step,
      image: image,
      device: device,
      observation: observerSnapshot?.observation,
    );
    writeStepScreenshotArtifacts(
      tester: tester,
      context: context,
      step: step,
      stepIndex: stepIndex,
      image: image,
      device: device,
      highlight: highlight,
      observerSnapshot: observerSnapshot,
    );
  } catch (error) {
    if (!isHostScreenshotDiagnostic(error) &&
        !isHostScreenshotCaptureFailure(error)) {
      rethrow;
    }
    context.runtime.consoleLogs.add(
      context.runtime.formatConsoleLine(
        '[Screenshot] Step $stepIndex capture skipped: $error',
      ),
    );
    // Do not call tester.takeException() — that would drain unrelated
    // application FlutterErrors recorded for the host attempt.
  }
}

ScreenshotHighlight? _hostStepHighlight({
  required WidgetTester tester,
  required AssertionEngine assertions,
  required TestStep step,
  required ui.Image image,
  required TestDeviceTarget? device,
  required UiObservation? observation,
}) {
  final finder = stepHighlightFinder(
    tester: tester,
    assertions: assertions,
    step: step,
  );
  ui.Rect? rect;
  if (finder != null) {
    // Host screenshots are captured after each step. Mutation steps can leave
    // selection handles on top of the field, so don't require a fresh hit test
    // for those; they still need current-route, visible geometry.
    final requireHitTestable =
        (step.type == 'tapAt' || isUserActionStep(step)) &&
            step.type != 'enterText' &&
            step.type != 'clearText' &&
            step.type != 'replaceText';
    rect = assertions.rectForVisuallyActionable(
      finder,
      requireHitTestable: requireHitTestable,
    );
  }
  rect ??= observation == null
      ? null
      : observedIdHighlightRect(step: step, observation: observation);
  if (rect == null) return null;

  final viewSize = tester.binding.renderViews.first.size;
  return buildScreenshotHighlight(
    logicalRect: rect,
    logicalSize: viewSize,
    imageSize: ui.Size(image.width.toDouble(), image.height.toDouble()),
    kind: screenshotHighlightKind(step, tapAtIsAction: true),
    device: device,
  );
}

/// One last frame when a host test dies before any step screenshot landed.
Future<void> captureHostEmergencyScreenshot({
  required WidgetTester tester,
  required EnsembleTestContext context,
}) async {
  if (!context.config.screenshots.enabled) return;
  try {
    await tester.pump();
    final device = hostScreenshotDevice(context);
    context.runtime.addScreenshotSheetFrame(
      captureEmergencyFailureScreenshotFrame(
        tester: tester,
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
  return screenshotDeviceTargetFor(ctx);
}

/// Applies the mode-specific display policy shared with standalone runs.
Future<void> applyHostScreenshotViewport(
  WidgetTester tester,
  EnsembleTestContext context, {
  ExecutionMode mode = ExecutionMode.widget,
}) async {
  await EnsembleTestHarness.runtimeAdapterFor(mode).applyViewport(
    tester,
    context,
    screenshotDeviceForTestCase(context.testCase, context.config),
    ensureDefaultViewport: false,
    reportLogicalDisplaySize: false,
  );
}

Future<void> resetHostScreenshotViewport(
  WidgetTester tester, {
  ExecutionMode mode = ExecutionMode.widget,
}) async {
  await EnsembleTestHarness.runtimeAdapterFor(mode).resetViewport(tester);
}

/// Writes screenshot frames, API, storage, and app console logs.
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
    final artifacts = context.runtime.takeScreenshotArtifacts();
    final frames = artifacts.frames;
    final stepObservers = artifacts.stepObservers;
    if (context.config.screenshots.enabled &&
        (frames.isNotEmpty ||
            stepObservers.isNotEmpty ||
            context.config.devices.isNotEmpty)) {
      final aggregator = ScreenshotSheetAggregator(
        screenshots: context.config.screenshots,
        devices: context.config.devices,
      );
      final path = usesDeviceArtifactTransport
          // Integration captures are already rasterized simulator frames.
          // Their PNG encoding and artifact transport do not need Flutter's
          // runAsync lane, which may still be occupied by a live plugin call.
          ? await aggregator.completeRun(
              testCase: context.testCase,
              frames: frames,
              status: status,
              durationMs: durationMs,
              failedStepIndex: failedStepIndex,
              failedStepLabel: failedStepLabel,
              failureMessage: failureMessage,
              stepObservers: stepObservers,
            )
          : await LiveAsyncCallSupport.runPriorityUntracked(
              () => aggregator.completeRun(
                testCase: context.testCase,
                frames: frames,
                status: status,
                durationMs: durationMs,
                failedStepIndex: failedStepIndex,
                failedStepLabel: failedStepLabel,
                failureMessage: failureMessage,
                stepObservers: stepObservers,
              ),
            );
      if (path != null) {
        context.logger.log('screenshotFrames: $path');
      }
    } else {
      for (final observer in stepObservers) {
        observer.dispose();
      }
      for (final frame in frames) {
        try {
          frame.image.dispose();
        } catch (_) {}
      }
    }
  } catch (error) {
    context.logger.log('screenshotsError: $error');
  }

  // Snapshot API calls at attempt cleanup. In-flight calls remain explicitly
  // pending in the report; artifact capture does not wait for their responses.
  await const TestArtifactCoordinator().attachLogArtifactsOnce(context);
  try {
    Map<String, dynamic> keys = const {};
    Map<String, dynamic> secureStorageKeys = const {};
    Map<String, dynamic> keychainKeys = const {};
    if (StorageManager().initialized) {
      try {
        keys = capturePublicStorage();
      } catch (_) {}
      try {
        secureStorageKeys = captureSecureStorage();
      } catch (_) {}
    }
    // The plugin keychain is independent of GetStorage initialization. Capture
    // it even when the app never initialized its public-storage backend.
    try {
      keychainKeys = await captureKeychainStorage();
    } catch (error) {
      context.logger.log('keychainStorageCaptureError: $error');
    }
    TestArtifactCoordinator.replaceArtifactLog(
      context.logger,
      'storage',
      await writeStorageLogFile(
        logger: context.logger,
        filePrefix: context.testCase.id,
        keys: keys,
        secureStorageKeys: secureStorageKeys,
        keychainKeys: keychainKeys,
        stepDiffs: context.runtime.storageStepDiffs,
        secureStepDiffs: context.runtime.secureStorageStepDiffs,
        keychainStepDiffs: context.runtime.keychainStepDiffs,
      ),
    );
  } catch (error) {
    context.logger.log('storageError: $error');
  }
}
