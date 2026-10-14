import 'support/test_step_executor_handler_harness.dart';
import 'support/session_operation.dart';
import 'package:ensemble_test_runner/actions/test_execution_config.dart';
import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:ensemble_test_runner/mocks/test_logger.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/test_bootstrap.dart';
import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:ensemble_test_runner/src/core/operation.dart';
import 'package:ensemble_test_runner/src/runtime/flutter_test_runtime.dart';
import 'package:ensemble_test_runner/src/runtime/operation_registry.dart'
    show operationRegistry;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('unfocus shares one ordered action path across session and step',
      (tester) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TextField(
          key: const ValueKey('unfocus-entry'),
          focusNode: focusNode,
        ),
      ),
    ));
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase:
            const EnsembleTestCase(id: 'unfocus-dispatch-parity', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
    );
    final descriptor = operationRegistry.lookup('unfocus')!;
    final operation = TestOperation(
      id: 'session-unfocus',
      name: descriptor.name,
      kind: descriptor.kind,
      handlerKey: descriptor.handlerKey,
      input: const {},
      source: const SourceLocation('unfocus-dispatch-parity', 'steps[0]'),
    );
    final events = <String>[];

    await tester.tap(find.byKey(const ValueKey('unfocus-entry')));
    expect(focusNode.hasFocus, isTrue);
    session.executor.onOperationEvidenceBoundary = (operationInput, _) async {
      events.add('session:${operationInput.operationName}');
      expect(focusNode.hasFocus, isTrue,
          reason: 'unfocus evidence must precede the focus mutation');
    };
    final result = await session.act(operation);
    expect(result.succeeded, isTrue, reason: result.error?.message);
    expect(focusNode.hasFocus, isFalse);
    expect(events, ['session:unfocus']);

    await tester.tap(find.byKey(const ValueKey('unfocus-entry')));
    expect(focusNode.hasFocus, isTrue);
    events.clear();
    session.executor.onEvidenceBoundary = (step) {
      events.add('step:${step.type}');
    };
    await session.executor.execute(const TestStep(type: 'unfocus', args: {}));
    expect(focusNode.hasFocus, isFalse);
    expect(events, ['step:unfocus']);
  });

  testWidgets('structured tap behaves the same through raw and compiled paths',
      (tester) async {
    var tapCount = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TextButton(
          onPressed: () => tapCount++,
          child: const Text('Continue'),
        ),
      ),
    ));
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(id: 'tap-dispatch-parity', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
    );
    const input = <String, dynamic>{
      'target': {'text': 'Continue'}
    };

    await session.executor.execute(
      const TestStep(type: 'tap', args: input),
    );
    expect(tapCount, 1, reason: 'the raw-step path must resolve target maps');

    final descriptor = operationRegistry.lookup('tap')!;
    final runtime = FlutterTestRuntime(session);
    final result = await runtime.execute(TestOperation(
      id: 'compiled-tap',
      name: descriptor.name,
      kind: descriptor.kind,
      handlerKey: descriptor.handlerKey,
      input: input,
      source: const SourceLocation('tap-dispatch-parity', 'steps[0]'),
    ));

    expect(result.succeeded, isTrue, reason: result.error);
    expect(tapCount, 2,
        reason: 'the compiled handler-key path must produce the same tap');
    await runtime.close();
  });

  testWidgets(
      'structured focus uses the same registered path for raw and compiled operations',
      (tester) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TextField(
          key: const ValueKey('focus-entry'),
          focusNode: focusNode,
        ),
      ),
    ));
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase:
            const EnsembleTestCase(id: 'focus-dispatch-parity', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
    );
    const input = <String, dynamic>{
      'target': {'id': 'focus-entry'},
    };
    final evidence = <String>[];
    session.executor.onEvidenceBoundary = (step) {
      evidence.add('step:${step.type}');
    };

    await session.executor.execute(const TestStep(type: 'focus', args: input));
    expect(focusNode.hasFocus, isTrue);
    expect(evidence, ['step:focus']);
    focusNode.unfocus();
    await tester.pump();
    evidence.clear();
    session.executor.onOperationEvidenceBoundary = (operationInput, _) async {
      evidence.add('operation:${operationInput.operationName}');
    };

    final descriptor = operationRegistry.lookup('focus')!;
    final runtime = FlutterTestRuntime(session);
    final result = await runtime.execute(TestOperation(
      id: 'compiled-focus',
      name: descriptor.name,
      kind: descriptor.kind,
      handlerKey: descriptor.handlerKey,
      input: input,
      source: const SourceLocation('focus-dispatch-parity', 'steps[0]'),
    ));

    expect(result.succeeded, isTrue, reason: result.error);
    expect(focusNode.hasFocus, isTrue);
    expect(evidence, ['operation:focus']);
    await runtime.close();
  });

  testWidgets('gestures share one evidence-first path for both inputs',
      (tester) async {
    var delta = Offset.zero;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: GestureDetector(
            key: const ValueKey('gesture-target'),
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (details) => delta += details.delta,
            child: const SizedBox(
              width: 200,
              height: 200,
              child: Center(child: Text('Gesture target')),
            ),
          ),
        ),
      ),
    ));
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase:
            const EnsembleTestCase(id: 'gesture-dispatch-parity', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
    );
    final runtime = FlutterTestRuntime(session);
    const cases = <({String name, Map<String, dynamic> input})>[
      (
        name: 'drag',
        input: {
          'id': 'gesture-target',
          'dx': 80,
          'dy': 0,
        },
      ),
      (
        name: 'swipe',
        input: {
          'id': 'gesture-target',
          'direction': 'right',
        },
      ),
      (
        name: 'pullToRefresh',
        input: {
          'id': 'gesture-target',
        },
      ),
    ];

    for (final gesture in cases) {
      final evidence = <String>[];
      var offsetAtEvidence = Offset.zero;
      delta = Offset.zero;
      session.executor.onEvidenceBoundary = (step) {
        evidence.add('step:${step.type}');
        offsetAtEvidence = delta;
      };
      await session.executor.execute(
        TestStep(type: gesture.name, args: gesture.input),
      );
      expect(evidence, ['step:${gesture.name}']);
      expect(offsetAtEvidence, Offset.zero);
      expect(delta, isNot(Offset.zero), reason: '${gesture.name} must move');

      evidence.clear();
      offsetAtEvidence = Offset.zero;
      delta = Offset.zero;
      session.executor.onOperationEvidenceBoundary = (operationInput, _) async {
        evidence.add('operation:${operationInput.operationName}');
        offsetAtEvidence = delta;
      };
      final descriptor = operationRegistry.lookup(gesture.name)!;
      final result = await runtime.execute(TestOperation(
        id: 'compiled-${gesture.name}',
        name: descriptor.name,
        kind: descriptor.kind,
        handlerKey: descriptor.handlerKey,
        input: gesture.input,
        source: SourceLocation('gesture-dispatch-parity', 'steps[0]'),
      ));
      expect(result.succeeded, isTrue, reason: result.error);
      expect(evidence, ['operation:${gesture.name}']);
      expect(offsetAtEvidence, Offset.zero);
      expect(delta, isNot(Offset.zero), reason: '${gesture.name} must move');
    }
    await runtime.close();
  });

  testWidgets('doubleTap and longPress share raw and compiled paths',
      (tester) async {
    var taps = 0;
    var longPresses = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: GestureDetector(
            key: const ValueKey('tap-and-press-target'),
            behavior: HitTestBehavior.opaque,
            onTap: () => taps++,
            onLongPress: () => longPresses++,
            child: const SizedBox(
              width: 200,
              height: 200,
              child: Center(child: Text('Tap and press target')),
            ),
          ),
        ),
      ),
    ));
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(
          id: 'press-dispatch-parity',
          steps: [],
        ),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
    );
    final runtime = FlutterTestRuntime(session);
    const input = <String, dynamic>{
      'target': {'text': 'Tap and press target'},
    };

    final rawEvidence = <String>[];
    session.executor.onEvidenceBoundary = (step) {
      rawEvidence.add('${step.type}:$taps:$longPresses');
    };
    await session.executor.execute(
      const TestStep(type: 'doubleTap', args: input),
    );
    expect(taps, 2, reason: 'doubleTap must perform both taps sequentially');
    expect(rawEvidence, ['doubleTap:0:0']);

    rawEvidence.clear();
    await session.executor.execute(
      const TestStep(type: 'longPress', args: input),
    );
    expect(longPresses, 1);
    expect(rawEvidence, ['longPress:2:0']);

    final operationEvidence = <String>[];
    session.executor.onOperationEvidenceBoundary = (operationInput, _) async {
      operationEvidence
          .add('${operationInput.operationName}:$taps:$longPresses');
    };
    for (final name in ['doubleTap', 'longPress']) {
      final beforeTaps = taps;
      final beforeLongPresses = longPresses;
      operationEvidence.clear();
      final descriptor = operationRegistry.lookup(name)!;
      final result = await runtime.execute(TestOperation(
        id: 'compiled-$name',
        name: descriptor.name,
        kind: descriptor.kind,
        handlerKey: descriptor.handlerKey,
        input: input,
        source: SourceLocation('press-dispatch-parity', 'steps[0]'),
      ));
      expect(result.succeeded, isTrue, reason: result.error);
      expect(operationEvidence, ['$name:$beforeTaps:$beforeLongPresses']);
      if (name == 'doubleTap') {
        expect(taps - beforeTaps, 2);
      } else {
        expect(longPresses - beforeLongPresses, 1);
      }
    }
    await runtime.close();
  });

  testWidgets('selection controls share raw and canonical paths',
      (tester) async {
    var showOptions = false;
    String? selected;
    var sliderValue = 0.1;
    late StateSetter rebuild;
    final dateController = TextEditingController();
    final timeController = TextEditingController();
    addTearDown(dateController.dispose);
    addTearDown(timeController.dispose);
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(
        builder: (context, setState) {
          rebuild = setState;
          return Scaffold(
            body: ListView(
              children: [
                TextButton(
                  key: const ValueKey('chooser'),
                  onPressed: () => setState(() => showOptions = true),
                  child: const Text('Choose'),
                ),
                if (showOptions) ...[
                  ListTile(
                    title: const Text('First'),
                    onTap: () => setState(() => selected = 'First'),
                  ),
                  ListTile(
                    title: const Text('Second'),
                    onTap: () => setState(() => selected = 'Second'),
                  ),
                ],
                KeyedSubtree(
                  key: const ValueKey('slider'),
                  child: Slider(
                    value: sliderValue,
                    onChanged: (value) => setState(() => sliderValue = value),
                  ),
                ),
                TextField(
                  key: const ValueKey('date'),
                  controller: dateController,
                ),
                TextField(
                  key: const ValueKey('time'),
                  controller: timeController,
                ),
              ],
            ),
          );
        },
      ),
    ));
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase:
            const EnsembleTestCase(id: 'controls-dispatch-parity', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
    );
    final runtime = FlutterTestRuntime(session);

    const controlCases = <({String name, Map<String, dynamic> input})>[
      (
        name: 'selectIndex',
        input: {
          'target': {'id': 'chooser'},
          'index': 1,
        },
      ),
      (
        name: 'setSlider',
        input: {
          'target': {'id': 'slider'},
          'value': 0.75,
        },
      ),
      (
        name: 'chooseDate',
        input: {
          'target': {'id': 'date'},
          'value': '2026-10-12',
        },
      ),
      (
        name: 'chooseTime',
        input: {
          'target': {'id': 'time'},
          'value': '09:30',
        },
      ),
    ];

    for (final control in controlCases) {
      final evidence = <String>[];
      session.executor.onEvidenceBoundary = (step) {
        evidence.add('step:${step.type}');
      };
      await session.executor.execute(
        TestStep(type: control.name, args: control.input),
      );
      expect(evidence, ['step:${control.name}']);

      if (control.name == 'selectIndex') {
        expect(selected, 'Second');
        rebuild(() {
          showOptions = false;
          selected = null;
        });
        await tester.pump();
      } else if (control.name == 'setSlider') {
        expect(sliderValue, closeTo(0.75, 0.08));
        rebuild(() => sliderValue = 0.1);
        await tester.pump();
      } else if (control.name == 'chooseDate') {
        expect(dateController.text, '2026-10-12');
        dateController.clear();
      } else {
        expect(timeController.text, '09:30');
        timeController.clear();
      }

      evidence.clear();
      session.executor.onOperationEvidenceBoundary = (operationInput, _) async {
        evidence.add('operation:${operationInput.operationName}');
      };
      final descriptor = operationRegistry.lookup(control.name)!;
      final result = await runtime.execute(TestOperation(
        id: 'compiled-${control.name}',
        name: descriptor.name,
        kind: descriptor.kind,
        handlerKey: descriptor.handlerKey,
        input: control.input,
        source: SourceLocation('controls-dispatch-parity', 'steps[0]'),
      ));
      expect(result.succeeded, isTrue, reason: result.error);
      expect(evidence, ['operation:${control.name}']);

      if (control.name == 'selectIndex') {
        expect(selected, 'Second');
        rebuild(() {
          showOptions = false;
          selected = null;
        });
        await tester.pump();
      } else if (control.name == 'setSlider') {
        expect(sliderValue, closeTo(0.75, 0.08));
        rebuild(() => sliderValue = 0.1);
        await tester.pump();
      } else if (control.name == 'chooseDate') {
        expect(dateController.text, '2026-10-12');
        dateController.clear();
      } else {
        expect(timeController.text, '09:30');
        timeController.clear();
      }
    }
    await runtime.close();
  });

  testWidgets('bound evidence emits once for direct and delegated actions',
      (tester) async {
    var sliderValue = 0.1;
    var tapCount = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            KeyedSubtree(
              key: const ValueKey('evidence-slider'),
              child: Slider(
                value: sliderValue,
                onChanged: (value) => sliderValue = value,
              ),
            ),
            TextButton(
              onPressed: () => tapCount++,
              child: const Text('Evidence tap'),
            ),
          ],
        ),
      ),
    ));
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(id: 'evidence-once', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
    );
    final runtime = FlutterTestRuntime(session);
    final evidence = <String>[];
    runtime.bindEvidenceBoundaryEmitter((_, name) => evidence.add(name));

    for (final action in <({String name, Map<String, dynamic> input})>[
      (
        name: 'setSlider',
        input: {
          'target': {'id': 'evidence-slider'},
          'value': 0.7,
        },
      ),
      (
        name: 'tap',
        input: {
          'target': {'text': 'Evidence tap'},
        },
      ),
    ]) {
      final descriptor = operationRegistry.lookup(action.name)!;
      final result = await runtime.execute(TestOperation(
        id: 'compiled-${action.name}',
        name: descriptor.name,
        kind: descriptor.kind,
        handlerKey: descriptor.handlerKey,
        input: action.input,
        source: SourceLocation('evidence-once', 'steps[0]'),
      ));
      expect(result.succeeded, isTrue, reason: result.error);
    }
    expect(sliderValue, closeTo(0.7, 0.08));
    expect(tapCount, 1);
    expect(evidence, ['setSlider', 'tap']);

    evidence.clear();
    await session.executor.execute(const TestStep(
      type: 'tap',
      args: {
        'target': {'text': 'Evidence tap'},
      },
    ));
    expect(tapCount, 2);
    expect(evidence, ['tap'], reason: 'authored-step evidence stays intact');
    runtime.bindEvidenceBoundaryEmitter(null);
    await runtime.close();
  });

  testWidgets(
      'structured text entry behaves the same through raw and compiled paths',
      (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TextField(
          key: const ValueKey('entry'),
          controller: controller,
        ),
      ),
    ));
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase:
            const EnsembleTestCase(id: 'entry-dispatch-parity', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
    );
    const rawInput = <String, dynamic>{
      'target': {'id': 'entry'},
      'value': 'raw value',
    };

    await session.executor.execute(
      const TestStep(type: 'enterText', args: rawInput),
    );
    expect(controller.text, 'raw value');

    final descriptor = operationRegistry.lookup('enterText')!;
    final runtime = FlutterTestRuntime(session);
    final result = await runtime.execute(TestOperation(
      id: 'compiled-enter-text',
      name: descriptor.name,
      kind: descriptor.kind,
      handlerKey: descriptor.handlerKey,
      input: const {
        'target': {'id': 'entry'},
        'value': 'compiled value',
      },
      source: const SourceLocation('entry-dispatch-parity', 'steps[0]'),
    ));

    expect(result.succeeded, isTrue, reason: result.error);
    expect(controller.text, 'compiled value');
    await runtime.close();
    controller.dispose();
  });

  testWidgets(
      'structured toggle behaves the same through raw and compiled paths',
      (tester) async {
    var selected = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => Switch(
            key: const ValueKey('toggle-control'),
            value: selected,
            onChanged: (value) => setState(() => selected = value),
          ),
        ),
      ),
    ));
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase:
            const EnsembleTestCase(id: 'toggle-dispatch-parity', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
    );
    const targetInput = <String, dynamic>{
      'target': {'id': 'toggle-control'},
    };

    await session.executor.execute(
      const TestStep(type: 'toggle', args: targetInput),
    );
    expect(selected, isTrue);

    final descriptor = operationRegistry.lookup('toggle')!;
    final runtime = FlutterTestRuntime(session);
    final result = await runtime.execute(TestOperation(
      id: 'compiled-toggle',
      name: descriptor.name,
      kind: descriptor.kind,
      handlerKey: descriptor.handlerKey,
      input: targetInput,
      source: const SourceLocation('toggle-dispatch-parity', 'steps[0]'),
    ));

    expect(result.succeeded, isTrue, reason: result.error);
    expect(selected, isFalse);
    await runtime.close();
  });

  testWidgets('simple interactions preserve input identity across both routes',
      (tester) async {
    var toggleValue = false;
    var checkValue = false;
    String? selection = 'one';
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          StatefulBuilder(
            builder: (context, setState) => Switch(
              key: const ValueKey('parity-switch'),
              value: toggleValue,
              onChanged: (value) => setState(() => toggleValue = value),
            ),
          ),
          StatefulBuilder(
            builder: (context, setState) => Checkbox(
              key: const ValueKey('parity-checkbox'),
              value: checkValue,
              onChanged: (value) => setState(() => checkValue = value!),
            ),
          ),
          StatefulBuilder(
            builder: (context, setState) => PopupMenuButton<String>(
              key: const ValueKey('parity-dropdown'),
              onSelected: (value) => setState(() => selection = value),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'one', child: Text('one')),
                PopupMenuItem(value: 'two', child: Text('two')),
              ],
              child: const Text('choose'),
            ),
          ),
          Builder(
              builder: (context) => TextButton(
                    key: const ValueKey('parity-tap'),
                    onPressed: () {},
                    child: const Text('tap'),
                  )),
        ]),
      ),
    ));
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(id: 'simple-interactions', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
    );
    final rawInputs = <String, TestStep>{
      'tap': const TestStep(type: 'tap', args: {
        'target': {'id': 'parity-tap'}
      }),
      'select': const TestStep(type: 'select', args: {
        'target': {'id': 'parity-dropdown'},
        'value': 'two',
      }),
      'toggle': const TestStep(type: 'toggle', args: {
        'target': {'id': 'parity-switch'}
      }),
      'check': const TestStep(type: 'check', args: {
        'target': {'id': 'parity-checkbox'}
      }),
      'uncheck': const TestStep(type: 'uncheck', args: {
        'target': {'id': 'parity-checkbox'}
      }),
    };
    final seenRaw = <TestStep>[];
    session.executor.onEvidenceBoundary = seenRaw.add;
    for (final step in rawInputs.values) {
      await session.executor.execute(step);
      expect(seenRaw, contains(same(step)));
    }
    expect(toggleValue, isTrue);
    expect(checkValue, isFalse);
    expect(selection, 'two');

    final seenOperations = <TestOperation>[];
    session.executor.onOperationEvidenceBoundary = (operationInput, _) async {
      seenOperations.add(operationInput as TestOperation);
    };
    for (final entry in rawInputs.entries) {
      final descriptor = operationRegistry.lookup(entry.key)!;
      final operation = TestOperation(
        id: 'compiled-${entry.key}',
        name: descriptor.name,
        kind: descriptor.kind,
        handlerKey: descriptor.handlerKey,
        input: Map<String, Object?>.from(entry.value.args),
        source: SourceLocation('simple-interactions', entry.key),
      );
      await session.act(operation);
      expect(seenOperations, contains(same(operation)));
    }
    expect(toggleValue, isFalse);
    expect(checkValue, isFalse);
    expect(selection, 'two');
  });

  testWidgets(
      'structured clearText behaves the same through raw and compiled paths',
      (tester) async {
    final controller = TextEditingController(text: 'initial');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TextField(
          key: const ValueKey('clear-entry'),
          controller: controller,
        ),
      ),
    ));
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase:
            const EnsembleTestCase(id: 'clear-dispatch-parity', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
    );
    const input = <String, dynamic>{
      'target': {'id': 'clear-entry'}
    };

    await session.executor.execute(
      const TestStep(type: 'clearText', args: input),
    );
    expect(controller.text, isEmpty);
    controller.text = 'again';

    final descriptor = operationRegistry.lookup('clearText')!;
    final runtime = FlutterTestRuntime(session);
    final result = await runtime.execute(TestOperation(
      id: 'compiled-clear-text',
      name: descriptor.name,
      kind: descriptor.kind,
      handlerKey: descriptor.handlerKey,
      input: input,
      source: const SourceLocation('clear-dispatch-parity', 'steps[0]'),
    ));

    expect(result.succeeded, isTrue, reason: result.error);
    expect(controller.text, isEmpty);
    await runtime.close();
    controller.dispose();
  });

  testWidgets(
      'structured replaceText behaves the same through raw and compiled paths',
      (tester) async {
    final controller = TextEditingController(text: 'initial');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TextField(
          key: const ValueKey('replace-entry'),
          controller: controller,
        ),
      ),
    ));
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase:
            const EnsembleTestCase(id: 'replace-dispatch-parity', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
    );
    const rawInput = <String, dynamic>{
      'target': {'id': 'replace-entry'},
      'value': 'raw replacement',
    };

    await session.executor.execute(
      const TestStep(type: 'replaceText', args: rawInput),
    );
    expect(controller.text, 'raw replacement');

    final descriptor = operationRegistry.lookup('replaceText')!;
    final runtime = FlutterTestRuntime(session);
    final result = await runtime.execute(TestOperation(
      id: 'compiled-replace-text',
      name: descriptor.name,
      kind: descriptor.kind,
      handlerKey: descriptor.handlerKey,
      input: const {
        'target': {'id': 'replace-entry'},
        'value': 'compiled replacement',
      },
      source: const SourceLocation('replace-dispatch-parity', 'steps[0]'),
    ));

    expect(result.succeeded, isTrue, reason: result.error);
    expect(controller.text, 'compiled replacement');
    await runtime.close();
    controller.dispose();
  });

  testWidgets('text editing operations share input handlers and evidence',
      (tester) async {
    final controller = TextEditingController(text: 'initial');
    final submitted = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TextField(
          key: const ValueKey('text-family-entry'),
          controller: controller,
          onSubmitted: submitted.add,
        ),
      ),
    ));
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(id: 'text-family-parity', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
    );
    final rawSteps = <TestStep>[
      const TestStep(type: 'enterText', args: {
        'target': {'id': 'text-family-entry'},
        'value': 'entered',
      }),
      const TestStep(type: 'clearText', args: {
        'target': {'id': 'text-family-entry'},
      }),
      const TestStep(type: 'replaceText', args: {
        'target': {'id': 'text-family-entry'},
        'value': 'replaced',
      }),
      const TestStep(type: 'submitText', args: {
        'target': {'id': 'text-family-entry'},
      }),
    ];
    final seenSteps = <TestStep>[];
    final rawValuesAtBoundary = <String>[];
    session.executor.onEvidenceBoundary = (step) {
      seenSteps.add(step);
      rawValuesAtBoundary.add(controller.text);
    };
    for (final step in rawSteps) {
      await session.executor.execute(step);
      expect(seenSteps, contains(same(step)));
    }
    expect(controller.text, 'replaced');
    expect(submitted, ['replaced']);
    expect(rawValuesAtBoundary, ['initial', 'entered', '', 'replaced']);

    final seenOperations = <TestOperation>[];
    final operationValuesAtBoundary = <String>[];
    session.executor.onOperationEvidenceBoundary = (operationInput, _) async {
      seenOperations.add(operationInput as TestOperation);
      operationValuesAtBoundary.add(controller.text);
    };
    submitted.clear();
    for (var index = 0; index < rawSteps.length; index++) {
      final step = rawSteps[index];
      final descriptor = operationRegistry.lookup(step.type)!;
      final operation = TestOperation(
        id: 'compiled-text-$index',
        name: descriptor.name,
        kind: descriptor.kind,
        handlerKey: descriptor.handlerKey,
        input: Map<String, Object?>.from(step.args),
        source: SourceLocation('text-family-parity', 'steps[$index]'),
      );
      await session.act(operation);
      expect(seenOperations, contains(same(operation)));
    }
    expect(controller.text, 'replaced');
    expect(submitted, ['replaced']);
    expect(
      operationValuesAtBoundary,
      ['replaced', 'entered', '', 'replaced'],
    );
    controller.dispose();
  });

  testWidgets('scroll operations preserve matched evidence across both routes',
      (tester) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView.builder(
          key: const ValueKey('scroll-family-list'),
          controller: scrollController,
          itemCount: 40,
          itemBuilder: (context, index) => SizedBox(
            height: 48,
            child: Text('row $index', key: ValueKey('scroll-row-$index')),
          ),
        ),
      ),
    ));
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(id: 'scroll-family-parity', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
    );
    final rawSteps = <TestStep>[
      const TestStep(type: 'scroll', args: {'delta': -180}),
      const TestStep(type: 'scrollUntilVisible', args: {
        'id': 'scroll-row-30',
        'scrollableId': 'scroll-family-list',
        'timeoutMs': 500,
      }),
    ];
    final seenSteps = <TestStep>[];
    session.executor.onEvidenceBoundary = (step) {
      seenSteps.add(step);
      if (step.type == 'condition:scrollUntilVisible') {
        expect(find.byKey(const ValueKey('scroll-row-30')).hitTestable(),
            findsOneWidget);
      }
    };
    for (final step in rawSteps) {
      await session.executor.execute(step);
      if (step.type == 'scrollUntilVisible') {
        expect(seenSteps.last.type, 'condition:scrollUntilVisible');
        expect(seenSteps.last.args, step.args);
      } else {
        expect(seenSteps, contains(same(step)));
      }
    }
    expect(
      find.byKey(const ValueKey('scroll-row-30')).hitTestable(),
      findsOneWidget,
    );

    scrollController.jumpTo(0);
    await tester.pump();
    final seenOperations = <TestOperation>[];
    session.executor.onOperationEvidenceBoundary = (operationInput, _) async {
      seenOperations.add(operationInput as TestOperation);
      if (operationInput.operationName == 'scrollUntilVisible') {
        expect(find.byKey(const ValueKey('scroll-row-30')).hitTestable(),
            findsOneWidget);
      }
    };
    for (var index = 0; index < rawSteps.length; index++) {
      final step = rawSteps[index];
      final descriptor = operationRegistry.lookup(step.type)!;
      final operation = TestOperation(
        id: 'compiled-scroll-$index',
        name: descriptor.name,
        kind: descriptor.kind,
        handlerKey: descriptor.handlerKey,
        input: Map<String, Object?>.from(step.args),
        source: SourceLocation('scroll-family-parity', 'steps[$index]'),
      );
      final result = await session.act(operation);
      expect(result.succeeded, isTrue, reason: result.error?.toString());
      expect(seenOperations, contains(same(operation)));
    }
    expect(
      find.byKey(const ValueKey('scroll-row-30')).hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets('scrollUntilVisible applies its timeout through both routes',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase:
            const EnsembleTestCase(id: 'scroll-timeout-parity', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
    );
    const args = {
      'id': 'not-mounted',
      'scrollableId': 'not-mounted-scrollable',
      'timeoutMs': 25,
    };
    await expectLater(
      () => session.executor.execute(const TestStep(
        type: 'scrollUntilVisible',
        args: args,
      )),
      throwsA(isA<EnsembleTestFailure>()),
    );
    final descriptor = operationRegistry.lookup('scrollUntilVisible')!;
    final stopwatch = Stopwatch()..start();
    final result = await session.act(TestOperation(
      id: 'compiled-scroll-timeout',
      name: descriptor.name,
      kind: descriptor.kind,
      handlerKey: descriptor.handlerKey,
      input: args,
      source: const SourceLocation('scroll-timeout-parity', 'steps[0]'),
    ));
    stopwatch.stop();
    expect(result.succeeded, isFalse);
    expect(stopwatch.elapsedMilliseconds, lessThan(500));
  });

  testWidgets(
      'scrollUntilVisible uses the configured default timeout on both routes',
      (tester) async {
    const defaultTimeout = Duration(milliseconds: 35);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(
          id: 'scroll-default-timeout-parity',
          steps: [],
        ),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      executionConfig: const TestExecutionConfig(
        defaultWaitTimeout: defaultTimeout,
      ),
    );
    addTearDown(session.close);

    EnsembleTestFailure? rawFailure;
    final rawWall = Stopwatch()..start();
    try {
      await session.executor.execute(const TestStep(
        type: 'scrollUntilVisible',
        args: {
          'id': 'not-mounted',
          'scrollableId': 'not-mounted-scrollable',
        },
      ));
    } on EnsembleTestFailure catch (error) {
      rawFailure = error;
    }
    rawWall.stop();

    final registeredWall = Stopwatch()..start();
    final registered = await session.act(sessionOperation(
      'scrollUntilVisible',
      input: const {
        'id': 'not-mounted',
        'scrollableId': 'not-mounted-scrollable',
      },
    ));
    registeredWall.stop();

    expect(rawFailure, isNotNull);
    expect(rawFailure!.message, contains('35ms'));
    expect(registered.succeeded, isFalse);
    expect(registered.error?.message, rawFailure.message);
    // Flutter's fake clock advances by several seconds during these error
    // paths, so measure the operation's deadline against wall time instead.
    expect(rawWall.elapsed, lessThan(const Duration(milliseconds: 250)));
    expect(registeredWall.elapsed, lessThan(const Duration(milliseconds: 250)));
  });
}
