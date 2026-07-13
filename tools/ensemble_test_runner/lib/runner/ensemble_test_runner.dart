import 'dart:ui' as ui;

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/screen_tracker.dart';
import 'package:ensemble_test_runner/actions/extended_step_handlers.dart';
import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/discovery/ensemble_test_execution_planner.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:ensemble_test_runner/mocks/test_logger.dart';
import 'package:ensemble_test_runner/reporters/test_reporter.dart';
import 'package:ensemble_test_runner/runner/app_performance_log.dart';
import 'package:ensemble_test_runner/runner/debug_artifact_logs.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/runner/live_async_call.dart';
import 'package:ensemble_test_runner/runner/test_runtime_state.dart';
import 'package:ensemble_test_runner/runner/yaml_test_session.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

typedef EnsembleTestRunOutput = ({
  EnsembleSingleTestResult result,
  EnsembleConfig config,
  EnsembleTestContext context,
});

class EnsembleTestPlanRunResult {
  final Map<String, EnsembleSingleTestResult> resultsById;
  final List<String> suiteLogs;

  const EnsembleTestPlanRunResult({
    required this.resultsById,
    this.suiteLogs = const [],
  });
}

/// Executes parsed Ensemble YAML test plans against a widget tester.
class EnsembleTestRunner {
  /// Harness used to boot and reset the real Ensemble runtime.
  final EnsembleTestHarness harness;

  /// Creates a runner backed by [harness].
  EnsembleTestRunner({required this.harness});

