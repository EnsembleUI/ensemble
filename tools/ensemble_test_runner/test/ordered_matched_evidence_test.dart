import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'support/test_step_executor_handler_harness.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/session_operation.dart';

void main() {
  testWidgets('authored condition publishes after its match', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('Ready')));
    final executor = _executor(tester);
    final boundaries = <String>[];
    executor.onEvidenceBoundary = (step) => boundaries.add(step.type);

    await executor.execute(const TestStep(
      type: 'wait',
      args: {'durationMs': 0},
    ));

    expect(boundaries, ['condition:wait']);
  });

  testWidgets('session condition publishes through the same boundary',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('Ready')));
    final executor = _executor(tester);
    final boundaries = <String>[];
    executor.onOperationEvidenceBoundary =
        (_, detail) => boundaries.add(detail);

    await executor.executeWaitOperation(sessionOperation(
      'wait',
      input: const {'durationMs': 0},
    ));

    expect(boundaries, ['condition:wait']);
  });

  testWidgets('matched text boundary carries the actual matching text',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('Ready')));
    final executor = _executor(tester);
    final boundaries = <TestStep>[];
    executor.onEvidenceBoundary = boundaries.add;

    await executor.execute(const TestStep(
      type: 'waitForText',
      args: {
        'anyOf': ['Ready', 'Other']
      },
    ));

    expect(boundaries, hasLength(1));
    expect(boundaries.single.type, 'waitForText');
    expect(boundaries.single.args['text'], 'Ready');
    expect(boundaries.single.args.containsKey('anyOf'), isFalse);
  });
}

TestStepExecutor _executor(WidgetTester tester) {
  final context = EnsembleTestContext.fromTestCase(
    const EnsembleTestCase(id: 'ordered_matched_evidence', steps: []),
  );
  return TestStepExecutor(
    tester: tester,
    context: context,
    assertions: AssertionEngine(tester: tester, context: context),
  );
}
