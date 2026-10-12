import 'support/test_step_executor_handler_harness.dart';
import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:ensemble_test_runner/mocks/test_logger.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/actions/test_execution_config.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/test_bootstrap.dart';
import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:ensemble_test_runner/session/action_operation_handler.dart';
import 'package:ensemble_test_runner/session/errors/test_execution_error.dart';
import 'support/session_operation.dart';
import 'package:ensemble_test_runner/src/core/operation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'toggle and enterText preserve the default target wait on both routes',
      (tester) async {
    const config = TestExecutionConfig(
      defaultWaitTimeout: Duration(milliseconds: 300),
    );
    await tester.pumpWidget(const MaterialApp(
      home: _DelayedOperationTargets(key: ValueKey('raw-toggle')),
    ));
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(id: 'default-action-waits', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      executionConfig: config,
    );

    await session.executor.execute(const TestStep(
      type: 'toggle',
      args: {'id': 'delayed-toggle'},
    ));
    expect(
        tester
            .widget<Checkbox>(find.byKey(const ValueKey('delayed-toggle')))
            .value,
        isTrue);

    await tester.pumpWidget(const MaterialApp(
      home: _DelayedOperationTargets(key: ValueKey('registered-toggle')),
    ));
    final toggle = await session.act(
      sessionOperation('toggle', input: const {'id': 'delayed-toggle'}),
    );
    expect(toggle.succeeded, isTrue, reason: toggle.error?.message);
    expect(
        tester
            .widget<Checkbox>(find.byKey(const ValueKey('delayed-toggle')))
            .value,
        isTrue);

    await tester.pumpWidget(const MaterialApp(
      home: _DelayedOperationTargets(key: ValueKey('raw-text')),
    ));
    await session.executor.execute(const TestStep(
      type: 'enterText',
      args: {'id': 'delayed-entry', 'value': 'raw route'},
    ));
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('delayed-entry')))
          .controller
          ?.text,
      'raw route',
    );

    await tester.pumpWidget(const MaterialApp(
      home: _DelayedOperationTargets(key: ValueKey('registered-text')),
    ));
    final enterText = await session.act(sessionOperation(
      'enterText',
      input: const {'id': 'delayed-entry', 'value': 'registered route'},
    ));
    expect(enterText.succeeded, isTrue, reason: enterText.error?.message);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('delayed-entry')))
          .controller
          ?.text,
      'registered route',
    );
    await session.close();
  });

  testWidgets(
      'simple ID tap default timeout matches across raw and registered routes',
      (tester) async {
    var tapCount = 0;
    await tester.pumpWidget(MaterialApp(
      home: _DelayedTapTarget(onTap: () => tapCount++),
    ));
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(id: 'tap-default-timeout', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      executionConfig: const TestExecutionConfig(
        defaultWaitTimeout: Duration(milliseconds: 300),
      ),
    );

    await session.executor.execute(const TestStep(
      type: 'tap',
      args: {'id': 'delayed-target'},
    ));
    expect(tapCount, 1, reason: 'raw route uses configured default timeout');

    await tester.pumpWidget(MaterialApp(
      home: _DelayedTapTarget(onTap: () => tapCount++),
    ));
    final registered = await session.act(sessionOperation(
      'tap',
      input: const {'id': 'delayed-target'},
    ));

    expect(registered.succeeded, isTrue, reason: registered.error?.message);
    expect(tapCount, 2,
        reason: 'registered route uses configured default timeout');
    await session.close();
  });

  testWidgets(
      'toggle and enterText honor explicit target timeouts on both routes',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase:
            const EnsembleTestCase(id: 'action-timeout-override', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      executionConfig: const TestExecutionConfig(
        defaultWaitTimeout: Duration(milliseconds: 350),
      ),
    );
    addTearDown(session.close);

    for (final name in ['toggle', 'enterText']) {
      const args = {'id': 'never-mounted', 'timeoutMs': 13, 'value': 'x'};
      EnsembleTestFailure? rawFailure;
      final rawWall = Stopwatch()..start();
      try {
        await session.executor.execute(TestStep(type: name, args: args));
      } on EnsembleTestFailure catch (error) {
        rawFailure = error;
      }
      rawWall.stop();

      final registeredWall = Stopwatch()..start();
      final registered = await session.act(
        sessionOperation(name, input: args),
      );
      registeredWall.stop();

      expect(rawFailure, isNotNull, reason: 'raw $name');
      expect(rawFailure!.message, contains('13ms'), reason: 'raw $name');
      expect(registered.succeeded, isFalse, reason: 'registered $name');
      expect(registered.error?.message, contains('13ms'),
          reason: 'registered $name');
      expect(rawWall.elapsed, lessThan(const Duration(milliseconds: 250)));
      expect(
          registeredWall.elapsed, lessThan(const Duration(milliseconds: 250)));
    }
  });

  testWidgets('select honors its explicit target timeout on both routes',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase:
            const EnsembleTestCase(id: 'select-timeout-override', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      executionConfig: const TestExecutionConfig(
        defaultWaitTimeout: Duration(milliseconds: 350),
      ),
    );
    addTearDown(session.close);
    const args = {'id': 'never-mounted', 'value': 'Option', 'timeoutMs': 13};

    EnsembleTestFailure? rawFailure;
    final rawWall = Stopwatch()..start();
    try {
      await session.executor.execute(TestStep(type: 'select', args: args));
    } on EnsembleTestFailure catch (error) {
      rawFailure = error;
    }
    rawWall.stop();

    final registeredWall = Stopwatch()..start();
    final registered = await session.act(
      sessionOperation('select', input: args),
    );
    registeredWall.stop();

    expect(rawFailure, isNotNull);
    expect(rawFailure!.message, contains('13ms'));
    expect(registered.succeeded, isFalse);
    expect(registered.error?.message, contains('13ms'));
    expect(rawWall.elapsed, lessThan(const Duration(milliseconds: 250)));
    expect(registeredWall.elapsed, lessThan(const Duration(milliseconds: 250)));
  });

  testWidgets('structured select waits using explicit timeout on both routes',
      (tester) async {
    var selectedCount = 0;
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(
          id: 'structured-select-timeout-override',
          steps: [],
        ),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      executionConfig: const TestExecutionConfig(
        defaultWaitTimeout: Duration(milliseconds: 13),
      ),
    );
    addTearDown(session.close);
    const args = {
      'target': {'id': 'delayed-select-target'},
      'value': 'Option',
      'timeoutMs': 500,
    };

    await tester.pumpWidget(MaterialApp(
      home: _DelayedSelectTarget(onSelected: () => selectedCount++),
    ));
    final rawWall = Stopwatch()..start();
    await session.executor.execute(TestStep(type: 'select', args: args));
    rawWall.stop();
    expect(selectedCount, 1, reason: 'raw structured target wait');

    await tester.pumpWidget(MaterialApp(
      home: _DelayedSelectTarget(onSelected: () => selectedCount++),
    ));
    final registeredWall = Stopwatch()..start();
    final registered = await session.act(
      sessionOperation('select', input: args),
    );
    registeredWall.stop();

    expect(registered.succeeded, isTrue, reason: registered.error?.message);
    expect(selectedCount, 2, reason: 'registered structured target wait');
    expect(rawWall.elapsed, lessThan(const Duration(milliseconds: 250)));
    expect(registeredWall.elapsed, lessThan(const Duration(milliseconds: 250)));
  });

  testWidgets('structured toggle waits using explicit timeout on both routes',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: _DelayedStructuredToggleTarget(key: ValueKey('raw-toggle')),
    ));
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(
          id: 'structured-toggle-timeout',
          steps: [],
        ),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      executionConfig: const TestExecutionConfig(
        defaultWaitTimeout: Duration(milliseconds: 13),
      ),
    );
    addTearDown(session.close);
    const args = {
      'target': {'id': 'delayed-structured-toggle'},
      'timeoutMs': 500,
    };

    final rawWall = Stopwatch()..start();
    await session.executor.execute(TestStep(type: 'toggle', args: args));
    rawWall.stop();
    expect(
      tester
          .widget<Checkbox>(
            find.byKey(const ValueKey('delayed-structured-toggle')),
          )
          .value,
      isTrue,
      reason: 'raw structured target wait',
    );

    await tester.pumpWidget(const MaterialApp(
      home: _DelayedStructuredToggleTarget(key: ValueKey('registered-toggle')),
    ));
    final registeredWall = Stopwatch()..start();
    final registered = await session.act(
      sessionOperation('toggle', input: args),
    );
    registeredWall.stop();

    expect(registered.succeeded, isTrue, reason: registered.error?.message);
    expect(
      tester
          .widget<Checkbox>(
            find.byKey(const ValueKey('delayed-structured-toggle')),
          )
          .value,
      isTrue,
      reason: 'registered structured target wait',
    );
    expect(rawWall.elapsed, lessThan(const Duration(milliseconds: 250)));
    expect(registeredWall.elapsed, lessThan(const Duration(milliseconds: 250)));
  });

  testWidgets(
      'structured toggle uses configured default timeout on both routes',
      (tester) async {
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(
          id: 'structured-toggle-default-timeout',
          steps: [],
        ),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      executionConfig: const TestExecutionConfig(
        defaultWaitTimeout: Duration(milliseconds: 500),
      ),
    );
    addTearDown(session.close);
    const args = {
      'target': {'id': 'delayed-structured-toggle'},
    };

    await tester.pumpWidget(const MaterialApp(
      home: _DelayedStructuredToggleTarget(key: ValueKey('raw-toggle-default')),
    ));
    await session.executor.execute(const TestStep(type: 'toggle', args: args));
    expect(
      tester
          .widget<Checkbox>(
            find.byKey(const ValueKey('delayed-structured-toggle')),
          )
          .value,
      isTrue,
      reason: 'raw structured target uses configured default wait',
    );

    await tester.pumpWidget(const MaterialApp(
      home: _DelayedStructuredToggleTarget(
        key: ValueKey('registered-toggle-default'),
      ),
    ));
    final registered = await session.act(
      sessionOperation('toggle', input: args),
    );

    expect(registered.succeeded, isTrue, reason: registered.error?.message);
    expect(
      tester
          .widget<Checkbox>(
            find.byKey(const ValueKey('delayed-structured-toggle')),
          )
          .value,
      isTrue,
      reason: 'registered structured target uses configured default wait',
    );
  });

  testWidgets('check waits for delayed structured targets on both routes',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: _DelayedStructuredToggleTarget(key: ValueKey('raw-check')),
    ));
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(id: 'check-target-timeout', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      executionConfig: const TestExecutionConfig(
        defaultWaitTimeout: Duration(milliseconds: 13),
      ),
    );
    addTearDown(session.close);
    const args = {
      'target': {'id': 'delayed-structured-toggle'},
      'timeoutMs': 500,
    };

    await session.executor.execute(TestStep(type: 'check', args: args));
    expect(
      tester
          .widget<Checkbox>(
            find.byKey(const ValueKey('delayed-structured-toggle')),
          )
          .value,
      isTrue,
      reason: 'raw check waits for the structured target',
    );

    await tester.pumpWidget(const MaterialApp(
      home: _DelayedStructuredToggleTarget(key: ValueKey('registered-check')),
    ));
    final registered = await session.act(
      sessionOperation('check', input: args),
    );
    expect(registered.succeeded, isTrue, reason: registered.error?.message);
    expect(
      tester
          .widget<Checkbox>(
            find.byKey(const ValueKey('delayed-structured-toggle')),
          )
          .value,
      isTrue,
      reason: 'registered check waits for the structured target',
    );
  });

  testWidgets('uncheck waits for delayed structured targets on both routes',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: _DelayedStructuredToggleTarget(
        key: ValueKey('raw-uncheck'),
        initialValue: true,
      ),
    ));
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase:
            const EnsembleTestCase(id: 'uncheck-target-timeout', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      executionConfig: const TestExecutionConfig(
        defaultWaitTimeout: Duration(milliseconds: 13),
      ),
    );
    addTearDown(session.close);
    const args = {
      'target': {'id': 'delayed-structured-toggle'},
      'timeoutMs': 500,
    };

    await session.executor.execute(TestStep(type: 'uncheck', args: args));
    expect(
      tester
          .widget<Checkbox>(
            find.byKey(const ValueKey('delayed-structured-toggle')),
          )
          .value,
      isFalse,
      reason: 'raw uncheck waits for the structured target',
    );

    await tester.pumpWidget(const MaterialApp(
      home: _DelayedStructuredToggleTarget(
        key: ValueKey('registered-uncheck'),
        initialValue: true,
      ),
    ));
    final registered = await session.act(
      sessionOperation('uncheck', input: args),
    );
    expect(registered.succeeded, isTrue, reason: registered.error?.message);
    expect(
      tester
          .widget<Checkbox>(
            find.byKey(const ValueKey('delayed-structured-toggle')),
          )
          .value,
      isFalse,
      reason: 'registered uncheck waits for the structured target',
    );
  });

  testWidgets('focus waits for delayed structured targets on both routes',
      (tester) async {
    final rawFocus = FocusNode(debugLabel: 'raw delayed focus');
    final registeredFocus = FocusNode(debugLabel: 'registered delayed focus');
    addTearDown(rawFocus.dispose);
    addTearDown(registeredFocus.dispose);
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(id: 'focus-timeout-parity', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      executionConfig: const TestExecutionConfig(
        defaultWaitTimeout: Duration(milliseconds: 13),
      ),
    );
    addTearDown(session.close);
    const args = {
      'target': {'id': 'delayed-focus-target'},
      'timeoutMs': 500,
    };

    await tester.pumpWidget(MaterialApp(
      home: _DelayedFocusTarget(
        key: const ValueKey('raw-focus'),
        focusNode: rawFocus,
      ),
    ));
    await session.executor.execute(const TestStep(type: 'focus', args: args));
    expect(rawFocus.hasFocus, isTrue, reason: 'raw target wait');

    await tester.pumpWidget(MaterialApp(
      home: _DelayedFocusTarget(
        key: const ValueKey('registered-focus'),
        focusNode: registeredFocus,
      ),
    ));
    final registered = await session.act(
      sessionOperation('focus', input: args),
    );
    expect(registered.succeeded, isTrue, reason: registered.error?.message);
    expect(registeredFocus.hasFocus, isTrue, reason: 'registered target wait');
  });

  testWidgets('focus uses configured default wait on both routes',
      (tester) async {
    final rawFocus = FocusNode(debugLabel: 'raw default focus');
    final registeredFocus = FocusNode(debugLabel: 'registered default focus');
    addTearDown(rawFocus.dispose);
    addTearDown(registeredFocus.dispose);
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase:
            const EnsembleTestCase(id: 'focus-default-timeout', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      executionConfig: const TestExecutionConfig(
        defaultWaitTimeout: Duration(milliseconds: 500),
      ),
    );
    addTearDown(session.close);
    const args = {
      'target': {'id': 'delayed-focus-target'},
    };

    await tester.pumpWidget(MaterialApp(
      home: _DelayedFocusTarget(
        key: const ValueKey('raw-default-focus'),
        focusNode: rawFocus,
      ),
    ));
    await session.executor.execute(const TestStep(type: 'focus', args: args));
    expect(rawFocus.hasFocus, isTrue, reason: 'raw default target wait');

    await tester.pumpWidget(MaterialApp(
      home: _DelayedFocusTarget(
        key: const ValueKey('registered-default-focus'),
        focusNode: registeredFocus,
      ),
    ));
    final registered = await session.act(
      sessionOperation('focus', input: args),
    );
    expect(registered.succeeded, isTrue, reason: registered.error?.message);
    expect(registeredFocus.hasFocus, isTrue,
        reason: 'registered default target wait');
  });

  testWidgets('submitText waits for delayed simple-ID targets on both routes',
      (tester) async {
    final submitted = <String>[];
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(id: 'submit-text-timeout', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      executionConfig: const TestExecutionConfig(
        defaultWaitTimeout: Duration(milliseconds: 13),
      ),
    );
    addTearDown(session.close);
    const args = {'id': 'delayed-entry', 'timeoutMs': 500};

    await tester.pumpWidget(MaterialApp(
      home: _DelayedOperationTargets(
        key: const ValueKey('raw-submit'),
        onSubmitted: submitted.add,
      ),
    ));
    await session.executor.execute(
      const TestStep(type: 'submitText', args: args),
    );
    expect(submitted, ['']);

    await tester.pumpWidget(MaterialApp(
      home: _DelayedOperationTargets(
        key: const ValueKey('registered-submit'),
        onSubmitted: submitted.add,
      ),
    ));
    final registered = await session.act(
      sessionOperation('submitText', input: args),
    );
    expect(registered.succeeded, isTrue, reason: registered.error?.message);
    expect(submitted, ['', '']);
  });

  testWidgets(
      'structured submitText uses configured default timeout on both routes',
      (tester) async {
    final submitted = <String>[];
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(
          id: 'submit-text-structured-default',
          steps: [],
        ),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      executionConfig: const TestExecutionConfig(
        defaultWaitTimeout: Duration(milliseconds: 500),
      ),
    );
    addTearDown(session.close);
    const args = {
      'target': {'id': 'delayed-entry'},
    };

    await tester.pumpWidget(MaterialApp(
      home: _DelayedOperationTargets(
        key: const ValueKey('raw-structured-default-submit'),
        onSubmitted: submitted.add,
      ),
    ));
    await session.executor.execute(
      const TestStep(type: 'submitText', args: args),
    );

    await tester.pumpWidget(MaterialApp(
      home: _DelayedOperationTargets(
        key: const ValueKey('registered-structured-default-submit'),
        onSubmitted: submitted.add,
      ),
    ));
    final registered = await session.act(
      sessionOperation('submitText', input: args),
    );

    expect(registered.succeeded, isTrue, reason: registered.error?.message);
    expect(submitted, ['', '']);
  });

  testWidgets(
      'structured submitText explicit timeout overrides short default on both routes',
      (tester) async {
    final submitted = <String>[];
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(
          id: 'submit-text-structured-override',
          steps: [],
        ),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      executionConfig: const TestExecutionConfig(
        defaultWaitTimeout: Duration(milliseconds: 13),
      ),
    );
    addTearDown(session.close);
    const args = {
      'target': {'id': 'delayed-entry'},
      'timeoutMs': 500,
    };

    await tester.pumpWidget(MaterialApp(
      home: _DelayedOperationTargets(
        key: const ValueKey('raw-structured-override-submit'),
        onSubmitted: submitted.add,
      ),
    ));
    await session.executor.execute(
      const TestStep(type: 'submitText', args: args),
    );

    await tester.pumpWidget(MaterialApp(
      home: _DelayedOperationTargets(
        key: const ValueKey('registered-structured-override-submit'),
        onSubmitted: submitted.add,
      ),
    ));
    final registered = await session.act(
      sessionOperation('submitText', input: args),
    );

    expect(registered.succeeded, isTrue, reason: registered.error?.message);
    expect(submitted, ['', '']);
  });

  testWidgets(
      'structured replaceText waits using explicit timeout on both routes',
      (tester) async {
    final rawContext = EnsembleTestContext(
      testCase: const EnsembleTestCase(id: 'replace-text-timeout', steps: []),
      apiOverlay: TestApiProviderOverlay(mocks: const {}),
      logger: TestLogger(),
      setup: const EnsembleTestSetup(),
    );
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: rawContext,
      executionConfig: const TestExecutionConfig(
        defaultWaitTimeout: Duration(milliseconds: 13),
      ),
    );
    addTearDown(session.close);
    const args = {
      'target': {'id': 'delayed-entry'},
      'value': 'replaced',
      'timeoutMs': 500,
    };

    await tester.pumpWidget(const MaterialApp(
      home: _DelayedOperationTargets(key: ValueKey('raw-replace')),
    ));
    await session.executor.execute(
      const TestStep(type: 'replaceText', args: args),
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('delayed-entry')))
          .controller
          ?.text,
      'replaced',
      reason: 'raw structured target wait',
    );

    await tester.pumpWidget(const MaterialApp(
      home: _DelayedOperationTargets(key: ValueKey('registered-replace')),
    ));
    final registered = await session.act(
      sessionOperation('replaceText', input: args),
    );
    expect(registered.succeeded, isTrue, reason: registered.error?.message);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('delayed-entry')))
          .controller
          ?.text,
      'replaced',
      reason: 'registered structured target wait',
    );
  });

  testWidgets('doubleTap and longPress wait for delayed targets on both routes',
      (tester) async {
    var doubleTapCount = 0;
    var longPressCount = 0;
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase:
            const EnsembleTestCase(id: 'gesture-timeout-parity', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      executionConfig: const TestExecutionConfig(
        defaultWaitTimeout: Duration(milliseconds: 13),
      ),
    );
    addTearDown(session.close);
    const args = {
      'target': {'id': 'delayed-gesture-target'},
      'timeoutMs': 500,
    };

    await tester.pumpWidget(MaterialApp(
      home: _DelayedGestureTarget(
        key: const ValueKey('raw-double-tap'),
        onTap: () => doubleTapCount++,
        onLongPress: () => longPressCount++,
      ),
    ));
    await session.executor.execute(
      const TestStep(type: 'doubleTap', args: args),
    );
    expect(doubleTapCount, 2, reason: 'raw doubleTap target wait');

    await tester.pumpWidget(MaterialApp(
      home: _DelayedGestureTarget(
        key: const ValueKey('registered-long-press'),
        onTap: () => doubleTapCount++,
        onLongPress: () => longPressCount++,
      ),
    ));
    final registered = await session.act(
      sessionOperation('longPress', input: args),
    );
    expect(registered.succeeded, isTrue, reason: registered.error?.message);
    expect(longPressCount, 1, reason: 'registered longPress target wait');
  });

  testWidgets(
      'doubleTap and longPress use the configured default for delayed targets',
      (tester) async {
    var doubleTapCount = 0;
    var longPressCount = 0;
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase:
            const EnsembleTestCase(id: 'gesture-default-timeout', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      executionConfig: const TestExecutionConfig(
        defaultWaitTimeout: Duration(milliseconds: 300),
      ),
    );
    addTearDown(session.close);
    const args = {
      'target': {'id': 'delayed-gesture-target'},
    };

    await tester.pumpWidget(MaterialApp(
      home: _DelayedGestureTarget(
        key: const ValueKey('raw-double-tap-default'),
        onTap: () => doubleTapCount++,
        onLongPress: () => longPressCount++,
      ),
    ));
    await session.executor.execute(
      const TestStep(type: 'doubleTap', args: args),
    );
    expect(doubleTapCount, 2, reason: 'raw route uses configured default');

    await tester.pumpWidget(MaterialApp(
      home: _DelayedGestureTarget(
        key: const ValueKey('registered-long-press-default'),
        onTap: () => doubleTapCount++,
        onLongPress: () => longPressCount++,
      ),
    ));
    final registered = await session.act(
      sessionOperation('longPress', input: args),
    );
    expect(registered.succeeded, isTrue, reason: registered.error?.message);
    expect(longPressCount, 1,
        reason: 'registered route uses configured default');
  });

  testWidgets('clearText honors timeout for simple and structured targets',
      (tester) async {
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(id: 'clear-text-timeout', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      executionConfig: const TestExecutionConfig(
        defaultWaitTimeout: Duration(milliseconds: 13),
      ),
    );
    addTearDown(session.close);

    Future<void> mount(String key) => tester.pumpWidget(MaterialApp(
          home: _DelayedOperationTargets(
            key: ValueKey(key),
            initialText: 'seed',
          ),
        ));

    Future<void> verifyCleared(String reason) async {
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('delayed-entry')))
            .controller
            ?.text,
        isEmpty,
        reason: reason,
      );
    }

    const simpleArgs = {'id': 'delayed-entry', 'timeoutMs': 500};
    await mount('raw-simple-clear');
    await session.executor.execute(
      const TestStep(type: 'clearText', args: simpleArgs),
    );
    await verifyCleared('raw simple-ID clear');

    await mount('registered-simple-clear');
    final simpleRegistered = await session.act(
      sessionOperation('clearText', input: simpleArgs),
    );
    expect(simpleRegistered.succeeded, isTrue,
        reason: simpleRegistered.error?.message);
    await verifyCleared('registered simple-ID clear');

    const structuredArgs = {
      'target': {'id': 'delayed-entry'},
      'timeoutMs': 500,
    };
    await mount('raw-structured-clear');
    await session.executor.execute(
      const TestStep(type: 'clearText', args: structuredArgs),
    );
    await verifyCleared('raw structured clear');

    await mount('registered-structured-clear');
    final structuredRegistered = await session.act(
      sessionOperation('clearText', input: structuredArgs),
    );
    expect(structuredRegistered.succeeded, isTrue,
        reason: structuredRegistered.error?.message);
    await verifyCleared('registered structured clear');
  });

  testWidgets(
      'structured enterText waits using explicit timeout on both routes',
      (tester) async {
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(
          id: 'structured-enter-text-timeout',
          steps: [],
        ),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      executionConfig: const TestExecutionConfig(
        defaultWaitTimeout: Duration(milliseconds: 13),
      ),
    );
    addTearDown(session.close);
    const args = {
      'target': {'id': 'delayed-entry'},
      'value': 'entered',
      'timeoutMs': 500,
    };

    await tester.pumpWidget(const MaterialApp(
      home: _DelayedOperationTargets(key: ValueKey('raw-structured-text')),
    ));
    await session.executor.execute(TestStep(type: 'enterText', args: args));
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('delayed-entry')))
          .controller
          ?.text,
      'entered',
      reason: 'raw structured target waits using its explicit timeout',
    );

    await tester.pumpWidget(const MaterialApp(
      home: _DelayedOperationTargets(
        key: ValueKey('registered-structured-text'),
      ),
    ));
    final registered = await session.act(
      sessionOperation('enterText', input: args),
    );
    expect(registered.succeeded, isTrue, reason: registered.error?.message);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('delayed-entry')))
          .controller
          ?.text,
      'entered',
      reason: 'registered structured target shares the same wait',
    );
  });

  testWidgets('structured enterText uses configured default on both routes',
      (tester) async {
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(
          id: 'structured-enter-text-default',
          steps: [],
        ),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      executionConfig: const TestExecutionConfig(
        defaultWaitTimeout: Duration(milliseconds: 500),
      ),
    );
    addTearDown(session.close);
    const args = {
      'target': {'id': 'delayed-entry'},
      'value': 'typed',
    };

    await tester.pumpWidget(const MaterialApp(
      home: _DelayedOperationTargets(key: ValueKey('raw-default-enter')),
    ));
    await session.executor.execute(
      const TestStep(type: 'enterText', args: args),
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('delayed-entry')))
          .controller
          ?.text,
      'typed',
    );

    await tester.pumpWidget(const MaterialApp(
      home: _DelayedOperationTargets(
        key: ValueKey('registered-default-enter'),
      ),
    ));
    final registered = await session.act(
      sessionOperation('enterText', input: args),
    );

    expect(registered.succeeded, isTrue, reason: registered.error?.message);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('delayed-entry')))
          .controller
          ?.text,
      'typed',
    );
  });

  testWidgets(
      'target boundary behavior matches across raw and registered routes',
      (tester) async {
    const configuredTimeout = Duration(milliseconds: 35);
    final cases = <({
      String name,
      String operation,
      String targetId,
      bool disabled,
      int? timeoutMs,
      int expectedTimeoutMs,
      bool targetExists,
      bool succeeds,
    })>[
      (
        name: 'missing target uses configured default',
        operation: 'tap',
        targetId: 'missing-default',
        disabled: false,
        timeoutMs: null,
        expectedTimeoutMs: configuredTimeout.inMilliseconds,
        targetExists: false,
        succeeds: false,
      ),
      (
        name: 'missing target honors timeout override',
        operation: 'tap',
        targetId: 'missing-override',
        disabled: false,
        timeoutMs: 7,
        expectedTimeoutMs: 7,
        targetExists: false,
        succeeds: false,
      ),
      (
        name: 'visible disabled target satisfies visibility assertion',
        operation: 'expectVisible',
        targetId: 'disabled-visible',
        disabled: true,
        timeoutMs: null,
        expectedTimeoutMs: 0,
        targetExists: true,
        succeeds: true,
      ),
    ];

    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(id: 'tap-failure-parity', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      executionConfig: const TestExecutionConfig(
        defaultWaitTimeout: configuredTimeout,
      ),
    );
    addTearDown(session.close);

    for (final scenario in cases) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: scenario.targetExists
              ? TextButton(
                  key: ValueKey(scenario.targetId),
                  onPressed: scenario.disabled ? null : () {},
                  child: const Text('Target'),
                )
              : const SizedBox(),
        ),
      ));
      final args = <String, Object?>{
        'id': scenario.targetId,
        if (scenario.timeoutMs case final timeout?) 'timeoutMs': timeout,
      };

      Object? rawFailure;
      try {
        await session.executor.execute(
          TestStep(type: scenario.operation, args: args),
        );
      } catch (error) {
        rawFailure = error;
      }
      expect(rawFailure == null, scenario.succeeds, reason: scenario.name);

      if (scenario.operation == 'expectVisible') {
        final registered = await session.assertCondition(
          sessionOperation(scenario.operation, input: args),
        );
        expect(registered.passed, scenario.succeeds, reason: scenario.name);
      } else {
        final registered = await session.act(
          sessionOperation(scenario.operation, input: args),
        );
        expect(registered.succeeded, scenario.succeeds, reason: scenario.name);
        final rawMessage = rawFailure.toString();
        expect(registered.error?.message, rawMessage,
            reason:
                '${scenario.name}: both dispatch routes should diagnose the same failure');
        expect(
          rawMessage,
          contains('Timed out after ${scenario.expectedTimeoutMs}ms'),
          reason: scenario.name,
        );
        expect(
          rawMessage.contains('become hit-testable'),
          scenario.targetExists,
          reason: scenario.name,
        );
      }
    }
  });

  testWidgets('raw and registered taps do not activate disabled ID targets',
      (tester) async {
    var tapCount = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TextButton(
          key: const ValueKey('disabled-action-target'),
          onPressed: null,
          child: const Text('Disabled'),
        ),
      ),
    ));
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(id: 'disabled-tap-parity', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
    );
    addTearDown(session.close);

    await expectLater(
      session.executor.execute(const TestStep(
        type: 'tap',
        args: {'id': 'disabled-action-target'},
      )),
      throwsA(isA<TestExecutionError>()),
    );

    final registered = await session.act(sessionOperation(
      'tap',
      input: const {'id': 'disabled-action-target'},
    ));
    expect(registered.succeeded, isFalse);
    expect(
      registered.error?.code,
      anyOf(
        TestExecutionErrorCode.elementNotFound,
        TestExecutionErrorCode.elementNotInteractable,
      ),
    );
    expect(tapCount, 0);
  });

  testWidgets(
      'simple ID tap scrolls an off-screen target into view on both routes',
      (tester) async {
    var tapCount = 0;
    Widget fixture() => MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 1200),
                  TextButton(
                    key: const ValueKey('off-screen-action-target'),
                    onPressed: () => tapCount++,
                    child: const Text('Target'),
                  ),
                ],
              ),
            ),
          ),
        );

    await tester.pumpWidget(fixture());
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase:
            const EnsembleTestCase(id: 'off-screen-simple-tap', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
    );
    addTearDown(session.close);

    await session.executor.execute(const TestStep(
      type: 'tap',
      args: {'id': 'off-screen-action-target'},
    ));
    expect(tapCount, 1);

    await tester.pumpWidget(fixture());
    final registered = await session.act(sessionOperation(
      'tap',
      input: const {'id': 'off-screen-action-target'},
    ));
    expect(registered.succeeded, isTrue, reason: registered.error?.message);
    expect(tapCount, 2);
  });

  testWidgets('structured tap waits for a target mounted within timeout',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: _DelayedTapTarget(onTap: () => tapped = true),
    ));
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(id: 'structured-tap-wait', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
    );

    final result = await session.act(sessionOperation('tap', input: const {
      'target': {'id': 'delayed-target'},
      'timeoutMs': 500,
    }));

    expect(result.succeeded, isTrue, reason: result.error?.message);
    expect(find.byKey(const ValueKey('delayed-target')), findsOneWidget);
    expect(tapped, isTrue);
    await session.close();
  });

  testWidgets('structured text locator tap waits for a delayed match',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: _DelayedTapTarget(onTap: () => tapped = true),
    ));
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase:
            const EnsembleTestCase(id: 'structured-text-tap-wait', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
    );

    final result = await session.act(sessionOperation('tap', input: const {
      'target': {'text': 'Tap'},
      'timeoutMs': 500,
    }));

    expect(result.succeeded, isTrue, reason: result.error?.message);
    expect(tapped, isTrue);

    tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: _DelayedTapTarget(onTap: () => tapped = true),
    ));
    await session.executor.execute(const TestStep(
      type: 'tap',
      args: {
        'target': {'text': 'Tap'},
        'timeoutMs': 500,
      },
    ));
    expect(tapped, isTrue, reason: 'the authored-step route shares the wait');
    await session.close();
  });

  testWidgets('structured interaction dispatch keeps typed target semantics',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TextButton(
          key: const ValueKey('target'),
          onPressed: () => tapped = true,
          child: const Text('Tap'),
        ),
      ),
    ));
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(
            id: 'structured-registered-action', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
    );

    await ActionOperationHandler(session)
        .execute(sessionOperation('tap', input: const {
      'target': {'id': 'target'},
      'timeoutMs': 500,
    }));

    expect(tapped, isTrue);
    await session.close();
  });

  testWidgets('registered and session action paths have matching behavior',
      (tester) async {
    var tapCount = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TextButton(
          key: const ValueKey('target'),
          onPressed: () => tapCount++,
          child: const Text('Tap'),
        ),
      ),
    ));
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(id: 'action-path-parity', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
    );

    await ActionOperationHandler(session)
        .execute(sessionOperation('tap', input: const {
      'target': {'id': 'target'},
    }));
    final sessionResult =
        await session.act(sessionOperation('tap', input: const {
      'target': {'id': 'target'},
    }));

    expect(sessionResult.succeeded, isTrue);
    expect(tapCount, 2);
    await session.close();
  });

  testWidgets('unknown interaction handler keys are rejected', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('Home')));
    final context = EnsembleTestContext(
      testCase:
          const EnsembleTestCase(id: 'registered-action-alias', steps: []),
      apiOverlay: TestApiProviderOverlay(mocks: const {}),
      logger: TestLogger(),
      setup: const EnsembleTestSetup(),
    );
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: context,
    );

    final operation = sessionOperation('tap');
    expect(
      () => session.act(TestOperation(
        id: operation.id,
        name: operation.name,
        kind: operation.kind,
        handlerKey: 'interaction.unknown',
        input: operation.input,
        source: operation.source,
      )),
      throwsArgumentError,
    );
    await session.close();
  });
}

