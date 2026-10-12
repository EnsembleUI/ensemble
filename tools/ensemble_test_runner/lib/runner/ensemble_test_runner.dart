import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/screen_tracker.dart';
import 'package:ensemble_test_runner/application/application_test_driver.dart';
import 'package:ensemble_test_runner/application/application_suite_execution_boundary.dart';
import 'package:ensemble_test_runner/application/standalone_ensemble_test_driver.dart';
import 'package:ensemble_test_runner/discovery/ensemble_test_execution_planner.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/mocks/wifi_test_setup.dart';
import 'package:ensemble_test_runner/reporters/test_reporter.dart';
import 'package:ensemble_test_runner/runner/app_session_snapshot.dart';
import 'package:ensemble_test_runner/runner/emergency_failure_screenshot.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/event_driven_settler.dart';
import 'package:ensemble_test_runner/runner/flutter_error_isolation.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/runner/screenshot_sheet_aggregator.dart';
import 'package:ensemble_test_runner/runner/setup_step_executor.dart';
import 'package:ensemble_test_runner/runner/step_policy.dart';
import 'package:ensemble_test_runner/runner/step_report_capture.dart';
import 'package:ensemble_test_runner/runner/storage_step_diff.dart';
import 'package:ensemble_test_runner/runner/test_artifact_coordinator.dart';
import 'package:ensemble_test_runner/runner/test_plan_executor.dart';
import 'package:ensemble_test_runner/runner/test_service_manager.dart';
import 'package:ensemble_test_runner/runner/test_run_orchestration.dart';
import 'package:ensemble_test_runner/runner/test_session.dart';
import 'package:ensemble_test_runner/runner/test_runtime_state.dart';
import 'package:ensemble_test_runner/runner/test_visual_artifacts.dart';
import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:ensemble_test_runner/runner/retry_execution.dart';
import 'package:ensemble_test_runner/runner/attempt_lifecycle_coordinator.dart';
import 'package:ensemble_test_runner/src/runtime/compiled_plan.dart';
import 'package:ensemble_test_runner/src/core/kernel.dart';
import 'package:ensemble_test_runner/src/core/operation.dart';
import 'package:ensemble_test_runner/src/core/execution_kernel_runner.dart';
import 'package:ensemble_test_runner/src/core/step_timing_subscriber.dart';
import 'package:ensemble_test_runner/src/core/step_performance_subscriber.dart';
import 'package:ensemble_test_runner/src/core/attempt_artifact_subscriber.dart';
import 'package:ensemble_test_runner/src/core/attempt_coordinator.dart';
import 'package:ensemble_test_runner/src/core/step_context_subscriber.dart';
import 'package:ensemble_test_runner/src/core/step_boundary_subscriber.dart';
import 'package:ensemble_test_runner/src/runtime/step_evidence_subscriber.dart';
import 'package:ensemble_test_runner/src/runtime/step_evidence_policy.dart';
import 'package:ensemble_test_runner/src/runtime/flutter_test_runtime.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

export 'retry_execution.dart' show EnsembleTestRunOutput;
export 'test_plan_executor.dart' show EnsembleTestPlanRunResult;

part 'ensemble_test_runner_steps.dart';

typedef EnsembleTestProgressListener = FutureOr<void> Function(
  EnsembleTestDefinition definition,
  EnsembleSingleTestResult result,
);

int? _stepIndexFromSource(SourceLocation? source) {
  final stepPath = source?.stepPath;
  if (stepPath == null) return null;
  final match = RegExp(r'^steps\[(\d+)\]').firstMatch(stepPath);
  return match == null ? null : int.tryParse(match.group(1)!);
}

final class _ActiveStep {
  _ActiveStep({
    required this.index,
    required this.startFrame,
    required this.startTime,
  });

  final int index;
  final int startFrame;
  final DateTime startTime;
  bool durationRecorded = false;
}

/// Executes parsed Ensemble test plans against a widget tester.
class EnsembleTestRunner {
  /// Harness used to boot and reset the real Ensemble runtime.
  final EnsembleTestHarness? _harness;
  final ApplicationTestDriver? _applicationDriver;
  final StandaloneEnsembleTestDriver? _standaloneDriver;
  ScreenshotSheetAggregator? _activeScreenshotSheets;
  final _artifactCoordinator = const TestArtifactCoordinator();
  TestVisualArtifacts? _visualArtifacts;

  TestVisualArtifacts get _visuals => _visualArtifacts ??= TestVisualArtifacts(
        screenshotSheets: () => _activeScreenshotSheets,
        drainFlutterExceptions: _drainFlutterExceptions,
      );

  /// Creates a runner backed by [harness].
  EnsembleTestRunner({required EnsembleTestHarness harness})
      : _harness = harness,
        _applicationDriver = null,
        _standaloneDriver = StandaloneEnsembleTestDriver(harness: harness);

