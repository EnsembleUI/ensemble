import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'wrapper ID resolves its rendered target for screenshot and tap proof',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: KeyedSubtree(
                key: const ValueKey('target_wrapper'),
                child: ElevatedButton(
                  onPressed: () {},
                  child: const Text('Open item'),
                ),
              ),
            ),
          ),
        ),
      );

      final context = EnsembleTestContext.fromTestCase(
        const EnsembleTestCase(id: 'visibility', startScreen: 'Home', steps: []),
      );
      final assertions = AssertionEngine(tester: tester, context: context);
      final wrapper = assertions.finderForId('target_wrapper');

      expect(wrapper.evaluate(), hasLength(1));
      expect(
        assertions.rectForVisuallyActionable(wrapper),
        isNotNull,
        reason: 'waitFor evidence must highlight a rendered descendant',
      );
      expect(
        assertions.rectForVisuallyActionable(
          wrapper,
          requireHitTestable: true,
        ),
        isNotNull,
        reason: 'tap evidence must highlight the live hit-testable target',
      );
    },
  );

  testWidgets(
    'visually actionable finder ignores covered hit-testable targets',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    width: 200,
                    height: 48,
                    child: ColoredBox(
                      key: ValueKey('target_button'),
                      color: Colors.blue,
                      child: Center(child: Text('Hidden target')),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.white,
                    child: Center(child: Text('Covering screen')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final context = EnsembleTestContext.fromTestCase(
        const EnsembleTestCase(
          id: 'visibility',
          startScreen: 'Home',
          steps: [],
        ),
      );
      final assertions = AssertionEngine(tester: tester, context: context);
      final finder = assertions.finderForId('target_button');

      // Widget is still in the tree with a layout rect at the bottom…
      expect(finder.evaluate(), isNotEmpty);
      expect(tester.getRect(finder.first).bottom, greaterThan(400));

      // …but must not be used for tap screenshot highlights while covered.
      expect(
        assertions.firstVisuallyActionableElement(
          finder,
          requireHitTestable: true,
        ),
        isNull,
      );
      expect(
        assertions.rectForVisuallyActionable(
          finder,
          requireHitTestable: true,
        ),
        isNull,
      );
    },
  );

  testWidgets(
    'visually actionable finder accepts an uncovered target',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 48,
                child: ColoredBox(
                  key: ValueKey('target_button'),
                  color: Colors.blue,
                  child: Center(child: Text('Visible target')),
                ),
              ),
            ),
          ),
        ),
      );

      final context = EnsembleTestContext.fromTestCase(
        const EnsembleTestCase(
          id: 'visibility',
          startScreen: 'Home',
          steps: [],
        ),
      );
      final assertions = AssertionEngine(tester: tester, context: context);
      final finder = assertions.finderForId('target_button');

      expect(
        assertions.firstVisuallyActionableElement(
          finder,
          requireHitTestable: true,
        ),
        isNotNull,
      );
      expect(
        assertions.rectForVisuallyActionable(
          finder,
          requireHitTestable: true,
        ),
        isNotNull,
      );
    },
  );

  testWidgets(
    'expectVisible uses painted bounds, not hit-testability',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: IgnorePointer(
              child:
                  Text('Hello from Ensemble', key: ValueKey('greeting_text')),
            ),
          ),
        ),
      );

      final context = EnsembleTestContext.fromTestCase(
        const EnsembleTestCase(
          id: 'visibility',
          startScreen: 'Home',
          steps: [],
        ),
      );
      final assertions = AssertionEngine(tester: tester, context: context);

      expect(
        find.byKey(const ValueKey('greeting_text')).hitTestable().evaluate(),
        isEmpty,
      );
      assertions.expectVisible('greeting_text');
      expect(
        () => assertions.expectNotVisible('greeting_text'),
        throwsA(isA<EnsembleTestFailure>()),
      );
    },
  );
}
