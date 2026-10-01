import 'package:ensemble_test_runner/actions/test_execution_config.dart';
import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/flutter_error_isolation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'framework diagnostics are logged without poisoning the enclosing test',
      (tester) async {
    var nextCaseRan = false;

    await withFlutterErrorIsolation(() async {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: StateError('app framework diagnostic'),
          library: 'test app',
        ),
      );
      await tester.pump();
    });

    expect(tester.takeException(), isNull);
    // The suite can proceed to its next independent test case.
    nextCaseRan = true;
    expect(nextCaseRan, isTrue);
  });

  testWidgets('framework errors do not fail a step that can run',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('ok'),
        ),
      ),
    );

    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'framework_error_policy', steps: []),
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

    var nextCaseRan = false;
    await withFlutterErrorIsolation(() async {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: StateError('app callback diagnostic'),
          library: 'test app',
        ),
      );
      await executor.execute(
        const TestStep(type: 'wait', args: {'durationMs': 1}),
      );
      // A framework error from this case must not poison a later case.
      nextCaseRan = true;
    });

    expect(context.runtime.flutterErrors, hasLength(1));
    expect(nextCaseRan, isTrue);
    expect(tester.takeException(), isNull);
  });
}
