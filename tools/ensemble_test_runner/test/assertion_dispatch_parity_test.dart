import 'support/test_step_executor_handler_harness.dart';
import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:ensemble_test_runner/mocks/test_logger.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:ensemble_test_runner/session/operation_result.dart'
    show AssertionStatus;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/session_operation.dart';

void main() {
  testWidgets(
      'exists assertions preserve tree-presence semantics on both routes',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Text('Retained', key: ValueKey('retained-widget')),
    ));
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      harness: EnsembleTestHarness(appPath: 'unused/', appHome: 'Home'),
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(id: 'assertion-parity', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
    );

    await session.executor.execute(
      const TestStep(type: 'expectExists', args: {'id': 'retained-widget'}),
    );
    final present = await session.assertCondition(
      sessionOperation('expectExists', input: const {'id': 'retained-widget'}),
    );
    expect(present.status, AssertionStatus.passed);

    String? rawFailureMessage;
    try {
      await session.executor.execute(
        const TestStep(
          type: 'expectNotExists',
          args: {'id': 'retained-widget'},
        ),
      );
    } on EnsembleTestFailure catch (error) {
      rawFailureMessage = error.message;
    }
    expect(rawFailureMessage, 'Expected resolved element to not exist.');
    final notPresent = await session.assertCondition(
      sessionOperation(
        'expectNotExists',
        input: const {'id': 'retained-widget'},
      ),
    );
    expect(notPresent.status, AssertionStatus.failed);
    expect(notPresent.message, rawFailureMessage);

    await session.executor.execute(
      const TestStep(type: 'expectNotExists', args: {'id': 'missing-widget'}),
    );
    final missing = await session.assertCondition(
      sessionOperation('expectNotExists',
          input: const {'id': 'missing-widget'}),
    );
    expect(missing.status, AssertionStatus.passed);

    await session.executor.execute(
      const TestStep(type: 'expectNotVisible', args: {'id': 'missing-widget'}),
    );
    final notVisible = await session.assertCondition(
      sessionOperation(
        'expectNotVisible',
        input: const {'id': 'missing-widget'},
      ),
    );
    expect(notVisible.status, AssertionStatus.passed);

    await session.close();
  });
}
