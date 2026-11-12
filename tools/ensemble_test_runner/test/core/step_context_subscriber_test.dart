import 'package:ensemble_test_runner/src/core/kernel.dart';
import 'package:ensemble_test_runner/src/core/step_context_subscriber.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('publishes the active step at the step-start boundary', () async {
    final activeSteps = <int>[];
    final finishedSteps = <int>[];
    final subscriber = StepContextSubscriber(
      onStepStarted: activeSteps.add,
      onStepFinished: finishedSteps.add,
    );

    await subscriber.call(const ExecutionEvent(
      sequence: 1,
      kind: ExecutionEventKind.stepStarted,
      stepIndex: 4,
    ));
    await subscriber.call(const ExecutionEvent(
      sequence: 2,
      kind: ExecutionEventKind.operationStarted,
      stepIndex: 4,
    ));
    await subscriber.call(const ExecutionEvent(
      sequence: 3,
      kind: ExecutionEventKind.stepFinished,
      stepIndex: 4,
    ));

    expect(activeSteps, [4]);
    expect(finishedSteps, [4]);
  });

  test('clears the active step after its finish boundary', () async {
    var activeStep = -1;
    final subscriber = StepContextSubscriber(
      onStepStarted: (index) => activeStep = index,
      onStepFinished: (_) => activeStep = -1,
    );

    await subscriber.call(const ExecutionEvent(
      sequence: 1,
      kind: ExecutionEventKind.stepStarted,
      stepIndex: 2,
    ));
    expect(activeStep, 2);

    await subscriber.call(const ExecutionEvent(
      sequence: 2,
      kind: ExecutionEventKind.stepFinished,
      stepIndex: 2,
    ));
    expect(activeStep, -1);
  });

  test('ignores non-step and malformed start events', () async {
    var updates = 0;
    final subscriber = StepContextSubscriber(
      onStepStarted: (_) => updates++,
    );

    await subscriber.call(const ExecutionEvent(
      sequence: 1,
      kind: ExecutionEventKind.stepStarted,
    ));
    await subscriber.call(const ExecutionEvent(
      sequence: 2,
      kind: ExecutionEventKind.operationStarted,
      stepIndex: 1,
    ));

    expect(updates, 0);
  });
}
