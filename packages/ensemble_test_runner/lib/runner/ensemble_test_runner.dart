import 'package:ensemble/ensemble.dart';
import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/debug/agent_debug_log.dart';
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
    // #region agent log
    agentDebugLog('H2', 'runner/ensemble_test_runner.dart:29',
        'runPlan before initial buildConfig', {
      'testCount': plan.ordered.length,
      'tests': plan.ordered.map((def) => def.testCase.id).toList(),
    });
    // #endregion
    var config = await harness.buildConfig();
    // #region agent log
    agentDebugLog('H2', 'runner/ensemble_test_runner.dart:35',
        'runPlan after initial buildConfig', {});
    // #endregion

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
      // #region agent log
      agentDebugLog(
          'H5', 'runner/ensemble_test_runner.dart:82', 'runOne start', {
        'testId': test.id,
        'startScreen': test.startScreen,
        'prerequisite': test.prerequisite,
        'continuation': continuation,
        'stepCount': test.steps.length,
        'firstStep': test.steps.isEmpty ? null : test.steps.first.type,
      });
      // #endregion
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
        // #region agent log
        agentDebugLog(
            'H5', 'runner/ensemble_test_runner.dart:160', 'executing step', {
          'testId': test.id,
          'stepIndex': i,
          'stepType': step.type,
          'args':
              step.args.map((key, value) => MapEntry(key, value?.toString())),
        });
        // #endregion
        await executor.execute(step);
        // #region agent log
        agentDebugLog(
            'H7', 'runner/ensemble_test_runner.dart:170', 'step completed', {
          'testId': test.id,
          'stepIndex': i,
          'stepType': step.type,
        });
        // #endregion
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

    // #region agent log
    agentDebugLog('H8', 'runner/ensemble_test_runner.dart:188',
        'all steps complete before passed result report', {
      'testId': test.id,
      'durationMs': stopwatch.elapsedMilliseconds,
    });
    // #endregion
    return EnsembleSingleTestResult.passed(
      testId: test.id,
      metadata: test.metadataJson,
      durationMs: stopwatch.elapsedMilliseconds,
      logs: ctx.logger.logs,
      report: buildTestReportDetails(test),
    );
  }
}