  /// Creates a runner backed by an application-owned lifecycle.
  EnsembleTestRunner.application({required ApplicationTestDriver driver})
      : _harness = null,
        _applicationDriver = driver,
        _standaloneDriver = null;

  EnsembleTestHarness get harness {
    final value = _harness;
    if (value == null) {
      throw StateError(
          'This runner uses an ApplicationTestDriver, not a harness.');
    }
    return value;
  }

  StandaloneEnsembleTestDriver get standaloneDriver {
    final value = _standaloneDriver;
    if (value == null) {
      throw StateError('This runner has no standalone Ensemble driver.');
    }
    return value;
  }

  /// Runs every test in [plan] and returns results keyed by test id.
  ///
  /// [serializedPlans] is an optional scheduler hand-off keyed by test id.
  /// When present, standalone execution validates and reuses those compiled
  /// graphs; missing entries retain the existing compiler path. The map is
  /// deliberately explicit so callers cannot silently mix a plan with a
  /// different selected test.
  Future<EnsembleTestPlanRunResult> runPlan(
    EnsembleTestExecutionPlan plan,
    WidgetTester tester, {
    TestPlanStartListener? onTestStart,
    EnsembleTestProgressListener? onTestComplete,
    Map<String, String> serializedPlans = const {},
  }) {
    return withFlutterErrorIsolation(() async {
      try {
        return await _runPlanIsolated(
          plan,
          tester,
          onTestStart: onTestStart,
          onTestComplete: onTestComplete,
          serializedPlans: serializedPlans,
        );
      } catch (error, stackTrace) {
        // Infrastructure and orchestration errors still produce a complete
        // result set, so the report and the remaining suite lifecycle survive.
        return EnsembleTestPlanRunResult(
          resultsById: {
            for (final definition in plan.ordered)
              definition.testCase.id: EnsembleSingleTestResult.failed(
                testId: definition.testCase.id,
                metadata: definition.testCase.metadataJson,
                durationMs: 0,
                message: 'Test plan could not execute this case: $error',
                stackTrace: stackTrace.toString(),
                report: buildTestReportDetails(
                  definition.testCase,
                  navigationFlow: NavigationFlowRecorder(),
                ),
              ),
          },
          suiteLogs: ['Test plan orchestration failed: $error'],
        );
      }
    });
  }

  Future<EnsembleTestPlanRunResult> _runPlanIsolated(
    EnsembleTestExecutionPlan plan,
    WidgetTester tester, {
    TestPlanStartListener? onTestStart,
    EnsembleTestProgressListener? onTestComplete,
    Map<String, String> serializedPlans = const {},
  }) async {
    final applicationDriver = _applicationDriver;
    if (applicationDriver != null) {
      return const TestRunOrchestration().runApplicationPlan(
        driver: applicationDriver,
        plan: plan,
        tester: tester,
        serializedPlans: serializedPlans,
        onTestStart: onTestStart,
        onTestComplete: onTestComplete,
      );
    }
    const hostOwnsServices = bool.fromEnvironment(
      'ensembleTestHostOwnsServices',
    );
    final services = TestServiceManager(
      hostOwnsServices ? const [] : plan.config.services,
    );
    final suiteContext = TestSuiteContext(
      runId: 'run_${DateTime.now().microsecondsSinceEpoch}',
      config: plan.config,
      launchKind: TestApplicationLaunchKind.standaloneEnsemble,
    );
    return const ApplicationSuiteExecutionBoundary().run(
      tester: tester,
      services: services,
      driver: standaloneDriver,
      context: suiteContext,
      execute: (registerCleanup) async {
        _activeScreenshotSheets = ScreenshotSheetAggregator(
          screenshots: plan.config.screenshots,
          devices: plan.config.devices,
        );
        registerCleanup(() async {
          await _activeScreenshotSheets?.flushRemaining();
          _activeScreenshotSheets = null;
        });
        return TestPlanExecutor(
          runTest: _runOneWithRetries,
        ).execute(
          plan,
          tester,
          onTestStart: onTestStart,
          onTestComplete: onTestComplete,
          serializedPlans: serializedPlans,
        );
      },
    );
  }

