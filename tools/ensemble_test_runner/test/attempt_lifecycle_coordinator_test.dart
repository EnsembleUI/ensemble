import 'dart:async';

import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/attempt_lifecycle_coordinator.dart';
import 'package:ensemble_test_runner/runner/retry_execution.dart';
import 'package:ensemble_test_runner/src/core/attempt_coordinator.dart';
import 'package:ensemble/framework/screen_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AttemptLifecycleCoordinator newCoordinator(
    WidgetTester tester, {
    String id = 'lifecycle',
  }) =>
      AttemptLifecycleCoordinator.forAttempt(
        attemptId: id,
        attempt: const AttemptDescriptor(number: 1, index: 0, total: 1),
        test: EnsembleTestCase(id: id, steps: const []),
        config: const EnsembleTestConfig(),
        tester: tester,
      );

  testWidgets('runs prepare, launch, and execute in shared phase order',
      (tester) async {
    final events = <String>[];
    final coordinator = newCoordinator(tester);

    final outcome = await coordinator.runCaptured<int, String, String>(
      prepare: () async {
        events.add('prepare');
        return 7;
      },
      launch: (prepared) async {
        expect(prepared, 7);
        events.add('launch');
        return 'handle';
      },
      execute: (prepared, launched) async {
        expect(prepared, 7);
        expect(launched, 'handle');
        events.add('execute');
        return 'passed';
      },
      beforeClose: (_, __) async => events.add('close'),
    );

    expect(outcome.requireValue(), 'passed');
    expect(events, ['prepare', 'launch', 'execute', 'close']);
  });

  testWidgets('shared attempt setup preserves identity across both contexts',
      (tester) async {
    final events = <String>[];
    const testCase = EnsembleTestCase(id: 'identity', steps: []);
    final lifecycle = AttemptLifecycleCoordinator.forAttempt(
      attemptId: 'run_identity_1',
      attempt: const AttemptDescriptor(number: 2, index: 1, total: 3),
      test: testCase,
      config: const EnsembleTestConfig(),
      tester: tester,
      checkpoint: 'checkpoint',
    );
    final attemptContext = lifecycle.attemptContext;

    expect(attemptContext.launch.attemptId, 'run_identity_1');
    expect(attemptContext.launch.attempt, 1);
    expect(attemptContext.launch.checkpoint, 'checkpoint');
    expect(attemptContext.launch.testCase, same(testCase));
    expect(attemptContext.runtime.runtime.attemptNumber, 2);
    expect(attemptContext.runtime.runtime.attemptCount, 3);

    final outcome = await tester.runAsync(
      () => lifecycle
          .runCaptured<void, void, void>(
            prepare: () async => events.add('prepare'),
            launch: (_) async => events.add('launch'),
            execute: (_, __) async => events.add('execute'),
            beforeClose: (_, __) async => events.add('cleanup'),
          )
          .timeout(const Duration(seconds: 2)),
    );

    expect(outcome?.completed, isTrue);
    expect(events, ['prepare', 'launch', 'execute', 'cleanup']);
    final recordedAtClose = attemptContext.runtime.navigationFlow.flow;
    ScreenTracker().trackScreen(screenName: 'after-attempt');
    await tester.pump();
    expect(attemptContext.runtime.navigationFlow.flow, recordedAtClose);
  });

  testWidgets('navigation listener startup is inside the guarded attempt',
      (tester) async {
    final lifecycle = AttemptLifecycleCoordinator.forAttempt(
      attemptId: 'run_navigation_setup_failure',
      attempt: const AttemptDescriptor(number: 1, index: 0, total: 1),
      test: const EnsembleTestCase(id: 'navigation_setup_failure', steps: []),
      config: const EnsembleTestConfig(),
      tester: tester,
    );
    final navigationFlow = lifecycle.attemptContext.runtime.navigationFlow;

    expect(navigationFlow.isListening, isFalse);
    final outcome = await lifecycle.runCaptured<void, void, void>(
      prepare: () async {
        expect(navigationFlow.isListening, isTrue);
        throw StateError('preparation failed');
      },
      launch: (_) async {},
      execute: (_, __) async {},
    );

    expect(outcome.bodyError, isA<StateError>());
    expect(navigationFlow.isListening, isFalse);
  });

  testWidgets('launch failure skips execution and reaches adapter close',
      (tester) async {
    final events = <String>[];
    final coordinator = newCoordinator(tester, id: 'launch-failure');

    final outcome = await coordinator.runCaptured<void, void, void>(
      prepare: () async => events.add('prepare'),
      launch: (_) async {
        events.add('launch');
        throw StateError('launch failed');
      },
      execute: (_, __) async => events.add('execute'),
      beforeClose: (error, _) async {
        expect(error.toString(), contains('launch failed'));
        events.add('close');
      },
    );

    expect(outcome.bodyError, isA<StateError>());
    expect(events, ['prepare', 'launch', 'close']);
  });

  testWidgets('body failure stays primary when adapter close also fails',
      (tester) async {
    final coordinator = newCoordinator(tester, id: 'body-failure');

    final outcome = await coordinator.runCaptured<void, void, void>(
      prepare: () async {},
      launch: (_) async {},
      execute: (_, __) async => throw StateError('execution failed'),
      beforeClose: (bodyError, _) async {
        expect(bodyError.toString(), contains('execution failed'));
        throw ArgumentError('close failed');
      },
    );

    expect(outcome.primaryFailure?.error, isA<StateError>());
    expect(
        outcome.primaryFailure?.error.toString(), contains('execution failed'));
    expect(outcome.closeError, isA<ArgumentError>());
  });

  testWidgets('attempt cleanup is gated by shared setup ownership',
      (tester) async {
    final beforeOwnership = <String>[];
    final notStarted = newCoordinator(tester, id: 'not-started');
    notStarted.registerCleanupAfterStart(() async {
      beforeOwnership.add('cleanup');
    });
    final notStartedOutcome = await notStarted.runCaptured<void, void, void>(
      prepare: () async => throw StateError('setup failed before allocation'),
      launch: (_) async {},
      execute: (_, __) async {},
    );
    expect(notStartedOutcome.bodyError, isA<StateError>());
    expect(beforeOwnership, isEmpty);

    final afterOwnership = <String>[];
    final started = newCoordinator(tester, id: 'started');
    final markStarted = started.registerCleanupAfterStart(() async {
      afterOwnership.add('cleanup');
    });
    final startedOutcome = await started.runCaptured<void, void, void>(
      prepare: () async {
        markStarted();
        throw StateError('setup failed after allocation');
      },
      launch: (_) async {},
      execute: (_, __) async {},
    );
    expect(startedOutcome.bodyError, isA<StateError>());
    expect(afterOwnership, ['cleanup']);
  });

  testWidgets('in-flight timeout and cancellation drain cleanup once',
      (tester) async {
    final interruptions = <Object>[
      TimeoutException('attempt timed out'),
      _AttemptInterrupted(),
    ];
    for (var index = 0; index < interruptions.length; index++) {
      final lifecycle = newCoordinator(tester, id: 'interrupted-$index');
      final navigationFlow = lifecycle.attemptContext.runtime.navigationFlow;
      final executeStarted = Completer<void>();
      final interruptExecution = Completer<void>();
      var cleanupCalls = 0;
      final markResourceStarted = lifecycle.registerCleanupAfterStart(() async {
        cleanupCalls++;
      });

      final running = lifecycle.runCaptured<void, void, void>(
        prepare: () async {},
        launch: (_) async {},
        execute: (_, __) async {
          markResourceStarted();
          executeStarted.complete();
          await interruptExecution.future;
        },
      );
      await executeStarted.future;
      interruptExecution.completeError(interruptions[index]);

      final outcome = await running;

      expect(outcome.bodyError, same(interruptions[index]));
      expect(cleanupCalls, 1);
      expect(navigationFlow.isListening, isFalse);
    }
  });

  testWidgets('test journey starts after launch navigation is flushed',
      (tester) async {
    ScreenTracker().clearAll();
    final lifecycle = AttemptLifecycleCoordinator.forAttempt(
      attemptId: 'run_navigation_boundary',
      attempt: const AttemptDescriptor(number: 1, index: 0, total: 1),
      test: const EnsembleTestCase(id: 'navigation_boundary', steps: []),
      config: const EnsembleTestConfig(),
      tester: tester,
    );
    final context = lifecycle.attemptContext.runtime;

    final outcome = await lifecycle.runCaptured<void, void, void>(
      prepare: () async {},
      launch: (_) async {
        ScreenTracker().trackScreen(screenName: 'Ready');
        await tester.pump();
      },
      execute: (_, __) async {
        expect(context.navigationFlow.flow, ['Ready']);
      },
    );
    expect(outcome.completed, isTrue);
    expect(outcome.primaryFailure, isNull);
  });

  testWidgets('failed launch retains routes announced before the failure',
      (tester) async {
    ScreenTracker().clearAll();
    final lifecycle = AttemptLifecycleCoordinator.forAttempt(
      attemptId: 'run_partial_launch',
      attempt: const AttemptDescriptor(number: 1, index: 0, total: 1),
      test: const EnsembleTestCase(id: 'partial_launch', steps: []),
      config: const EnsembleTestConfig(),
      tester: tester,
    );
    final context = lifecycle.attemptContext.runtime;

    final outcome = await lifecycle.runCaptured<void, void, void>(
      prepare: () async {},
      launch: (_) async {
        ScreenTracker().trackScreen(screenName: 'PartiallyOpened');
        await tester.pump();
        throw StateError('launch failed after route change');
      },
      execute: (_, __) async {},
    );

    expect(outcome.bodyError, isA<StateError>());
    expect(context.navigationFlow.flow, ['PartiallyOpened']);
  });

  test('shared attempt loop keeps identity and stops retrying after success',
      () async {
    final descriptors = <AttemptDescriptor>[];
    final sequence = await RetryExecutionCoordinator.collect<int>(
      retries: 2,
      executeAttempt: (attempt) async {
        descriptors.add(attempt);
        return attempt.number == 2 ? 1 : 0;
      },
      succeeded: (outcome) => outcome == 1,
      durationMs: (_) => 5,
      logs: (attempt) => ['attempt-$attempt'],
    );

    expect(descriptors.map((attempt) => attempt.number), [1, 2]);
    expect(descriptors.map((attempt) => attempt.index), [0, 1]);
    expect(descriptors.map((attempt) => attempt.total), [3, 3]);
    expect(sequence.outcome, 1);
    expect(sequence.attempts, 2);
    expect(sequence.durationMs, 10);
    expect(sequence.logsByAttempt, [
      ['attempt-0'],
      ['attempt-1'],
    ]);
  });

  test('shared attempt loop propagates infrastructure errors without retry',
      () async {
    var attempts = 0;
    await expectLater(
      RetryExecutionCoordinator.collect<int>(
        retries: 3,
        executeAttempt: (_) async {
          attempts++;
          throw StateError('driver infrastructure');
        },
        succeeded: (_) => false,
        durationMs: (_) => 0,
        logs: (_) => const [],
      ),
      throwsA(isA<StateError>()),
    );
    expect(attempts, 1);
  });
}

final class _AttemptInterrupted implements Exception {}
