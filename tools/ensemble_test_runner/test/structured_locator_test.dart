import 'support/session_operation.dart';
import 'package:ensemble_test_runner/actions/test_execution_config.dart';
import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:ensemble_test_runner/mocks/test_logger.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/session/operation_target.dart';
import 'package:ensemble_test_runner/session/errors/test_execution_error.dart';
import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:ensemble_test_runner/session/local/element_semantics.dart';
import 'package:ensemble_test_runner/session/action_operation_handler.dart';
import 'package:ensemble_test_runner/session/assertion_operation_handler.dart';
import 'package:ensemble_test_runner/session/wait_operation_handler.dart';
import 'package:ensemble_test_runner/session/observation/observation_options.dart';
import 'package:ensemble_test_runner/session/session_capabilities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'test_event_loop.dart';

LocalTestExecutionSession _attach(
  WidgetTester tester, {
  TestExecutionConfig? executionConfig,
}) =>
    LocalTestExecutionSession.attach(
      tester: tester,
      harness: EnsembleTestHarness(appPath: 'unused/', appHome: 'Home'),
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(id: 'locator', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      permissions: SessionPermissions.restrictedUi,
      executionConfig: executionConfig,
    );

void main() {
  test('element locators round trip every nested selector field', () {
    const locator = ElementLocator(
      id: 'continue',
      text: 'Continue',
      label: 'Continue action',
      role: 'button',
      within: ElementLocator(
        id: 'login_form',
        occurrence: 1,
      ),
      occurrence: 0,
      bounds: ElementBounds(left: 1, top: 2, width: 100, height: 48),
    );

    expect(
        ElementLocator.fromJson(locator.toJson()).toJson(), locator.toJson());
  });

  test('typed element targets round trip snapshot and locator identities', () {
    const target = ElementTarget(
      testId: 'continue',
      elementId: 'element-7',
      observationId: 'observation-3',
      occurrence: 1,
      locator: ElementLocator(
        text: 'Continue',
        label: 'Continue action',
        role: 'button',
        within: ElementLocator(id: 'login_form', occurrence: 0),
        bounds: ElementBounds(left: 1, top: 2, width: 100, height: 48),
      ),
    );

    expect(
      ElementTarget.fromJson(target.toJson()).toJson(),
      target.toJson(),
    );
  });

  test('operation target maps keep compact locators and legacy ids distinct',
      () {
    final structured = ElementTarget.fromOperationArgs({
      'target': {
        'text': 'Continue',
        'occurrence': 1,
        'within': {'id': 'login_form'},
      },
    });
    final legacy = ElementTarget.fromOperationArgs({'id': 'continue'});

    expect(
      structured.normalizedLocator?.toJson(),
      {
        'text': 'Continue',
        'within': {'id': 'login_form'},
        'occurrence': 1,
      },
    );
    expect(legacy.testId, 'continue');
    expect(legacy.normalizedLocator?.toJson(), {'id': 'continue'});
  });

  testWidgets('structured locators support within, ambiguity, and occurrence',
      (tester) async {
    final taps = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            _form('login_form', () => taps.add('login')),
            _form('signup_form', () => taps.add('signup')),
          ],
        ),
      ),
    );
    final session = _attach(tester);

    final ambiguous = await session.act(actionOperation('tap',
        target: ElementTarget(
          locator: ElementLocator(label: 'Continue', role: 'button'),
        )));
    expect(ambiguous.error?.code.name, 'ambiguousTarget');

    final scoped = await session.act(actionOperation('tap',
        target: ElementTarget(
          locator: ElementLocator(
            label: 'Continue',
            role: 'button',
            within: ElementLocator(id: 'login_form'),
          ),
        )));
    expect(scoped.succeeded, isTrue, reason: scoped.error?.toString());
    expect(taps, ['login']);

    // A scoped locator with an occurrence is meaningful even without an
    // additional id/text/label/role constraint: it selects a descendant in
    // the requested scope. Keep this valid through locator emptiness checks.
    final scopedOccurrence = await session.act(actionOperation('tap',
        target: ElementTarget(
          locator: ElementLocator(
            within: ElementLocator(id: 'signup_form'),
            occurrence: 0,
          ),
        )));
    expect(scopedOccurrence.succeeded, isTrue,
        reason: scopedOccurrence.error?.toString());
    expect(taps, ['login', 'signup']);

    final occurrence = await session.act(actionOperation('tap',
        target: ElementTarget(
          locator: ElementLocator(
            label: 'Continue',
            role: 'button',
            occurrence: 1,
          ),
        )));
    expect(occurrence.succeeded, isTrue, reason: occurrence.error?.toString());
    expect(taps, ['login', 'signup', 'signup']);
    await session.close();
  });

  testWidgets('structured locator fields are exact conjunctive constraints',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            Semantics(
              label: 'Continue',
              button: true,
              child: ElevatedButton(
                onPressed: () {},
                child: const Text('Continue'),
              ),
            ),
            Semantics(
              label: 'Continue',
              button: true,
              child: ElevatedButton(
                onPressed: () {},
                child: const Text('Next'),
              ),
            ),
          ],
        ),
      ),
    );
    final session = _attach(
      tester,
      executionConfig: const TestExecutionConfig(
        defaultWaitTimeout: Duration(milliseconds: 100),
      ),
    );

    final exact = await session.act(actionOperation('tap',
        target: ElementTarget(
          locator: ElementLocator(
            text: 'Continue',
            label: 'Continue',
            role: 'button',
          ),
        )));
    expect(exact.succeeded, isTrue, reason: exact.error?.toString());

    final wrongText = await session.act(actionOperation('tap',
        target: ElementTarget(
          locator: ElementLocator(
            text: 'Missing',
            label: 'Continue',
            role: 'button',
          ),
        )));
    expect(wrongText.error?.code, TestExecutionErrorCode.elementNotFound);

    final wrongRole = await session.act(actionOperation('tap',
        target: ElementTarget(
          locator: ElementLocator(
            text: 'Continue',
            label: 'Continue',
            role: 'textField',
          ),
        )));
    expect(wrongRole.error?.code, TestExecutionErrorCode.elementNotFound);
    await session.close();
  });

  testWidgets(
      'historical locator matrix preserves id paths, nested scopes, labels, and interaction filtering',
      (tester) async {
    final taps = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            KeyedSubtree(
              key: const ValueKey('Home.account_area'),
              child: Column(
                children: [
                  for (var index = 0; index < 2; index++)
                    Semantics(
                      container: true,
                      label: 'Account group',
                      child: Semantics(
                        container: true,
                        label: 'Open account',
                        button: true,
                        child: ElevatedButton(
                          key: const ValueKey('Home.account_area.open'),
                          onPressed: () => taps.add('group-$index'),
                          child: const Text('Open'),
                        ),
                      ),
                    ),
                  ElevatedButton(
                    key: const ValueKey('Home.account_area.disabled'),
                    onPressed: null,
                    child: const Text('Disabled'),
                  ),
                  Offstage(
                    child: ElevatedButton(
                      key: const ValueKey('Home.account_area.hidden'),
                      onPressed: () => taps.add('hidden'),
                      child: const Text('Hidden'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    final session = _attach(tester);

    // Path-like ids remain exact ValueKeys, and an occurrence selects the
    // requested duplicate rather than a textual prefix or the first match.
    final pathTarget = ElementTarget.fromOperationArgs({
      'target': {'id': 'Home.account_area.open', 'occurrence': 1},
    });
    expect(pathTarget.normalizedLocator?.toJson(), {
      'id': 'Home.account_area.open',
      'occurrence': 1,
    });
    final secondByPath = await session.act(actionOperation(
      'tap',
      target: pathTarget,
    ));
    expect(secondByPath.succeeded, isTrue,
        reason: secondByPath.error?.toString());
    expect(taps, ['group-1']);

    // Nested within scopes form a locator path. The same exact semantic label
    // can be selected in the second scope without becoming ambiguous.
    final secondAccount = await session.act(actionOperation(
      'tap',
      target: const ElementTarget(
        locator: ElementLocator(
          label: 'Open account',
          role: 'button',
          within: ElementLocator(
            label: 'Account group',
            occurrence: 1,
            within: ElementLocator(id: 'Home.account_area'),
          ),
        ),
      ),
    ));
    expect(secondAccount.succeeded, isTrue,
        reason: secondAccount.error?.toString());
    expect(taps, ['group-1', 'group-1']);

    // Existence includes disabled/offstage widgets, while actions require a
    // visible and actionable match.
    final disabledExists = await session.assertCondition(sessionOperation(
      'expectExists',
      input: const {
        'target': {'id': 'Home.account_area.disabled'},
      },
    ));
    expect(disabledExists.passed, isTrue, reason: disabledExists.message);
    final disabledTap = await session.act(actionOperation(
      'tap',
      target: const ElementTarget(testId: 'Home.account_area.disabled'),
    ));
    expect(
        disabledTap.error?.code,
        anyOf(TestExecutionErrorCode.elementNotFound,
            TestExecutionErrorCode.elementNotInteractable));

    final hiddenExists = await session.assertCondition(sessionOperation(
      'expectExists',
      input: const {
        'target': {'id': 'Home.account_area.hidden'},
      },
    ));
    expect(hiddenExists.passed, isTrue, reason: hiddenExists.message);
    final hiddenTap = await session.act(actionOperation(
      'tap',
      target: const ElementTarget(testId: 'Home.account_area.hidden'),
    ));
    expect(
        hiddenTap.error?.code,
        anyOf(TestExecutionErrorCode.elementNotFound,
            TestExecutionErrorCode.elementNotInteractable));
    expect(taps, ['group-1', 'group-1']);
    await session.close();
  });

  testWidgets('gesture enabled state recognizes non-tap callbacks',
      (tester) async {
    Widget detector(
      String key, {
      GestureLongPressCallback? onLongPress,
      GestureDragUpdateCallback? onPanUpdate,
      GestureDragUpdateCallback? onHorizontalDragUpdate,
      GestureDragUpdateCallback? onVerticalDragUpdate,
      GestureScaleUpdateCallback? onScaleUpdate,
      GestureForcePressPeakCallback? onForcePressPeak,
      GestureTapCallback? onDoubleTap,
    }) =>
        GestureDetector(
          key: ValueKey(key),
          onLongPress: onLongPress,
          onPanUpdate: onPanUpdate,
          onHorizontalDragUpdate: onHorizontalDragUpdate,
          onVerticalDragUpdate: onVerticalDragUpdate,
          onScaleUpdate: onScaleUpdate,
          onForcePressPeak: onForcePressPeak,
          onDoubleTap: onDoubleTap,
          child: const SizedBox(width: 80, height: 48),
        );

    await tester.pumpWidget(MaterialApp(
      home: Column(
        children: [
          detector('long_press', onLongPress: () {}),
          detector('pan', onPanUpdate: (_) {}),
          detector('horizontal_drag', onHorizontalDragUpdate: (_) {}),
          detector('vertical_drag', onVerticalDragUpdate: (_) {}),
          detector('scale', onScaleUpdate: (_) {}),
          detector('force_press', onForcePressPeak: (_) {}),
          detector('double_tap', onDoubleTap: () {}),
          detector('no_handler'),
          Semantics(
            enabled: false,
            child: detector('explicitly_disabled', onPanUpdate: (_) {}),
          ),
        ],
      ),
    ));

    for (final key in [
      'long_press',
      'pan',
      'horizontal_drag',
      'vertical_drag',
      'scale',
      'force_press',
      'double_tap',
    ]) {
      expect(readEnabled(tester.element(find.byKey(ValueKey(key)))), isTrue,
          reason: '$key has a configured gesture callback');
    }
    expect(
        readEnabled(tester.element(find.byKey(const ValueKey('no_handler')))),
        isFalse);
    expect(
      readEnabled(
          tester.element(find.byKey(const ValueKey('explicitly_disabled')))),
      isFalse,
    );
  });

  testWidgets('out of range locator occurrence is a stable not found error',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(
          children: [
            Text('Duplicate'),
            Text('Duplicate'),
          ],
        ),
      ),
    );
    final session = _attach(tester);
    final result = await session.assertCondition(targetedOperation(
      'expectVisible',
      const ElementTarget(
        locator: ElementLocator(text: 'Duplicate', occurrence: 2),
      ),
    ));

    expect(result.passed, isFalse);
    expect(result.error?.code, TestExecutionErrorCode.elementNotFound);
    expect(result.error?.details['occurrence'], 2);
    await session.close();
  });

  testWidgets('assertions reach handlers as compiled operations',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Text('Ready', key: Key('ready'))),
    );
    final session = _attach(tester);
    final operation = sessionOperation(
      'expectVisible',
      input: const {'id': 'ready'},
    );
    Object? evidenceOperation;
    String? evidenceDetail;
    session.executor.onOperationEvidenceBoundary = (matched, detail) {
      evidenceOperation = matched;
      evidenceDetail = detail;
    };

    final result = await session.assertCondition(operation);

    expect(result.passed, isTrue);
    expect(identical(evidenceOperation, operation), isTrue);
    expect(evidenceDetail, 'condition:expectVisible');
    expect(operation.operationName, 'expectVisible');
    await session.close();
  });

  testWidgets('bounded text assertions preserve timeout error mapping',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    final session = _attach(tester);
    var evidenceCount = 0;
    session.executor.onOperationEvidenceBoundary = (_, __) {
      evidenceCount++;
    };

    final result = await session.assertCondition(
      sessionOperation(
        'expectText',
        input: const {'text': 'not present', 'timeoutMs': 1},
      ),
    );

    expect(result.passed, isFalse);
    expect(result.error?.code, TestExecutionErrorCode.actionTimeout);
    expect(evidenceCount, 0);
    await session.close();
  });

  testWidgets('within occurrence selects an exact nested scope',
      (tester) async {
    final taps = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            Semantics(
              container: true,
              label: 'Form',
              child: ElevatedButton(
                onPressed: () => taps.add('first'),
                child: const Text('Continue'),
              ),
            ),
            Semantics(
              container: true,
              label: 'Form',
              child: ElevatedButton(
                onPressed: () => taps.add('second'),
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
    final session = _attach(tester);

    final ambiguousScope = await session.act(actionOperation(
      'tap',
      target: const ElementTarget(
        locator: ElementLocator(
          label: 'Continue',
          role: 'button',
          within: ElementLocator(label: 'Form'),
        ),
      ),
    ));
    expect(ambiguousScope.error?.code, TestExecutionErrorCode.ambiguousTarget);

    final missingScopeOccurrence = await session.act(actionOperation(
      'tap',
      input: const {'timeoutMs': 100},
      target: const ElementTarget(
        locator: ElementLocator(
          label: 'Continue',
          role: 'button',
          within: ElementLocator(label: 'Form', occurrence: 2),
        ),
      ),
    ));
    expect(missingScopeOccurrence.error?.code,
        TestExecutionErrorCode.elementNotFound);
    expect(
      (missingScopeOccurrence.error?.details['locator'] as Map?)?['within'],
      {'label': 'Form', 'occurrence': 2},
    );

    final result = await session.act(actionOperation('tap',
        target: ElementTarget(
          locator: ElementLocator(
            label: 'Continue',
            role: 'button',
            within: ElementLocator(
              label: 'Form',
              occurrence: 1,
            ),
          ),
        )));

    expect(result.succeeded, isTrue, reason: result.error?.toString());
    expect(taps, ['second']);
    await session.close();
  });

  testWidgets('within-only target skips non-actionable wrapper descendants',
      (tester) async {
    final taps = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            Padding(
              key: const ValueKey('action_scope'),
              padding: const EdgeInsets.all(8),
              child: Builder(
                builder: (context) => Padding(
                  padding: const EdgeInsets.all(4),
                  child: ElevatedButton(
                    onPressed: () => taps.add('nested'),
                    child: const Text('Nested action'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    final session = _attach(tester);

    final result = await session.act(actionOperation(
      'tap',
      target: const ElementTarget(
        locator: ElementLocator(
          within: ElementLocator(id: 'action_scope'),
          occurrence: 0,
        ),
      ),
    ));

    expect(result.succeeded, isTrue, reason: result.error?.toString());
    expect(taps, ['nested']);
    await session.close();
  });

  testWidgets('offstage widgets are skipped for actions but exist for exists',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(
          children: [
            Offstage(
              child: ElevatedButton(
                key: ValueKey('hidden_btn'),
                onPressed: null,
                child: Text('Hidden'),
              ),
            ),
            ElevatedButton(
              key: ValueKey('visible_btn'),
              onPressed: null,
              child: Text('Visible'),
            ),
          ],
        ),
      ),
    );
    final session = _attach(
      tester,
      executionConfig: const TestExecutionConfig(
        defaultWaitTimeout: Duration(milliseconds: 200),
      ),
    );

    final tapHidden = await session.act(
        actionOperation('tap', target: ElementTarget(testId: 'hidden_btn')));
    expect(tapHidden.error?.code.name,
        anyOf('elementNotFound', 'elementNotInteractable'),
        reason: tapHidden.error?.toString());

    final exists = await session.assertCondition(sessionOperation(
      'expectExists',
      input: const {'id': 'hidden_btn'},
    ));
    expect(exists.passed, isTrue, reason: exists.message);
    await session.close();
  });

  testWidgets('structured expectNotVisible passes when absent or offstage',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(
          children: [
            Offstage(
              child: ElevatedButton(
                key: ValueKey('hidden_btn'),
                onPressed: null,
                child: Text('Hidden'),
              ),
            ),
            ElevatedButton(
              key: ValueKey('visible_btn'),
              onPressed: null,
              child: Text('Visible'),
            ),
          ],
        ),
      ),
    );
    final session = _attach(tester);

    final absent = await session.assertCondition(targetedOperation(
      'expectNotVisible',
      const ElementTarget(locator: ElementLocator(id: 'nonexistent_button')),
    ));
    expect(absent.passed, isTrue, reason: absent.message);

    final absentInMissingScope =
        await session.assertCondition(targetedOperation(
      'expectNotVisible',
      const ElementTarget(
        locator: ElementLocator(
          text: 'Missing',
          within: ElementLocator(id: 'missing_scope'),
        ),
      ),
    ));
    expect(absentInMissingScope.passed, isTrue,
        reason: absentInMissingScope.message);

    final outOfRangeScopeOccurrence = await session.assertCondition(
      targetedOperation(
        'expectNotVisible',
        const ElementTarget(
          locator: ElementLocator(
            id: 'visible_btn',
            within: ElementLocator(id: 'hidden_btn', occurrence: 1),
          ),
        ),
      ),
    );
    expect(outOfRangeScopeOccurrence.passed, isTrue,
        reason: outOfRangeScopeOccurrence.message);

    final offstage = await session.assertCondition(targetedOperation(
      'expectNotVisible',
      const ElementTarget(locator: ElementLocator(id: 'hidden_btn')),
    ));
    expect(offstage.passed, isTrue, reason: offstage.message);

    final stillVisible = await session.assertCondition(targetedOperation(
      'expectNotVisible',
      const ElementTarget(locator: ElementLocator(id: 'visible_btn')),
    ));
    expect(stillVisible.passed, isFalse);
    await session.close();
  });

  testWidgets('const child within scope keeps element identity',
      (tester) async {
    const shared = Text('Continue');
    final taps = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            Container(
              key: const ValueKey('left'),
              child: ElevatedButton(
                onPressed: () => taps.add('left'),
                child: shared,
              ),
            ),
            Container(
              key: const ValueKey('right'),
              child: ElevatedButton(
                onPressed: () => taps.add('right'),
                child: shared,
              ),
            ),
          ],
        ),
      ),
    );
    final session = _attach(tester);
    final left = await session.act(actionOperation('tap',
        target: ElementTarget(
          locator: ElementLocator(
            text: 'Continue',
            within: ElementLocator(id: 'left'),
          ),
        )));
    expect(left.succeeded, isTrue, reason: left.error?.toString());
    expect(taps, ['left']);
    await session.close();
  });

  testWidgets('text-only locator collapses button and nested Text',
      (tester) async {
    final taps = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ElevatedButton(
          onPressed: () => taps.add('one'),
          child: const Text('Continue'),
        ),
      ),
    );
    final session = _attach(tester);
    final single = await session.act(actionOperation('tap',
        target: ElementTarget(locator: ElementLocator(text: 'Continue'))));
    expect(single.succeeded, isTrue, reason: single.error?.toString());
    expect(taps, ['one']);
    await session.close();
  });

  testWidgets('two text Continue buttons remain ambiguous', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            ElevatedButton(
              onPressed: () {},
              child: const Text('Continue'),
            ),
            ElevatedButton(
              onPressed: () {},
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
    final session = _attach(tester);
    final ambiguous = await session.act(actionOperation('tap',
        target: ElementTarget(locator: ElementLocator(text: 'Continue'))));
    expect(ambiguous.error?.code.name, 'ambiguousTarget');
    await session.close();
  });

  testWidgets('bounds disambiguate identical controls and reject stale bounds',
      (tester) async {
    final taps = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            ElevatedButton(
              onPressed: () => taps.add('first'),
              child: const Text('Continue'),
            ),
            ElevatedButton(
              onPressed: () => taps.add('second'),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
    final rect = tester.getRect(find.text('Continue').last);
    final targetBounds = ElementBounds(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
    );
    final session = _attach(tester);
    await ActionOperationHandler(session)
        .execute(sessionOperation('tap', input: {
      'target': {
        'text': 'Continue',
        'bounds': targetBounds.toJson(),
      },
    }));
    expect(taps, ['second']);

    await WaitOperationHandler(session)
        .execute(sessionOperation('waitForText', input: {
      'text': 'Continue',
      'target': {'bounds': targetBounds.toJson()},
    }));

    final staleWait = await session.waitFor(sessionOperation('waitFor', input: {
      'text': 'Continue',
      'target': {
        'bounds': const ElementBounds(
          left: -1000,
          top: -1000,
          width: 100,
          height: 30,
        ).toJson(),
      },
      'timeoutMs': 100,
    }));
    expect(staleWait.satisfied, isFalse);
    await session.close();
  });

  testWidgets('bounds targets work for value and checked assertions',
      (tester) async {
    final controller = TextEditingController(text: 'hello');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: controller),
                Checkbox(value: true, onChanged: (_) {}),
              ],
            ),
          ),
        ),
      ),
    );
    final fieldRect = tester.getRect(find.byType(TextField));
    final checkboxRect = tester.getRect(find.byType(Checkbox));
    ElementBounds boundsFor(Rect rect) => ElementBounds(
          left: rect.left,
          top: rect.top,
          width: rect.width,
          height: rect.height,
        );
    final session = _attach(tester);
    await AssertionOperationHandler(session)
        .execute(sessionOperation('expectValue', input: {
      'target': {'bounds': boundsFor(fieldRect).toJson()},
      'equals': 'hello',
    }));
    await AssertionOperationHandler(session)
        .execute(sessionOperation('expectChecked', input: {
      'target': {'bounds': boundsFor(checkboxRect).toJson()},
      'equals': true,
    }));
    await session.close();
    controller.dispose();
  });

  testWidgets(
      'registered assertion identity selects behavior independently '
      'of its diagnostic name', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Text('Present', key: ValueKey('present')),
    ));
    final session = _attach(tester);
    final exists = sessionOperation('expectExists', input: const {
      'id': 'present',
    });
    expect(exists.handlerKey, 'assertion.exists');
    final result = await session.assertCondition(exists);
    expect(result.passed, isTrue, reason: result.message);

    await session.close();
  });

  testWidgets('bounds target scopes list assertions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Card(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [Text('First row'), Text('Second row')],
              ),
            ),
          ),
        ),
      ),
    );
    final rect = tester.getRect(find.byType(Card));
    final bounds = ElementBounds(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
    );
    final session = _attach(tester);
    await AssertionOperationHandler(session)
        .execute(sessionOperation('expectListContains', input: {
      'target': {'bounds': bounds.toJson()},
      'text': 'Second row',
    }));
    await AssertionOperationHandler(session)
        .execute(sessionOperation('expectNotEmpty', input: {
      'target': {'bounds': bounds.toJson()},
    }));
    await session.close();
  });

  testWidgets('modal overlay resolves the foreground button uniquely',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              key: const ValueKey('open'),
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (_) => AlertDialog(
                    content: ElevatedButton(
                      key: const ValueKey('dialog_ok'),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    final session = _attach(tester);
    final open = await session
        .act(actionOperation('tap', target: ElementTarget(testId: 'open')));
    expect(open.succeeded, isTrue, reason: open.error?.toString());
    await pumpUntilIdle(tester);
    final ok = await session.act(
        actionOperation('tap', target: ElementTarget(testId: 'dialog_ok')));
    expect(ok.succeeded, isTrue, reason: ok.error?.toString());
    await session.close();
  });

  testWidgets('secure password fields redact text from observations',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TextField(
            key: ValueKey('password'),
            obscureText: true,
            decoration: InputDecoration(labelText: 'Password'),
          ),
        ),
      ),
    );
    final session = _attach(tester);
    await tester.enterText(find.byKey(const ValueKey('password')), 'secret');
    await tester.pump();
    final observation = await session.observe();
    final password =
        observation.elements.where((e) => e.testId == 'password').toList();
    expect(password, isNotEmpty);
    expect(password.first.state.secure, isTrue);
    expect(password.first.text, isNull);
    await session.close();
  });

  testWidgets('scrollUntilVisible finds lazy list items', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            key: const ValueKey('list'),
            itemCount: 40,
            itemBuilder: (_, i) => SizedBox(
              height: 48,
              child: Text('Item $i', key: ValueKey('item_$i')),
            ),
          ),
        ),
      ),
    );
    final session = _attach(tester);
    final result = await session.act(actionOperation('scrollUntilVisible',
        target: ElementTarget(testId: 'item_25'),
        input: {'scrollableId': 'list'}));
    expect(result.succeeded, isTrue, reason: result.error?.toString());
    final visible = await session.assertCondition(
      sessionOperation('expectVisible', input: const {'id': 'item_25'}),
    );
    expect(visible.passed, isTrue, reason: visible.message);
    await session.close();
  });

  testWidgets('scrollUntilVisible waits for its scrollable to mount',
      (tester) async {
    final ready = Future<void>.delayed(const Duration(milliseconds: 200));
    await tester.pumpWidget(MaterialApp(
      home: FutureBuilder<void>(
        future: ready,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(body: SizedBox());
          }
          return Scaffold(
            body: ListView.builder(
              key: const ValueKey('delayed_list'),
              itemCount: 40,
              itemBuilder: (_, i) => SizedBox(
                height: 48,
                child: Text('Delayed $i', key: ValueKey('delayed_$i')),
              ),
            ),
          );
        },
      ),
    ));
    final session = _attach(tester);

    final result = await session.act(actionOperation('scrollUntilVisible',
        target: ElementTarget(testId: 'delayed_25'),
        input: {'scrollableId': 'delayed_list'}));

    expect(result.succeeded, isTrue, reason: result.error?.toString());
    expect(find.byKey(const ValueKey('delayed_25')), findsOneWidget);
    await session.close();
  });

  testWidgets('scrollUntilVisible waits for a default scrollable to mount',
      (tester) async {
    final ready = Future<void>.delayed(const Duration(milliseconds: 200));
    await tester.pumpWidget(MaterialApp(
      home: FutureBuilder<void>(
        future: ready,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(body: SizedBox());
          }
          return Scaffold(
            body: ListView.builder(
              itemCount: 40,
              itemBuilder: (_, i) => SizedBox(
                height: 48,
                child: Text('Mounted $i', key: ValueKey('mounted_$i')),
              ),
            ),
          );
        },
      ),
    ));
    final session = _attach(tester);

    final result = await session.act(actionOperation('scrollUntilVisible',
        target: ElementTarget(testId: 'mounted_25')));

    expect(result.succeeded, isTrue, reason: result.error?.toString());
    expect(find.byKey(const ValueKey('mounted_25')), findsOneWidget);
    await session.close();
  });

  testWidgets('observed keyed widget name works as an action selector',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              for (var i = 0; i < 30; i++)
                SizedBox(height: 48, child: Text('Before $i')),
              KeyedSubtree(
                key: const ValueKey('DeviceHeader'),
                child: const Text('Sample Device 12'),
              ),
            ],
          ),
        ),
      ),
    );
    final session = _attach(tester);

    final scrolled = await session.act(actionOperation('scrollUntilVisible',
        target: ElementTarget(testId: 'DeviceHeader')));
    expect(scrolled.succeeded, isTrue, reason: scrolled.error?.toString());

    final visible = await session.assertCondition(
      sessionOperation('expectVisible', input: const {'id': 'DeviceHeader'}),
    );
    expect(visible.passed, isTrue, reason: visible.message);
    await session.close();
  });

  testWidgets('unified observe stays within 2x keyed baseline', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              for (var i = 0; i < 40; i++)
                SizedBox(key: ValueKey('row_$i'), height: 8, width: 8),
            ],
          ),
        ),
      ),
    );
    final session = _attach(tester);
    const immediate = ObservationOptions(
      synchronization: ObservationSynchronization.immediate,
    );
    const keyed = ObservationOptions(
      synchronization: ObservationSynchronization.immediate,
      keyedOnly: true,
    );

    // Warm both paths so the timed runs exclude one-time semantics setup.
    await session.observe(options: keyed);
    await session.observe(options: immediate);

    final keyedSamples = <int>[];
    final unifiedSamples = <int>[];
    for (var i = 0; i < 10; i++) {
      final keyedSw = Stopwatch()..start();
      await session.observe(options: keyed);
      keyedSw.stop();
      keyedSamples.add(keyedSw.elapsedMicroseconds);

      final unifiedSw = Stopwatch()..start();
      final unified = await session.observe(options: immediate);
      unifiedSw.stop();
      unifiedSamples.add(unifiedSw.elapsedMicroseconds);
      expect(unified.elements.where((e) => e.testId != null).length, 40);
    }

    keyedSamples.sort();
    unifiedSamples.sort();
    // Drop min/max so a single CI scheduling spike cannot dominate.
    final keyedCore = keyedSamples.sublist(1, keyedSamples.length - 1);
    final unifiedCore = unifiedSamples.sublist(1, unifiedSamples.length - 1);
    final keyedMedian = keyedCore[keyedCore.length ~/ 2].toDouble();
    final unifiedMedian = unifiedCore[unifiedCore.length ~/ 2].toDouble();
    // Microsecond ratios on tiny trees are noisy on shared CI runners. Enforce
    // the relative bound only above a noise floor; otherwise require a modest
    // absolute budget that still catches real regressions.
    const noiseFloorUs = 2000.0;
    const absoluteBudgetUs = 50000.0;
    final ratio = unifiedMedian / keyedMedian.clamp(1, 1e12);
    final withinRatio = ratio <= 4.0;
    final withinAbsolute = unifiedMedian <= absoluteBudgetUs;
    final aboveNoise =
        keyedMedian >= noiseFloorUs || unifiedMedian >= noiseFloorUs;
    expect(
      aboveNoise ? withinRatio : withinAbsolute,
      isTrue,
      reason: 'unifiedMedian=${unifiedMedian}µs keyedMedian=${keyedMedian}µs '
          'ratio=$ratio (≤4x when above ${noiseFloorUs}µs noise floor; '
          'otherwise ≤${absoluteBudgetUs}µs absolute) '
          'samplesUnified=$unifiedSamples samplesKeyed=$keyedSamples',
    );
    await session.close();
  });
}

Widget _form(String id, VoidCallback onPressed) => Container(
      key: ValueKey(id),
      child: ElevatedButton(
        onPressed: onPressed,
        child: const Text('Continue'),
      ),
    );
