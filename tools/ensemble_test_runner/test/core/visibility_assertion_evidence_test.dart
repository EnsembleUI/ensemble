import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import '../support/test_step_executor_handler_harness.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'visibility assertions publish ordered condition evidence after dispatch',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Text('shown', key: ValueKey('shown')),
              Offstage(
                offstage: true,
                child: Text('hidden', key: ValueKey('hidden')),
              ),
            ],
          ),
        ),
      ),
    );
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'visibility-dispatch', steps: []),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      harness: EnsembleTestHarness(appPath: 'ensemble/apps/', appHome: 'Home'),
    );
    final matched = <String>[];
    executor.onEvidenceBoundary = (step) => matched.add(step.type);

    await executor.execute(
      const TestStep(type: 'expectVisible', args: {'id': 'shown'}),
    );
    await executor.execute(
      const TestStep(type: 'expectNotVisible', args: {'id': 'hidden'}),
    );

    expect(matched, [
      'condition:expectVisible',
      'condition:expectNotVisible',
    ]);
  });
}
