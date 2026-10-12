import 'package:ensemble_test_runner/src/core/kernel.dart';
import 'package:ensemble_test_runner/src/core/step_boundary_subscriber.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dispatches only indexed start and finish events in order', () async {
    final calls = <String>[];
    final errors = <Object>[];
    final subscriber = StepBoundarySubscriber(
      onStarted: (index) => calls.add('start:$index'),
      onFinished: (index) => calls.add('finish:$index'),
      onError: (error, _) => errors.add(error),
    );

    await subscriber.call(const ExecutionEvent(
      sequence: 1,
      kind: ExecutionEventKind.operationFinished,
      stepIndex: 2,
    ));
    await subscriber.call(const ExecutionEvent(
      sequence: 2,
      kind: ExecutionEventKind.stepStarted,
      stepIndex: 2,
    ));
    await subscriber.call(const ExecutionEvent(
      sequence: 3,
      kind: ExecutionEventKind.stepFinished,
      stepIndex: 2,
    ));
    await subscriber.call(const ExecutionEvent(
      sequence: 4,
      kind: ExecutionEventKind.stepFinished,
    ));

    expect(calls, ['start:2', 'finish:2']);
    expect(errors, isEmpty);
  });

  test('returns callback errors to the attempt adapter', () async {
    final error = StateError('boundary callback failed');
    final received = <Object>[];
    final subscriber = StepBoundarySubscriber(
      onStarted: (_) async => throw error,
      onFinished: (_) {},
      onError: (failure, _) => received.add(failure),
    );

    await subscriber.call(const ExecutionEvent(
      sequence: 1,
      kind: ExecutionEventKind.stepStarted,
      stepIndex: 0,
    ));

    expect(received, [same(error)]);
  });
}
