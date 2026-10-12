import 'dart:ui' as ui;

import 'package:ensemble/framework/screen_tracker.dart';
import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/app_performance_log.dart';
import 'package:ensemble_test_runner/runner/test_runtime_state.dart';
import 'package:ensemble_test_runner/runner/debug_artifact_logs.dart';
import 'package:ensemble_test_runner/runner/diagnostic_ui_snapshot.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/flutter_error_filters.dart';
import 'package:ensemble_test_runner/runner/screenshot_capture.dart';
import 'package:ensemble_test_runner/runner/screenshot_capture_failure.dart';
import 'package:ensemble_test_runner/runner/screenshot_lottie_ready.dart';
import 'package:ensemble_test_runner/runner/screenshot_sheet_aggregator.dart';
import 'package:ensemble_test_runner/runner/screenshot_device_target.dart';
import 'package:ensemble_test_runner/runner/screenshot_highlight_builder.dart';
import 'package:ensemble_test_runner/runner/screenshot_target_support.dart';
import 'package:ensemble_test_runner/runner/step_highlight_finder.dart';
import 'package:ensemble_test_runner/runner/step_report_capture.dart';
import 'package:ensemble_test_runner/runner/step_screenshot_artifact_writer.dart';
import 'package:ensemble_test_runner/runner/step_visual_snapshot.dart';
import 'package:ensemble_test_runner/runner/step_policy.dart' as step_policy;
import 'package:ensemble_test_runner/session/observation/observation_options.dart';
import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records a standalone screenshot failure without changing test outcome.
void logStandaloneScreenshotCaptureFailure({
  required EnsembleTestContext context,
  required TestStep step,
  required int stepIndex,
  required Object error,
}) {
  RunnerBenchmark.count('screenshotCaptureFailures', 1);
  final failureKind = classifyScreenshotCaptureFailure(error);
  context.logger.log(
    'Screenshot capture skipped for step ${stepIndex + 1} '
    '(${step.type}): ${failureKind.name}: $error',
  );
}

final class TestVisualArtifacts {
  const TestVisualArtifacts({
    required this.screenshotSheets,
    required this.drainFlutterExceptions,
  });

  final ScreenshotSheetAggregator? Function() screenshotSheets;
  final void Function(WidgetTester tester) drainFlutterExceptions;

  ScreenshotTargetSupport get _targetSupport => ScreenshotTargetSupport(
        drainFlutterExceptions: drainFlutterExceptions,
      );

  /// Screenshots for [waitForNavigation] are captured only after the target
  /// remains visible through a paint pass. A tracker event can precede the
  /// destination's first rendered frame, so an early snapshot may belong to
  /// the previous route. If the target disappears before paint, return false
  /// and let the step completion boundary capture the actual rendered screen.
  ///
  /// Returns whether a frame was recorded.
  Future<bool> captureWaitForNavigationScreenshot({
    required TestStepExecutor executor,
    required TestStep step,
    required int stepIndex,
  }) async {
    return await RunnerBenchmark.async(
        'screenshot', 'captureWaitForNavigationScreenshot', () async {
      final options = executor.context.config.screenshots;
      if (!options.shouldCaptureStep(step.type)) return false;

      final screen = step.args['screen']?.toString();
      if (screen == null || screen.isEmpty) return false;

      final tracker = ScreenTracker();
      bool isTargetVisible() =>
          tracker.isScreenVisible(screenName: screen) ||
          tracker.isScreenVisible(screenId: screen);

      if (!isTargetVisible()) return false;
      if (treeHasFlutterErrorWidget(executor.tester)) return false;

      try {
        // Tracker events can precede the route's first paint. Give Flutter a
        // frame, then advance once more only when rendering still has scheduled
        // work. A fixed six-frame wait adds up to 300ms for already-painted
        // destinations without improving those captures.
        await pumpScreenshotStabilityFrames(executor.tester);
        if (isTargetVisible() && areVisibleLottiesReady(executor.tester)) {
          seekVisibleLottiesForScreenshot(executor.tester);
          await executor.tester.pump();
        }
      } catch (_) {
        // Best-effort paint only.
      }

      if (isTargetVisible()) {
        // Still on target after paint; capture the rendered destination.
        await captureAutomaticScreenshotForStepBestEffort(
          executor: executor,
          step: step,
          stepIndex: stepIndex,
          ensureTargetVisible: false,
          waitForLottie: false,
          stabilize: false,
        );
        return executor.context.runtime.screenshotSheetFrames
            .any((frame) => frame.stepIndex == stepIndex);
      }

      // Tracker observed a visit, but no target frame was rendered. Evidence
      // capture falls back to the step completion boundary, which pairs the
      // actual current screen with its Observer snapshot. Give a replacement
      // route one bounded frame to apply state changes queued by the transient
      // route callback; otherwise the completion boundary can freeze the
      // transient widget tree before that queued replacement is built.
      await executor.tester.pump(const Duration(milliseconds: 50));
      return false;
    });
  }

