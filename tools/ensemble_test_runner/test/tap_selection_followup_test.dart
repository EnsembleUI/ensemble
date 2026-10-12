import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'support/test_step_executor_handler_harness.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tap selection renders the following action target',
      (tester) async {
    var selected = false;
    var proceeded = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Column(
            children: [
              ElevatedButton(
                key: const ValueKey('qos_device_AA:BB:CC:DD:EE:01'),
                onPressed: () => setState(() => selected = true),
                child: const Text('device'),
              ),
              if (selected)
                ElevatedButton(
                  key: const ValueKey('qos_select_devices_proceed_button'),
                  onPressed: () => proceeded = true,
                  child: const Text('proceed'),
                ),
            ],
          ),
        ),
      ),
    );
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'tap-selection-followup', steps: []),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
    );

    await executor.execute(const TestStep(
      type: 'tap',
      args: {'id': 'qos_device_AA:BB:CC:DD:EE:01', 'timeoutMs': 500},
    ));
    expect(selected, isTrue);
    expect(find.byKey(const ValueKey('qos_select_devices_proceed_button')),
        findsOneWidget);

    await executor.execute(const TestStep(
      type: 'tap',
      args: {'id': 'qos_select_devices_proceed_button', 'timeoutMs': 500},
    ));
    expect(proceeded, isTrue);
  });
}