class _DelayedOperationTargets extends StatefulWidget {
  const _DelayedOperationTargets(
      {super.key, this.onSubmitted, this.initialText = ''});

  final ValueChanged<String>? onSubmitted;
  final String initialText;

  @override
  State<_DelayedOperationTargets> createState() =>
      _DelayedOperationTargetsState();
}

class _DelayedOperationTargetsState extends State<_DelayedOperationTargets>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 40),
  )..forward();
  var _checked = false;
  late final _textController = TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _controller.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => _controller.value < 0.5
              ? const SizedBox()
              : Column(
                  children: [
                    Checkbox(
                      key: const ValueKey('delayed-toggle'),
                      value: _checked,
                      onChanged: (value) =>
                          setState(() => _checked = value ?? false),
                    ),
                    TextField(
                      key: const ValueKey('delayed-entry'),
                      controller: _textController,
                      onSubmitted: widget.onSubmitted,
                    ),
                  ],
                ),
        ),
      );
}

class _DelayedTapTarget extends StatefulWidget {
  const _DelayedTapTarget({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_DelayedTapTarget> createState() => _DelayedTapTargetState();
}

class _DelayedSelectTarget extends StatefulWidget {
  const _DelayedSelectTarget({required this.onSelected});

  final VoidCallback onSelected;

  @override
  State<_DelayedSelectTarget> createState() => _DelayedSelectTargetState();
}

class _DelayedSelectTargetState extends State<_DelayedSelectTarget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 40),
  )..forward();
  var _showOptions = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => _controller.value < 0.5
              ? const SizedBox()
              : Column(
                  children: [
                    TextButton(
                      key: const ValueKey('delayed-select-target'),
                      onPressed: () => setState(() => _showOptions = true),
                      child: const Text('Choose'),
                    ),
                    if (_showOptions)
                      TextButton(
                        onPressed: widget.onSelected,
                        child: const Text('Option'),
                      ),
                  ],
                ),
        ),
      );
}

