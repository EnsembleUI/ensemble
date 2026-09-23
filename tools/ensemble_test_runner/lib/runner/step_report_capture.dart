import 'package:ensemble_test_runner/models/ensemble_test_models.dart';

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

  /// Before tap/toggle/etc.: wait for paint, short settle, contrast gate.
  factory StepScreenshotOptions.beforeAction() => const StepScreenshotOptions(
        pumpBeforeCapture: true,
        ensureTargetVisible: true,
        waitForTarget: true,
        waitForLottie: false,
        stabilize: true,
        requireVisibleActionHighlight: true,
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

  /// Mid-wait text match: paint the highlight target, no long settle.
  factory StepScreenshotOptions.waitForTextMatched() =>
      const StepScreenshotOptions(
        pumpBeforeCapture: true,
        ensureTargetVisible: true,
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
      );
}

/// Atomically capture a step screenshot then its Observer overlays.
///
/// Invariant: Observer is written only when [captureScreenshot] returns true
/// (a frame was added). Skipped/failed shots never leave an orphan Observer.
///
/// [captureObserver] should be best-effort and never throw.
Future<bool> captureStepReportArtifacts({
  required Future<bool> Function() captureScreenshot,
  required Future<void> Function() captureObserver,
}) async {
  final didCapture = await captureScreenshot();
  if (!didCapture) return false;
  await captureObserver();
  return true;
}
