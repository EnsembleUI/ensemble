import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'support/test_step_executor_handler_harness.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('trigger actions preserve action and evidence ordering', (
    tester,
  ) async {
    final events = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ElevatedButton(
              key: const ValueKey('trigger_tap'),
              onPressed: () => events.add('tap'),
              child: const Text('Tap'),
            ),
            ElevatedButton(
              key: const ValueKey('trigger_long_press'),
              onPressed: () {},
              onLongPress: () => events.add('longPress'),
              child: const Text('Long press'),
            ),
          ],
        ),
      ),
    ));
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'trigger_dispatch', steps: []),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
    );
    executor.onEvidenceBoundary = (step) {
      events.add('evidence:${step.type}');
    };

    await executor.execute(const TestStep(
      type: 'trigger',
      args: {'action': 'onTap', 'id': 'trigger_tap'},
    ));
    await executor.execute(const TestStep(
      type: 'trigger',
      args: {'action': 'onLongPress', 'id': 'trigger_long_press'},
    ));

    expect(events, [
      'evidence:trigger',
      'tap',
      'evidence:trigger',
      'longPress',
    ]);
  });

  testWidgets('trigger dispatch preserves unsupported-action errors', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'trigger_unknown', steps: []),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
    );

    await expectLater(
      executor.execute(const TestStep(
        type: 'trigger',
        args: {'action': 'onSwipe'},
      )),
      throwsA(isA<EnsembleTestFailure>().having(
        (failure) => failure.message,
        'message',
        'Unsupported trigger action: onSwipe',
      )),
    );
  });
}