  /// Screenshot + Observer as one pair. Skipped shots never write Observer.
  Future<bool> captureStepArtifacts({
    required TestStepExecutor executor,
    required TestStep step,
    required int stepIndex,
    required StepScreenshotOptions options,
    TestStep? labelStep,
    Future<bool> Function()? captureScreenshot,
  }) {
    return captureStepReportArtifacts(
      enabled: executor.context.config.screenshots.shouldCaptureStep(step.type),
      captureScreenshot: captureScreenshot ??
          () => captureAutomaticScreenshotForStepBestEffort(
                executor: executor,
                step: step,
                stepIndex: stepIndex,
                labelStep: labelStep,
                pumpBeforeCapture: options.pumpBeforeCapture,
                ensureTargetVisible: options.ensureTargetVisible,
                waitForTarget: options.waitForTarget,
                waitForLottie: options.waitForLottie,
                stabilize: options.stabilize,
                forFailure: options.forFailure,
                observationDetail: options.observationDetail,
                requireVisibleActionHighlight:
                    options.requireVisibleActionHighlight,
              ),
    );
  }

  Future<bool> _captureAutomaticScreenshotForStep({
    required TestStepExecutor executor,
    required TestStep step,
    required int stepIndex,
    TestStep? labelStep,
    bool pumpBeforeCapture = false,
    bool ensureTargetVisible = true,
    bool waitForTarget = false,
    bool waitForLottie = true,
    bool stabilize = true,
    bool forFailure = false,
    ObservationDetailLevel observationDetail = ObservationDetailLevel.standard,

    /// When true, skip the frame unless an action highlight lands on pixels
    /// that are not a flat empty region (avoids phantom optional-tap rings).
    bool requireVisibleActionHighlight = false,
  }) async {
    return await RunnerBenchmark.async(
        'screenshot', 'captureAutomaticScreenshotForStep', () async {
      final options = executor.context.config.screenshots;
      if (!options.shouldCaptureStep(step.type)) return false;

      if (pumpBeforeCapture) {
        await executor.tester.pump();
      }

      if (waitForTarget) {
        await _targetSupport.waitForScreenshotTarget(executor, step);
      }

      if (ensureTargetVisible) {
        await _targetSupport.ensureHighlightTargetVisible(executor, step);
      }

      if (stabilize) {
        // Finish route transitions so the captured pixels match the highlight target.
        await _stabilizeScreenshotFrame(
          executor,
          waitForLottie: waitForLottie,
        );
      }

      // Read pixels and Observer in the same synchronous turn. A route/timer
      // callback can advance the live tree as soon as this method yields.
      final visual = captureStepVisualSnapshot(
        tester: executor.tester,
        assertions: executor.assertions,
        navigation: executor.services.navigation,
        observationDetail: observationDetail,
      );
      final image = visual.image;
      final observerSnapshot = visual.observerSnapshot;
      final device = _screenshotDeviceTarget(executor.context);
      final highlight = _highlightForStep(
        executor: executor,
        image: image,
        step: step,
        device: device,
        observerSnapshot: observerSnapshot,
        forFailure: forFailure,
      );
      if (requireVisibleActionHighlight) {
        final logicalRect = _targetSupport.highlightRectForStep(executor, step,
            forFailure: forFailure);
        final renderView = executor.tester.binding.renderViews.first;
        final region = logicalRect == null
            ? null
            : screenshotLogicalRectToImagePixels(
                logicalRect: logicalRect,
                logicalSize: renderView.size,
                imageSize:
                    Size(image.width.toDouble(), image.height.toDouble()),
              );
        final hasContrast = region != null &&
            highlight != null &&
            highlight.kind == 'action' &&
            await screenshotImageRegionHasContrast(
              image: image,
              region: region,
            );
        if (!hasContrast) {
          RunnerBenchmark.count('framesDropped', 1);
          image.dispose();
          return false;
        }
      }
      writeStepScreenshotArtifacts(
        tester: executor.tester,
        context: executor.context,
        step: step,
        stepIndex: stepIndex,
        image: image,
        labelStep: labelStep,
        device: device,
        highlight: highlight,
        observerSnapshot: observerSnapshot,
      );
      return true;
    });
  }

  TestDeviceTarget? _screenshotDeviceTarget(EnsembleTestContext ctx) {
    return screenshotDeviceTargetFor(ctx);
  }

  ScreenshotSheetAggregator screenshotSheetsFor(EnsembleTestConfig config) {
    return screenshotSheets() ??
        ScreenshotSheetAggregator(
          screenshots: config.screenshots,
          devices: config.devices,
        );
  }