  Future<EnsembleTestRunOutput> _runOneForAttempt(
    EnsembleTestCase test,
    WidgetTester tester, {
    required EnsembleTestConfig suiteConfig,
    required AttemptDescriptor attempt,
    EnsembleConfig? existingConfig,
    AppSessionSnapshot? sessionSnapshot,
    CompiledPlanReuse? planReuse,
  }) async {
    final stopwatch = Stopwatch()..start();
    final lifecycle = AttemptLifecycleCoordinator.forAttempt(
      attemptId: '${test.id}_${stopwatch.elapsedMicroseconds}',
      attempt: attempt,
      test: test,
      config: suiteConfig,
      tester: tester,
    );
    final attemptContext = lifecycle.attemptContext;
    final launchContext = attemptContext.launch;
    final ctx = attemptContext.runtime;
    void Function(List<ui.FrameTiming>)? timingsCallback;
    var attemptCloseFailures =
        const <({Object error, StackTrace stackTrace})>[];
    final markTimingsStarted = lifecycle.registerCleanupAfterStart(() async {
      final callback = timingsCallback;
      if (callback != null) {
        SchedulerBinding.instance.removeTimingsCallback(callback);
      }
    });
    try {
      final outcome = await lifecycle.runCaptured<
          ({int startFrame, DateTime startTime}),
          EnsembleConfig,
          EnsembleTestRunOutput>(
        prepare: () async {
          applyWifiTestConfig(suiteConfig.wifi);
          timingsCallback = (List<ui.FrameTiming> timings) {
            ctx.runtime.addFrameTimings(timings);
          };
          SchedulerBinding.instance.addTimingsCallback(timingsCallback!);
          markTimingsStarted();

          return (
            startFrame: ctx.runtime.appFrameTimings.length + 1,
            startTime: DateTime.now(),
          );
        },
        launch: (startup) async {
          await standaloneDriver.prepareTest(launchContext);

          final config = await harness.loadScreen(
            tester: tester,
            testCase: test,
            existingConfig: existingConfig,
            context: ctx,
            suiteConfig: suiteConfig,
            beforeBootstrap: () =>
                const SetupStepExecutor().executeAttemptSetup(
              test,
              beforeSteps: sessionSnapshot?.restore,
            ),
            forcedLocale: sessionSnapshot?.locale ?? ctx.runtime.locale,
          );
          _drainFlutterExceptions(tester);
          _recordPerformanceMarker(
            ctx: ctx,
            testId: test.id,
            stepIndex: null,
            label: '${test.id} startup',
            phase: 'startup',
            startFrame: startup.startFrame,
            startTime: startup.startTime,
          );
          return config;
        },
        execute: (_, config) async {
          final result = await _executeSteps(
            test: test,
            tester: tester,
            ctx: ctx,
            config: config,
            stopwatch: stopwatch,
            planReuse: planReuse,
          );
          // Successful step execution already settles live work before
          // publishing the final artifacts. Settling again here added another
          // 5-second best-effort wait to every test with a long-lived stream.
          return (result: result, config: config, context: ctx);
        },
      );
      attemptCloseFailures = outcome.closeFailures;
      if (!outcome.completed) return outcome.requireValue();

      final output = outcome.value as EnsembleTestRunOutput;
      return (
        result: RetryExecutionCoordinator.withAttemptCleanupFailures(
          output.result,
          failures: attemptCloseFailures,
          phase: 'cleanup',
        ),
        config: output.config,
        context: output.context,
      );
    } catch (error, stackTrace) {
      final config = existingConfig ?? Ensemble().getConfig();
      final errorMessage = error.toString();
      final logs = <String>[];
      try {
        await _settleLiveApiWorkBestEffort(tester, ctx);
        final hadScreenshotFrames =
            ctx.runtime.screenshotSheetFrames.isNotEmpty;
        await _flushPendingScreenshots(
          ctx,
          status: TestStatus.failed,
          durationMs: stopwatch.elapsedMilliseconds,
          failedStepLabel: 'Startup/setup',
          failureMessage: errorMessage,
        );
        await _artifactCoordinator.attachPerTestDebugArtifactsOnce(ctx);
        logs.addAll(ctx.logger.logs);
        if (!hadScreenshotFrames) {
          logs.addAll(
            await writeEmergencyFailureScreenshot(
              tester: tester,
              test: test,
              config: suiteConfig,
              error: error,
            ),
          );
        }
      } catch (_) {
        try {
          await _artifactCoordinator.attachPerTestDebugArtifactsOnce(ctx);
        } catch (_) {}
        logs.addAll(ctx.logger.logs);
      }
      var result = EnsembleSingleTestResult.failed(
        testId: test.id,
        metadata: test.metadataJson,
        message: errorMessage,
        stackTrace: stackTrace.toString(),
        durationMs: stopwatch.elapsedMilliseconds,
        logs: logs,
        report: buildTestReportDetails(
          test,
          navigationFlow: ctx.navigationFlow,
        ),
      );
      if (attemptCloseFailures.isNotEmpty) {
        result = RetryExecutionCoordinator.withAttemptCleanupFailures(
          result,
          failures: attemptCloseFailures,
          phase: 'cleanup',
        );
      }
      return (
        result: result,
        config: config ?? await harness.buildConfig(),
        context: ctx,
      );
    }
  }

