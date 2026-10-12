import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
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
  testWidgets('structured selectIndex supports application-owned list options',
      (tester) async {
    var expanded = false;
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: Column(
              children: [
                TextButton(
                  key: const ValueKey('select_target'),
                  onPressed: () => setState(() => expanded = true),
                  child: const Text('Choose'),
                ),
                if (expanded) ...[
                  ListTile(
                    title: const Text('First'),
                    onTap: () => setState(() => selected = 'First'),
                  ),
                  ListTile(
                    title: const Text('Second'),
                    onTap: () => setState(() => selected = 'Second'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'select-index-parity', steps: []),
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

    await localActions.execute(
      actionOperation('selectIndex',
          target: const ElementTarget(testId: 'select_target'),
          input: const {'index': 1}),
    );

    expect(selected, 'Second');
  });
}