  Future<bool> captureAutomaticScreenshotForStepBestEffort({
    required TestStepExecutor executor,
    required TestStep step,
    required int stepIndex,
    TestStep? labelStep,
    bool pumpBeforeCapture = false,
    bool ensureTargetVisible = true,
    bool waitForTarget = false,
    bool waitForLottie = true,
    bool stabilize = true,
    bool forFailure = false,
    ObservationDetailLevel observationDetail = ObservationDetailLevel.standard,
    bool requireVisibleActionHighlight = false,
  }) async {
    try {
      return await _captureAutomaticScreenshotForStep(
        executor: executor,
        step: step,
        stepIndex: stepIndex,
        labelStep: labelStep,
        pumpBeforeCapture: pumpBeforeCapture,
        ensureTargetVisible: ensureTargetVisible,
        waitForTarget: waitForTarget,
        waitForLottie: waitForLottie,
        stabilize: stabilize,
        forFailure: forFailure,
        observationDetail: observationDetail,
        requireVisibleActionHighlight: requireVisibleActionHighlight,
      );
    } catch (error) {
      // Screenshot capture must never replace the real test failure, but a
      // silent drop makes a missing first-step artifact impossible to explain.
      // Keep the diagnostic lightweight and in the normal per-test log so it
      // is available in the report without changing the execution result.
      logStandaloneScreenshotCaptureFailure(
        context: executor.context,
        step: step,
        stepIndex: stepIndex,
        error: error,
      );
      return false;
    }
  }

  Future<void> _stabilizeScreenshotFrame(
    TestStepExecutor executor, {
    bool waitForLottie = true,
  }) async {
    return await RunnerBenchmark.async('screenshot', 'stabilizeScreenshotFrame',
        () async {
      try {
        // Cover short push/fade transitions, then stop once the binding has no
        // scheduled work. Repeating animations still receive the second frame.
        await pumpScreenshotStabilityFrames(executor.tester);
        if (!waitForLottie) {
          // Transient navigation screens leave during a long Lottie wait; if the
          // composition is already ready, still seek past intro-only frames.
          if (areVisibleLottiesReady(executor.tester)) {
            seekVisibleLottiesForScreenshot(executor.tester);
            await executor.tester.pump();
          }
          return;
        }
        // Local Lottie.asset is still async; with an external AnimationController
        // nothing paints until onLoaded. Wait so step screenshots are not blank.
        await waitForVisibleLottiesReady(executor.tester);
      } catch (_) {
        // Stabilization is best-effort for screenshots only.
      }
    });
  }

  Future<void> waitForHighlightTargetToPaint(
    TestStepExecutor executor,
    TestStep step,
  ) =>
      _targetSupport.waitForHighlightTargetToPaint(executor, step);

  Future<void> paintAfterUserAction(
    TestStepExecutor executor,
    EnsembleTestContext ctx,
  ) =>
      _targetSupport.paintAfterUserAction(executor, ctx);

  bool isUserActionStep(TestStep step) => step_policy.isUserActionStep(step);

  ScreenshotHighlight? _highlightForStep({
    required TestStepExecutor executor,
    required ui.Image image,
    required TestStep step,
    required TestDeviceTarget? device,
    DiagnosticUiSnapshot? observerSnapshot,
    bool forFailure = false,
  }) {
    final rect = _targetSupport.highlightRectForStep(executor, step,
            forFailure: forFailure) ??
        (observerSnapshot == null
            ? null
            : observedIdHighlightRect(
                step: step,
                observation: observerSnapshot.observation,
              ));
    if (rect == null) return null;

    final tester = executor.tester;
    final renderView = tester.binding.renderViews.first;
    return buildScreenshotHighlight(
      logicalRect: rect,
      logicalSize: renderView.size,
      imageSize: Size(image.width.toDouble(), image.height.toDouble()),
      kind: screenshotHighlightKind(step, forFailure: forFailure),
      device: device,
    );
  }

  void captureScreenArtifacts(EnsembleTestContext ctx) {
    return RunnerBenchmark.sync('workflow', 'captureScreenArtifacts', () {
      final screenName = ScreenTracker().getCurrentScreenIdentifier();
      if (screenName == null || screenName.isEmpty) return;

      String? debugTree;
      if (ctx.config.dumpTree.enabled) {
        try {
          debugTree = captureDebugDumpApp();
        } catch (_) {}
      }

      Map<String, dynamic>? performance;
      if (ctx.config.performance.enabled) {
        try {
          performance = buildScreenPerformanceJson(
            screenName: screenName,
            frames: ctx.runtime.appFrameTimings,
            markers: ctx.runtime.performanceMarkers,
          );
        } catch (_) {}
      }

      if (debugTree != null || performance != null) {
        ctx.runtime.screenArtifacts[screenName] = {
          if (debugTree != null) 'debugTree': debugTree,
          if (performance != null) 'performance': performance,
        };
      }
    });
  }
}
