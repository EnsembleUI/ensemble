import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:ensemble_test_runner/mocks/test_logger.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:ensemble_test_runner/session/observation/observation_options.dart';
import 'package:ensemble_test_runner/session/observation/observe_formatter.dart';
import 'package:ensemble_test_runner/session/session_capabilities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('observe formatter emits elements from a live session',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Hello', key: ValueKey('greeting')),
          ),
        ),
      ),
    );

    final session = LocalTestExecutionSession.attach(
      tester: tester,
      harness: EnsembleTestHarness(
        appPath: 'unused/',
        appHome: 'Home',
      ),
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(id: 'observe-smoke', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      permissions: SessionPermissions.restrictedUi,
    );

    final observation = await session.observe(
      options: const ObservationOptions(
        synchronization: ObservationSynchronization.immediate,
      ),
    );
    final text = const ObserveFormatter().format(observation);

    expect(observation.elements.map((e) => e.testId), contains('greeting'));
    expect(text, contains('greeting'));
    expect(text, contains('Elements ('));

    await session.close();
  });
}
