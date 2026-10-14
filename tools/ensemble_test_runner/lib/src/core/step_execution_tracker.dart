import 'dart:async';

import 'kernel.dart';
import 'step_timing_subscriber.dart';

/// Keeps the execution state that every application entry needs while a plan
/// crosses authored step boundaries.
///
/// The tracker deliberately contains no Flutter or reporting dependencies. It
/// owns timing and the currently active/last failed step. An optional boundary
/// callback lets an entry update its current-step context without registering
/// a second subscriber for the same events.
final class StepExecutionTracker {
  StepExecutionTracker({
    StepTimingSubscriber? timing,
    void Function(int stepIndex)? onStepStarted,
  })  : timing = timing ?? StepTimingSubscriber(),
        _onStepStarted = onStepStarted;

  final StepTimingSubscriber timing;
  final void Function(int stepIndex)? _onStepStarted;
  final List<int> stepDurationsMs = <int>[];
  final List<String> stepStartTimes = <String>[];

  int activeStepIndex = -1;
  int failedStepIndex = -1;

  FutureOr<void> call(ExecutionEvent event) {
    final index = event.stepIndex;
    if (index == null) return null;
    final timingResult = timing.call(event);
    if (timingResult is Future<void>) {
      return timingResult.then((_) => _record(event));
    }
    _record(event);
    return null;
  }

  void _record(ExecutionEvent event) {
    final index = event.stepIndex;
    if (index == null) return null;
    switch (event.kind) {
      case ExecutionEventKind.stepStarted:
        activeStepIndex = index;
        failedStepIndex = index;
        stepStartTimes.add(
            timing.startTimeFor(index) ?? DateTime.now().toIso8601String());
        _onStepStarted?.call(index);
      case ExecutionEventKind.stepFinished:
        stepDurationsMs.add(timing.durationFor(index) ?? 0);
        activeStepIndex = -1;
      default:
        break;
    }
  }

  /// Records a step that failed before its finish boundary was emitted.
  void recordActiveDuration() {
    if (activeStepIndex < 0) return null;
    stepDurationsMs.add(timing.elapsedMsFor(activeStepIndex));
  }

  int failureIndex({int fallback = 0}) => activeStepIndex >= 0
      ? activeStepIndex
      : failedStepIndex >= 0
          ? failedStepIndex
          : fallback;

  void clearFailure() {
    activeStepIndex = -1;
    failedStepIndex = -1;
  }
}
