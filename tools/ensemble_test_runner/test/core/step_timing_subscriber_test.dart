import 'package:ensemble_test_runner/src/core/kernel.dart';
import 'package:ensemble_test_runner/src/core/step_timing_subscriber.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('records ordered step boundaries and elapsed duration', () async {
    var now = DateTime.utc(2026, 1, 1);
    final timing = StepTimingSubscriber(now: () => now);
    await timing.call(const ExecutionEvent(
      sequence: 1,
      kind: ExecutionEventKind.stepStarted,
      stepIndex: 3,
    ));
    expect(timing.startTimeFor(3), '2026-01-01T00:00:00.000Z');
    expect(timing.durationFor(3), isNull);

    now = now.add(const Duration(milliseconds: 27));
    await timing.call(const ExecutionEvent(
      sequence: 2,
      kind: ExecutionEventKind.stepFinished,
      stepIndex: 3,
    ));
    expect(timing.durationFor(3), 27);
    expect(timing.elapsedMsFor(3), 27);
  });

  test('rejects an unmatched finish boundary', () async {
    final timing = StepTimingSubscriber();
    await expectLater(
      timing.call(const ExecutionEvent(
        sequence: 1,
        kind: ExecutionEventKind.stepFinished,
        stepIndex: 0,
      )),
      throwsA(isA<StateError>()),
    );
  });
}
