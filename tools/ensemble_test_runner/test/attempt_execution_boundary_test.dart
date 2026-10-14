import 'dart:async';

import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/attempt_execution_boundary.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/live_async_call.dart';
import 'package:ensemble_test_runner/runner/retry_execution.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  EnsembleTestContext context() => EnsembleTestContext.fromTestCase(
        const EnsembleTestCase(id: 'boundary', steps: []),
      );

  testWidgets('runs cleanup before restoring the attempt scope',
      (tester) async {
    final events = <String>[];
    final boundary = AttemptExecutionBoundary(
      context: context(),
      tester: tester,
    );

    await boundary.run<void>(
      body: () async => events.add('body'),
      beforeClose: (_, __) async => events.add('cleanup'),
    );
    expect(events, ['body', 'cleanup']);
  });

  testWidgets('a duplicate concurrent run cannot close the active attempt',
      (tester) async {
    final previousRunner = LiveAsyncCallSupport.runner;
    final boundary = AttemptExecutionBoundary(
      context: context(),
      tester: tester,
    );
    final bodyStarted = Completer<void>();
    final finishBody = Completer<void>();
    var duplicateBodyCalls = 0;
    var cleanupCalls = 0;
    boundary.addCleanup(() async => cleanupCalls++);

    final activeRun = boundary.runCaptured<void>(
      body: () async {
        bodyStarted.complete();
        await finishBody.future;
      },
    );
    await bodyStarted.future;
    final activeRunner = LiveAsyncCallSupport.runner;
    expect(activeRunner, isNot(same(previousRunner)));

    await expectLater(
      boundary.runCaptured<void>(
        body: () async => duplicateBodyCalls++,
      ),
      throwsA(isA<StateError>()),
    );
    expect(duplicateBodyCalls, 0);
    expect(LiveAsyncCallSupport.runner, same(activeRunner));
    expect(cleanupCalls, 0);

    finishBody.complete();
    final outcome = await activeRun;
    expect(outcome.completed, isTrue);
    expect(cleanupCalls, 1);
    expect(LiveAsyncCallSupport.runner, same(previousRunner));
  });

  testWidgets('shared attempt owner drains adapter resources in reverse order',
      (tester) async {
    final events = <String>[];
    final boundary = AttemptExecutionBoundary(
      context: context(),
      tester: tester,
    )..addCleanup(() async => events.add('driver'));
    boundary.addCleanup(() async => events.add('session'));

    await boundary.run<void>(
      body: () async => events.add('body'),
      beforeClose: (_, __) async => events.add('report'),
    );

    expect(events, ['body', 'report', 'session', 'driver']);
  });

  testWidgets('shared cleanup failure remains secondary to body failure',
      (tester) async {
    final boundary = AttemptExecutionBoundary(
      context: context(),
      tester: tester,
    )..addCleanup(() async => throw StateError('resource cleanup'));

    final outcome = await boundary.runCaptured<void>(
      body: () async => throw FormatException('attempt body'),
    );

    expect(outcome.bodyError, isA<FormatException>());
    expect(outcome.closeError.toString(), contains('resource cleanup'));
    expect(outcome.primaryFailure?.error, same(outcome.bodyError));

    final failure = EnsembleSingleTestResult.failed(
      testId: 'boundary',
      durationMs: 0,
      message: outcome.primaryFailure!.error.toString(),
      stackTrace: outcome.primaryFailure!.stackTrace.toString(),
    );
    final projected = RetryExecutionCoordinator.withAttemptCleanupFailure(
      failure,
      error: outcome.closeError!,
      stackTrace: outcome.closeStackTrace ?? StackTrace.current,
    );

    expect(projected.message, contains('attempt body'));
    expect(projected.secondaryFailures, hasLength(1));
    expect(projected.secondaryFailures.single.kind, TestFailureKind.cleanup);
    expect(
      projected.secondaryFailures.single.message,
      contains('resource cleanup'),
    );
  });

  testWidgets('retains runtime hook restoration failures in attempt outcome',
      (tester) async {
    final boundary = AttemptExecutionBoundary(
      context: context(),
      tester: tester,
      captureDebugPrint: () => () => throw StateError('debug print restore'),
    );

    final outcome = await boundary.runCaptured<void>(
      body: () async => throw FormatException('attempt body'),
    );

    expect(outcome.primaryFailure?.error, same(outcome.bodyError));
    expect(
      outcome.closeFailures.map((failure) => failure.error.toString()),
      ['Bad state: debug print restore'],
    );
  });

  testWidgets('attempt close callbacks run once when every cleanup fails',
      (tester) async {
    var beforeCloseCalls = 0;
    var resourceCleanupCalls = 0;
    final boundary = AttemptExecutionBoundary(
      context: context(),
      tester: tester,
    )..addCleanup(() async {
        resourceCleanupCalls++;
        throw StateError('resource cleanup');
      });

    final outcome = await boundary.runCaptured<void>(
      body: () async {},
      beforeClose: (_, __) async {
        beforeCloseCalls++;
        throw FormatException('adapter cleanup');
      },
    );

    expect(beforeCloseCalls, 1);
    expect(resourceCleanupCalls, 1);
    expect(outcome.closeError, isA<FormatException>());
    expect(outcome.primaryFailure?.error, same(outcome.closeError));
  });

  testWidgets('restores a pre-existing overlay async runner on close',
      (tester) async {
    final testContext = context();
    Future<T?> previousRunner<T>(Future<T> Function() callback) => callback();
    testContext.apiOverlay.liveAsyncRunner = previousRunner;
    final boundary = AttemptExecutionBoundary(
      context: testContext,
      tester: tester,
    );

    await boundary.run<void>(body: () async {});

    expect(testContext.apiOverlay.liveAsyncRunner, same(previousRunner));
  });

  testWidgets('restores an empty overlay async runner on close',
      (tester) async {
    final testContext = context();
    expect(testContext.apiOverlay.liveAsyncRunner, isNull);
    final boundary = AttemptExecutionBoundary(
      context: testContext,
      tester: tester,
    );

    await boundary.run<void>(body: () async {
      expect(testContext.apiOverlay.liveAsyncRunner, isNotNull);
    });

    expect(testContext.apiOverlay.liveAsyncRunner, isNull);
  });

  testWidgets('keeps a body failure primary when cleanup also fails',
      (tester) async {
    final boundary = AttemptExecutionBoundary(
      context: context(),
      tester: tester,
    );

    Object? caught;
    try {
      await boundary.run<void>(
        body: () async => throw StateError('body'),
        beforeClose: (_, __) async => throw FormatException('cleanup'),
      );
    } catch (error) {
      caught = error;
    }

    expect(caught, isA<StateError>());
    expect(caught.toString(), contains('body'));
  });

  testWidgets('captures body and close failures for report projection',
      (tester) async {
    final boundary = AttemptExecutionBoundary(
      context: context(),
      tester: tester,
    );
    Object? observedBodyError;
    final outcome = await boundary.runCaptured<void>(
      body: () async => throw StateError('body'),
      beforeClose: (bodyError, _) async {
        observedBodyError = bodyError;
        throw FormatException('close');
      },
    );

    expect(observedBodyError.toString(), contains('body'));
    expect(outcome.bodyError.toString(), contains('body'));
    expect(outcome.closeError.toString(), contains('close'));
    expect(outcome.primaryFailure?.error, same(outcome.bodyError));
    expect(outcome.completed, isFalse);
  });

  testWidgets('retains every cleanup failure for shared result projection',
      (tester) async {
    final boundary = AttemptExecutionBoundary(
      context: context(),
      tester: tester,
    )..addCleanup(() => throw StateError('resource cleanup'));
    boundary.addCleanup(() => throw FormatException('later cleanup'));

    final outcome = await boundary.runCaptured<void>(
      body: () async => throw StateError('body'),
      beforeClose: (_, __) async => throw ArgumentError('adapter close'),
    );

    expect(outcome.primaryFailure?.error, same(outcome.bodyError));
    expect(
      outcome.closeFailures.map((failure) => failure.error.toString()),
      [
        'Invalid argument(s): adapter close',
        'FormatException: later cleanup',
        'Bad state: resource cleanup',
      ],
    );
  });

  testWidgets('captures scope setup failure and still runs adapter cleanup',
      (tester) async {
    final boundary = AttemptExecutionBoundary(
      context: context(),
      tester: tester,
      captureDebugPrint: () => throw StateError('hook setup failed'),
    );
    var bodyCalls = 0;
    var cleanupCalls = 0;

    final outcome = await boundary.runCaptured<void>(
      body: () async => bodyCalls++,
      beforeClose: (bodyError, _) async {
        expect(bodyError.toString(), contains('hook setup failed'));
        cleanupCalls++;
      },
    );

    expect(bodyCalls, 0);
    expect(cleanupCalls, 1);
    expect(outcome.bodyError.toString(), contains('hook setup failed'));
    expect(outcome.completed, isFalse);
  });

  testWidgets('restores every hook when debug print restoration throws',
      (tester) async {
    final testContext = context();
    final previousFlutterError = FlutterError.onError;
    final previousRunner = LiveAsyncCallSupport.runner;
    final previousPlatformRunner = LiveAsyncCallSupport.platformHttpRunner;
    final previousOverlayRunner = testContext.apiOverlay.liveAsyncRunner;
    Future<T?> runner<T>(Future<T> Function() callback) => callback();
    void Function(FlutterErrorDetails) flutterErrorHandler = (_) {};
    FlutterError.onError = flutterErrorHandler;
    LiveAsyncCallSupport.runner = runner;
    LiveAsyncCallSupport.platformHttpRunner = runner;
    testContext.apiOverlay.liveAsyncRunner = runner;

    try {
      final boundary = AttemptExecutionBoundary(
        context: testContext,
        tester: tester,
        captureDebugPrint: () => () => throw StateError('debug restore failed'),
      );

      final outcome = await boundary.runCaptured<void>(body: () async {});

      expect(outcome.closeError.toString(), contains('debug restore failed'));
      expect(FlutterError.onError, same(flutterErrorHandler));
      expect(LiveAsyncCallSupport.runner, same(runner));
      expect(LiveAsyncCallSupport.platformHttpRunner, same(runner));
      expect(testContext.apiOverlay.liveAsyncRunner, same(runner));
    } finally {
      FlutterError.onError = previousFlutterError;
      LiveAsyncCallSupport.runner = previousRunner;
      LiveAsyncCallSupport.platformHttpRunner = previousPlatformRunner;
      testContext.apiOverlay.liveAsyncRunner = previousOverlayRunner;
    }
  });

  testWidgets('selects cleanup failure when the attempt body passes',
      (tester) async {
    final boundary = AttemptExecutionBoundary(
      context: context(),
      tester: tester,
    );
    final outcome = await boundary.runCaptured<void>(
      body: () async {},
      beforeClose: (_, __) async => throw StateError('cleanup'),
    );

    expect(outcome.completed, isTrue);
    expect(outcome.bodyError, isNull);
    expect(outcome.primaryFailure?.error, same(outcome.closeError));
  });
}
