import 'dart:async';

import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'support/test_step_executor_handler_harness.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:ensemble_test_runner/mocks/test_logger.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/runner/step_report_capture.dart';
import 'package:ensemble_test_runner/runner/test_visual_artifacts.dart';
import 'package:ensemble_test_runner/session/errors/test_execution_error.dart';
import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:ensemble_test_runner/session/operation_result.dart';
import 'package:ensemble_test_runner/session/session_capabilities.dart';
import 'package:ensemble_test_runner/src/core/operation_input.dart'
    show OperationInput;
import 'package:ensemble_test_runner/src/core/operation_registry.dart'
    show OperationDescriptor;
import 'support/session_operation.dart';
import 'package:ensemble_test_runner/session/wait_operation_handler.dart';
import 'package:ensemble/framework/screen_tracker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('registered wait dispatch stays on its selected wait route',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('Ready')));
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'registered_wait_route', steps: []),
    );
    final executor = _RegisteredWaitRouteTrackingExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
    );
    final boundaries = <String>[];
    executor.onOperationEvidenceBoundary =
        (_, detail) => boundaries.add(detail);

    await executor.executeWaitOperation(
      sessionOperation('waitForText', input: const {
        'text': 'Ready',
        'timeoutMs': 10,
      }),
    );

    expect(executor.registeredWaitDispatches, 1);
    expect(boundaries, ['waitForText']);
  });

  testWidgets('waitForText evidence boundary captures matched state',
      (tester) async {
    var label = 'Ready';
    late StateSetter updateLabel;
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(builder: (context, setState) {
        updateLabel = setState;
        return Text(label);
      }),
    ));
    final session = _session(tester, screenshotsEnabled: true);
    final visuals = TestVisualArtifacts(
      screenshotSheets: () => null,
      drainFlutterExceptions: (_) {},
    );
    final matched = <String>[];
    session.executor.onOperationEvidenceBoundary = (operation, _) async {
      final matchedText = operation.arguments['text']?.toString() ?? '';
      matched.add(matchedText);
      // Replace the text at the start of the next frame. Evidence at the
      // successful wait boundary must not advance to that replacement state.
      WidgetsBinding.instance.scheduleFrameCallback((_) {
        updateLabel(() => label = 'Later state');
      });
      final step = TestStep(
        type: 'waitForText',
        args: {'text': matchedText},
      );
      await visuals.waitForHighlightTargetToPaint(session.executor, step);
      await visuals.captureStepArtifacts(
        executor: session.executor,
        step: step,
        stepIndex: 0,
        options: StepScreenshotOptions.waitForTextMatched(),
      );
    };

    await WaitOperationHandler(session).execute(sessionOperation('waitForText',
        input: {'text': 'Ready', 'timeoutMs': 100}));

    expect(matched, ['Ready']);
    expect(session.context.runtime.screenshotSheetFrames, hasLength(1));
    expect(session.context.runtime.stepObservers, hasLength(1));
    expect(
      session.context.runtime.stepObservers.single.observationJson.toString(),
      contains('Ready'),
    );
    expect(
      session.context.runtime.stepObservers.single.observationJson.toString(),
      isNot(contains('Later state')),
    );
    await tester.pump();
    expect(find.text('Later state'), findsOneWidget);
    await session.close();
  });

  testWidgets('text-bearing waitFor is serialized with session leaf commands',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('Ready')));
    final session = _session(tester);
    final started = Completer<void>();
    final release = Completer<void>();
    final blocker = session.queue.run(() async {
      started.complete();
      await release.future;
    });
    await started.future;

    var completed = false;
    final wait = WaitOperationHandler(session)
        .execute(sessionOperation('waitFor', input: {'text': 'Ready'}))
        .whenComplete(() => completed = true);

    // Let the handler submit its command to the queue before checking it.
    await Future<void>.microtask(() {});
    expect(completed, isFalse);

    release.complete();
    await blocker;
    await wait;
    expect(completed, isTrue);
    await session.close();
  });

  testWidgets('waitForText operation emits one ordered evidence boundary',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('Ready')));
    final session = _session(tester);
    final order = <String>[];
    session.executor.onOperationEvidenceBoundary = (operation, detail) {
      order.add('event:$detail');
    };

    await WaitOperationHandler(session).execute(sessionOperation('waitForText',
        input: {'text': 'Ready', 'timeoutMs': 100}));

    expect(order, ['event:waitForText']);
    await session.close();
  });

  testWidgets('text wait delegates exact anyOf match with parity evidence',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('Ready')));
    final session = _session(tester);
    final boundaries = <OperationInput>[];
    session.executor.onOperationEvidenceBoundary = (operation, _) {
      boundaries.add(operation);
    };

    await WaitOperationHandler(session).execute(
      sessionOperation('waitFor', input: {
        'anyOf': ['Loading', 'Ready'],
        'timeoutMs': 100,
      }),
    );

    expect(boundaries, hasLength(1));
    expect(boundaries.single.operationName, 'waitFor');
    expect(boundaries.single.arguments['text'], 'Ready');
    expect(boundaries.single.arguments, isNot(contains('anyOf')));
    await session.close();
  });

  testWidgets('compiled text wait evidence stays an operation', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('Ready')));
    final session = _session(tester);
    final boundaries = <String>[];
    session.executor.onEvidenceBoundary = (_) {
      fail('Compiled wait evidence must not be projected into TestStep.');
    };
    session.executor.onOperationEvidenceBoundary = (operation, detail) {
      boundaries.add('$detail:${operation.operationName}');
      expect(operation.arguments['text'], 'Ready');
      expect(operation.arguments, isNot(contains('anyOf')));
    };

    await WaitOperationHandler(session).execute(
      sessionOperation('waitFor', input: {
        'anyOf': ['Loading', 'Ready'],
        'timeoutMs': 100,
      }),
    );

    expect(boundaries, ['condition:waitFor:waitFor']);
    await session.close();
  });

  testWidgets('text-bearing waitFor preserves element-or-text behavior',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('Ready')));
    final session = _session(tester);
    final boundaries = <String>[];
    session.executor.onOperationEvidenceBoundary =
        (_, detail) => boundaries.add(detail);

    await WaitOperationHandler(session).execute(sessionOperation('waitFor',
        input: {'id': 'missing-element', 'text': 'Ready', 'timeoutMs': 500}));

    expect(boundaries, ['condition:waitFor']);
    await session.close();
  });

  testWidgets('waitFor decodes a serialized ElementTarget through shared logic',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Text('Ready', key: ValueKey('ready')),
      ),
    );
    final session = _session(tester);

    await WaitOperationHandler(session)
        .execute(sessionOperation('waitFor', input: {
      'target': {'testId': 'ready'},
      'timeoutMs': 100,
    }));

    await session.close();
  });

  testWidgets('text-bearing waitFor enforces text-wait permission',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('Ready')));
    final session = _session(
      tester,
      permissions: const SessionPermissions(waits: {'uiElement'}),
    );

    await expectLater(
      WaitOperationHandler(session)
          .execute(sessionOperation('waitFor', input: {'text': 'Ready'})),
      throwsA(
        isA<TestExecutionError>().having(
          (error) => error.code,
          'code',
          TestExecutionErrorCode.permissionDenied,
        ),
      ),
    );
    await session.close();
  });

  testWidgets('text-bearing waitFor preserves structured timeout errors',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('Ready')));
    final session = _session(tester);

    await expectLater(
      WaitOperationHandler(session).execute(sessionOperation('waitFor',
          input: {'text': 'Missing', 'timeoutMs': 0})),
      throwsA(
        isA<TestExecutionError>().having(
          (error) => error.code,
          'code',
          TestExecutionErrorCode.actionTimeout,
        ),
      ),
    );
    await session.close();
  });

  testWidgets('session timeout overrides serialized text wait timeout',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('Ready')));
    final session = _session(tester);

    final result = await session.waitFor(
      sessionOperation('waitForText', input: const {
        'text': 'Missing',
        'timeoutMs': 10000,
      }),
      timeout: Duration.zero,
    );

    expect(result.status, WaitStatus.timedOut);
    expect(result.error?.code, TestExecutionErrorCode.actionTimeout);
    await session.close();
  });

  testWidgets('structured target timeout override matches text wait behavior',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('Ready')));
    final session = _session(tester);

    final result = await session.waitFor(
      sessionOperation('waitFor', input: const {
        'target': {'testId': 'missing'},
        'timeoutMs': 10000,
      }),
      timeout: Duration.zero,
    );

    expect(result.status, WaitStatus.timedOut);
    expect(result.error?.code, TestExecutionErrorCode.actionTimeout);
    await session.close();
  });

  testWidgets('structured waitForGone preserves existence-only semantics',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Text('Status label', key: ValueKey('status_label')),
    ));
    final session = _session(tester);

    EnsembleTestFailure? directFailure;
    try {
      await session.executor.execute(const TestStep(
        type: 'waitForGone',
        args: {'id': 'status_label', 'timeoutMs': 0},
      ));
    } on EnsembleTestFailure catch (error) {
      directFailure = error;
    }
    expect(directFailure?.message, contains('Timed out'));

    final result = await session.waitFor(
      sessionOperation('waitForGone', input: const {
        'target': {'id': 'status_label'},
        'timeoutMs': 0,
      }),
    );

    expect(result.status, WaitStatus.timedOut);
    expect(result.error?.code, TestExecutionErrorCode.actionTimeout);
    await session.close();
  });

  testWidgets('empty navigation screen is rejected by both execution paths',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('Home')));
    final session = _session(tester);
    const step = TestStep(
      type: 'waitForNavigation',
      args: {'screen': '', 'timeoutMs': 0},
    );

    await expectLater(
      session.executor.execute(step),
      throwsA(
        isA<EnsembleTestFailure>().having(
          (error) => error.message,
          'message',
          'waitForNavigation requires "screen"',
        ),
      ),
    );
    await expectLater(
      WaitOperationHandler(session)
          .execute(sessionOperation('waitForNavigation', input: step.args)),
      throwsA(
        isA<TestExecutionError>().having(
          (error) => error.message,
          'message',
          'waitForNavigation requires "screen"',
        ),
      ),
    );

    await session.close();
  });

  testWidgets('navigation timeout fallback matches across execution paths',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('Home')));
    ScreenTracker().clearAll();
    addTearDown(ScreenTracker().clearAll);
    ScreenTracker().trackScreen(screenName: 'Home');
    final session = _session(tester);
    session.context.navigationFlow.seed(['Home']);
    const input = {'screen': 'Home', 'timeoutMs': 'invalid'};

    await session.executor.execute(
      const TestStep(type: 'waitForNavigation', args: input),
    );
    final result = await session.waitFor(
      sessionOperation('waitForNavigation', input: input),
    );

    expect(result.status, WaitStatus.satisfied);
    await session.close();
  });

  testWidgets('navigation wait paths publish one ordered matched boundary each',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('Home')));
    ScreenTracker().clearAll();
    addTearDown(ScreenTracker().clearAll);
    ScreenTracker().trackScreen(screenName: 'Home');
    final session = _session(tester);
    session.context.navigationFlow.seed(['Home']);
    final boundaries = <String>[];
    session.executor.onEvidenceBoundary = (step) => boundaries.add(step.type);
    session.executor.onOperationEvidenceBoundary =
        (_, detail) => boundaries.add(detail);

    await session.executor.execute(const TestStep(
      type: 'waitForNavigation',
      args: {'screen': 'Home', 'timeoutMs': 1},
    ));
    await WaitOperationHandler(session).execute(
      sessionOperation('waitForNavigation',
          input: const {'screen': 'Home', 'timeoutMs': 1}),
    );

    expect(boundaries, ['waitForNavigation', 'waitForNavigation']);
    await session.close();
  });

  testWidgets('session navigation wait publishes the operation boundary',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('Home')));
    ScreenTracker().clearAll();
    addTearDown(ScreenTracker().clearAll);
    ScreenTracker().trackScreen(screenName: 'Home');
    final session = _session(tester);
    session.context.navigationFlow.seed(['Home']);
    final boundaries = <String>[];
    session.executor.onOperationEvidenceBoundary = (operation, detail) {
      boundaries.add('${operation.operationName}:$detail');
    };

    await WaitOperationHandler(session).execute(
      sessionOperation('waitForNavigation', input: const {
        'screen': 'Home',
        'timeoutMs': 1,
      }),
    );

    expect(boundaries, ['waitForNavigation:waitForNavigation']);
    await session.close();
  });

  testWidgets('waitForText keeps text scoped to its structured target',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(
          children: [
            KeyedSubtree(key: ValueKey('scope'), child: Text('Other')),
            Text('Ready'),
          ],
        ),
      ),
    );
    final session = _session(tester);
    await expectLater(
      WaitOperationHandler(session)
          .execute(sessionOperation('waitForText', input: {
        'text': 'Ready',
        'target': {'id': 'scope'},
        'timeoutMs': 0,
      })),
      throwsA(isA<TestExecutionError>()),
    );

    await session.close();
  });
}

