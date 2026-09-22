import 'package:ensemble_test_runner/actions/test_execution_config.dart';
import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:ensemble_test_runner/mocks/test_logger.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('wait/tap pumps fail fast on recorded flutterErrors',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('ok'),
        ),
      ),
    );

    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'fail_fast', steps: []),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      executionConfig: const TestExecutionConfig(
        waitPollInterval: Duration(milliseconds: 10),
        defaultWaitTimeout: Duration(seconds: 5),
      ),
    );

    context.runtime.flutterErrors.add(
      'during a scheduler callback: Tried to build dirty widget in the wrong build scope.',
    );

    expect(
      () => executor.execute(
        const TestStep(
          type: 'waitFor',
          args: {'id': 'missing', 'timeoutMs': 5000},
        ),
      ),
      throwsA(
        isA<EnsembleTestFailure>().having(
          (e) => e.toString(),
          'message',
          contains('Unexpected Flutter framework error during waitFor'),
        ),
      ),
    );
  });
}
