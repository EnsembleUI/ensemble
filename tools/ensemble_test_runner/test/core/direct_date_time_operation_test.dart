import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:ensemble_test_runner/mocks/test_logger.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/test_bootstrap.dart';
import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:ensemble_test_runner/session/operation_target.dart';
import 'package:ensemble_test_runner/session/session_capabilities.dart';
import 'package:ensemble_test_runner/src/runtime/flutter_test_runtime.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/session_operation.dart';

void main() {
  testWidgets('date and time values dispatch directly', (tester) async {
    final dateController = TextEditingController(text: '2020-01-01');
    final timeController = TextEditingController(text: '08:00');
    addTearDown(dateController.dispose);
    addTearDown(timeController.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            TextField(
              key: const ValueKey('date_target'),
              controller: dateController,
            ),
            TextField(
              key: const ValueKey('time_target'),
              controller: timeController,
            ),
          ],
        ),
      ),
    ));

    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(id: 'direct-date-time', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      permissions: SessionPermissions.testController,
    );
    final runtime = FlutterTestRuntime(session);
    final evidence = <String>[];
    runtime.bindEvidenceBoundaryEmitter((_, operation) {
      evidence.add('$operation:${dateController.text}:${timeController.text}');
    });

    final date = await runtime.execute(sessionOperation(
      'chooseDate',
      input: const {'id': 'date_target', 'value': '2030-05-06'},
    ));
    expect(date.succeeded, isTrue, reason: date.error);
    expect(dateController.text, '2030-05-06');

    final time = await runtime.execute(actionOperation(
      'chooseTime',
      target: const ElementTarget(testId: 'time_target'),
      input: const {'value': '09:30'},
    ));
    expect(time.succeeded, isTrue, reason: time.error);
    expect(timeController.text, '09:30');
    expect(
      evidence,
      ['chooseDate:2020-01-01:08:00', 'chooseTime:2030-05-06:08:00'],
    );

    await runtime.close();
  });
}
