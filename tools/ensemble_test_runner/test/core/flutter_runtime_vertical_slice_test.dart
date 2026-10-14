// ignore_for_file: deprecated_member_use_from_same_package

import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:ensemble_test_runner/mocks/test_logger.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/parser/ensemble_test_parser.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/runner/step_report_capture.dart';
import 'package:ensemble_test_runner/runner/test_visual_artifacts.dart';
import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:ensemble_test_runner/session/session_capabilities.dart';
import 'package:ensemble_test_runner/src/runtime/compiled_plan.dart';
import 'package:ensemble_test_runner/src/core/kernel.dart';
import 'package:ensemble_test_runner/src/core/execution_kernel_runner.dart';
import 'package:ensemble_test_runner/src/runtime/step_evidence_subscriber.dart';
import 'package:ensemble_test_runner/src/core/operation.dart';
import 'package:ensemble_test_runner/src/core/plan.dart';
import 'package:ensemble_test_runner/src/core/policy.dart';
import 'package:ensemble_test_runner/src/core/runtime.dart';
import 'package:ensemble_test_runner/src/runtime/flutter_test_runtime.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test_event_loop.dart';

void main() {
  testWidgets('compiled goBack evidence captures the visible route before pop',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            key: const ValueKey('push-second-route'),
            onPressed: () => Navigator.of(context).push<void>(
              PageRouteBuilder<void>(
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
                pageBuilder: (_, __, ___) => const Scaffold(
                  body: Text('SecondRoute'),
                ),
              ),
            ),
            child: const Text('FirstRoute'),
          ),
        ),
      ),
    ));
    await tester.tap(find.byKey(const ValueKey('push-second-route')));
    await tester.pump();
    expect(find.text('SecondRoute'), findsOneWidget);

    final testCase = EnsembleTestParser.parseString('''
id: go_back_capture_order
steps:
  - goBack: {}
''');
    final context = EnsembleTestContext(
      testCase: testCase,
      config: const EnsembleTestConfig(
        screenshots: ScreenshotConfig(enabled: true),
      ),
      apiOverlay: TestApiProviderOverlay(mocks: const {}),
      logger: TestLogger(),
      setup: const EnsembleTestSetup(),
    );
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: context,
    );
    final visuals = TestVisualArtifacts(
      screenshotSheets: () => null,
      drainFlutterExceptions: (_) {},
    );
    var boundaryCaptureCount = 0;
    final evidence = StepEvidenceSubscriber(
      capture: (_) async => false,
      captureBeforeMutation: (event) async {
        expect(event.detail, 'goBack');
        expect(find.text('SecondRoute'), findsOneWidget);
        expect(find.text('FirstRoute'), findsNothing);
        boundaryCaptureCount++;
        return visuals.captureStepArtifacts(
          executor: session.executor,
          step: testCase.steps[event.stepIndex!],
          stepIndex: event.stepIndex!,
          options: StepScreenshotOptions.beforeAction(),
        );
      },
    );
    final runtime = FlutterTestRuntime(session);
    final result = await ExecutionKernelRunner(
      plan: CompiledPlanCompiler().compile(testCase),
      runtime: runtime,
      eventSubscribers: [
        (event) {
          if (event.kind == ExecutionEventKind.stepStarted) {
            context.runtime.currentStepIndex = event.stepIndex;
          }
          return evidence(event);
        },
      ],
    ).run();

    expect(result.outcome, AttemptOutcome.passed,
        reason: result.cause?.toString());
    expect(boundaryCaptureCount, 1);
    expect(find.text('FirstRoute'), findsOneWidget);
    expect(find.text('SecondRoute'), findsNothing);
    expect(context.runtime.stepObservers, hasLength(1));
    final observation =
        context.runtime.stepObservers.single.observationJson.toString();
    expect(observation, contains('SecondRoute'));
    expect(observation, isNot(contains('FirstRoute')));
    await runtime.close();
  });

  testWidgets('standalone tap evidence captures the pre-navigation screen',
      (tester) async {
    var detailsVisible = false;
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(builder: (context, setState) {
        return Scaffold(
          body: detailsVisible
              ? const Text('DeviceDetails')
              : Column(children: [
                  const Text('Devices'),
                  ElevatedButton(
                    key: const ValueKey('gateway_card'),
                    onPressed: () => setState(() => detailsVisible = true),
                    child: const Text('Gateway'),
                  ),
                ]),
        );
      }),
    ));

    final testCase = EnsembleTestParser.parseString('''
id: tap_capture_order
steps:
  - tap: {id: gateway_card}
''');
    final context = EnsembleTestContext(
      testCase: testCase,
      config: const EnsembleTestConfig(
        screenshots: ScreenshotConfig(enabled: true),
      ),
      apiOverlay: TestApiProviderOverlay(mocks: const {}),
      logger: TestLogger(),
      setup: const EnsembleTestSetup(),
    );
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: context,
    );
    final visuals = TestVisualArtifacts(
      screenshotSheets: () => null,
      drainFlutterExceptions: (_) {},
    );
    final evidence = StepEvidenceSubscriber(
      capture: (_) async => false,
      captureBeforeMutation: (event) async {
        expect(event.detail, 'tap');
        expect(detailsVisible, isFalse);
        expect(find.text('Devices'), findsOneWidget);
        expect(find.text('DeviceDetails'), findsNothing);
        return visuals.captureStepArtifacts(
          executor: session.executor,
          step: testCase.steps[event.stepIndex!],
          stepIndex: event.stepIndex!,
          options: StepScreenshotOptions.beforeAction(
            targetAlreadyResolved: true,
          ),
        );
      },
    );
    final runtime = FlutterTestRuntime(session);
    final result = await ExecutionKernelRunner(
      plan: CompiledPlanCompiler().compile(testCase),
      runtime: runtime,
      eventSubscribers: [
        (event) {
          if (event.kind == ExecutionEventKind.stepStarted) {
            context.runtime.currentStepIndex = event.stepIndex;
          }
          return evidence(event);
        },
      ],
    ).run();

    expect(result.outcome, AttemptOutcome.passed,
        reason: result.cause?.toString());
    expect(detailsVisible, isTrue);
    expect(context.runtime.stepObservers, hasLength(1));
    final observation =
        context.runtime.stepObservers.single.observationJson.toString();
    expect(observation, contains('Devices'));
    expect(observation, isNot(contains('DeviceDetails')));
    await runtime.close();
  });

  testWidgets('compiled setDevice enforces the same permission before resize',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('Home')));
    final initialSize = tester.binding.renderViews.first.size;
    final testCase = EnsembleTestParser.parseString('''
id: compiled_set_device_permission_slice
startScreen: Home
steps:
  - setDevice: {width: 393, height: 852}
''');
    final context = EnsembleTestContext(
      testCase: testCase,
      apiOverlay: TestApiProviderOverlay(mocks: const {}),
      logger: TestLogger(),
      setup: const EnsembleTestSetup(),
    );
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: context,
      harness: EnsembleTestHarness(appPath: 'ensemble/apps/', appHome: 'Home'),
      permissions: SessionPermissions.restrictedUi,
    );
    final runtime = FlutterTestRuntime(session);

    final result = await runtime.execute(TestOperation(
      id: 'set-device',
      name: 'setDevice',
      kind: OperationKind.environment,
      handlerKey: 'environment.setDevice',
      input: const {'width': 393, 'height': 852},
      source: const SourceLocation(
        'compiled_set_device_permission_slice.yaml',
        'steps/0',
      ),
    ));

    expect(result.succeeded, isFalse);
    expect(result.errorCode, 'permissionDenied');
    expect(tester.binding.renderViews.first.size, initialSize);
    expect(context.runtime.deviceSize, isNull);
    await runtime.close();
  });

  testWidgets('compiled environment operation preserves executor arguments',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('Home')));
    final testCase = EnsembleTestParser.parseString('''
id: environment_runtime_slice
startScreen: Home
steps:
  - setEnv: {key: FEATURE_FLAG, value: true}
''');
    final context = EnsembleTestContext(
      testCase: testCase,
      apiOverlay: TestApiProviderOverlay(mocks: const {}),
      logger: TestLogger(),
      setup: const EnsembleTestSetup(),
    );
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: context,
    );
    final runtime = FlutterTestRuntime(session);

    final result = await runtime.execute(TestOperation(
      id: 'set-environment',
      name: 'setEnv',
      kind: OperationKind.environment,
      handlerKey: 'environment.set',
      input: const {'key': 'FEATURE_FLAG', 'value': true},
      source: const SourceLocation('environment_runtime_slice.yaml', 'steps/0'),
    ));

    expect(result.succeeded, isTrue, reason: result.error);
    expect(context.envOverrides, {'FEATURE_FLAG': true});
    await runtime.close();
  });

  testWidgets('compiled setEnv uses the direct environment handler',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('Home')));
    final testCase = EnsembleTestParser.parseString('''
id: environment_permission_slice
startScreen: Home
steps:
  - setEnv: {key: FEATURE_FLAG, value: true}
''');
    final context = EnsembleTestContext(
      testCase: testCase,
      apiOverlay: TestApiProviderOverlay(mocks: const {}),
      logger: TestLogger(),
      setup: const EnsembleTestSetup(),
    );
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: context,
      permissions: SessionPermissions.restrictedUi,
    );
    final runtime = FlutterTestRuntime(session);

    final result = await runtime.execute(TestOperation(
      id: 'set-environment',
      name: 'setEnv',
      kind: OperationKind.environment,
      handlerKey: 'environment.set',
      input: const {'key': 'FEATURE_FLAG', 'value': true},
      source:
          const SourceLocation('environment_permission_slice.yaml', 'steps/0'),
    ));

    expect(result.succeeded, isFalse);
    expect(result.errorCode, 'permissionDenied');
    expect(context.envOverrides, isEmpty);
    await runtime.close();
  });

  testWidgets('compiled lifecycle goBack uses the runtime boundary',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            key: const ValueKey('push'),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(
                  body: Text('Second route', key: ValueKey('second-route')),
                ),
              ),
            ),
            child: const Text('Push'),
          ),
        ),
      ),
    ));
    await tester.tap(find.byKey(const ValueKey('push')));
    await pumpUntilIdle(tester);
    expect(find.byKey(const ValueKey('second-route')), findsOneWidget);

    final testCase = EnsembleTestParser.parseString('''
id: lifecycle_runtime_slice
startScreen: Home
steps:
  - goBack: {}
''');
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase: testCase,
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      permissions: SessionPermissions.testController,
    );
    var callbackSawPreNavigationState = false;
    final runtime = FlutterTestRuntime(session);
    runtime.bindEvidenceBoundaryEmitter((_, operation) {
      if (operation == 'goBack') {
        callbackSawPreNavigationState =
            find.byKey(const ValueKey('second-route')).evaluate().isNotEmpty;
      }
    });

    final result = await runtime.execute(TestOperation(
      id: 'go-back',
      name: 'goBack',
      kind: OperationKind.lifecycle,
      handlerKey: 'lifecycle.goBack',
      input: const {},
      source: const SourceLocation('lifecycle_runtime_slice.yaml', 'steps/0'),
    ));

    expect(result.succeeded, isTrue, reason: result.error);
    expect(callbackSawPreNavigationState, isTrue);
    await pumpUntilIdle(tester);
    expect(find.byKey(const ValueKey('push')), findsOneWidget);
    expect(find.byKey(const ValueKey('second-route')), findsNothing);
    await runtime.close();
  });

  testWidgets('compiled trigger publishes its pre-tap evidence boundary',
      (tester) async {
    var taps = 0;
    var mutationApplied = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(builder: (context, setState) {
          return Column(children: [
            Text(mutationApplied ? 'After' : 'Before'),
            ElevatedButton(
              key: const ValueKey('trigger-target'),
              onPressed: () => setState(() {
                taps++;
                mutationApplied = true;
              }),
              child: const Text('Trigger'),
            ),
          ]);
        }),
      ),
    ));
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase:
            const EnsembleTestCase(id: 'trigger_lifecycle_slice', steps: []),
        config: const EnsembleTestConfig(
          screenshots: ScreenshotConfig(enabled: true),
        ),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
    );
    var callbackSawPreTapState = false;
    final runtime = FlutterTestRuntime(session);
    runtime.bindEvidenceBoundaryEmitter((_, operation) {
      if (operation == 'trigger') {
        callbackSawPreTapState = find.text('Before').evaluate().isNotEmpty;
      }
    });

    final result = await runtime.execute(TestOperation(
      id: 'trigger',
      name: 'trigger',
      kind: OperationKind.lifecycle,
      handlerKey: 'lifecycle.trigger',
      input: const {'id': 'trigger-target', 'action': 'onTap'},
      source: const SourceLocation('trigger_lifecycle_slice.yaml', 'steps/0'),
    ));

    expect(result.succeeded, isTrue, reason: result.error);
    expect(callbackSawPreTapState, isTrue);
    expect(taps, 1);
    expect(mutationApplied, isTrue);
    await runtime.close();
  });

  testWidgets('compiled lifecycle goBack honors session permissions',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('Home')));
    final testCase = EnsembleTestParser.parseString('''
id: lifecycle_permission_slice
startScreen: Home
steps:
  - goBack: {}
''');
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase: testCase,
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      permissions: SessionPermissions.restrictedUi,
    );
    final runtime = FlutterTestRuntime(session);

    final result = await runtime.execute(TestOperation(
      id: 'go-back',
      name: 'goBack',
      kind: OperationKind.lifecycle,
      handlerKey: 'lifecycle.goBack',
      input: const {},
      source:
          const SourceLocation('lifecycle_permission_slice.yaml', 'steps/0'),
    ));

    expect(result.succeeded, isFalse);
    expect(result.errorCode, 'permissionDenied');
    await runtime.close();
  });

  testWidgets('compiled tests execute through the Flutter runtime',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(builder: (context, setState) {
          return Column(children: [
            ElevatedButton(
              key: const ValueKey('open'),
              onPressed: () => setState(() => taps++),
              child: const Text('Open'),
            ),
            if (taps > 0) const Text('Done', key: ValueKey('done')),
          ]);
        }),
      ),
    ));

    final testCase = EnsembleTestParser.parseString('''
id: runtime_slice
startScreen: Home
steps:
  - ifVisible:
      target: {id: open}
      step:
        tap:
          target: {text: Open}
  - tap: {id: open}
  - optional:
      step:
        tap: {id: missing}
  - waitFor: {id: done, timeoutMs: 1000}
  - waitForText: {text: Done, timeoutMs: 1000}
  - expectVisible: {id: done}
''');
    final plan = CompiledPlanCompiler().compile(testCase);
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase: testCase,
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      permissions: SessionPermissions.restrictedUi,
    );
    final runtime = FlutterTestRuntime(session);
    final request = ObservationRequest(target: const {'id': 'open'});
    final firstView = await runtime.observe(request);
    final repeatedView = await runtime.observe(request);
    expect(firstView.targetVisible, isTrue);
    expect(repeatedView, same(firstView));
    final structuredView = await runtime.observe(
      ObservationRequest(target: const {
        'target': {'text': 'Open'}
      }),
    );
    expect(structuredView.targetVisible, isTrue);

    final directAction = await runtime.execute(TestOperation(
      id: 'cache-invalidation-action',
      name: 'tap',
      kind: OperationKind.interaction,
      handlerKey: 'interaction.tap',
      input: const {'id': 'open'},
      source: const SourceLocation('runtime_slice.yaml', 'setup'),
    ));
    expect(directAction.succeeded, isTrue);
    final refreshedView = await runtime.observe(request);
    expect(refreshedView, isNot(same(firstView)));
    expect(refreshedView.revision, greaterThan(firstView.revision));

    final result = await ExecutionKernel(
      plan: plan,
      policy: CompiledExecutionPolicy(plan),
      runtime: runtime,
    ).run();

    expect(result.outcome, AttemptOutcome.passed,
        reason: result.primaryFailure);
    expect(result.operations, 6);
    expect(taps, 3);
    expect(find.byKey(const ValueKey('done')), findsOneWidget);
  });

  testWidgets(
      'compiled visibility branches propagate target resolution errors after wire decode',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('Ready')));
    final testCase = EnsembleTestParser.parseString('''
id: invalid_visibility_target
steps:
  - ifVisible:
      target:
        locator:
          bounds: {left: invalid, top: 0, width: 10, height: 10}
      step:
        tap: {id: should_not_run}
''');
    final compiled = CompiledPlanCompiler().compile(testCase);
    final plans = [
      compiled,
      ExecutionPlan.fromWire(compiled.toWire()),
    ];

    for (final plan in plans) {
      final session = LocalTestExecutionSession.attach(
        tester: tester,
        context: EnsembleTestContext(
          testCase: testCase,
          apiOverlay: TestApiProviderOverlay(mocks: const {}),
          logger: TestLogger(),
          setup: const EnsembleTestSetup(),
        ),
      );
      final runtime = FlutterTestRuntime(session);
      final events = <ExecutionEvent>[];

      final result = await ExecutionKernelRunner(
        plan: plan,
        runtime: runtime,
        eventSubscribers: [events.add],
      ).run();

      expect(result.outcome, AttemptOutcome.failed);
      expect(result.failureCode, 'internalError');
      expect(events.map((event) => event.kind),
          contains(ExecutionEventKind.observationFailed));
      expect(
        events.where(
            (event) => event.kind == ExecutionEventKind.operationStarted),
        isEmpty,
      );
    }
  });
}
