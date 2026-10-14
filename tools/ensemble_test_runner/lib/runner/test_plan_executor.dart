import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:ensemble_test_runner/discovery/ensemble_test_execution_planner.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/app_session_snapshot.dart';
import 'package:ensemble_test_runner/runner/emergency_failure_screenshot.dart';
import 'package:ensemble_test_runner/runner/retry_execution.dart';
import 'package:ensemble_test_runner/runner/suite_case_coordinator.dart';
import 'package:ensemble_test_runner/runner/test_session.dart';
import 'package:ensemble_test_runner/reporters/test_reporter.dart';
import 'package:ensemble_test_runner/src/runtime/compiled_plan.dart';

/// Executes the ordered cases in a compiled suite plan.
///
/// This boundary owns suite ordering, session snapshot reuse, failure
/// containment, and progress publication. The runner supplies the attempt
/// implementation, so planning does not know how an individual test is
/// launched or executed.
typedef PlannedTestRunner = Future<EnsembleTestRunOutput> Function(
  EnsembleTestCase test,
  WidgetTester tester, {
  required EnsembleTestConfig suiteConfig,
  AppSessionSnapshot? sessionSnapshot,
  CompiledPlanReuse? planReuse,
});

typedef TestPlanProgressListener = FutureOr<void> Function(
  EnsembleTestDefinition definition,
  EnsembleSingleTestResult result,
);

typedef TestPlanStartListener = FutureOr<void> Function(
  EnsembleTestDefinition definition,
);

final class EnsembleTestPlanRunResult {
  final Map<String, EnsembleSingleTestResult> resultsById;
  final List<String> suiteLogs;

  const EnsembleTestPlanRunResult({
    required this.resultsById,
    this.suiteLogs = const [],
  });
}

final class TestPlanExecutor {
  const TestPlanExecutor({required this.runTest});

  final PlannedTestRunner runTest;

  Future<EnsembleTestPlanRunResult> execute(
    EnsembleTestExecutionPlan plan,
    WidgetTester tester, {
    TestPlanStartListener? onTestStart,
    TestPlanProgressListener? onTestComplete,
    Map<String, String> serializedPlans = const {},
  }) async {
    final result =
        await const SuiteCaseCoordinator<AppSessionSnapshot>().execute(
      plan,
      serializedPlans: serializedPlans,
      onCaseStart: onTestStart == null
          ? null
          : (definition) async => await onTestStart(definition),
      onCaseComplete: onTestComplete == null
          ? null
          : (definition, result) async =>
              await onTestComplete(definition, result),
      runCase: ({
        required test,
        required checkpoint,
        required planReuse,
        required onCheckpoint,
      }) async {
        final output = await runTest(
          test,
          tester,
          suiteConfig: plan.config,
          sessionSnapshot: checkpoint,
          planReuse: planReuse,
        );
        return output.result;
      },
      captureCheckpoint: (_) => AppSessionSnapshot.capture(),
      onCaseFailure: (
        EnsembleTestCase test,
        Object error,
        StackTrace stackTrace,
      ) async {
        var logs = <String>[];
        try {
          logs = await writeEmergencyFailureScreenshot(
            tester: tester,
            test: test,
            config: plan.config,
            error: error,
          );
        } catch (captureError) {
          logs.add('Emergency failure screenshot failed: $captureError');
        }
        return EnsembleSingleTestResult.failed(
          testId: test.id,
          metadata: test.metadataJson,
          message: error.toString(),
          stackTrace: stackTrace.toString(),
          durationMs: 0,
          logs: logs,
          report: buildTestReportDetails(
            test,
            navigationFlow: NavigationFlowRecorder(),
          ),
        );
      },
    );
    return EnsembleTestPlanRunResult(
      resultsById: result.resultsById,
      suiteLogs: result.suiteLogs,
    );
  }
}
