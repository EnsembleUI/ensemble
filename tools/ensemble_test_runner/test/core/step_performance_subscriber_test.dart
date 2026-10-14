import 'dart:async';

import 'package:ensemble_test_runner/src/core/kernel.dart';
import 'package:ensemble_test_runner/src/core/step_performance_subscriber.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stages only completed authored step boundaries', () async {
    final captured = <int>[];
    final subscriber = StepPerformanceSubscriber(
      capture: (stepIndex) => captured.add(stepIndex),
    );

    await subscriber(const ExecutionEvent(
      sequence: 1,
      kind: ExecutionEventKind.stepStarted,
      stepIndex: 4,
    ));
    await subscriber(const ExecutionEvent(
      sequence: 2,
      kind: ExecutionEventKind.operationFinished,
      stepIndex: 4,
    ));
    await subscriber(const ExecutionEvent(
      sequence: 3,
      kind: ExecutionEventKind.stepFinished,
      stepIndex: 4,
    ));

    expect(captured, isEmpty);
    await subscriber.flush(4);
    await subscriber.flush(4);
    expect(captured, [4]);
  });

  test('awaits flush and ignores malformed boundaries', () async {
    final events = <String>[];
    final subscriber = StepPerformanceSubscriber(
      capture: (stepIndex) async {
        events.add('start:$stepIndex');
        await Future<void>.delayed(Duration.zero);
        events.add('end:$stepIndex');
      },
    );

    await subscriber(const ExecutionEvent(
      sequence: 1,
      kind: ExecutionEventKind.stepFinished,
    ));
    await subscriber(const ExecutionEvent(
      sequence: 2,
      kind: ExecutionEventKind.stepFinished,
      stepIndex: 1,
    ));
    expect(events, isEmpty);
    await subscriber.flush(1);

    expect(events, ['start:1', 'end:1']);
  });

  test('retains a failed capture for a later cleanup retry', () async {
    var attempts = 0;
    final captured = <int>[];
    final subscriber = StepPerformanceSubscriber(
      capture: (stepIndex) {
        attempts++;
        if (attempts == 1) throw StateError('temporary evidence failure');
        captured.add(stepIndex);
      },
    );

    await subscriber(const ExecutionEvent(
      sequence: 1,
      kind: ExecutionEventKind.stepFinished,
      stepIndex: 3,
    ));
    await expectLater(subscriber.flush(3), throwsStateError);
    await subscriber.flush(3);

    expect(attempts, 2);
    expect(captured, [3]);
  });

  test('shares an in-flight evidence capture', () async {
    final completer = Completer<void>();
    var captures = 0;
    final subscriber = StepPerformanceSubscriber(
      capture: (_) async {
        captures++;
        await completer.future;
      },
    );
    await subscriber(const ExecutionEvent(
      sequence: 1,
      kind: ExecutionEventKind.stepFinished,
      stepIndex: 5,
    ));

    final first = subscriber.flush(5);
    final second = subscriber.flush(5);
    expect(identical(first, second), isTrue);
    completer.complete();
    await first;
    expect(captures, 1);
  });
}
