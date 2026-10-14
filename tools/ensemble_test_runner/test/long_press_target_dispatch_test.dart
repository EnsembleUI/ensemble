import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'support/test_step_executor_handler_harness.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/session/local/flutter_target_resolver.dart';
import 'package:ensemble_test_runner/session/local/observation_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('registered longPress preserves structured target locators',
      (tester) async {
    var longPresses = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: GestureDetector(
            key: const ValueKey('long_press_target'),
            onLongPress: () => longPresses++,
            child: Container(width: 80, height: 40, color: Colors.blue),
          ),
        ),
      ),
    );

    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'long-press-target-dispatch', steps: []),
    );
    final assertions = AssertionEngine(tester: tester, context: context);
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: assertions,
    );
    final resolver = FlutterTargetResolver(
      tester: tester,
      assertions: assertions,
      registry: ObservationRegistry(),
    );
    executor.resolveTargetFinder = resolver.resolveFinder;

    await executor.execute(
      const TestStep(
        type: 'longPress',
        args: {
          'target': {'id': 'long_press_target'},
        },
      ),
    );

    expect(longPresses, 1);
  });
}