  Future<EnsembleTestRunOutput> _runOneWithRetries(
    EnsembleTestCase test,
    WidgetTester tester, {
    required EnsembleTestConfig suiteConfig,
    EnsembleConfig? existingConfig,
    AppSessionSnapshot? sessionSnapshot,
    CompiledPlanReuse? planReuse,
  }) async {
    final preparedPlan = planReuse ??
        CompiledPlanReuse(() => CompiledPlanCompiler().compile(test));
    return RetryExecutionCoordinator(retries: test.retry).run(
      executeAttempt: (AttemptDescriptor attempt) async {
        final out = await _runOneForAttempt(
          test,
          tester,
          suiteConfig: suiteConfig,
          existingConfig: existingConfig,
          sessionSnapshot: sessionSnapshot,
          attempt: attempt,
          planReuse: preparedPlan,
        );
        existingConfig = out.config;
        return out;
      },
    );
  }

  void _recordPerformanceMarker({
    required EnsembleTestContext ctx,
    required String testId,
    required int? stepIndex,
    required String label,
    required String phase,
    required int startFrame,
    required DateTime startTime,
  }) {
    if (!ctx.config.performance.enabled) return;
    final endFrame = ctx.runtime.appFrameTimings.length;
    if (endFrame < startFrame) return;
    ctx.runtime.recordPerformanceMarker(
      PerformanceMarker(
        testId: testId,
        stepIndex: stepIndex,
        label: label,
        screen: ScreenTracker().getCurrentScreenIdentifier(),
        phase: phase,
        startFrame: startFrame,
        endFrame: endFrame,
        startTime: startTime,
        endTime: DateTime.now(),
      ),
    );
  }

  String _phaseForStep(TestStep step) {
    switch (step.type) {
      case 'waitForNavigation':
      case 'openScreen':
      case 'goBack':
      case 'restartApp':
      case 'reloadScreen':
      case 'launchApp':
        return 'navigation';
      case 'settle':
      case 'wait':
      case 'waitFor':
      case 'waitForApi':
        return 'settle';
      default:
        return 'step';
    }
  }

  Future<void> _settleLiveApiWork(
    WidgetTester tester,
    EnsembleTestContext ctx,
  ) async {
    await EventDrivenSettler(
      tester: tester,
      hasExternalWork: () => ctx.apiOverlay.hasPendingLiveCalls,
      waitForExternalWork: ctx.apiOverlay.waitForLiveCalls,
      onPump: () => ctx.navigationFlow.flushPending(),
    ).waitFor(
      timeout: const Duration(seconds: 5),
      condition: () => !ctx.apiOverlay.hasPendingLiveCalls,
    );
    // Cleanup needs completed API work and queued route notifications. It does
    // not need every repeating app timer or animation to become idle; that
    // condition can never hold in apps with active timer-driven screens.
    await tester.pump();
    await ctx.navigationFlow.flushPending();
  }

  Future<void> _settleLiveApiWorkBestEffort(
    WidgetTester tester,
    EnsembleTestContext ctx,
  ) async {
    try {
      await _settleLiveApiWork(tester, ctx);
    } catch (_) {
      // Cleanup settling is only to give async work a chance to finish before
      // screenshots/logs are written. It must not decide the test result.
    }
  }

  /// Consume any exceptions already queued by a plugin or a prior handler.
  /// Flutter framework diagnostics handled by this runner are written to the
  /// console and recorded in the test context, but do not independently decide
  /// whether a test step or test passed.
  void _drainFlutterExceptions(WidgetTester tester) {
    while (tester.takeException() != null) {}
  }

  Future<void> _flushPendingScreenshots(
    EnsembleTestContext ctx, {
    required TestStatus status,
    required int durationMs,
    int? failedStepIndex,
    String? failedStepLabel,
    String? failureMessage,
  }) async {
    final artifacts = ctx.runtime.takeScreenshotArtifacts();
    final sheetFrames = artifacts.frames;
    final stepObservers = artifacts.stepObservers;
    if (sheetFrames.isEmpty &&
        stepObservers.isEmpty &&
        !ctx.config.hasDeviceMatrix) {
      return;
    }

    final path = await _visuals.screenshotSheetsFor(ctx.config).completeRun(
          testCase: ctx.testCase,
          frames: sheetFrames,
          status: status,
          durationMs: durationMs,
          failedStepIndex: failedStepIndex,
          failedStepLabel: failedStepLabel,
          failureMessage: failureMessage,
          stepObservers: stepObservers,
        );
    if (path != null) {
      // Primary artifact is the frames manifest; HTML builds the gallery from it.
      ctx.logger.log('screenshotFrames: $path');
    }
  }
}