class _DelayedStructuredToggleTarget extends StatefulWidget {
  const _DelayedStructuredToggleTarget({super.key, this.initialValue = false});

  final bool initialValue;

  @override
  State<_DelayedStructuredToggleTarget> createState() =>
      _DelayedStructuredToggleTargetState();
}

class _DelayedStructuredToggleTargetState
    extends State<_DelayedStructuredToggleTarget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 40),
  )..forward();
  late var _checked = widget.initialValue;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => _controller.value < 0.5
              ? const SizedBox()
              : Checkbox(
                  key: const ValueKey('delayed-structured-toggle'),
                  value: _checked,
                  onChanged: (value) =>
                      setState(() => _checked = value ?? false),
                ),
        ),
      );
}

class _DelayedGestureTarget extends StatefulWidget {
  const _DelayedGestureTarget({
    super.key,
    required this.onTap,
    required this.onLongPress,
  });

  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  State<_DelayedGestureTarget> createState() => _DelayedGestureTargetState();
}

class _DelayedGestureTargetState extends State<_DelayedGestureTarget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 40),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => _controller.value < 0.5
              ? const SizedBox()
              : GestureDetector(
                  key: const ValueKey('delayed-gesture-target'),
                  onTap: widget.onTap,
                  onLongPress: widget.onLongPress,
                  child: const SizedBox(
                    width: 200,
                    height: 200,
                    child: ColoredBox(color: Colors.blue),
                  ),
                ),
        ),
      );
}

class _DelayedFocusTarget extends StatefulWidget {
  const _DelayedFocusTarget({
    super.key,
    required this.focusNode,
  });

  final FocusNode focusNode;

  @override
  State<_DelayedFocusTarget> createState() => _DelayedFocusTargetState();
}

class _DelayedFocusTargetState extends State<_DelayedFocusTarget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 40),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => _controller.value < 0.5
              ? const SizedBox()
              : TextField(
                  key: const ValueKey('delayed-focus-target'),
                  focusNode: widget.focusNode,
                ),
        ),
      );
}

class _DelayedTapTargetState extends State<_DelayedTapTarget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 40),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => _controller.value >= 0.5
              ? TextButton(
                  key: const ValueKey('delayed-target'),
                  onPressed: widget.onTap,
                  child: const Text('Tap'),
                )
              : const SizedBox(),
        ),
      );
}
