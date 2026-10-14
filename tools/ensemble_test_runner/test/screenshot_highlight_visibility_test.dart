import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
