import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/setup_step_executor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const executor = SetupStepExecutor();

  test('attempt setup keeps adapter hooks around the shared step stage',
      () async {
    final events = <String>[];
    await executor.executeAttemptSetup(
      const EnsembleTestCase(id: 'setup-order', steps: []),
      beforeSteps: () async => events.add('before'),
      afterSteps: () async => events.add('after'),
    );

    expect(events, ['before', 'after']);
  });

  test('attempt setup does not run its after hook when setup fails', () async {
    final events = <String>[];
    await expectLater(
      executor.executeAttemptSetup(
        const EnsembleTestCase(
          id: 'setup-failure',
          steps: [],
          setupSteps: [TestStep(type: 'unsupported', args: {})],
        ),
        beforeSteps: () async => events.add('before'),
        afterSteps: () async => events.add('after'),
      ),
      throwsA(isA<EnsembleTestFailure>()),
    );

    expect(events, ['before']);
  });

  test('runs nested empty groups', () async {
    const testCase = EnsembleTestCase(
      id: 'setup',
      steps: [],
      setupSteps: [
        TestStep(type: 'group', args: {}, nestedSteps: [
          TestStep(type: 'group', args: {}),
        ]),
      ],
    );

    await executor.execute(testCase);
  });

  test('optional setup contains failures', () async {
    const testCase = EnsembleTestCase(
      id: 'setup',
      steps: [],
      setupSteps: [
        TestStep(type: 'optional', args: {}, nestedSteps: [
          TestStep(type: 'unsupported', args: {}),
        ]),
      ],
    );

    await executor.execute(testCase);
  });

  test('reports unsupported required setup actions with position', () async {
    const testCase = EnsembleTestCase(
      id: 'setup',
      steps: [],
      setupSteps: [TestStep(type: 'unsupported', args: {})],
    );

    await expectLater(
      executor.execute(testCase),
      throwsA(
        isA<EnsembleTestFailure>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('Setup 1'),
            contains('Unsupported setup action "unsupported"'),
          ),
        ),
      ),
    );
  });
}
