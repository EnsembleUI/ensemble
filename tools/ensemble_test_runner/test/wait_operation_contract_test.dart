import 'package:ensemble_test_runner/actions/test_execution_config.dart';
import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'support/test_step_executor_handler_harness.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:ensemble_test_runner/session/operation_result.dart'
    show WaitStatus;
import 'package:ensemble_test_runner/session/errors/test_execution_error.dart';
import 'package:ensemble_test_runner/src/core/operation.dart'
    show OperationKind, TestOperation;
import 'package:ensemble_test_runner/src/core/operation_input.dart'
    show OperationInput;
import 'support/session_operation.dart';
import 'package:ensemble/framework/screen_tracker.dart';
import 'package:ensemble_test_runner/src/runtime/operation_registry.dart'
    show operationRegistry;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('wait and pump keep their own defaults on both routes',
      (tester) async {
    const config = TestExecutionConfig(
      waitPollInterval: Duration(milliseconds: 37),
    );
    await tester.pumpWidget(const SizedBox());
    final session = _session(tester, executionConfig: config);

    for (final (name, expected) in [
      ('wait', const Duration(milliseconds: 500)),
      ('pump', const Duration(milliseconds: 37)),
    ]) {
      final rawStart = tester.binding.clock.now();
      await session.executor.execute(TestStep(type: name, args: const {}));
      final rawElapsed = tester.binding.clock.now().difference(rawStart);

      final registeredStart = tester.binding.clock.now();
      final result = await session.waitFor(sessionOperation(name));
      expect(result.status, WaitStatus.satisfied, reason: name);
      final registeredElapsed =
          tester.binding.clock.now().difference(registeredStart);

      expect(rawElapsed, expected, reason: 'raw $name default');
      expect(
        registeredElapsed,
        expected,
        reason: 'registered $name default',
      );
    }

    await session.close();
  });

  testWidgets('settle uses the configured default timeout on both routes',
      (tester) async {
    const timeout = Duration(milliseconds: 35);
    final session = _session(
      tester,
      executionConfig: const TestExecutionConfig(
        settleStepDuration: Duration(milliseconds: 1),
        settleTimeout: timeout,
      ),
    );
    await tester.pumpWidget(const MaterialApp(home: _LongAnimation()));

    final rawStart = tester.binding.clock.now();
    await session.executor.execute(const TestStep(type: 'settle', args: {}));
    final rawElapsed = tester.binding.clock.now().difference(rawStart);

    final registeredStart = tester.binding.clock.now();
    final result = await session.waitFor(sessionOperation('settle'));
    final registeredElapsed =
        tester.binding.clock.now().difference(registeredStart);

    expect(result.status, WaitStatus.satisfied);
    expect(rawElapsed, greaterThanOrEqualTo(timeout));
    expect(registeredElapsed, greaterThanOrEqualTo(timeout));
    expect(rawElapsed, lessThan(const Duration(milliseconds: 300)));
    expect(registeredElapsed, lessThan(const Duration(milliseconds: 300)));
    await session.close();
  });

  testWidgets(
      'condition waits use the configured default timeout on both routes',
      (tester) async {
    const timeout = Duration.zero;
    const config = TestExecutionConfig(
      defaultWaitTimeout: timeout,
    );
    await tester.pumpWidget(const MaterialApp(
      home: Text('Still present', key: ValueKey('still-present')),
    ));
    final session = _session(tester, executionConfig: config);
    addTearDown(session.close);
    ScreenTracker().clearAll();
    addTearDown(ScreenTracker().clearAll);

    final cases = <({
      String name,
      Map<String, dynamic> raw,
      Map<String, Object?> registered
    })>[
      (
        name: 'waitForText',
        raw: const {'text': 'Never appears'},
        registered: const {'text': 'Never appears'},
      ),
      (
        name: 'waitFor',
        raw: const {'id': 'missing'},
        registered: const {
          'target': {'id': 'missing'}
        },
      ),
      (
        name: 'waitForGone',
        raw: const {'id': 'still-present'},
        registered: const {
          'target': {'id': 'still-present'}
        },
      ),
      (
        name: 'waitForApi',
        raw: const {'name': 'never-called'},
        registered: const {'name': 'never-called'},
      ),
      (
        name: 'waitForNavigation',
        raw: const {'screen': 'NeverVisited'},
        registered: const {'screen': 'NeverVisited'},
      ),
    ];

    for (final entry in cases) {
      EnsembleTestFailure? rawFailure;
      try {
        await session.executor
            .execute(TestStep(type: entry.name, args: entry.raw));
      } on EnsembleTestFailure catch (error) {
        rawFailure = error;
      }
      expect(rawFailure, isNotNull, reason: 'raw ${entry.name}');
      expect(rawFailure!.message, contains('${timeout.inMilliseconds}ms'),
          reason: 'raw ${entry.name} timeout');

      final result = await session.waitFor(
        sessionOperation(entry.name, input: entry.registered),
      );
      expect(result.status, WaitStatus.timedOut, reason: entry.name);
      expect(result.error?.code, TestExecutionErrorCode.actionTimeout,
          reason: entry.name);
      expect(
        result.error?.message,
        contains('${timeout.inMilliseconds}ms'),
        reason: 'registered ${entry.name} timeout diagnostic',
      );

      final overridden = await session.waitFor(
        sessionOperation(entry.name, input: {
          ...entry.registered,
          'timeoutMs': 10000,
        }),
        timeout: Duration.zero,
      );
      expect(overridden.status, WaitStatus.timedOut,
          reason: '${entry.name} timeout override');
      expect(overridden.error?.code, TestExecutionErrorCode.actionTimeout,
          reason: '${entry.name} timeout override');
      expect(
        overridden.error?.message,
        contains('0ms'),
        reason: 'registered ${entry.name} override diagnostic',
      );
    }
  });

  testWidgets('condition waits honor explicit timeoutMs on both routes',
      (tester) async {
    final session = _session(
      tester,
      executionConfig: const TestExecutionConfig(
        defaultWaitTimeout: Duration(milliseconds: 250),
      ),
    );
    await tester.pumpWidget(const MaterialApp(
      home: Text('Present', key: ValueKey('present')),
    ));
    ScreenTracker().clearAll();
    addTearDown(ScreenTracker().clearAll);

    final cases = <({
      String name,
      Map<String, dynamic> args,
      Map<String, Object?> input,
    })>[
      (
        name: 'waitForText',
        args: const {'text': 'Never appears', 'timeoutMs': 0},
        input: const {'text': 'Never appears', 'timeoutMs': 0},
      ),
      (
        name: 'waitFor',
        args: const {'id': 'missing', 'timeoutMs': 0},
        input: const {
          'target': {'id': 'missing'},
          'timeoutMs': 0,
        },
      ),
      (
        name: 'waitForGone',
        args: const {'id': 'present', 'timeoutMs': 0},
        input: const {
          'target': {'id': 'present'},
          'timeoutMs': 0,
        },
      ),
      (
        name: 'waitForApi',
        args: const {'name': 'never-called', 'timeoutMs': 0},
        input: const {'name': 'never-called', 'timeoutMs': 0},
      ),
      (
        name: 'waitForNavigation',
        args: const {'screen': 'NeverVisited', 'timeoutMs': 0},
        input: const {'screen': 'NeverVisited', 'timeoutMs': 0},
      ),
    ];

    for (final entry in cases) {
      EnsembleTestFailure? rawFailure;
      final rawStart = tester.binding.clock.now();
      try {
        await session.executor.execute(
          TestStep(type: entry.name, args: entry.args),
        );
      } on EnsembleTestFailure catch (error) {
        rawFailure = error;
      }
      final rawElapsed = tester.binding.clock.now().difference(rawStart);
      expect(rawFailure, isNotNull, reason: 'raw ${entry.name}');
      expect(rawFailure!.message, contains('0ms'), reason: 'raw ${entry.name}');
      expect(rawElapsed, lessThan(const Duration(milliseconds: 150)),
          reason: 'raw ${entry.name} must use its explicit timeout');

      final registeredStart = tester.binding.clock.now();
      final registered = await session.waitFor(
        sessionOperation(entry.name, input: entry.input),
      );
      final registeredElapsed =
          tester.binding.clock.now().difference(registeredStart);
      expect(registered.status, WaitStatus.timedOut, reason: entry.name);
      expect(registered.error?.code, TestExecutionErrorCode.actionTimeout,
          reason: entry.name);
      expect(
        registered.error?.message,
        contains('0ms'),
        reason: 'registered ${entry.name} timeout diagnostic',
      );
      expect(registeredElapsed, lessThan(const Duration(milliseconds: 150)),
          reason: 'registered ${entry.name} must use its explicit timeout');
    }
    await session.close();
  });

  test('wait kind is declared by each registered wait operation', () {
    final waits = operationRegistry.descriptors
        .where((descriptor) => descriptor.kind == OperationKind.wait);

    expect(waits, isNotEmpty);
    expect(waits.every((descriptor) => descriptor.waitKind != null), isTrue);
    expect(operationRegistry.lookup('wait')?.waitKind, 'pump');
    expect(operationRegistry.lookup('settle')?.waitKind, 'settle');
    expect(
        operationRegistry.lookup('waitForNavigation')?.waitKind, 'navigation');
    expect(operationRegistry.lookup('waitForApi')?.waitKind, 'api');
  });

  testWidgets('registered pump keeps the configured default duration',
      (tester) async {
    const pollInterval = Duration(milliseconds: 37);
    await tester.pumpWidget(const SizedBox());
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'pump-default-compatibility', steps: []),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      executionConfig: const TestExecutionConfig(
        waitPollInterval: pollInterval,
      ),
    );
    final before = tester.binding.clock.now();

    await executor.executeWaitOperation(sessionOperation('pump'));

    expect(
      tester.binding.clock.now().difference(before),
      greaterThanOrEqualTo(pollInterval),
    );
  });

  testWidgets('session wait aliases resolve through the registered handler',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('Ready')));
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'wait-alias-handler', steps: []),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
    );

    await executor.executeWaitOperation(
      sessionOperation('waitForText',
          input: const {'text': 'Ready', 'timeoutMs': 100}),
    );
  });

  testWidgets('session timeout argument overrides operation timeoutMs',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'wait-timeout-override', steps: []),
    );
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: context,
      executionConfig: const TestExecutionConfig(
        waitPollInterval: Duration(milliseconds: 1),
      ),
    );

    final result = await session.waitFor(
      sessionOperation('waitForText',
          input: const {'text': 'Never appears', 'timeoutMs': 500}),
      timeout: Duration.zero,
    );

    expect(result.status, WaitStatus.timedOut);
    expect(result.error?.code.name, 'actionTimeout');
    expect(result.error?.message, contains('0ms'));
    await session.close();
  });

  testWidgets('structured session waits honor configured frame cadence',
      (tester) async {
    const config = TestExecutionConfig(
      waitPollInterval: Duration(milliseconds: 1),
      settleStepDuration: Duration(milliseconds: 1),
      defaultWaitTimeout: Duration(milliseconds: 200),
    );
    await tester.pumpWidget(const MaterialApp(home: _TimedTarget()));
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'structured-wait-cadence', steps: []),
    );
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: context,
      executionConfig: config,
    );
    final start = tester.binding.clock.now();

    final result = await session.waitFor(
      sessionOperation('waitFor', input: const {
        'target': {'id': 'appears'},
        'timeoutMs': 70,
      }),
    );

    expect(result.satisfied, isTrue);
    expect(
        tester.binding.clock.now().difference(start),
        lessThan(
          const Duration(milliseconds: 65),
        ));
    await session.close();
  });

  testWidgets('target-only waitFor matches across raw and registered routes',
      (tester) async {
    final session = _session(
      tester,
      executionConfig: const TestExecutionConfig(
        defaultWaitTimeout: Duration(milliseconds: 250),
        waitPollInterval: Duration(milliseconds: 1),
        settleStepDuration: Duration(milliseconds: 1),
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: _TimedTarget()));
    await session.executor.executeWaitOperation(
      sessionOperation('waitFor', input: const {
        'target': {'id': 'appears'},
      }),
    );

    await tester.pumpWidget(const MaterialApp(
      home: _TimedTarget(key: ValueKey('registered')),
    ));
    final registered = await session.waitFor(
      sessionOperation('waitFor', input: const {
        'target': {'id': 'appears'},
      }),
    );

    expect(registered.status, WaitStatus.satisfied);
    await session.close();
  });

  testWidgets('structured target waits publish equivalent match evidence',
      (tester) async {
    final session = _session(
      tester,
      executionConfig: const TestExecutionConfig(
        defaultWaitTimeout: Duration(milliseconds: 250),
        waitPollInterval: Duration(milliseconds: 1),
        settleStepDuration: Duration(milliseconds: 1),
      ),
    );
    final boundaries = <String>[];
    session.executor.onEvidenceBoundary = (step) => boundaries.add(step.type);
    session.executor.onOperationEvidenceBoundary =
        (_, detail) => boundaries.add(detail);

    await tester.pumpWidget(const MaterialApp(home: _TimedTarget()));
    await session.executor.execute(const TestStep(
      type: 'waitFor',
      args: {
        'target': {'id': 'appears'},
        'timeoutMs': 100,
      },
    ));
    expect(boundaries, ['condition:waitFor']);

    await tester.pumpWidget(const MaterialApp(
      home: _TimedTarget(key: ValueKey('registered')),
    ));
    final appeared = await session.waitFor(
      sessionOperation('waitFor', input: const {
        'target': {'id': 'appears'},
        'timeoutMs': 100,
      }),
    );
    expect(appeared.status, WaitStatus.satisfied);
    expect(boundaries, ['condition:waitFor', 'condition:waitFor']);

    await session.executor.execute(const TestStep(
      type: 'waitForGone',
      args: {
        'target': {'id': 'not-present'},
        'timeoutMs': 100,
      },
    ));
    final gone = await session.waitFor(
      sessionOperation('waitForGone', input: const {
        'target': {'id': 'not-present'},
        'timeoutMs': 100,
      }),
    );
    expect(gone.status, WaitStatus.satisfied);
    expect(
      boundaries,
      [
        'condition:waitFor',
        'condition:waitFor',
        'condition:waitForGone',
        'condition:waitForGone',
      ],
    );
    await session.close();
  });

  testWidgets('registered waits retain their canonical operation evidence',
      (tester) async {
    final session = _session(
      tester,
      executionConfig: const TestExecutionConfig(
        defaultWaitTimeout: Duration(milliseconds: 250),
        waitPollInterval: Duration(milliseconds: 1),
        settleStepDuration: Duration(milliseconds: 1),
      ),
    );
    final operationEvidence = <(String, Map)>[];
    session.executor.onOperationEvidenceBoundary = (operation, detail) {
      operationEvidence
          .add((operation.runtimeType.toString(), operation.arguments));
      expect(detail, 'condition:waitFor');
    };

    await tester.pumpWidget(const MaterialApp(home: _TimedTarget()));
    final result = await session.waitFor(
      sessionOperation('waitFor', input: const {
        'target': {'id': 'appears'},
        'timeoutMs': 100,
      }),
    );

    expect(result.status, WaitStatus.satisfied);
    expect(operationEvidence, hasLength(1));
    expect(operationEvidence.single.$1, 'TestOperation');
    expect(
      (operationEvidence.single.$2['target'] as Map)['id'],
      'appears',
    );
    await session.close();
  });

  testWidgets('session text waits dispatch through the registered handler',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('Ready')));
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'session-text-wait-route', steps: []),
    );
    final executor = _WaitRouteTrackingExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
    );
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: context,
      executor: executor,
      executionConfig: const TestExecutionConfig(
        defaultWaitTimeout: Duration(milliseconds: 100),
      ),
    );
    final evidence = <OperationInput>[];
    executor.onOperationEvidenceBoundary = (operation, _) {
      evidence.add(operation);
    };

    final result = await session.waitFor(
      sessionOperation('waitFor', input: const {
        'anyOf': ['Loading', 'Ready'],
        'timeoutMs': 100,
      }),
    );

    expect(result.status, WaitStatus.satisfied);
    expect(executor.registeredWaitDispatches, 1);
    expect(evidence, hasLength(1));
    expect(evidence.single.arguments['text'], 'Ready');
    expect(evidence.single.arguments, isNot(contains('anyOf')));
    await session.close();
  });

  testWidgets('target-only waitFor applies the same configured timeout',
      (tester) async {
    final session = _session(
      tester,
      executionConfig: const TestExecutionConfig(
        defaultWaitTimeout: Duration.zero,
      ),
    );
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    EnsembleTestFailure? rawFailure;
    try {
      await session.executor.execute(const TestStep(
        type: 'waitFor',
        args: {
          'target': {'id': 'missing'},
        },
      ));
    } on EnsembleTestFailure catch (error) {
      rawFailure = error;
    }
    final registered = await session.waitFor(
      sessionOperation('waitFor', input: const {
        'target': {'id': 'missing'},
      }),
    );

    expect(rawFailure?.message, contains('0ms'));
    expect(registered.status, WaitStatus.timedOut);
    expect(registered.error?.code, TestExecutionErrorCode.actionTimeout);
    await session.close();
  });

  testWidgets('shared waits publish matched conditions through one boundary',
      (tester) async {
    await tester.pumpWidget(const SizedBox());
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'shared-wait-handlers', steps: []),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      executionConfig: const TestExecutionConfig(
        settleTimeout: Duration.zero,
        actionSettleTimeout: Duration.zero,
      ),
    );
    final boundaries = <String>[];
    executor.onEvidenceBoundary = (step) => boundaries.add(step.type);
    executor.onOperationEvidenceBoundary =
        (_, detail) => boundaries.add(detail);

    await executor.execute(const TestStep(type: 'settle', args: {}));
    await executor.executeWaitOperation(
      sessionOperation('settle', input: const {}),
    );

    expect(boundaries, ['condition:settle', 'condition:settle']);
  });
}

