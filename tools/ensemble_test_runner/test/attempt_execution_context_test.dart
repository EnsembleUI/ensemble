import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/attempt_execution_context.dart';
import 'package:ensemble_test_runner/src/core/attempt_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creates matching driver and runtime attempt context', () {
    const testCase = EnsembleTestCase(id: 'checkout', steps: []);
    final attempt = AttemptExecutionContext.fromDescriptor(
      attemptId: 'run_checkout_1',
      attempt: const AttemptDescriptor(number: 2, index: 1, total: 3),
      test: testCase,
      config: const EnsembleTestConfig(),
      checkpoint: 'checkpoint',
    );

    expect(attempt.launch.attemptId, 'run_checkout_1');
    expect(attempt.launch.attempt, 1);
    expect(attempt.launch.testCase, same(testCase));
    expect(attempt.launch.checkpoint, 'checkpoint');
    expect(attempt.runtime.testCase, same(testCase));
    expect(attempt.runtime.runtime.attemptNumber, 2);
    expect(attempt.runtime.runtime.attemptCount, 3);
  });

  test('rejects attempt descriptors with inconsistent identity', () {
    expect(
      () => AttemptExecutionContext.fromDescriptor(
        attemptId: 'mismatched',
        attempt: const AttemptDescriptor(number: 2, index: 0, total: 3),
        test: const EnsembleTestCase(id: 'checkout', steps: []),
        config: const EnsembleTestConfig(),
      ),
      throwsArgumentError,
    );
  });

  test('rejects attempt descriptors outside their declared range', () {
    const testCase = EnsembleTestCase(id: 'checkout', steps: []);
    const config = EnsembleTestConfig();
    for (final attempt in [
      const AttemptDescriptor(number: 3, index: 2, total: 2),
      const AttemptDescriptor(number: 0, index: -1, total: 2),
      const AttemptDescriptor(number: 1, index: 0, total: 0),
    ]) {
      expect(
        () => AttemptExecutionContext.fromDescriptor(
          attemptId: 'out-of-range',
          attempt: attempt,
          test: testCase,
          config: config,
        ),
        throwsArgumentError,
      );
    }
  });
}
