import 'package:ensemble_test_runner/src/core/kernel.dart';
import 'package:ensemble_test_runner/src/core/step_boundary_subscriber.dart';
import 'package:ensemble_test_runner/src/runtime/step_evidence_policy.dart';
import 'package:ensemble_test_runner/src/runtime/step_evidence_subscriber.dart';
import 'package:ensemble_test_runner/src/runtime/operation_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('host and standalone binders share evidence boundary classification',
      () {
    expect(
      StepEvidencePolicy.classify('waitForNavigation'),
      StepEvidenceBoundary.navigation,
    );
    expect(
      StepEvidencePolicy.classify('waitForText'),
      StepEvidenceBoundary.textMatch,
    );
    expect(
      StepEvidencePolicy.classify('condition:expectVisible'),
      StepEvidenceBoundary.condition,
    );
    expect(
      StepEvidencePolicy.classify('condition:customStep'),
      StepEvidenceBoundary.none,
    );
    expect(
      StepEvidencePolicy.classify('tap'),
      StepEvidenceBoundary.orderedOperation,
    );
    expect(
      StepEvidencePolicy.classify('customStep'),
      StepEvidenceBoundary.none,
    );
    expect(StepEvidencePolicy.classify(null), StepEvidenceBoundary.none);
    expect(StepEvidencePolicy.acceptsBoundary('tap'), isTrue);
    expect(
        StepEvidencePolicy.acceptsBoundary('condition:expectVisible'), isTrue);
    expect(StepEvidencePolicy.acceptsBoundary('condition:customStep'), isFalse);
    expect(StepEvidencePolicy.acceptsBoundary('customStep'), isFalse);
  });

  test('screenshot eligible user actions use ordered evidence ownership', () {
    for (final operation in operationRegistry.descriptors) {
      if (!operation.userAction) continue;
      expect(
        StepEvidencePolicy.ownsOrderedCapture(operation.name),
        isTrue,
        reason: '${operation.name} still needs a runner-owned capture path',
      );
    }
  });

  test('ordered action evidence captures before mutation once', () async {
    final snapshots = <String>[];
    var state = 'before';
    final subscriber = StepEvidenceSubscriber(
      capture: (_) async => false,
      captureBeforeMutation: (_) async {
        snapshots.add(state);
        return true;
      },
    );

    await subscriber.call(const ExecutionEvent(
      sequence: 1,
      kind: ExecutionEventKind.evidenceBoundary,
      detail: 'toggle',
      stepIndex: 3,
    ));
    state = 'after';
    final finished = subscriber.call(const ExecutionEvent(
      sequence: 2,
      kind: ExecutionEventKind.stepFinished,
      stepIndex: 3,
    ));
    expect(
      finished,
      isNull,
      reason:
          'a completed pre-mutation capture makes the finish fallback redundant',
    );

    expect(snapshots, ['before']);
  });

  test('paired report frame and observer share one ordered capture', () async {
    var screenshotFrames = 0;
    var observerSnapshots = 0;
    final subscriber = StepEvidenceSubscriber(
      capture: (_) async {
        screenshotFrames++;
        observerSnapshots++;
        return true;
      },
      captureBeforeMutation: (_) async {
        screenshotFrames++;
        observerSnapshots++;
        return true;
      },
    );

    await subscriber.call(const ExecutionEvent(
      sequence: 1,
      kind: ExecutionEventKind.evidenceBoundary,
      detail: 'tap',
      stepIndex: 8,
    ));
    await subscriber.call(const ExecutionEvent(
      sequence: 2,
      kind: ExecutionEventKind.stepFinished,
      stepIndex: 8,
    ));

    expect(screenshotFrames, 1);
    expect(observerSnapshots, 1);
  });

  test('excluded failure evidence does not allocate or consume the capture',
      () async {
    var captureCalls = 0;
    final subscriber = StepEvidenceSubscriber(capture: (_) async => true);

    expect(
      await subscriber.captureOnce(
        5,
        () async {
          captureCalls++;
          return true;
        },
        enabled: false,
      ),
      isFalse,
    );
    expect(subscriber.hasCaptured(5), isFalse);
    expect(captureCalls, 0);

    expect(
      await subscriber.captureOnce(5, () async {
        captureCalls++;
        return true;
      }),
      isTrue,
    );
    expect(captureCalls, 1);
  });

  test('excluded steps skip event and completion capture work', () async {
    var eligibilityChecks = 0;
    var captureCalls = 0;
    final subscriber = StepEvidenceSubscriber(
      shouldCaptureStep: (stepIndex) {
        eligibilityChecks++;
        return stepIndex != 4;
      },
      capture: (_) async {
        captureCalls++;
        return true;
      },
      captureBeforeMutation: (_) async {
        captureCalls++;
        return true;
      },
    );

    await subscriber.call(const ExecutionEvent(
      sequence: 1,
      kind: ExecutionEventKind.evidenceBoundary,
      detail: 'tap',
      stepIndex: 4,
    ));
    await subscriber.call(const ExecutionEvent(
      sequence: 2,
      kind: ExecutionEventKind.stepFinished,
      stepIndex: 4,
    ));

    expect(eligibilityChecks, 2);
    expect(captureCalls, 0);
    expect(subscriber.hasCaptured(4), isFalse);
  });

  test('evidence policy covers action and condition boundaries', () {
    expect(StepEvidencePolicy.ownsOrderedCapture('tap'), isTrue);
    expect(
      StepEvidencePolicy.ownsOrderedCapture('waitForNavigation'),
      isTrue,
    );
    expect(StepEvidencePolicy.ownsOrderedCapture('customStep'), isFalse);
  });

  test('trigger evidence is captured at its ordered mutation boundary',
      () async {
    final captures = <String>[];
    final subscriber = StepEvidenceSubscriber(
      capture: (_) async => false,
      captureBeforeMutation: (event) async {
        captures.add('event:${event.detail}');
        return true;
      },
    );

    await subscriber.call(const ExecutionEvent(
      sequence: 1,
      kind: ExecutionEventKind.evidenceBoundary,
      detail: 'trigger',
      stepIndex: 2,
    ));

    expect(captures, ['event:trigger']);
    expect(subscriber.hasCaptured(2), isTrue);
  });

  test('waitForText matched event wins over the completion fallback', () async {
    final captures = <String>[];
    final subscriber = StepEvidenceSubscriber(
      capture: (index) async {
        captures.add('finished:$index');
        return true;
      },
      captureBeforeMutation: (event) async {
        captures.add('matched:${event.detail}');
        return true;
      },
    );

    await subscriber.call(const ExecutionEvent(
      sequence: 1,
      kind: ExecutionEventKind.evidenceBoundary,
      detail: 'waitForText',
      stepIndex: 5,
    ));
    await subscriber.call(const ExecutionEvent(
      sequence: 2,
      kind: ExecutionEventKind.stepFinished,
      stepIndex: 5,
    ));

    expect(captures, ['matched:waitForText']);
  });

  test('captures once for each completed authored step', () async {
    final captured = <int>[];
    final subscriber = StepEvidenceSubscriber(
      capture: (stepIndex) async {
        captured.add(stepIndex);
        return true;
      },
    );

    await subscriber.call(const ExecutionEvent(
      sequence: 1,
      kind: ExecutionEventKind.stepStarted,
      stepIndex: 2,
    ));
    await subscriber.call(const ExecutionEvent(
      sequence: 2,
      kind: ExecutionEventKind.operationFinished,
      stepIndex: 2,
    ));
    await subscriber.call(const ExecutionEvent(
      sequence: 3,
      kind: ExecutionEventKind.stepFinished,
      stepIndex: 2,
    ));

    expect(captured, [2]);
  });

  test('captures completed evidence after boundary cleanup', () async {
    final order = <String>[];
    final boundary = StepBoundarySubscriber(
      onStarted: (_) {},
      onFinished: (_) {
        order.addAll(['paint', 'drain', 'flush', 'duration', 'clear']);
      },
      onError: (error, stackTrace) => fail('$error'),
    );
    final evidence = StepEvidenceSubscriber(capture: (_) {
      order.add('capture');
      return true;
    });
    const event = ExecutionEvent(
      sequence: 1,
      kind: ExecutionEventKind.stepFinished,
      stepIndex: 0,
    );

    await boundary.call(event);
    await evidence.call(event);

    expect(order, ['paint', 'drain', 'flush', 'duration', 'clear', 'capture']);
  });

  test('ignores a malformed completed boundary without a step index', () async {
    var captures = 0;
    final subscriber = StepEvidenceSubscriber(capture: (_) async {
      captures++;
      return true;
    });

    await subscriber.call(const ExecutionEvent(
      sequence: 1,
      kind: ExecutionEventKind.stepFinished,
    ));

    expect(captures, 0);
  });

  test('keeps irrelevant event delivery synchronous', () {
    final subscriber = StepEvidenceSubscriber(capture: (_) => true);

    expect(
      subscriber.call(const ExecutionEvent(
        sequence: 1,
        kind: ExecutionEventKind.operationFinished,
      )),
      isNull,
    );
    expect(
      subscriber.call(const ExecutionEvent(
        sequence: 2,
        kind: ExecutionEventKind.stepFinished,
      )),
      isNull,
    );
  });

  test('pre-action and finished boundaries share one in-flight capture',
      () async {
    var captures = 0;
    final subscriber = StepEvidenceSubscriber(capture: (_) async {
      captures++;
      await Future<void>.delayed(Duration.zero);
      return true;
    });

    final preAction = subscriber.captureOnce(4, () async {
      captures++;
      await Future<void>.delayed(Duration.zero);
      return true;
    });
    final finishedBoundary = Future<void>.sync(() async {
      await subscriber.call(const ExecutionEvent(
        sequence: 1,
        kind: ExecutionEventKind.stepFinished,
        stepIndex: 4,
      ));
    });
    await Future.wait<void>([
      preAction.then<void>((_) {}),
      finishedBoundary,
    ]);

    expect(captures, 1);
    expect(subscriber.hasCaptured(4), isTrue);
  });

  test('gesture evidence boundaries capture once before completion', () async {
    final captured = <int>[];
    final subscriber = StepEvidenceSubscriber(
      capture: (stepIndex) {
        captured.add(stepIndex);
        return true;
      },
      captureBeforeMutation: (_) {
        captured.add(-1);
        return true;
      },
    );

    for (final (index, type) in [
      (0, 'scroll'),
      (1, 'swipe'),
      (2, 'drag'),
      (3, 'pullToRefresh'),
    ]) {
      await subscriber.call(ExecutionEvent(
        sequence: index * 2,
        kind: ExecutionEventKind.evidenceBoundary,
        detail: type,
        stepIndex: index,
      ));
      await subscriber.call(ExecutionEvent(
        sequence: index * 2 + 1,
        kind: ExecutionEventKind.stepFinished,
        stepIndex: index,
      ));
    }

    expect(captured, [-1, -1, -1, -1]);
  });

  test('unsuccessful evidence can be retried at the finished boundary',
      () async {
    var captures = 0;
    final subscriber = StepEvidenceSubscriber(capture: (_) async {
      captures++;
      return true;
    });

    expect(await subscriber.captureOnce(2, () async => false), isFalse);
    await subscriber.call(const ExecutionEvent(
      sequence: 1,
      kind: ExecutionEventKind.stepFinished,
      stepIndex: 2,
    ));

    expect(captures, 1);
    expect(subscriber.hasCaptured(2), isTrue);
  });

  test('pre-mutation evidence wins over the finished-step fallback', () async {
    var preMutationCaptures = 0;
    var completedCaptures = 0;
    final subscriber = StepEvidenceSubscriber(
      capture: (_) async {
        completedCaptures++;
        return true;
      },
      captureBeforeMutation: (event) async {
        expect(event.detail, 'tap');
        preMutationCaptures++;
        return true;
      },
    );

    const boundary = ExecutionEvent(
      sequence: 1,
      kind: ExecutionEventKind.evidenceBoundary,
      stepIndex: 3,
      detail: 'tap',
    );
    await subscriber.call(boundary);
    expect(
      subscriber.call(boundary),
      isNull,
      reason: 'duplicate compatibility notifications should stay synchronous',
    );
    await subscriber.call(const ExecutionEvent(
      sequence: 2,
      kind: ExecutionEventKind.stepFinished,
      stepIndex: 3,
    ));

    expect(preMutationCaptures, 1);
    expect(completedCaptures, 0);
    expect(subscriber.hasCaptured(3), isTrue);
  });

  test('goBack evidence is captured at its pre-mutation boundary', () async {
    var preMutation = 0;
    var completed = 0;
    final subscriber = StepEvidenceSubscriber(
      capture: (_) {
        completed++;
        return true;
      },
      captureBeforeMutation: (event) {
        expect(event.detail, 'goBack');
        preMutation++;
        return true;
      },
    );

    await subscriber.call(const ExecutionEvent(
      sequence: 1,
      kind: ExecutionEventKind.evidenceBoundary,
      stepIndex: 7,
      detail: 'goBack',
    ));
    await subscriber.call(const ExecutionEvent(
      sequence: 2,
      kind: ExecutionEventKind.stepFinished,
      stepIndex: 7,
    ));

    expect(preMutation, 1);
    expect(completed, 0);
  });

  test('transient navigation evidence is captured on its matched event',
      () async {
    final captures = <String>[];
    final subscriber = StepEvidenceSubscriber(
      capture: (_) {
        captures.add('finished');
        return true;
      },
      captureBeforeMutation: (event) {
        captures.add('matched:${event.detail}');
        return true;
      },
    );

    await subscriber.call(const ExecutionEvent(
      sequence: 1,
      kind: ExecutionEventKind.evidenceBoundary,
      stepIndex: 8,
      detail: 'waitForNavigation',
    ));
    await subscriber.call(const ExecutionEvent(
      sequence: 2,
      kind: ExecutionEventKind.stepFinished,
      stepIndex: 8,
    ));

    expect(captures, ['matched:waitForNavigation']);
    expect(subscriber.hasCaptured(8), isTrue);
  });

  test('successful conditions use an explicit after-condition boundary',
      () async {
    final captures = <String>[];
    final subscriber = StepEvidenceSubscriber(
      capture: (index) {
        captures.add('finished:$index');
        return true;
      },
      captureBeforeMutation: (event) {
        captures.add('matched:${event.detail}');
        return true;
      },
    );

    expect(
      StepEvidencePolicy.isConditionStep('expectVisible'),
      isTrue,
    );
    expect(
      StepEvidencePolicy.ownsOrderedCapture('expectVisible'),
      isTrue,
    );
    await subscriber.call(const ExecutionEvent(
      sequence: 1,
      kind: ExecutionEventKind.evidenceBoundary,
      detail: 'condition:expectVisible',
      stepIndex: 4,
    ));
    await subscriber.call(const ExecutionEvent(
      sequence: 2,
      kind: ExecutionEventKind.stepFinished,
      stepIndex: 4,
    ));

    expect(captures, ['matched:condition:expectVisible']);
  });

  test('unknown condition boundary details are ignored', () async {
    var captures = 0;
    final subscriber = StepEvidenceSubscriber(
      capture: (_) => true,
      captureBeforeMutation: (_) {
        captures++;
        return true;
      },
    );

    await subscriber.call(const ExecutionEvent(
      sequence: 1,
      kind: ExecutionEventKind.evidenceBoundary,
      detail: 'condition:customStep',
      stepIndex: 4,
    ));

    expect(captures, 0);
  });
}