LocalTestExecutionSession _session(
  WidgetTester tester, {
  TestExecutionConfig executionConfig = const TestExecutionConfig(),
}) =>
    LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext.fromTestCase(
        const EnsembleTestCase(id: 'wait-operation-contract', steps: []),
      ),
      executionConfig: executionConfig,
    );

class _WaitRouteTrackingExecutor extends TestStepExecutor {
  _WaitRouteTrackingExecutor({
    required super.tester,
    required super.context,
    required super.assertions,
  });

  int registeredWaitDispatches = 0;

  @override
  Future<void> executeWaitOperation(TestOperation operation) {
    registeredWaitDispatches++;
    return super.executeWaitOperation(operation);
  }
}

class _TimedTarget extends StatefulWidget {
  const _TimedTarget({super.key});

  @override
  State<_TimedTarget> createState() => _TimedTargetState();
}

class _LongAnimation extends StatefulWidget {
  const _LongAnimation();

  @override
  State<_LongAnimation> createState() => _LongAnimationState();
}

class _LongAnimationState extends State<_LongAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(hours: 1),
  )..repeat();

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) =>
            LinearProgressIndicator(value: _controller.value),
      );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _TimedTargetState extends State<_TimedTarget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 40),
  )..forward();

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Visibility(
          visible: _controller.value >= 0.5,
          child: const Text('Ready', key: ValueKey('appears')),
        ),
      );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
