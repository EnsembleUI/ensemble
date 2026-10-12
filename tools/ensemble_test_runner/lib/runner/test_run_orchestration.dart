import 'package:flutter_test/flutter_test.dart';

import 'package:ensemble_test_runner/application/application_test_driver.dart';
import 'package:ensemble_test_runner/runner/test_plan_executor.dart';
import 'package:ensemble_test_runner/runner/suite_case_coordinator.dart';
import 'package:ensemble_test_runner/entry/application_test_entry.dart';
import 'package:ensemble_test_runner/discovery/ensemble_test_execution_planner.dart';

/// Coordinates suite-level dispatch and retry policy without owning runtime
/// state. The runner supplies the execution callback for each attempt.
final class TestRunOrchestration {
  const TestRunOrchestration();

  Future<EnsembleTestPlanRunResult> runApplicationPlan({
    required ApplicationTestDriver driver,
    required EnsembleTestExecutionPlan plan,
    required WidgetTester tester,
    required Map<String, String> serializedPlans,
    SuiteCaseStart? onTestStart,
    TestPlanProgressListener? onTestComplete,
  }) async {
    final result = await runApplicationTestPlan(
      driver: driver,
      plan: plan,
      tester: tester,
      mode: plan.config.mode,
      serializedPlans: serializedPlans,
      onTestStart: onTestStart,
      onTestComplete: onTestComplete,
    );
    final byId = {for (final item in result.results) item.testId: item};
    return EnsembleTestPlanRunResult(
      resultsById: byId,
      suiteLogs: result.suiteLogs,
    );
  }
}
