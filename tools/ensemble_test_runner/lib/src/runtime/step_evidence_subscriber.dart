import 'dart:async';

import 'package:ensemble_test_runner/src/core/kernel.dart';
import 'package:ensemble_test_runner/src/core/step_capture_guard.dart';
import 'step_evidence_policy.dart';

/// Captures evidence after an authored step has completed.
///
/// The kernel delivers subscribers in order, so callers can place this after
/// timing or state subscribers when evidence needs their completed state. The
/// capture callback stays outside the execution runtime; it can be disabled by
/// omitting this subscriber from the kernel.
final class StepEvidenceSubscriber {
  StepEvidenceSubscriber({
    required FutureOr<bool> Function(int stepIndex) capture,
    FutureOr<bool> Function(ExecutionEvent event)? captureBeforeMutation,
    bool Function(int stepIndex)? shouldCaptureStep,
  })  : _capture = capture,
        _captureBeforeMutation = captureBeforeMutation,
        _shouldCaptureStep = shouldCaptureStep ?? _captureEveryStep;

  final FutureOr<bool> Function(int stepIndex) _capture;
  final FutureOr<bool> Function(ExecutionEvent event)? _captureBeforeMutation;
  final bool Function(int stepIndex) _shouldCaptureStep;
  final Map<int, StepCaptureGuard> _guards = {};

  static bool _captureEveryStep(int _) => true;

  bool hasCaptured(int stepIndex) => _guards[stepIndex]?.captured ?? false;

  void markCaptured(int stepIndex) =>
      _guards.putIfAbsent(stepIndex, StepCaptureGuard.new).markCaptured();

  /// Shares one in-flight capture and successful result across all boundaries
  /// for this authored step (pre-action, transient-state, and completion).
  Future<bool> captureOnce(
    int stepIndex,
    FutureOr<bool> Function() capture, {
    bool enabled = true,
  }) {
    // Failure handling can request evidence even when the subscriber itself
    // was omitted from the kernel. Preserve that path's once-only contract,
    // but avoid allocating a guard or invoking the capture pipeline when the
    // current step is excluded.
    if (!enabled) return Future<bool>.value(false);
    return _guards
        .putIfAbsent(stepIndex, StepCaptureGuard.new)
        .capture(() async => await capture());
  }

  /// Returns synchronously for all non-boundary events. Kernel subscribers see
  /// operation and observation events far more often than completed steps, so
  /// avoiding an async state machine on that path keeps evidence collection
  /// out of the normal execution cost.
  FutureOr<void> call(ExecutionEvent event) {
    final stepIndex = event.stepIndex;
    if (stepIndex == null) return null;
    // Excluded steps should skip the whole evidence path. In particular, do
    // not allocate a guard at the mutation boundary only to retry the same
    // ineligible capture at step completion.
    if (!_shouldCaptureStep(stepIndex)) return null;
    if (event.kind == ExecutionEventKind.evidenceBoundary) {
      // A successful boundary already owns this step's evidence. Ignore
      // later compatibility notifications before allocating the async
      // capture continuation; failed captures remain eligible for retry.
      if (hasCaptured(stepIndex)) return null;
      final capture = _captureBeforeMutation;
      if (capture == null) return null;
      final detail = event.detail;
      if (detail == null) return null;
      if (!StepEvidencePolicy.acceptsBoundary(detail)) return null;
      return captureOnce(stepIndex, () => capture(event)).then<void>((_) {});
    }
    if (event.kind != ExecutionEventKind.stepFinished) return null;
    // Most action steps captured their evidence at an earlier ordered
    // boundary. Skip the completion fallback when that capture succeeded;
    // uncaptured or failed attempts still use this fallback as before.
    if (hasCaptured(stepIndex)) return null;
    return captureOnce(stepIndex, () => _capture(stepIndex)).then<void>((_) {});
  }
}
