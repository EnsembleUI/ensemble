import 'dart:async';

import 'package:ensemble_test_runner/runner/live_async_call.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(LiveAsyncCallSupport.reset);
  tearDown(LiveAsyncCallSupport.reset);

  test('reset keeps runAsync work serialized across attempts', () async {
    final firstCallStarted = Completer<void>();
    final finishFirstCall = Completer<void>();
    var activeCalls = 0;
    var maximumActiveCalls = 0;
    var secondCallStarted = false;

    LiveAsyncCallSupport.runner = <T>(Future<T> Function() callback) async {
      activeCalls++;
      if (activeCalls > maximumActiveCalls) {
        maximumActiveCalls = activeCalls;
      }
      try {
        firstCallStarted.complete();
        await finishFirstCall.future;
        return await callback();
      } finally {
        activeCalls--;
      }
    };
    final firstCall = LiveAsyncCallSupport.run(() async => 'first');
    await firstCallStarted.future;

    // This mirrors the app-owned driver tearing down one case while an
    // unawaited app request is still inside WidgetTester.runAsync.
    LiveAsyncCallSupport.reset();
    LiveAsyncCallSupport.runner = <T>(Future<T> Function() callback) async {
      activeCalls++;
      if (activeCalls > maximumActiveCalls) {
        maximumActiveCalls = activeCalls;
      }
      secondCallStarted = true;
      try {
        return await callback();
      } finally {
        activeCalls--;
      }
    };
    final secondCall = LiveAsyncCallSupport.run(() async => 'second');

    // Allow the queue's continuation a turn; it must not enter runner two
    // until runner one has fully completed.
    await Future<void>.delayed(Duration.zero);
    expect(secondCallStarted, isFalse);
    expect(LiveAsyncCallSupport.pendingLiveCallCount, 1);

    finishFirstCall.complete();
    expect(await firstCall, 'first');
    expect(await secondCall, 'second');
    expect(maximumActiveCalls, 1);
    expect(LiveAsyncCallSupport.completedLiveCallCount, 1);
    expect(LiveAsyncCallSupport.pendingLiveCallCount, 0);
  });

  test('priority diagnostic work runs before queued app calls', () async {
    final firstCallStarted = Completer<void>();
    final finishFirstCall = Completer<void>();
    final executionOrder = <String>[];

    LiveAsyncCallSupport.runner =
        <T>(Future<T> Function() callback) => callback();
    // Hold the first operation in the runner lane to make the following two
    // operations queue deterministically.
    final first = LiveAsyncCallSupport.run(() async {
      firstCallStarted.complete();
      await finishFirstCall.future;
      executionOrder.add('active');
      return 'active';
    });
    await firstCallStarted.future;
    final background = LiveAsyncCallSupport.run(() async {
      executionOrder.add('background');
      return 'background';
    });
    final diagnostic = LiveAsyncCallSupport.runPriorityUntracked(() async {
      executionOrder.add('screenshot');
      return 'screenshot';
    });

    finishFirstCall.complete();
    await Future.wait([first, background, diagnostic]);

    expect(executionOrder, ['active', 'screenshot', 'background']);
    expect(LiveAsyncCallSupport.pendingLiveCallCount, 0);
  });

  test('same-turn live calls share one runAsync scope concurrently', () async {
    var runnerCalls = 0;
    var startedCalls = 0;
    final allCallsStarted = Completer<void>();
    final finishCalls = Completer<void>();

    LiveAsyncCallSupport.runner = <T>(Future<T> Function() callback) {
      runnerCalls++;
      return callback();
    };

    Future<String> request() async {
      startedCalls++;
      if (startedCalls == 3) allCallsStarted.complete();
      await finishCalls.future;
      return 'done';
    }

    final calls = [
      LiveAsyncCallSupport.run(request),
      LiveAsyncCallSupport.run(request),
      LiveAsyncCallSupport.run(request),
    ];

    await allCallsStarted.future.timeout(const Duration(seconds: 1));
    expect(runnerCalls, 1);
    expect(startedCalls, 3);

    finishCalls.complete();
    expect(await Future.wait(calls), ['done', 'done', 'done']);
    expect(LiveAsyncCallSupport.completedLiveCallCount, 3);
  });
}
