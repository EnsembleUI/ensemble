import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/step_highlight_finder.dart';
import 'package:ensemble_test_runner/session/observation/ui_element.dart';
import 'package:ensemble_test_runner/session/observation/ui_observation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'stepHighlightFinder resolves structured target label+role for tap',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Semantics(
                label: 'Login with test token',
                button: true,
                child: ElevatedButton(
                  onPressed: () {},
                  child: const Text('Login with test token'),
                ),
              ),
            ),
          ),
        ),
      );

      final context = EnsembleTestContext.fromTestCase(
        const EnsembleTestCase(
          id: 'highlight_target',
          startScreen: 'Login',
          steps: [],
        ),
      );
      final assertions = AssertionEngine(tester: tester, context: context);
      final step = const TestStep(
        type: 'tap',
        args: {
          'target': {
            'label': 'Login with test token',
            'role': 'button',
          },
        },
      );

      final finder = stepHighlightFinder(
        tester: tester,
        assertions: assertions,
        step: step,
      );
      expect(finder, isNotNull);
      expect(finder!.evaluate(), isNotEmpty);
      expect(
        assertions.rectForVisuallyActionable(
          finder,
          requireHitTestable: true,
        ),
        isNotNull,
      );
    },
  );

  testWidgets('stepHighlightFinder still resolves bare id', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ElevatedButton(
            key: const ValueKey('login_btn'),
            onPressed: () {},
            child: const Text('Go'),
          ),
        ),
      ),
    );

    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(
        id: 'highlight_id',
        startScreen: 'Login',
        steps: [],
      ),
    );
    final assertions = AssertionEngine(tester: tester, context: context);
    final finder = stepHighlightFinder(
      tester: tester,
      assertions: assertions,
      step: const TestStep(type: 'tap', args: {'id': 'login_btn'}),
    );
    expect(finder, isNotNull);
    expect(finder!.evaluate(), hasLength(1));
  });

  testWidgets('text-entry target geometry remains available after editing',
      (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextField(
            key: const ValueKey('email_field'),
            controller: controller,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('email_field')));
    await tester.enterText(find.byKey(const ValueKey('email_field')), 'a@b.c');
    await tester.pump();

    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'highlight_text_entry', steps: []),
    );
    final assertions = AssertionEngine(tester: tester, context: context);
    final finder = stepHighlightFinder(
      tester: tester,
      assertions: assertions,
      step: const TestStep(type: 'enterText', args: {'id': 'email_field'}),
    );

    expect(finder, isNotNull);
    final rect = assertions.rectForVisuallyActionable(finder!);
    expect(rect, isNotNull);
    expect(rect!.width,
        tester.getSize(find.byKey(const ValueKey('email_field'))).width);
  });

  test('observer bounds provide a fallback for one visible id target', () {
    final observation = UiObservation(
      observationId: 'snapshot',
      revision: 1,
      timestamp: DateTime.utc(2026),
      screen: const ScreenObservation(name: 'Login', unknown: false),
      elements: [
        UiElement(
          elementId: 'email',
          testId: 'email_field',
          type: 'textInput',
          state: UiElementState(visible: true, offscreen: false),
          bounds: UiBounds(left: 24, top: 175, width: 345, height: 56),
        ),
      ],
      observableFingerprint: '',
    );
    final rect = observedIdHighlightRect(
      step: const TestStep(type: 'enterText', args: {'id': 'email_field'}),
      observation: observation,
    );

    expect(rect, const Rect.fromLTWH(24, 175, 345, 56));
  });

  test('observer bounds refuse ambiguous id targets', () {
    final observation = UiObservation(
      observationId: 'snapshot',
      revision: 1,
      timestamp: DateTime.utc(2026),
      screen: const ScreenObservation(name: 'Login', unknown: false),
      elements: [
        UiElement(
          elementId: 'email-a',
          testId: 'email_field',
          type: 'textInput',
          state: UiElementState(visible: true, offscreen: false),
          bounds: UiBounds(left: 24, top: 175, width: 345, height: 56),
        ),
        UiElement(
          elementId: 'email-b',
          testId: 'email_field',
          type: 'textInput',
          state: UiElementState(visible: true, offscreen: false),
          bounds: UiBounds(left: 24, top: 243, width: 345, height: 56),
        ),
      ],
      observableFingerprint: '',
    );

    expect(
      observedIdHighlightRect(
        step: const TestStep(type: 'enterText', args: {'id': 'email_field'}),
        observation: observation,
      ),
      isNull,
    );
  });

  testWidgets('stepHighlightFinder resolves value and semantics assertions',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextField(
            key: const ValueKey('room_name_input'),
            controller: TextEditingController(),
          ),
        ),
      ),
    );

    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(
        id: 'highlight_value_and_semantics',
        startScreen: 'RoomName',
        steps: [],
      ),
    );
    final assertions = AssertionEngine(tester: tester, context: context);

    for (final step in [
      const TestStep(type: 'expectValue', args: {'id': 'room_name_input'}),
      const TestStep(
        type: 'expectSemanticsLabel',
        args: {'id': 'room_name_input', 'label': 'Room name'},
      ),
    ]) {
      final finder = stepHighlightFinder(
        tester: tester,
        assertions: assertions,
        step: step,
      );
      expect(finder, isNotNull, reason: step.type);
      expect(
        assertions.rectForVisuallyActionable(finder!),
        isNotNull,
        reason: step.type,
      );
    }
  });
}
