import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/session/observation/observation_options.dart';

/// When report artifacts (screenshot + Observer) are taken relative to the step.
///
/// - [beforeAction]: pixels/overlays of the control about to be acted on.
/// - [afterCondition]: pixels/overlays after a wait/assert matched.
/// - [onFailure]: best-effort freeze before cleanup pumps advance the tree.
enum StepReportCapturePolicy {
  beforeAction,
  afterCondition,
  onFailure,
}

/// Screenshot timing/quality flags for a [StepReportCapturePolicy].
///
/// The runner applies these to its screenshot pipeline; [captureStepReportArtifacts]
/// only enforces the shot→observe pairing invariant.
class StepScreenshotOptions {
  const StepScreenshotOptions({
    this.pumpBeforeCapture = false,
    this.ensureTargetVisible = true,
    this.waitForTarget = false,
    this.waitForLottie = true,
    this.stabilize = true,
    this.forFailure = false,
    this.requireVisibleActionHighlight = false,
    this.allowObserveWhileQueueBusy = false,
    this.observationDetail = ObservationDetailLevel.standard,
  });

  final bool pumpBeforeCapture;
  final bool ensureTargetVisible;
  final bool waitForTarget;
  final bool waitForLottie;
  final bool stabilize;
  final bool forFailure;

  /// Drop the frame when an action highlight lands on flat empty pixels.
  final bool requireVisibleActionHighlight;

  /// Report Observer uses [captureDiagnosticUiSnapshot] (no queue). Mid-wait
  /// hooks hold the leaf queue — allow observe so overlays match the mid-wait
  /// PNG instead of the next screen after `execute` returns.
  final bool allowObserveWhileQueueBusy;

  /// Detail required for the Observer evidence paired with this frame.
  ///
  /// Normal report frames use [ObservationDetailLevel.standard]. Failure
  /// freezes opt into [ObservationDetailLevel.diagnostic] without changing
  /// the screenshot timing or execution path.
  final ObservationDetailLevel observationDetail;

  /// Before tap/toggle/etc.: wait for paint, short settle when the executor
  /// has not already resolved the target. A resolved tap is captured at the
  /// executor boundary without advancing another frame, so the evidence stays
  /// on the pre-action screen and avoids a redundant stability pump.
  ///
  /// [requireVisibleActionHighlight] is only for optional taps — it drops
  /// frames whose highlight lands on flat empty pixels (loading chrome).
  /// Required actions must keep the shot even when the control was off-screen
  /// and just scrolled into view (low-contrast rows / partial paints).
  factory StepScreenshotOptions.beforeAction({
    bool requireVisibleActionHighlight = false,
    bool targetAlreadyResolved = false,
  }) =>
      StepScreenshotOptions(
        // Tap execution already pumps immediately before this callback
        // (`tap.beforeTap` or `tap.ensureVisible`). Avoid advancing one more
        // frame and keep the captured image at the executor boundary.
        pumpBeforeCapture: !targetAlreadyResolved,
        // The tap path resolves a unique hit-testable target immediately
        // before invoking this callback. Re-running visibility recovery here
        // would perform another finder walk, Scrollable.ensureVisible, and
        // pump on every tap. Other actions keep the defensive visibility pass.
        ensureTargetVisible: !targetAlreadyResolved,
        // Action execution has already resolved the target immediately
        // before this callback. Waiting for it again duplicates the action
        // configured action timeout and makes the first-step capture appear
        // missing while adding the same delay to every tap.
        waitForTarget: false,
        waitForLottie: false,
        stabilize: !targetAlreadyResolved,
        requireVisibleActionHighlight: requireVisibleActionHighlight,
      );

  /// After expect/wait (post-step fallback).
  factory StepScreenshotOptions.afterCondition(TestStep step) {
    final isText = step.type == 'expectText' ||
        step.type == 'expectTextContains' ||
        step.type == 'waitForText' ||
        step.type == 'expectNoText';
    return StepScreenshotOptions(
      pumpBeforeCapture: step.type != 'waitForText',
      ensureTargetVisible: true,
      waitForTarget: false,
      waitForLottie: step.type != 'waitForNavigation',
      stabilize: !isText,
    );
  }

  /// A matched condition already advanced Flutter to the satisfying state.
  /// Freeze that frame before a scheduled callback replaces it.
  factory StepScreenshotOptions.matchedCondition() =>
      const StepScreenshotOptions(
        pumpBeforeCapture: false,
        ensureTargetVisible: false,
        waitForTarget: false,
        waitForLottie: false,
        stabilize: false,
        allowObserveWhileQueueBusy: true,
      );

  /// Mid-wait text match: paint the highlight target, no long settle.
  factory StepScreenshotOptions.waitForTextMatched() =>
      const StepScreenshotOptions(
        // The condition waiter has already pumped the frame that satisfied
        // the text predicate. Advancing here can capture a later state.
        pumpBeforeCapture: false,
        // A successful text wait already matched an on-screen text target.
        // Do not run ensureVisible's zero-duration pump at this boundary.
        ensureTargetVisible: false,
        waitForTarget: false,
        waitForLottie: false,
        stabilize: false,
        allowObserveWhileQueueBusy: true,
      );

  /// Mid-wait navigation: runner uses a dedicated paint/early-frame path;
  /// these flags apply when falling through to the normal screenshot helper.
  factory StepScreenshotOptions.waitForNavigationMatched() =>
      const StepScreenshotOptions(
        pumpBeforeCapture: false,
        ensureTargetVisible: false,
        waitForTarget: false,
        waitForLottie: false,
        stabilize: false,
        allowObserveWhileQueueBusy: true,
      );

  /// Failure freeze: no pumps that advance the tree.
  factory StepScreenshotOptions.onFailure() => const StepScreenshotOptions(
        pumpBeforeCapture: false,
        ensureTargetVisible: false,
        waitForTarget: false,
        waitForLottie: false,
        stabilize: false,
        forFailure: true,
        allowObserveWhileQueueBusy: true,
        observationDetail: ObservationDetailLevel.diagnostic,
      );
}

/// Capture one report screenshot.
///
/// Frame-aligned Observer data must be captured inside [captureScreenshot],
/// in the same synchronous turn that freezes the image. A post-capture callback
/// could observe a later frame and produce mismatched report evidence.
Future<bool> captureStepReportArtifacts({
  required Future<bool> Function() captureScreenshot,
  bool enabled = true,
}) {
  if (!enabled) return Future<bool>.value(false);
  return RunnerBenchmark.async('workflow', 'captureStepReportArtifacts',
      () async {
    return captureScreenshot();
  });
}