class _RegisteredWaitRouteTrackingExecutor extends TestStepExecutor {
  _RegisteredWaitRouteTrackingExecutor({
    required super.tester,
    required super.context,
    required super.assertions,
  });

  int registeredWaitDispatches = 0;

  @override
  Future<void> executeRegisteredWaitInput(
    OperationInput input, {
    required OperationDescriptor descriptor,
  }) {
    registeredWaitDispatches++;
    return super.executeRegisteredWaitInput(input, descriptor: descriptor);
  }
}

LocalTestExecutionSession _session(
  WidgetTester tester, {
  SessionPermissions? permissions,
  bool screenshotsEnabled = false,
}) {
  return LocalTestExecutionSession.attach(
    tester: tester,
    harness: EnsembleTestHarness(appPath: 'unused/', appHome: 'Home'),
    context: EnsembleTestContext(
      testCase: const EnsembleTestCase(id: 'yaml-wait', steps: []),
      config: EnsembleTestConfig(
        screenshots: ScreenshotConfig(enabled: screenshotsEnabled),
      ),
      apiOverlay: TestApiProviderOverlay(mocks: const {}),
      logger: TestLogger(),
      setup: const EnsembleTestSetup(),
    ),
    permissions: permissions ?? SessionPermissions.testController,
  );
}
