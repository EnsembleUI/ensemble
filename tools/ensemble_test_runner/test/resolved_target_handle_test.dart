import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/session/operation_target.dart';
import 'package:ensemble_test_runner/session/local/local_action_executor.dart';
import 'package:ensemble_test_runner/session/local/flutter_target_resolver.dart';
import 'support/session_operation.dart';
import 'package:ensemble_test_runner/session/local/observation_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('reuses a locator handle only within its UI revision',
      (tester) async {
    var revision = 4;
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Text('Target', key: ValueKey('target')),
      ),
    );
    final resolver = FlutterTargetResolver(
      tester: tester,
      assertions: AssertionEngine(tester: tester),
      registry: ObservationRegistry(),
      currentRevision: () => revision,
    );
    const target = ElementTarget(testId: 'target');

    final first = resolver.resolveFinder(target, requireInteractive: false);
    final sameRevision =
        resolver.resolveFinder(target, requireInteractive: false);
    expect(identical(first, sameRevision), isTrue);

    revision++;
    final nextRevision =
        resolver.resolveFinder(target, requireInteractive: false);
    expect(identical(sameRevision, nextRevision), isFalse);
    expect(nextRevision.evaluate(), hasLength(1));
  });

  testWidgets('does not cache snapshot element handles', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Text('Target', key: ValueKey('target')),
      ),
    );
    final element = find.byKey(const ValueKey('target')).evaluate().single;
    final registry = ObservationRegistry();
    registry.registerObservation(
      observationId: 'observation-1',
      handles: {
        'element-1': SnapshotElementHandle(
          observationId: 'observation-1',
          elementId: 'element-1',
          testId: 'target',
          element: element,
          observableFingerprint: 'unused',
        ),
      },
    );
    final resolver = FlutterTargetResolver(
      tester: tester,
      assertions: AssertionEngine(tester: tester),
      registry: registry,
    );
    const target = ElementTarget(
      elementId: 'element-1',
      observationId: 'observation-1',
    );

    final first = resolver.resolveFinder(target);
    final second = resolver.resolveFinder(target);
    expect(identical(first, second), isFalse);
    expect(second.evaluate(), hasLength(1));
  });

  testWidgets('structured long press publishes evidence before mutation',
      (tester) async {
    var longPressed = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: TextButton(
            key: const ValueKey('press_target'),
            onLongPress: () => longPressed = true,
            onPressed: () {},
            child: const Text('Press me'),
          ),
        ),
      ),
    ));
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'long_press_evidence', steps: []),
    );
    final assertions = AssertionEngine(tester: tester, context: context);
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: assertions,
    );
    final localActions = LocalActionExecutor(
      executor: executor,
      resolver: FlutterTargetResolver(
        tester: tester,
        assertions: assertions,
        registry: ObservationRegistry(),
      ),
    );
    final boundaries = <String>[];
    executor.onOperationEvidenceBoundary = (operationInput, detail) async {
      boundaries.add(detail);
      expect(longPressed, isFalse);
      expect(operationInput.arguments['target'], isA<Map<String, dynamic>>());
    };

    await localActions.execute(
      actionOperation('longPress',
          target:
              const ElementTarget(locator: ElementLocator(id: 'press_target'))),
    );

    expect(boundaries, ['longPress']);
    expect(longPressed, isTrue);
  });

  testWidgets('structured double tap publishes evidence before first tap',
      (tester) async {
    var tapCount = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: TextButton(
            key: const ValueKey('double_tap_target'),
            onPressed: () => tapCount++,
            child: const Text('Tap twice'),
          ),
        ),
      ),
    ));
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'double_tap_evidence', steps: []),
    );
    final assertions = AssertionEngine(tester: tester, context: context);
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: assertions,
    );
    final localActions = LocalActionExecutor(
      executor: executor,
      resolver: FlutterTargetResolver(
        tester: tester,
        assertions: assertions,
        registry: ObservationRegistry(),
      ),
    );
    final boundaries = <String>[];
    executor.onOperationEvidenceBoundary = (operationInput, detail) async {
      boundaries.add(detail);
      expect(tapCount, 0);
      expect(operationInput.arguments['target'], isA<Map<String, dynamic>>());
    };

    await localActions.execute(
      actionOperation(
        'doubleTap',
        target: const ElementTarget(
            locator: ElementLocator(id: 'double_tap_target')),
      ),
    );

    expect(boundaries, ['doubleTap']);
    expect(tapCount, 2);
  });

  testWidgets('structured focus publishes evidence before taking focus',
      (tester) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TextField(
          key: const ValueKey('focus_target'),
          focusNode: focusNode,
        ),
      ),
    ));
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'focus_evidence', steps: []),
    );
    final assertions = AssertionEngine(tester: tester, context: context);
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: assertions,
    );
    final localActions = LocalActionExecutor(
      executor: executor,
      resolver: FlutterTargetResolver(
        tester: tester,
        assertions: assertions,
        registry: ObservationRegistry(),
      ),
    );
    final boundaries = <String>[];
    executor.onOperationEvidenceBoundary = (operationInput, detail) async {
      boundaries.add(detail);
      expect(focusNode.hasFocus, isFalse);
      expect(operationInput.arguments['target'], isA<Map<String, dynamic>>());
    };

    await localActions.execute(
      actionOperation('focus',
          target:
              const ElementTarget(locator: ElementLocator(id: 'focus_target'))),
    );

    expect(boundaries, ['focus']);
    expect(focusNode.hasFocus, isTrue);
  });

  testWidgets('structured check publishes evidence before changing value',
      (tester) async {
    var checked = false;
    late StateSetter updateChecked;
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(builder: (context, setState) {
        updateChecked = setState;
        return Scaffold(
          body: Checkbox(
            key: const ValueKey('check_target'),
            value: checked,
            onChanged: (value) => updateChecked(() => checked = value!),
          ),
        );
      }),
    ));
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'check_evidence', steps: []),
    );
    final assertions = AssertionEngine(tester: tester, context: context);
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: assertions,
    );
    final localActions = LocalActionExecutor(
      executor: executor,
      resolver: FlutterTargetResolver(
        tester: tester,
        assertions: assertions,
        registry: ObservationRegistry(),
      ),
    );
    final boundaries = <String>[];
    executor.onOperationEvidenceBoundary = (operationInput, detail) async {
      boundaries.add(detail);
      expect(checked, isFalse);
      expect(operationInput.arguments['target'], isA<Map<String, dynamic>>());
    };

    await localActions.execute(
      actionOperation('check',
          target:
              const ElementTarget(locator: ElementLocator(id: 'check_target'))),
    );

    expect(boundaries, ['check']);
    expect(checked, isTrue);
  });

  testWidgets('structured uncheck publishes evidence before changing value',
      (tester) async {
    var checked = true;
    late StateSetter updateChecked;
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(builder: (context, setState) {
        updateChecked = setState;
        return Scaffold(
          body: Checkbox(
            key: const ValueKey('uncheck_target'),
            value: checked,
            onChanged: (value) => updateChecked(() => checked = value!),
          ),
        );
      }),
    ));
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'uncheck_evidence', steps: []),
    );
    final assertions = AssertionEngine(tester: tester, context: context);
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: assertions,
    );
    final localActions = LocalActionExecutor(
      executor: executor,
      resolver: FlutterTargetResolver(
        tester: tester,
        assertions: assertions,
        registry: ObservationRegistry(),
      ),
    );
    final boundaries = <String>[];
    executor.onOperationEvidenceBoundary = (operationInput, detail) async {
      boundaries.add(detail);
      expect(checked, isTrue);
      expect(operationInput.arguments['target'], isA<Map<String, dynamic>>());
    };

    await localActions.execute(
      actionOperation('uncheck',
          target: const ElementTarget(
              locator: ElementLocator(id: 'uncheck_target'))),
    );

    expect(boundaries, ['uncheck']);
    expect(checked, isFalse);
  });

  testWidgets('structured select publishes evidence before choosing option',
      (tester) async {
    var selected = 'A';
    late StateSetter updateSelection;
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(builder: (context, setState) {
        updateSelection = setState;
        return Scaffold(
          body: DropdownButton<String>(
            key: const ValueKey('select_target'),
            value: selected,
            items: const [
              DropdownMenuItem(value: 'A', child: Text('A')),
              DropdownMenuItem(value: 'B', child: Text('B')),
            ],
            onChanged: (value) => updateSelection(() => selected = value!),
          ),
        );
      }),
    ));
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'select_evidence', steps: []),
    );
    final assertions = AssertionEngine(tester: tester, context: context);
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: assertions,
    );
    final localActions = LocalActionExecutor(
      executor: executor,
      resolver: FlutterTargetResolver(
        tester: tester,
        assertions: assertions,
        registry: ObservationRegistry(),
      ),
    );
    final boundaries = <String>[];
    executor.onOperationEvidenceBoundary = (operationInput, detail) async {
      boundaries.add(detail);
      expect(selected, 'A');
      expect(operationInput.arguments['value'], 'B');
      expect(operationInput.arguments['target'], isA<Map<String, dynamic>>());
    };

    await localActions.execute(
      actionOperation('select',
          target:
              const ElementTarget(locator: ElementLocator(id: 'select_target')),
          input: const {'value': 'B'}),
    );

    expect(boundaries, ['select']);
    expect(selected, 'B');
  });

  testWidgets('structured toggle publishes evidence before changing value',
      (tester) async {
    var enabled = false;
    late StateSetter updateEnabled;
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(builder: (context, setState) {
        updateEnabled = setState;
        return Scaffold(
          body: Switch(
            key: const ValueKey('toggle_target'),
            value: enabled,
            onChanged: (value) => updateEnabled(() => enabled = value),
          ),
        );
      }),
    ));
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'toggle_evidence', steps: []),
    );
    final assertions = AssertionEngine(tester: tester, context: context);
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: assertions,
    );
    final localActions = LocalActionExecutor(
      executor: executor,
      resolver: FlutterTargetResolver(
        tester: tester,
        assertions: assertions,
        registry: ObservationRegistry(),
      ),
    );
    final boundaries = <String>[];
    executor.onOperationEvidenceBoundary = (operationInput, detail) async {
      boundaries.add(detail);
      expect(enabled, isFalse);
      expect(operationInput.arguments['target'], isA<Map<String, dynamic>>());
    };

    await localActions.execute(
      actionOperation('toggle',
          target: const ElementTarget(
              locator: ElementLocator(id: 'toggle_target'))),
    );

    expect(boundaries, ['toggle']);
    expect(enabled, isTrue);
  });

  testWidgets('structured chooseDate publishes evidence before text entry',
      (tester) async {
    final controller = TextEditingController(text: '2020-01-01');
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TextField(
          key: const ValueKey('date_target'),
          controller: controller,
        ),
      ),
    ));
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'choose_date_evidence', steps: []),
    );
    final assertions = AssertionEngine(tester: tester, context: context);
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: assertions,
    );
    final localActions = LocalActionExecutor(
      executor: executor,
      resolver: FlutterTargetResolver(
        tester: tester,
        assertions: assertions,
        registry: ObservationRegistry(),
      ),
    );
    final boundaries = <String>[];
    executor.onOperationEvidenceBoundary = (operationInput, detail) async {
      boundaries.add(detail);
      expect(controller.text, '2020-01-01');
      expect(operationInput.arguments['value'], '2030-05-06');
    };

    await localActions.execute(
      actionOperation('chooseDate',
          target:
              const ElementTarget(locator: ElementLocator(id: 'date_target')),
          input: const {'value': '2030-05-06'}),
    );

    expect(boundaries, ['chooseDate']);
    expect(controller.text, '2030-05-06');
  });

  testWidgets('structured text actions publish evidence before mutation',
      (tester) async {
    final controller = TextEditingController(text: 'Initial');
    addTearDown(controller.dispose);
    var submitted = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TextField(
          key: const ValueKey('text_target'),
          controller: controller,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => submitted = true,
        ),
      ),
    ));
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'text_action_evidence', steps: []),
    );
    final assertions = AssertionEngine(tester: tester, context: context);
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: assertions,
    );
    final localActions = LocalActionExecutor(
      executor: executor,
      resolver: FlutterTargetResolver(
        tester: tester,
        assertions: assertions,
        registry: ObservationRegistry(),
      ),
    );
    final capturedValues = <String, String>{};
    final boundaries = <String>[];
    executor.onOperationEvidenceBoundary = (operationInput, detail) async {
      boundaries.add(detail);
      capturedValues[detail] = controller.text;
      expect(submitted, isFalse);
    };
    const target = ElementTarget(locator: ElementLocator(id: 'text_target'));

    await localActions.execute(
      actionOperation('enterText',
          target: target, input: const {'value': 'Entered'}),
    );
    await localActions.execute(
      actionOperation('replaceText',
          target: target, input: const {'value': 'Replaced'}),
    );
    await localActions.execute(actionOperation('clearText', target: target));
    expect(controller.text, isEmpty);

    await tester.enterText(find.byKey(const ValueKey('text_target')), 'Submit');
    await tester.pump();
    await localActions.execute(actionOperation('submitText', target: target));

    expect(boundaries, ['enterText', 'replaceText', 'clearText', 'submitText']);
    expect(capturedValues, {
      'enterText': 'Initial',
      'replaceText': 'Entered',
      'clearText': 'Replaced',
      'submitText': 'Submit',
    });
    expect(submitted, isTrue);
  });

  testWidgets('structured selectIndex publishes evidence before selection',
      (tester) async {
    var selected = 'A';
    late StateSetter updateSelection;
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(builder: (context, setState) {
        updateSelection = setState;
        return Scaffold(
          body: DropdownButton<dynamic>(
            key: const ValueKey('index_target'),
            value: selected,
            items: const [
              DropdownMenuItem<dynamic>(value: 'A', child: Text('A')),
              DropdownMenuItem<dynamic>(value: 'B', child: Text('B')),
            ],
            onChanged: (value) =>
                updateSelection(() => selected = value.toString()),
          ),
        );
      }),
    ));
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'select_index_evidence', steps: []),
    );
    final assertions = AssertionEngine(tester: tester, context: context);
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: assertions,
    );
    final localActions = LocalActionExecutor(
      executor: executor,
      resolver: FlutterTargetResolver(
        tester: tester,
        assertions: assertions,
        registry: ObservationRegistry(),
      ),
    );
    final boundaries = <String>[];
    executor.onOperationEvidenceBoundary = (operationInput, detail) async {
      boundaries.add(detail);
      expect(selected, 'A');
      expect(operationInput.arguments['index'], 1);
      throw StateError('stop at evidence boundary');
    };

    await expectLater(
      localActions.execute(
        actionOperation('selectIndex',
            target: const ElementTarget(
                locator: ElementLocator(id: 'index_target')),
            input: const {'index': 1}),
      ),
      throwsStateError,
    );

    expect(boundaries, ['selectIndex']);
    expect(selected, 'A');
  });

  testWidgets('structured setSlider publishes evidence before value change',
      (tester) async {
    var value = 0.1;
    late StateSetter updateValue;
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(builder: (context, setState) {
        updateValue = setState;
        return Scaffold(
          body: KeyedSubtree(
            key: const ValueKey('slider_target'),
            child: Slider(
              value: value,
              onChanged: (next) => updateValue(() => value = next),
            ),
          ),
        );
      }),
    ));
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'slider_evidence', steps: []),
    );
    final assertions = AssertionEngine(tester: tester, context: context);
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: assertions,
    );
    final localActions = LocalActionExecutor(
      executor: executor,
      resolver: FlutterTargetResolver(
        tester: tester,
        assertions: assertions,
        registry: ObservationRegistry(),
      ),
    );
    final boundaries = <String>[];
    executor.onOperationEvidenceBoundary = (operationInput, detail) async {
      boundaries.add(detail);
      expect(value, 0.1);
      expect(operationInput.arguments['value'], 0.8);
    };

    await localActions.execute(
      actionOperation('setSlider',
          target:
              const ElementTarget(locator: ElementLocator(id: 'slider_target')),
          input: const {'value': 0.8}),
    );

    expect(boundaries, ['setSlider']);
    expect(value, greaterThan(0.1));
  });

  testWidgets('structured gestures publish evidence before dragging',
      (tester) async {
    var gestureUpdates = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: GestureDetector(
            key: const ValueKey('gesture_target'),
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (_) => gestureUpdates++,
            child: const SizedBox(width: 120, height: 120),
          ),
        ),
      ),
    ));
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'gesture_evidence', steps: []),
    );
    final assertions = AssertionEngine(tester: tester, context: context);
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: assertions,
    );
    final localActions = LocalActionExecutor(
      executor: executor,
      resolver: FlutterTargetResolver(
        tester: tester,
        assertions: assertions,
        registry: ObservationRegistry(),
      ),
    );
    final boundaries = <String>[];
    var expectedUpdates = 0;
    executor.onOperationEvidenceBoundary = (operationInput, detail) async {
      boundaries.add(detail);
      expect(gestureUpdates, expectedUpdates);
      expect(operationInput.arguments['target'], isA<Map<String, dynamic>>());
    };
    const target = ElementTarget(
      locator: ElementLocator(id: 'gesture_target'),
    );

    await localActions.execute(actionOperation('scroll',
        target: target, input: const {'direction': 'down', 'distance': 40}));
    expectedUpdates = gestureUpdates;
    expect(gestureUpdates, greaterThan(0));
    await localActions.execute(
      actionOperation('swipe',
          target: target, input: const {'direction': 'left'}),
    );
    expectedUpdates = gestureUpdates;
    expect(gestureUpdates, greaterThan(1));
    await localActions.execute(
      actionOperation('drag',
          target: target, input: const {'dx': 30, 'dy': 20}),
    );
    expectedUpdates = gestureUpdates;
    expect(gestureUpdates, greaterThan(2));
    await localActions
        .execute(actionOperation('pullToRefresh', target: target));

    expect(boundaries, ['scroll', 'swipe', 'drag', 'pullToRefresh']);
    expect(gestureUpdates, greaterThan(expectedUpdates));
  });
}
