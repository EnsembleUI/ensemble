import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:ensemble_test_runner/mocks/test_logger.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/test_bootstrap.dart';
import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:ensemble_test_runner/session/operation_target.dart';
import 'package:ensemble_test_runner/session/session_capabilities.dart';
import 'package:ensemble_test_runner/src/runtime/flutter_test_runtime.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/session_operation.dart';

void main() {
  testWidgets('drag, swipe and pullToRefresh dispatch directly',
      (tester) async {
    var completedGestures = 0;
    Widget target(String id) => GestureDetector(
          key: ValueKey(id),
          onPanEnd: (_) => completedGestures++,
          child: SizedBox(
            width: 180,
            height: 100,
            child: Center(child: Text(id)),
          ),
        );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            target('drag_by_id'),
            target('drag_structured'),
            target('swipe_by_id'),
            target('swipe_structured'),
            target('refresh_by_id'),
            target('refresh_structured'),
          ],
        ),
      ),
    ));

    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(id: 'direct-drag', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      permissions: SessionPermissions.testController,
    );
    final runtime = FlutterTestRuntime(session);
    final boundaries = <String>[];
    runtime.bindEvidenceBoundaryEmitter((_, operation) {
      boundaries.add('$operation:$completedGestures');
    });

    final operations = [
      actionOperation(
        'drag',
        input: const {'id': 'drag_by_id', 'dx': 30, 'dy': -20},
      ),
      actionOperation(
        'drag',
        target: const ElementTarget(testId: 'drag_structured'),
        input: const {'dx': -30, 'dy': 20},
      ),
      actionOperation(
        'swipe',
        input: const {'id': 'swipe_by_id', 'direction': 'right'},
      ),
      actionOperation(
        'swipe',
        target: const ElementTarget(testId: 'swipe_structured'),
        input: const {'direction': 'up'},
      ),
      actionOperation(
        'pullToRefresh',
        input: const {'id': 'refresh_by_id'},
      ),
      actionOperation(
        'pullToRefresh',
        target: const ElementTarget(testId: 'refresh_structured'),
      ),
    ];
    for (final operation in operations) {
      final result = await runtime.execute(operation);
      expect(result.succeeded, isTrue, reason: result.error);
    }
    expect(completedGestures, 6);
    expect(
      boundaries,
      [
        'drag:0',
        'drag:1',
        'swipe:2',
        'swipe:3',
        'pullToRefresh:4',
        'pullToRefresh:5',
      ],
    );

    await runtime.close();
  });

  testWidgets('doubleTap and longPress dispatch directly for both targets',
      (tester) async {
    var doubleTapCount = 0;
    var longPressCount = 0;
    Widget target(String id) => GestureDetector(
          key: ValueKey(id),
          onTap: () => doubleTapCount++,
          onLongPress: () => longPressCount++,
          child: SizedBox(
            width: 140,
            height: 60,
            child: Center(child: Text(id)),
          ),
        );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            target('double_by_id'),
            target('double_structured'),
            target('long_by_id'),
            target('long_structured'),
          ],
        ),
      ),
    ));

    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(id: 'direct-gestures', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      permissions: SessionPermissions.testController,
    );
    final runtime = FlutterTestRuntime(session);
    final boundaries = <String>[];
    runtime.bindEvidenceBoundaryEmitter((_, operation) {
      boundaries.add('$operation:$doubleTapCount:$longPressCount');
    });

    final doubleById = await runtime.execute(actionOperation(
      'doubleTap',
      input: const {'id': 'double_by_id'},
    ));
    expect(doubleById.succeeded, isTrue, reason: doubleById.error);

    final doubleStructured = await runtime.execute(actionOperation(
      'doubleTap',
      target: const ElementTarget(testId: 'double_structured'),
    ));
    expect(doubleStructured.succeeded, isTrue, reason: doubleStructured.error);
    expect(doubleTapCount, 4);

    final longById = await runtime.execute(actionOperation(
      'longPress',
      input: const {'id': 'long_by_id'},
    ));
    expect(longById.succeeded, isTrue, reason: longById.error);

    final longStructured = await runtime.execute(actionOperation(
      'longPress',
      target: const ElementTarget(testId: 'long_structured'),
    ));
    expect(longStructured.succeeded, isTrue, reason: longStructured.error);
    expect(longPressCount, 2);
    expect(
      boundaries,
      [
        'doubleTap:0:0',
        'doubleTap:2:0',
        'longPress:4:0',
        'longPress:4:1',
      ],
    );

    await runtime.close();
  });

  testWidgets('selection and boolean controls dispatch directly',
      (tester) async {
    var showChoice = false;
    var selected = '';
    var toggled = false;
    var checked = false;
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(
        builder: (context, setState) => Scaffold(
          body: Column(
            children: [
              TextButton(
                key: const ValueKey('select_by_id'),
                onPressed: () => setState(() => showChoice = true),
                child: const Text('Choose by id'),
              ),
              TextButton(
                key: const ValueKey('select_structured'),
                onPressed: () => setState(() => showChoice = true),
                child: const Text('Choose structurally'),
              ),
              if (showChoice)
                TextButton(
                  onPressed: () => setState(() {
                    selected = 'Choice';
                    showChoice = false;
                  }),
                  child: const Text('Choice'),
                ),
              Switch(
                key: const ValueKey('direct_toggle'),
                value: toggled,
                onChanged: (value) => setState(() => toggled = value),
              ),
              Checkbox(
                key: const ValueKey('direct_check'),
                value: checked,
                onChanged: (value) => setState(() => checked = value!),
              ),
            ],
          ),
        ),
      ),
    ));

    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(id: 'direct-controls', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      permissions: SessionPermissions.testController,
    );
    final runtime = FlutterTestRuntime(session);
    final boundaries = <String>[];
    runtime.bindEvidenceBoundaryEmitter((_, operation) {
      boundaries.add('$operation:$selected:$toggled:$checked');
    });

    final selectById = await runtime.execute(actionOperation(
      'select',
      input: const {'id': 'select_by_id', 'value': 'Choice'},
    ));
    expect(selectById.succeeded, isTrue, reason: selectById.error);
    expect(selected, 'Choice');

    final selectStructured = await runtime.execute(actionOperation(
      'select',
      target: const ElementTarget(testId: 'select_structured'),
      input: const {'value': 'Choice'},
    ));
    expect(selectStructured.succeeded, isTrue, reason: selectStructured.error);

    final toggle = await runtime.execute(actionOperation(
      'toggle',
      input: const {'id': 'direct_toggle'},
    ));
    expect(toggle.succeeded, isTrue, reason: toggle.error);
    expect(toggled, isTrue);

    final check = await runtime.execute(actionOperation(
      'check',
      target: const ElementTarget(testId: 'direct_check'),
    ));
    expect(check.succeeded, isTrue, reason: check.error);
    expect(checked, isTrue);

    final uncheck = await runtime.execute(actionOperation(
      'uncheck',
      input: const {'id': 'direct_check'},
    ));
    expect(uncheck.succeeded, isTrue, reason: uncheck.error);
    expect(checked, isFalse);
    expect(
      boundaries,
      [
        'select::false:false',
        'select:Choice:false:false',
        'toggle:Choice:false:false',
        'check:Choice:true:false',
        'uncheck:Choice:true:true',
      ],
    );

    await runtime.close();
  });

  testWidgets('text operations dispatch directly with pre-mutation evidence',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final submitted = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TextField(
          key: const ValueKey('direct_text_target'),
          controller: controller,
          onSubmitted: submitted.add,
        ),
      ),
    ));

    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(id: 'direct-text', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      permissions: SessionPermissions.testController,
    );
    final runtime = FlutterTestRuntime(session);
    final boundaries = <String>[];
    runtime.bindEvidenceBoundaryEmitter((_, operation) {
      boundaries.add('$operation:${controller.text}');
    });

    final entered = await runtime.execute(actionOperation(
      'enterText',
      input: const {'id': 'direct_text_target', 'value': 'first'},
    ));
    expect(entered.succeeded, isTrue, reason: entered.error);
    expect(controller.text, 'first');

    final replacedById = await runtime.execute(actionOperation(
      'replaceText',
      input: const {'id': 'direct_text_target', 'value': 'id replacement'},
    ));
    expect(replacedById.succeeded, isTrue, reason: replacedById.error);
    expect(controller.text, 'id replacement');

    final replaced = await runtime.execute(actionOperation(
      'replaceText',
      target: const ElementTarget(testId: 'direct_text_target'),
      input: const {'value': 'second'},
    ));
    expect(replaced.succeeded, isTrue, reason: replaced.error);
    expect(controller.text, 'second');

    final cleared = await runtime.execute(actionOperation(
      'clearText',
      target: const ElementTarget(testId: 'direct_text_target'),
    ));
    expect(cleared.succeeded, isTrue, reason: cleared.error);
    expect(controller.text, isEmpty);

    final enteredForSubmit = await runtime.execute(actionOperation(
      'enterText',
      target: const ElementTarget(testId: 'direct_text_target'),
      input: const {'value': 'submit me'},
    ));
    expect(enteredForSubmit.succeeded, isTrue, reason: enteredForSubmit.error);

    final submit = await runtime.execute(actionOperation(
      'submitText',
      input: const {'id': 'direct_text_target'},
    ));
    expect(submit.succeeded, isTrue, reason: submit.error);
    expect(submitted, ['submit me']);

    final submitTarget = await runtime.execute(actionOperation(
      'submitText',
      target: const ElementTarget(testId: 'direct_text_target'),
    ));
    expect(submitTarget.succeeded, isTrue, reason: submitTarget.error);
    expect(submitted, ['submit me', 'submit me']);
    expect(
      boundaries,
      [
        'enterText:',
        'replaceText:first',
        'replaceText:id replacement',
        'clearText:second',
        'enterText:',
        'submitText:submit me',
        'submitText:submit me',
      ],
    );

    await runtime.close();
  });

  testWidgets('tap operations execute directly and capture before mutation',
      (tester) async {
    var tapCount = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ElevatedButton(
          key: const ValueKey('direct_tap_target'),
          onPressed: () => tapCount++,
          child: const Text('Tap'),
        ),
      ),
    ));

    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(id: 'direct-tap', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      permissions: SessionPermissions.testController,
    );
    final runtime = FlutterTestRuntime(session);
    final boundaries = <String>[];
    runtime.bindEvidenceBoundaryEmitter((_, operation) {
      boundaries.add('$operation:$tapCount');
    });

    final structuredTap = await runtime.execute(actionOperation(
      'tap',
      target: const ElementTarget(testId: 'direct_tap_target'),
    ));
    expect(structuredTap.succeeded, isTrue, reason: structuredTap.error);
    expect(tapCount, 1);

    final tapById = await runtime.execute(actionOperation(
      'tap',
      input: const {'id': 'direct_tap_target'},
    ));
    expect(tapById.succeeded, isTrue, reason: tapById.error);
    expect(tapCount, 2);
    expect(boundaries, ['tap:0', 'tap:1']);

    await runtime.close();
  });

  testWidgets('focus operations execute directly and capture before mutation',
      (tester) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TextField(
          key: const ValueKey('direct_focus_target'),
          focusNode: focusNode,
        ),
      ),
    ));

    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(id: 'direct-focus', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      permissions: SessionPermissions.testController,
    );
    final runtime = FlutterTestRuntime(session);
    final boundaries = <String>[];
    runtime.bindEvidenceBoundaryEmitter((_, operation) {
      boundaries.add('$operation:${focusNode.hasFocus}');
    });

    final focus = await runtime.execute(actionOperation(
      'focus',
      target: const ElementTarget(testId: 'direct_focus_target'),
    ));
    expect(focus.succeeded, isTrue, reason: focus.error);
    expect(focusNode.hasFocus, isTrue);

    final unfocus = await runtime.execute(sessionOperation('unfocus'));
    expect(unfocus.succeeded, isTrue, reason: unfocus.error);
    expect(focusNode.hasFocus, isFalse);

    final focusById = await runtime.execute(actionOperation(
      'focus',
      input: const {'id': 'direct_focus_target'},
    ));
    expect(focusById.succeeded, isTrue, reason: focusById.error);
    expect(focusNode.hasFocus, isTrue);

    final unfocusById = await runtime.execute(sessionOperation('unfocus'));
    expect(unfocusById.succeeded, isTrue, reason: unfocusById.error);
    expect(focusNode.hasFocus, isFalse);
    expect(
      boundaries,
      ['focus:false', 'unfocus:true', 'focus:false', 'unfocus:true'],
    );

    await runtime.close();
  });
}