  /// Runs every test in [plan] and returns results keyed by test id.
  Future<EnsembleTestPlanRunResult> runPlan(
    EnsembleTestExecutionPlan plan,
    WidgetTester tester,
  ) async {
    final resultsById = <String, EnsembleSingleTestResult>{};
    final suiteLogger = TestLogger();
    final suiteFrames = <AppFrameTimingEntry>[];
    final suiteMarkers = <PerformanceMarker>[];
    final suiteApiCalls = <APICallRecord>[];
    EnsembleTestContext? lastContext;
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
        suiteConfig: plan.config,
        existingConfig: config,
        continuation: test.hasPrerequisite,
      );
      resultsById[test.id] = out.result;
      config = out.config;
      lastContext = out.context;
      final frameOffset = suiteFrames.length;
      _appendSuiteFrames(suiteFrames, out.context.runtime.appFrameTimings);
      suiteMarkers.addAll(
        out.context.runtime.performanceMarkers.map(
          (marker) => marker.shiftedFrames(frameOffset),
        ),
      );
      suiteApiCalls.addAll(out.context.apiOverlay.calls);
    }

    final suiteLogs = await _writeSuiteLogs(
      tester: tester,
      config: plan.config,
      logger: suiteLogger,
      frames: suiteFrames,
      markers: suiteMarkers,
      apiCalls: suiteApiCalls,
      lastContext: lastContext,
    );

    return EnsembleTestPlanRunResult(
      resultsById: resultsById,
      suiteLogs: suiteLogs,
    );
  }

  /// Runs a single [test], optionally continuing an existing app session.
  Future<EnsembleTestRunOutput> runOne(
    EnsembleTestCase test,
    WidgetTester tester, {
    EnsembleTestConfig suiteConfig = const EnsembleTestConfig(),
    EnsembleConfig? existingConfig,
    bool continuation = false,
  }) async {
    final stopwatch = Stopwatch()..start();
    void Function(List<ui.FrameTiming>)? timingsCallback;
    final ctx = EnsembleTestContext.fromTestCase(
      test,
      config: suiteConfig,
    );

    try {
      timingsCallback = (List<ui.FrameTiming> timings) {
        ctx.runtime.addFrameTimings(timings);
      };

      SchedulerBinding.instance.addTimingsCallback(timingsCallback);
      ctx.apiOverlay.liveAsyncRunner = tester.runAsync;
      LiveAsyncCallSupport.runner = tester.runAsync;
      TestErrorTracker.install(ctx.runtime);
      final startupStartFrame = ctx.runtime.appFrameTimings.length + 1;
      final startupStartTime = DateTime.now();

      late final EnsembleConfig config;
      if (continuation) {
        if (!YamlTestSession.runtimeBootstrapped) {
          throw EnsembleTestFailure(
            'Test "${test.id}" has prerequisite "${test.prerequisite}" but the '
            'runtime is not bootstrapped — ensure the prerequisite test runs first',
          );
        }
        await EnsembleTestHarness.applyInPlaceSetup(ctx);
        config = existingConfig ?? Ensemble().getConfig()!;
        await EnsembleTestHarness.waitForInitialWidgets(tester, testCase: test);
      } else {
        config = await harness.loadScreen(
          tester: tester,
          testCase: test,
          existingConfig: existingConfig,
          context: ctx,
          suiteConfig: suiteConfig,
        );
      }
      await YamlTestSession.navigationFlow.flushPending();
      YamlTestSession.navigationFlow.beginTest(
        ScreenTracker().getCurrentScreenIdentifier(),
      );
      _recordPerformanceMarker(
        ctx: ctx,
        testId: test.id,
        stepIndex: null,
        label: '${test.id} startup',
        phase: 'startup',
        startFrame: startupStartFrame,
        startTime: startupStartTime,
      );

      final result = await _executeSteps(
        test: test,
        tester: tester,
        ctx: ctx,
        config: config,
        stopwatch: stopwatch,
      );
      return (result: result, config: config, context: ctx);
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
        context: ctx,
      );
    } finally {
      TestErrorTracker.reset();
      final callback = timingsCallback;
      if (callback != null) {
        SchedulerBinding.instance.removeTimingsCallback(callback);
      }
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
      final startFrame = ctx.runtime.appFrameTimings.length + 1;
      final startTime = DateTime.now();
      try {
        await executor.execute(step);
        await YamlTestSession.navigationFlow.flushPending();
        await _captureAutomaticScreenshotForStep(
          executor: executor,
          step: step,
          stepIndex: i,
        );
        _recordPerformanceMarker(
          ctx: ctx,
          testId: test.id,
          stepIndex: i + 1,
          label: '${test.id} step ${i + 1} ${formatStepBrief(step)}',
          phase: _phaseForStep(step),
          startFrame: startFrame,
          startTime: startTime,
        );
      } catch (error, stackTrace) {
        _recordPerformanceMarker(
          ctx: ctx,
          testId: test.id,
          stepIndex: i + 1,
          label: '${test.id} step ${i + 1} ${formatStepBrief(step)}',
          phase: _phaseForStep(step),
          startFrame: startFrame,
          startTime: startTime,
        );
        final idleStartFrame = ctx.runtime.appFrameTimings.length + 1;
        final idleStartTime = DateTime.now();
        await _settleLiveApiWork(tester, ctx);
        await _flushPendingScreenshots(tester, ctx);
        await YamlTestSession.navigationFlow.flushPending();
        _recordPerformanceMarker(
          ctx: ctx,
          testId: test.id,
          stepIndex: null,
          label: '${test.id} failure cleanup',
          phase: 'idle',
          startFrame: idleStartFrame,
          startTime: idleStartTime,
        );
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

    await YamlTestSession.navigationFlow.flushPending();
    final idleStartFrame = ctx.runtime.appFrameTimings.length + 1;
    final idleStartTime = DateTime.now();
    await _settleLiveApiWork(tester, ctx);
    await _flushPendingScreenshots(tester, ctx);
    _recordPerformanceMarker(
      ctx: ctx,
      testId: test.id,
      stepIndex: null,
      label: '${test.id} idle',
      phase: 'idle',
      startFrame: idleStartFrame,
      startTime: idleStartTime,
    );

    return EnsembleSingleTestResult.passed(
      testId: test.id,
      metadata: test.metadataJson,
      durationMs: stopwatch.elapsedMilliseconds,
      logs: ctx.logger.logs,
      report: buildTestReportDetails(test),
    );
  }

  Future<void> _captureAutomaticScreenshotForStep({
    required TestStepExecutor executor,
    required TestStep step,
    required int stepIndex,
  }) async {
    final options = executor.context.config.screenshots;
    if (!options.shouldCaptureStep(step.type)) return;
    await _captureAutomaticScreenshot(
      executor,
      name:
          'step_${(stepIndex + 1).toString().padLeft(3, '0')}_${_safeArtifactName(step.type)}',
    );
  }

  Future<void> _captureAutomaticScreenshot(
    TestStepExecutor executor, {
    required String name,
  }) {
    return ExtendedStepHandlers.captureScreenshot(
      executor,
      args: executor.context.config.screenshots.toScreenshotArgs({
        'name': name,
      }),
      deferWrite: true,
      pumpBeforeCapture: false,
    );
  }

  String _safeArtifactName(String value) =>
      value.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');

  void _recordPerformanceMarker({
    required EnsembleTestContext ctx,
    required String testId,
    required int? stepIndex,
    required String label,
    required String phase,
    required int startFrame,
    required DateTime startTime,
  }) {
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

  void _appendSuiteFrames(
    List<AppFrameTimingEntry> suiteFrames,
    List<AppFrameTimingEntry> testFrames,
  ) {
    for (final frame in testFrames) {
      suiteFrames.add(
        AppFrameTimingEntry(
          frameNumber: suiteFrames.length + 1,
          buildStartMicros: frame.buildStartMicros,
          buildMs: frame.buildMs,
          rasterMs: frame.rasterMs,
          vsyncOverheadMs: frame.vsyncOverheadMs,
          totalSpanMs: frame.totalSpanMs,
        ),
      );
    }
  }

  Future<List<String>> _writeSuiteLogs({
    required WidgetTester tester,
    required EnsembleTestConfig config,
    required TestLogger logger,
    required List<AppFrameTimingEntry> frames,
    required List<PerformanceMarker> markers,
    required List<APICallRecord> apiCalls,
    required EnsembleTestContext? lastContext,
  }) async {
    final logs = <String>[];

    if (config.performance.enabled) {
      final path = await tester.runAsync(() {
        return writePerformanceLog(
          logger: logger,
          filePrefix: '',
          name: 'app_performance',
          frames: frames,
          markers: markers,
          apiCalls: apiCalls,
        );
      });
      logs.add('appPerformance: $path');
    }

    if (config.dumpTree.enabled && lastContext != null) {
      final path = await tester.runAsync(() {
        return writeDumpTreeLogFile(logger: logger, filePrefix: '');
      });
      logs.add('dumpTree: $path');
    }

    if (config.logApiCalls.enabled) {
      final path = await tester.runAsync(() {
        return writeApiCallsLogFile(
          logger: logger,
          filePrefix: '',
          calls: apiCalls,
        );
      });
      logs.add('apiCalls: $path');
    }

    if (config.logStorage.enabled && lastContext != null) {
      final key = config.logStorage.key;
      final path = await tester.runAsync(() {
        return writeStorageLogFile(
          logger: logger,
          filePrefix: '',
          key: key,
        );
      });
      logs.add(
        key == null || key.isEmpty ? 'storage: $path' : 'storage[$key]: $path',
      );
    }

    return logs;
  }

  Future<void> _settleLiveApiWork(
    WidgetTester tester,
    EnsembleTestContext ctx,
  ) async {
    for (var i = 0; i < 20; i++) {
      await ctx.apiOverlay.waitForLiveCalls();
      await tester.pump();
      await YamlTestSession.navigationFlow.flushPending();
      if (!ctx.apiOverlay.hasPendingLiveCalls) {
        return;
      }
    }
  }

  Future<void> _flushPendingScreenshots(
    WidgetTester tester,
    EnsembleTestContext ctx,
  ) async {
    final writes = List<Future<void> Function()>.from(
      ctx.runtime.pendingScreenshotWrites,
    );
    ctx.runtime.pendingScreenshotWrites.clear();
    if (writes.isEmpty) return;

    await tester.runAsync(() async {
      for (final write in writes) {
        await write();
      }
    });
  }
}
