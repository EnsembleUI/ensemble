import 'package:ensemble/ensemble.dart';
import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/discovery/ensemble_test_execution_planner.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/reporters/test_reporter.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/runner/test_runtime_state.dart';
import 'package:ensemble_test_runner/runner/yaml_test_session.dart';
import 'package:flutter_test/flutter_test.dart';

typedef EnsembleTestRunOutput = ({
  EnsembleSingleTestResult result,
  EnsembleConfig config,
});

class EnsembleTestRunner {
  final EnsembleTestHarness harness;

  EnsembleTestRunner({required this.harness});

  Future<Map<String, EnsembleSingleTestResult>> runPlan(
    EnsembleTestExecutionPlan plan,
    WidgetTester tester,
  ) async {
    final resultsById = <String, EnsembleSingleTestResult>{};
    var config = await harness.buildConfig();

    for (final def in plan.ordered) {
      final test = def.testCase;
      final prereq = test.prerequisite;
      if (prereq != null) {
        final prereqResult = resultsById[prereq];
        if (prereqResult == null) {
          throw EnsembleTestFailure(
            'Internal error: prerequisite "$prereq" for "${test.id}" was not scheduled',
          );
        }
        if (prereqResult.status == TestStatus.failed) {
          resultsById[test.id] = EnsembleSingleTestResult.failed(
            testId: test.id,
            metadata: test.metadataJson,
            error: 'Prerequisite "$prereq" failed',
            durationMs: 0,
            report: buildTestReportDetails(test),
          );
          continue;
        }
      }

      final out = await runOne(
        test,
        tester,
        existingConfig: config,
        continuation: test.hasPrerequisite,
      );
      resultsById[test.id] = out.result;
      config = out.config;
    }

    return resultsById;
  }

  Future<EnsembleTestRunOutput> runOne(
    EnsembleTestCase test,
    WidgetTester tester, {
    EnsembleConfig? existingConfig,
    bool continuation = false,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      final ctx = EnsembleTestContext.fromTestCase(test);
      TestErrorTracker.install(ctx.runtime);

      late final EnsembleConfig config;
      if (continuation) {
        if (!YamlTestSession.runtimeBootstrapped) {
          throw EnsembleTestFailure(
            'Test "${test.id}" has prerequisite "${test.prerequisite}" but the '
            'runtime is not bootstrapped — ensure the prerequisite test runs first',
          );
        }
        EnsembleTestHarness.applyInPlaceSetup(ctx);
        config = existingConfig ?? Ensemble().getConfig()!;
        await EnsembleTestHarness.waitForInitialWidgets(tester, testCase: test);
      } else {
        config = await harness.loadScreen(
          tester: tester,
          testCase: test,
          existingConfig: existingConfig,
          context: ctx,
        );
      }

      final result = await _executeSteps(
        test: test,
        tester: tester,
        ctx: ctx,
        config: config,
        stopwatch: stopwatch,
      );
      return (result: result, config: config);
    } catch (error, stackTrace) {
      final config = existingConfig ?? Ensemble().getConfig();
      return (
        result: EnsembleSingleTestResult.failed(
          testId: test.id,
          metadata: test.metadataJson,
          error: error.toString(),
          stackTrace: stackTrace.toString(),
          durationMs: stopwatch.elapsedMilliseconds,
          report: buildTestReportDetails(test),
        ),
        config: config ?? await harness.buildConfig(),
      );
    } finally {
      TestErrorTracker.reset();
    }
  }

  Future<EnsembleSingleTestResult> _executeSteps({
    required EnsembleTestCase test,
    required WidgetTester tester,
    required EnsembleTestContext ctx,
    required EnsembleConfig config,
    required Stopwatch stopwatch,
  }) async {
    final assertions = AssertionEngine(tester: tester, context: ctx);
    final executor = TestStepExecutor(
      tester: tester,
      context: ctx,
      assertions: assertions,
      harness: harness,
      config: config,
    );

    for (var i = 0; i < test.steps.length; i++) {
      final step = test.steps[i];
      try {
        await executor.execute(step);
      } catch (error, stackTrace) {
        return EnsembleSingleTestResult.failed(
          testId: test.id,
          metadata: test.metadataJson,
          failedStepIndex: i,
          failedStep: step,
          error: error.toString(),
          stackTrace: stackTrace.toString(),
          durationMs: stopwatch.elapsedMilliseconds,
          logs: ctx.logger.logs,
          report: buildTestReportDetails(test),
        );
      }
    }

    return EnsembleSingleTestResult.passed(
      testId: test.id,
      metadata: test.metadataJson,
      durationMs: stopwatch.elapsedMilliseconds,
      logs: ctx.logger.logs,
      report: buildTestReportDetails(test),
    );
  }
}
