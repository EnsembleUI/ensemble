import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/reporters/test_reporter.dart';
import 'package:ensemble_test_runner/runner/attempt_execution_context.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/runner/live_async_call.dart';
import 'package:ensemble_test_runner/runner/test_session.dart';
import 'package:ensemble_test_runner/src/core/attempt_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('contexts without an injected recorder do not share suite state', () {
    const testCase = EnsembleTestCase(id: 'isolated-context', steps: []);

    final first = EnsembleTestContext.fromTestCase(testCase);
    final second = EnsembleTestContext.fromTestCase(testCase);
    first.navigationFlow.seed(['First']);

    expect(first.navigationFlow, isNot(same(second.navigationFlow)));
    expect(second.navigationFlow.flow, isEmpty);
  });

  testWidgets('attempt runtime reset clears only its recorder', (
    tester,
  ) async {
    final attempt = AttemptExecutionContext.fromDescriptor(
      attemptId: 'navigation-reset',
      attempt: const AttemptDescriptor(number: 1, index: 0, total: 1),
      test: const EnsembleTestCase(id: 'reset', steps: []),
      config: const EnsembleTestConfig(),
    );
    final unrelated = NavigationFlowRecorder()..seed(['Unrelated']);
    attempt.runtime.navigationFlow.seed(['Attempt', 'Next']);
    Future<T?> runner<T>(Future<T> Function() callback) => callback();
    LiveAsyncCallSupport.runner = runner;
    LiveAsyncCallSupport.platformHttpRunner = runner;

    EnsembleTestHarness.resetTestRuntime(
      navigationFlow: attempt.runtime.navigationFlow,
    );

    expect(unrelated.flow, ['Unrelated']);
    expect(attempt.runtime.navigationFlow.flow, isEmpty);
    expect(LiveAsyncCallSupport.runner, isNull);
    expect(LiveAsyncCallSupport.platformHttpRunner, isNull);
  });

  testWidgets('harness runtime reset targets only the active attempt', (
    tester,
  ) async {
    final attempt = AttemptExecutionContext.fromDescriptor(
      attemptId: 'navigation-harness-reset',
      attempt: const AttemptDescriptor(number: 1, index: 0, total: 1),
      test: const EnsembleTestCase(id: 'reset', steps: []),
      config: const EnsembleTestConfig(),
    );
    final unrelated = NavigationFlowRecorder()..seed(['Unrelated']);
    attempt.runtime.navigationFlow.seed(['Attempt', 'Next']);

    EnsembleTestHarness.resetTestRuntime(
      navigationFlow: attempt.runtime.navigationFlow,
    );

    expect(unrelated.flow, ['Unrelated']);
    expect(attempt.runtime.navigationFlow.flow, isEmpty);
  });

  testWidgets('attempt navigation listener stops within bounded cleanup', (
    tester,
  ) async {
    final attempt = AttemptExecutionContext.fromDescriptor(
      attemptId: 'navigation-cleanup',
      attempt: const AttemptDescriptor(number: 1, index: 0, total: 1),
      test: const EnsembleTestCase(id: 'cleanup', steps: []),
      config: const EnsembleTestConfig(),
    );
    await attempt.runtime.navigationFlow.startListeningWhenReady();

    await tester.runAsync(
      () => attempt.runtime.navigationFlow
          .stopListening()
          .timeout(const Duration(seconds: 1)),
    );
  });

  test('attempt navigation history is isolated and reportable', () {
    const testCase = EnsembleTestCase(
      id: 'navigation',
      startScreen: 'Home',
      steps: [],
    );
    final first = AttemptExecutionContext.fromDescriptor(
      attemptId: 'navigation-1',
      attempt: const AttemptDescriptor(number: 1, index: 0, total: 2),
      test: testCase,
      config: const EnsembleTestConfig(),
    );
    final second = AttemptExecutionContext.fromDescriptor(
      attemptId: 'navigation-2',
      attempt: const AttemptDescriptor(number: 2, index: 1, total: 2),
      test: testCase,
      config: const EnsembleTestConfig(),
    );

    first.runtime.navigationFlow.seed(['Home', 'Devices']);
    second.runtime.navigationFlow.seed(['Home', 'Settings']);

    expect(first.runtime.navigationFlow,
        isNot(same(second.runtime.navigationFlow)));
    expect(
      buildTestReportDetails(
        testCase,
        navigationFlow: first.runtime.navigationFlow,
      ).screensVisited,
      ['Home', 'Devices'],
    );
    expect(
      buildTestReportDetails(
        testCase,
        navigationFlow: second.runtime.navigationFlow,
      ).screensVisited,
      ['Home', 'Settings'],
    );
  });
}
