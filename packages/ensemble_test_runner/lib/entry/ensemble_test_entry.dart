import 'package:ensemble_test_runner/discovery/ensemble_test_execution_planner.dart';
import 'package:ensemble_test_runner/ensemble_test_runner.dart';
import 'package:ensemble_test_runner/runner/test_runtime_state.dart';
import 'package:ensemble_test_runner/runner/yaml_test_session.dart';
import 'package:flutter_test/flutter_test.dart';

/// Flutter test entry: discovers app-local `tests/*.test.yaml` and runs them.
void runEnsembleYamlTests() {
  EnsembleTestHarness.ensureTestPlugins();
  tearDown(() {
    TestErrorTracker.reset();
    EnsembleTestHarness.resetTestRuntime();
    YamlTestSession.dispose();
  });

  testWidgets(
    'Ensemble app *.test.yaml',
    (tester) async {
      final target = await EnsembleTestDiscovery.loadAppTarget();
      final plan = await EnsembleTestExecutionPlanner.build(target: target);
      final harness = EnsembleTestHarness(
        appPath: target.appPath,
        appHome: target.appHome,
        i18nPath: target.i18nPath,
      );

      final runner = EnsembleTestRunner(harness: harness);
      final resultsById = await runner.runPlan(plan, tester);

      final failures = <String>[];
      final orderedResults = <EnsembleSingleTestResult>[];

      for (final def in plan.ordered) {
        final result = resultsById[def.testCase.id]!;
        orderedResults.add(
          EnsembleSingleTestResult(
            testId: '${result.testId}  (${def.assetPath})',
            status: result.status,
            durationMs: result.durationMs,
            failedStepIndex: result.failedStepIndex,
            failedStep: result.failedStep,
            message: result.message,
            stackTrace: result.stackTrace,
            logs: result.logs,
            report: result.report,
          ),
        );

        if (result.status == TestStatus.failed) {
          failures.add(def.assetPath);
        }
      }

      final suiteSummary = TestReporter().formatSummary(
        EnsembleTestRunResult(results: orderedResults),
        testFile: '${target.testsAssetPrefix}*.test.yaml',
      );
      print(suiteSummary);

      if (failures.isNotEmpty) {
        fail(
          'Failed YAML tests:\n'
          '${failures.map((p) => '- $p').join('\n')}\n\n'
          '$suiteSummary',
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
