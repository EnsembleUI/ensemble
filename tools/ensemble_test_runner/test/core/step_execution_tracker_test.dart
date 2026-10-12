import 'package:ensemble_test_runner/src/core/kernel.dart';
import 'package:ensemble_test_runner/src/core/step_execution_tracker.dart';
import 'package:ensemble_test_runner/src/core/step_timing_subscriber.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tracks ordered boundaries and failure state', () async {
    var now = DateTime(2026, 1, 1);
    final startedSteps = <int>[];
    final tracker = StepExecutionTracker(
      timing: StepTimingSubscriber(now: () => now),
      onStepStarted: startedSteps.add,
    );

    await tracker(const ExecutionEvent(
      sequence: 1,
      kind: ExecutionEventKind.stepStarted,
      stepIndex: 2,
    ));
    expect(tracker.activeStepIndex, 2);
    expect(tracker.failedStepIndex, 2);
    now = now.add(const Duration(milliseconds: 17));
    await tracker(const ExecutionEvent(
      sequence: 2,
      kind: ExecutionEventKind.stepFinished,
      stepIndex: 2,
    ));

    expect(tracker.activeStepIndex, -1);
    expect(tracker.stepDurationsMs, [17]);
    expect(tracker.stepStartTimes, ['2026-01-01T00:00:00.000']);
    expect(startedSteps, [2]);
    expect(tracker.failureIndex(), 2);
  });

  test('records an open step when execution fails before finish', () async {
    final tracker = StepExecutionTracker(
      timing: StepTimingSubscriber(now: () => DateTime(2026, 1, 1)),
    );
    await tracker(const ExecutionEvent(
      sequence: 1,
      kind: ExecutionEventKind.stepStarted,
      stepIndex: 4,
    ));
    tracker.recordActiveDuration();

    expect(tracker.stepDurationsMs, [0]);
    expect(tracker.failureIndex(), 4);
    tracker.clearFailure();
    expect(tracker.failureIndex(fallback: 9), 9);
  });
}
