import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/screen_tracker.dart';
import 'package:ensemble_test_runner/actions/extended_step_handlers.dart';
import 'package:ensemble_test_runner/actions/http_request_action.dart';
import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/discovery/ensemble_test_execution_planner.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:ensemble_test_runner/mocks/test_logger.dart';
import 'package:ensemble_test_runner/mocks/wifi_test_setup.dart';
import 'package:ensemble_test_runner/reporters/test_reporter.dart';
import 'package:ensemble_test_runner/runner/app_performance_log.dart';
import 'package:ensemble_test_runner/runner/app_session_snapshot.dart';
import 'package:ensemble_test_runner/runner/debug_artifact_logs.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/runner/live_async_call.dart';
import 'package:ensemble_test_runner/runner/screenshot_contact_sheet.dart';
import 'package:ensemble_test_runner/runner/screenshot_lottie_ready.dart';
import 'package:ensemble_test_runner/runner/screenshot_sheet_aggregator.dart';
import 'package:ensemble_test_runner/runner/storage_step_diff.dart';
import 'package:ensemble_test_runner/runner/test_runtime_state.dart';
import 'package:ensemble_test_runner/runner/test_service_manager.dart';
import 'package:ensemble_test_runner/runner/yaml_test_session.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

typedef EnsembleTestRunOutput = ({
  EnsembleSingleTestResult result,
  EnsembleConfig config,
  EnsembleTestContext context,
});

typedef EnsembleTestProgressListener = FutureOr<void> Function(
  EnsembleTestDefinition definition,
  EnsembleSingleTestResult result,
);

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
  ScreenshotSheetAggregator? _activeScreenshotSheets;

  /// Creates a runner backed by [harness].
  EnsembleTestRunner({required this.harness});

  /// Runs every test in [plan] and returns results keyed by test id.
  Future<EnsembleTestPlanRunResult> runPlan(
    EnsembleTestExecutionPlan plan,
    WidgetTester tester, {
    EnsembleTestProgressListener? onTestComplete,
  }) async {
    final services = TestServiceManager(plan.config.services);
    await tester.runAsync(services.startAll);
    _activeScreenshotSheets = ScreenshotSheetAggregator(
      screenshots: plan.config.screenshots,
      devices: plan.config.devices,
    );
    try {
      return await _runPlan(
        plan,
        tester,
        onTestComplete: onTestComplete,
      );
    } finally {
      await _activeScreenshotSheets?.flushRemaining();
      _activeScreenshotSheets = null;
      await LiveAsyncCallSupport.run<void>(services.stopAll);
    }
  }

  Future<EnsembleTestPlanRunResult> _runPlan(
    EnsembleTestExecutionPlan plan,
    WidgetTester tester, {
    EnsembleTestProgressListener? onTestComplete,
  }) async {
    final resultsById = <String, EnsembleSingleTestResult>{};
    final suiteLogger = TestLogger();
    final suiteFrames = <AppFrameTimingEntry>[];
    final suiteMarkers = <PerformanceMarker>[];
    final suiteApiCalls = <APICallRecord>[];
    final sessionSnapshots = <String, AppSessionSnapshot>{};
    final requestedSessions = plan.ordered
        .map((definition) => definition.testCase.session)
        .whereType<String>()
        .toSet();
    EnsembleTestContext? lastContext;

    for (final def in plan.ordered) {
      final test = def.testCase;
      final session = test.session;
      AppSessionSnapshot? sessionSnapshot;
      if (session != null) {
        final sessionResult = resultsById[session];
        if (sessionResult == null) {
          throw EnsembleTestFailure(
            'Internal error: session "$session" for "${test.id}" was not scheduled',
          );
        }
        if (sessionResult.status == TestStatus.failed) {
          final result = EnsembleSingleTestResult.failed(
            testId: test.id,
            metadata: test.metadataJson,
            error: 'Session "$session" failed',
            durationMs: 0,
            report: buildTestReportDetails(test),
          );
          resultsById[test.id] = result;
          await onTestComplete?.call(def, result);
          continue;
        }
        sessionSnapshot = sessionSnapshots[session];
        if (sessionSnapshot == null) {
          throw EnsembleTestFailure(
            'Internal error: session "$session" completed without a snapshot',
          );
        }
      }

      late final EnsembleTestRunOutput out;
      try {
        out = await _runOneWithRetries(
          test,
          tester,
          suiteConfig: plan.config,
          existingConfig: null,
          sessionSnapshot: sessionSnapshot,
        );
      } catch (error, stackTrace) {
        final logs = await _writeEmergencyFailureScreenshot(
          tester: tester,
          test: test,
          config: plan.config,
          error: error,
        );
        final result = EnsembleSingleTestResult.failed(
          testId: test.id,
          metadata: test.metadataJson,
          error: error.toString(),
          stackTrace: stackTrace.toString(),
          durationMs: 0,
          logs: logs,
          report: buildTestReportDetails(test),
        );
        resultsById[test.id] = result;
        await onTestComplete?.call(def, result);
        continue;
      }
      resultsById[test.id] = out.result;
      await onTestComplete?.call(def, out.result);
      lastContext = out.context;
      final frameOffset = suiteFrames.length;
      _appendSuiteFrames(suiteFrames, out.context.runtime.appFrameTimings);
      suiteMarkers.addAll(
        out.context.runtime.performanceMarkers.map(
          (marker) => marker.shiftedFrames(frameOffset),
        ),
      );
      suiteApiCalls.addAll(out.context.apiOverlay.calls);
      if (out.result.status == TestStatus.passed &&
          requestedSessions.contains(test.id)) {
        sessionSnapshots[test.id] = await AppSessionSnapshot.capture();
      }
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
    AppSessionSnapshot? sessionSnapshot,
  }) async {
    final stopwatch = Stopwatch()..start();
    void Function(List<ui.FrameTiming>)? timingsCallback;
    final ctx = EnsembleTestContext.fromTestCase(
      test,
      config: suiteConfig,
    );
    final previousOnError = FlutterError.onError;

    final previousDebugPrint = debugPrint;
    try {
      FlutterError.onError = (details) {
        ctx.runtime.flutterErrors.add(_formatFlutterError(details));
      };
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) {
          ctx.runtime.consoleLogs.add(ctx.runtime.formatConsoleLine(message));
        }
        previousDebugPrint(message, wrapWidth: wrapWidth);
      };
      applyWifiTestConfig(suiteConfig.wifi);
      timingsCallback = (List<ui.FrameTiming> timings) {
        ctx.runtime.addFrameTimings(timings);
      };

      SchedulerBinding.instance.addTimingsCallback(timingsCallback);
      ctx.apiOverlay.liveAsyncRunner = tester.runAsync;
      LiveAsyncCallSupport.runner = tester.runAsync;
      LiveAsyncCallSupport.drainPendingExceptions = () {
        while (tester.takeException() != null) {}
      };

      return await runZoned(
        () async {
          final startupStartFrame = ctx.runtime.appFrameTimings.length + 1;
          final startupStartTime = DateTime.now();

          final config = await harness.loadScreen(
            tester: tester,
            testCase: test,
            existingConfig: existingConfig,
            context: ctx,
            suiteConfig: suiteConfig,
            beforeBootstrap: () async {
              await sessionSnapshot?.restore();
              await _executeSetup(test);
            },
            forcedLocale: sessionSnapshot?.locale ?? ctx.runtime.locale,
          );
          _drainPendingFlutterExceptions(tester);
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
          await _settleLiveApiWorkBestEffort(tester, ctx);
          return (result: result, config: config, context: ctx);
        },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            ctx.runtime.consoleLogs.add(ctx.runtime.formatConsoleLine(line));
            parent.print(zone, line);
          },
        ),
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
        await _attachPerTestDebugArtifacts(ctx);
        logs.addAll(ctx.logger.logs);
        if (!hadScreenshotFrames) {
          logs.addAll(
            await _writeEmergencyFailureScreenshot(
              tester: tester,
              test: test,
              config: suiteConfig,
              error: error,
            ),
          );
        }
      } catch (_) {
        try {
          await _attachPerTestDebugArtifacts(ctx);
        } catch (_) {}
        logs.addAll(ctx.logger.logs);
      }
      return (
        result: EnsembleSingleTestResult.failed(
          testId: test.id,
          metadata: test.metadataJson,
          error: errorMessage,
          stackTrace: stackTrace.toString(),
          durationMs: stopwatch.elapsedMilliseconds,
          logs: logs,
          report: buildTestReportDetails(test),
        ),
        config: config ?? await harness.buildConfig(),
        context: ctx,
      );
    } finally {
      debugPrint = previousDebugPrint;
      final callback = timingsCallback;
      if (callback != null) {
        SchedulerBinding.instance.removeTimingsCallback(callback);
      }
      FlutterError.onError = previousOnError;
    }
  }

  Future<EnsembleTestRunOutput> _runOneWithRetries(
    EnsembleTestCase test,
    WidgetTester tester, {
    required EnsembleTestConfig suiteConfig,
    EnsembleConfig? existingConfig,
    AppSessionSnapshot? sessionSnapshot,
  }) async {
    final maxAttempts = test.retry + 1;
    var totalDurationMs = 0;
    EnsembleTestRunOutput? lastOutput;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final out = await runOne(
        test,
        tester,
        suiteConfig: suiteConfig,
        existingConfig: existingConfig,
        sessionSnapshot: sessionSnapshot,
      );
      totalDurationMs += out.result.durationMs;
      lastOutput = out;
      existingConfig = out.config;

      if (out.result.status == TestStatus.passed || attempt == maxAttempts) {
        return (
          result: _withRetryMetadata(
            out.result,
            attempts: attempt,
            retry: test.retry,
            durationMs: totalDurationMs,
          ),
          config: out.config,
          context: out.context,
        );
      }
    }

    return lastOutput!;
  }

  EnsembleSingleTestResult _withRetryMetadata(
    EnsembleSingleTestResult result, {
    required int attempts,
    required int retry,
    required int durationMs,
  }) {
    return EnsembleSingleTestResult(
      testId: result.testId,
      metadata: result.metadata,
      status: result.status,
      durationMs: durationMs,
      attempts: attempts,
      retry: retry,
      failedStepIndex: result.failedStepIndex,
      failedStep: result.failedStep,
      message: result.message,
      stackTrace: result.stackTrace,
      logs: result.logs,
      report: result.report,
    );
  }

  Future<void> _executeSetup(EnsembleTestCase test) async {
    for (var i = 0; i < test.setupSteps.length; i++) {
      final step = test.setupSteps[i];
      try {
        await _executeSetupStep(step);
      } catch (error) {
        throw EnsembleTestFailure(
          'Setup ${i + 1} ${formatStepBrief(step)} failed: $error',
        );
      }
    }
  }

  Future<void> _executeSetupStep(TestStep step) async {
    switch (step.type) {
      case 'httpRequest':
        await HttpRequestAction.execute(step.args);
      case 'group':
        for (final nested in step.nestedSteps) {
          await _executeSetupStep(nested);
        }
      case 'optional':
        try {
          for (final nested in step.nestedSteps) {
            await _executeSetupStep(nested);
          }
        } catch (_) {
          // Optional setup is best effort.
        }
      default:
        throw EnsembleTestFailure(
          'Unsupported setup action "${step.type}"',
        );
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
    final stepDurationsMs = <int>[];
    final stepStartTimes = <String>[];
    for (var i = 0; i < test.steps.length; i++) {
      final step = test.steps[i];
      final startFrame = ctx.runtime.appFrameTimings.length + 1;
      final startTime = DateTime.now();
      ctx.runtime.currentStepIndex = i;
      stepStartTimes.add(startTime.toIso8601String());
      final storageBefore = capturePublicStorage();
      var capturedStep = false;
      try {
        _drainPendingFlutterExceptions(tester);
        if (i == 0 && ctx.config.screenshots.enabled) {
          await executor.settle();
        }
        final captureBeforeStep = _shouldCaptureBeforeStep(step);
        if (captureBeforeStep) {
          await _captureAutomaticScreenshotForStep(
            executor: executor,
            step: step,
            stepIndex: i,
            waitForTarget: true,
          );
          capturedStep = true;
        }
        if (step.type == 'waitForText') {
          executor.onWaitForTextMatched = (matchedStep) async {
            if (capturedStep) return;
            await _waitForHighlightTargetToPaint(executor, matchedStep);
            await _captureAutomaticScreenshotForStepBestEffort(
              executor: executor,
              step: matchedStep,
              stepIndex: i,
              stabilize: false,
            );
            capturedStep = true;
          };
        }
        if (step.type == 'waitForNavigation') {
          // Capture while the target screen is still the current route.
          // Immediate pixels are wrong for durable screens (Home) whose tracker
          // updates before paint; long waits are wrong for transient screens
          // (AutoSignIn_Gateway → Home). Paint briefly, then choose.
          executor.onWaitForNavigationMatched = (matchedStep) async {
            if (capturedStep) return;
            final didCapture = await _captureWaitForNavigationScreenshot(
              executor: executor,
              step: matchedStep,
              stepIndex: i,
            );
            if (didCapture) {
              capturedStep = true;
            }
          };
        }
        try {
          await executor.execute(step);
        } finally {
          executor.onWaitForTextMatched = null;
          executor.onWaitForNavigationMatched = null;
        }
        _drainPendingFlutterExceptions(tester);
        if (!captureBeforeStep && !capturedStep) {
          await _captureAutomaticScreenshotForStep(
            executor: executor,
            step: step,
            stepIndex: i,
            pumpBeforeCapture: _shouldPumpBeforePostStepCapture(step),
            // Prefer mid-wait capture for navigation; if we missed it, still
            // avoid a long Lottie wait that advances to the next screen.
            waitForLottie: step.type != 'waitForNavigation',
            stabilize: !_isTextVerificationStep(step),
          );
          capturedStep = true;
        }
        await YamlTestSession.navigationFlow.flushPending();
        _recordStorageStepDiff(
          ctx: ctx,
          stepIndex: i,
          before: storageBefore,
        );
        stepDurationsMs.add(
          DateTime.now().difference(startTime).inMilliseconds,
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
        _recordStorageStepDiff(
          ctx: ctx,
          stepIndex: i,
          before: storageBefore,
        );
        stepDurationsMs.add(
          DateTime.now().difference(startTime).inMilliseconds,
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
        final idleStartFrame = ctx.runtime.appFrameTimings.length + 1;
        final idleStartTime = DateTime.now();
        await _settleLiveApiWorkBestEffort(tester, ctx);
        _drainPendingFlutterExceptions(tester);
        if (!capturedStep) {
          await _captureAutomaticScreenshotForStepBestEffort(
            executor: executor,
            step: step,
            stepIndex: i,
            pumpBeforeCapture: true,
            ensureTargetVisible: false,
          );
        }
        final failureMessage = _failureMessageWithFlutterErrors(
          error.toString(),
          ctx,
        );
        await _flushPendingScreenshots(
          ctx,
          status: TestStatus.failed,
          durationMs: stopwatch.elapsedMilliseconds,
          failedStepIndex: i,
          failedStepLabel: formatStepBrief(step),
          failureMessage: failureMessage,
        );
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
        await _attachPerTestDebugArtifacts(ctx);
        return EnsembleSingleTestResult.failed(
          testId: test.id,
          metadata: test.metadataJson,
          failedStepIndex: i,
          failedStep: step,
          error: failureMessage,
          stackTrace: stackTrace.toString(),
          durationMs: stopwatch.elapsedMilliseconds,
          logs: ctx.logger.logs,
          report: buildTestReportDetails(
            test,
            stepDurationsMs: stepDurationsMs,
            stepStartTimes: stepStartTimes,
          ),
        );
      }
    }
    ctx.runtime.currentStepIndex = null;

    await YamlTestSession.navigationFlow.flushPending();
    final idleStartFrame = ctx.runtime.appFrameTimings.length + 1;
    final idleStartTime = DateTime.now();
    await _settleLiveApiWorkBestEffort(tester, ctx);
    _drainPendingFlutterExceptions(tester);
    await _flushPendingScreenshots(
      ctx,
      status: TestStatus.passed,
      durationMs: stopwatch.elapsedMilliseconds,
    );
    _recordPerformanceMarker(
      ctx: ctx,
      testId: test.id,
      stepIndex: null,
      label: '${test.id} idle',
      phase: 'idle',
      startFrame: idleStartFrame,
      startTime: idleStartTime,
    );
    await _attachPerTestDebugArtifacts(ctx);

    return EnsembleSingleTestResult.passed(
      testId: test.id,
      metadata: test.metadataJson,
      durationMs: stopwatch.elapsedMilliseconds,
      logs: ctx.logger.logs,
      report: buildTestReportDetails(
        test,
        stepDurationsMs: stepDurationsMs,
        stepStartTimes: stepStartTimes,
      ),
    );
  }

  /// Screenshots for [waitForNavigation]: durable screens need a paint pass;
  /// transient screens must keep a pre-navigation frame.
  ///
  /// Returns whether a frame was recorded.
  Future<bool> _captureWaitForNavigationScreenshot({
    required TestStepExecutor executor,
    required TestStep step,
    required int stepIndex,
  }) async {
    final options = executor.context.config.screenshots;
    if (!options.shouldCaptureStep(step.type)) return false;

    final screen = step.args['screen']?.toString();
    if (screen == null || screen.isEmpty) return false;

    final tracker = ScreenTracker();
    bool isTargetVisible() =>
        tracker.isScreenVisible(screenName: screen) ||
        tracker.isScreenVisible(screenId: screen);

    if (!isTargetVisible()) return false;

    // Hold a frame from the moment the tracker reports the target. Transient
    // screens (AutoSignIn_Gateway) often leave during the paint pumps below.
    ui.Image? earlyImage;
    try {
      earlyImage = ExtendedStepHandlers.captureScreenshotImage(executor.tester);
    } catch (_) {
      earlyImage = null;
    }

    try {
      // Tracker often updates before the new route paints. Give durable
      // destinations a few frames; re-check visibility so transient screens
      // that leave mid-wait keep the early frame instead.
      for (var i = 0; i < 6; i++) {
        await executor.tester.pump(const Duration(milliseconds: 50));
        if (!isTargetVisible()) break;
      }
      if (isTargetVisible() && areVisibleLottiesReady(executor.tester)) {
        seekVisibleLottiesForScreenshot(executor.tester);
        await executor.tester.pump();
      }
    } catch (_) {
      // Best-effort paint only.
    }

    if (isTargetVisible()) {
      // Still on target after paint — prefer the painted frame (Home, etc.).
      earlyImage?.dispose();
      earlyImage = null;
      await _captureAutomaticScreenshotForStepBestEffort(
        executor: executor,
        step: step,
        stepIndex: stepIndex,
        ensureTargetVisible: false,
        waitForLottie: false,
        stabilize: false,
      );
      return executor.context.runtime.screenshotSheetFrames
          .any((frame) => frame.stepIndex == stepIndex);
    }

    // Left during paint — commit the early frame so the step is not labeled
    // with the next screen's pixels.
    if (earlyImage == null) return false;

    final device = _screenshotDeviceTarget(executor.context);
    executor.context.runtime.addScreenshotSheetFrame(
      ScreenshotSheetFrame(
        stepIndex: stepIndex,
        label: '${stepIndex + 1}. ${formatStepBrief(step)}',
        image: earlyImage,
        deviceId: device?.id,
        deviceLabel: device?.displayLabel,
        platform: device?.platform,
        model: device?.model,
      ),
    );
    return true;
  }

  Future<void> _captureAutomaticScreenshotForStep({
    required TestStepExecutor executor,
    required TestStep step,
    required int stepIndex,
    bool pumpBeforeCapture = false,
    bool ensureTargetVisible = true,
    bool waitForTarget = false,
    bool waitForLottie = true,
    bool stabilize = true,
  }) async {
    final options = executor.context.config.screenshots;
    if (!options.shouldCaptureStep(step.type)) return;

    if (pumpBeforeCapture) {
      await executor.tester.pump();
    }

    if (waitForTarget) {
      await _waitForScreenshotTarget(executor, step);
    }

    if (ensureTargetVisible) {
      await _ensureHighlightTargetVisible(executor, step);
    }

    if (stabilize) {
      // Finish route transitions so the captured pixels match the highlight target.
      await _stabilizeScreenshotFrame(
        executor,
        waitForLottie: waitForLottie,
      );
    }

    var image = ExtendedStepHandlers.captureScreenshotImage(executor.tester);
    final highlightRect = _highlightRectForStep(executor, step);
    if (highlightRect != null) {
      try {
        final highlighted = await _highlightScreenshotImage(
          tester: executor.tester,
          image: image,
          rect: highlightRect,
          step: step,
        );
        image.dispose();
        image = highlighted;
      } catch (_) {
        // Screenshot annotations must never change test behavior.
      }
    }

    final device = _screenshotDeviceTarget(executor.context);
    executor.context.runtime.addScreenshotSheetFrame(
      ScreenshotSheetFrame(
        stepIndex: stepIndex,
        label: '${stepIndex + 1}. ${formatStepBrief(step)}',
        image: image,
        deviceId: device?.id,
        deviceLabel: device?.displayLabel,
        platform: device?.platform,
        model: device?.model,
      ),
    );
  }

  TestDeviceTarget? _screenshotDeviceTarget(EnsembleTestContext ctx) {
    final target = ctx.testCase.deviceTarget;
    if (target != null) return target;
    if (ctx.config.devices.length == 1) return ctx.config.devices.single;
    if (!ctx.config.screenshots.enabled) return null;
    return const TestDeviceTarget(
      id: 'ios',
      platform: 'ios',
      model: 'iPhone 15 Pro',
    );
  }

  ScreenshotSheetAggregator _screenshotSheetsFor(EnsembleTestConfig config) {
    return _activeScreenshotSheets ??
        ScreenshotSheetAggregator(
          screenshots: config.screenshots,
          devices: config.devices,
        );
  }

  Future<void> _captureAutomaticScreenshotForStepBestEffort({
    required TestStepExecutor executor,
    required TestStep step,
    required int stepIndex,
    bool pumpBeforeCapture = false,
    bool ensureTargetVisible = true,
    bool waitForTarget = false,
    bool waitForLottie = true,
    bool stabilize = true,
  }) async {
    try {
      await _captureAutomaticScreenshotForStep(
        executor: executor,
        step: step,
        stepIndex: stepIndex,
        pumpBeforeCapture: pumpBeforeCapture,
        ensureTargetVisible: ensureTargetVisible,
        waitForTarget: waitForTarget,
        waitForLottie: waitForLottie,
        stabilize: stabilize,
      );
    } catch (_) {
      // Screenshot capture must never replace the real test failure.
    }
  }

  bool _shouldCaptureBeforeStep(TestStep step) => _isUserActionStep(step);

  bool _shouldPumpBeforePostStepCapture(TestStep step) =>
      step.type != 'waitForText';

  bool _isTextVerificationStep(TestStep step) =>
      step.type == 'expectText' ||
      step.type == 'expectTextContains' ||
      step.type == 'waitForText';

  Future<void> _stabilizeScreenshotFrame(
    TestStepExecutor executor, {
    bool waitForLottie = true,
  }) async {
    try {
      // Two short pumps cover typical push/fade transitions without a full
      // pumpAndSettle (which can hang on repeating animations).
      await executor.tester.pump(const Duration(milliseconds: 50));
      await executor.tester.pump(const Duration(milliseconds: 50));
      if (!waitForLottie) {
        // Transient navigation screens leave during a long Lottie wait; if the
        // composition is already ready, still seek past intro-only frames.
        if (areVisibleLottiesReady(executor.tester)) {
          seekVisibleLottiesForScreenshot(executor.tester);
          await executor.tester.pump();
        }
        return;
      }
      // Local Lottie.asset is still async; with an external AnimationController
      // nothing paints until onLoaded. Wait so step screenshots are not blank.
      await waitForVisibleLottiesReady(executor.tester);
    } catch (_) {
      // Stabilization is best-effort for screenshots only.
    }
  }

  Future<void> _waitForScreenshotTarget(
    TestStepExecutor executor,
    TestStep step,
  ) async {
    if (!_shouldHighlightStep(step)) return;

    final finder = _highlightFinder(executor, step);
    if (finder == null) return;

    final waitsForHitTestable = _isUserActionStep(step);
    final timeoutMs = step.args['timeoutMs'] as int? ??
        executor.config.defaultWaitTimeout.inMilliseconds;
    final stopwatch = Stopwatch()..start();
    while (stopwatch.elapsedMilliseconds < timeoutMs) {
      if (_isScreenshotTargetReady(
            executor,
            finder,
            waitsForHitTestable,
          ) &&
          _isHighlightTargetPainted(executor, finder, waitsForHitTestable)) {
        return;
      }
      await executor.tester.pump(executor.config.waitPollInterval);
    }
  }

  bool _isScreenshotTargetReady(
    TestStepExecutor executor,
    Finder finder,
    bool waitsForHitTestable,
  ) {
    return executor.assertions.firstVisuallyActionableElement(
          finder,
          requireHitTestable: waitsForHitTestable,
        ) !=
        null;
  }

  Future<void> _waitForHighlightTargetToPaint(
    TestStepExecutor executor,
    TestStep step,
  ) async {
    if (step.type != 'waitForText') return;

    for (var i = 0; i < 8; i++) {
      final finder = _highlightFinder(executor, step);
      final element = finder == null
          ? null
          : executor.assertions.firstVisuallyActionableElement(finder);
      if (element == null) return;
      if (_effectiveOpacity(element) >= 0.85) return;

      await executor.tester.pump(const Duration(milliseconds: 50));
    }
  }

  bool _isHighlightTargetPainted(
    TestStepExecutor executor,
    Finder finder,
    bool prefersHitTestable,
  ) {
    final element = executor.assertions.firstVisuallyActionableElement(
      finder,
      requireHitTestable: prefersHitTestable,
    );
    if (element == null) return false;
    return _effectiveOpacity(element) >= 0.85;
  }

  double _effectiveOpacity(Element element) {
    var opacity = 1.0;
    element.visitAncestorElements((ancestor) {
      final renderObject = ancestor.renderObject;
      if (renderObject is RenderOpacity) {
        opacity *= renderObject.opacity;
      } else if (renderObject != null &&
          renderObject.runtimeType.toString() == 'RenderAnimatedOpacity') {
        try {
          final animatedOpacity = (renderObject as dynamic).opacity;
          if (animatedOpacity is Animation<double>) {
            opacity *= animatedOpacity.value;
          } else if (animatedOpacity is double) {
            opacity *= animatedOpacity;
          }
        } catch (_) {
          // Keep the known opacity from other ancestors.
        }
      }
      return true;
    });
    return opacity;
  }

  ui.Rect? _highlightRectForStep(TestStepExecutor executor, TestStep step) {
    if (!_shouldHighlightStep(step)) return null;

    final finder = _highlightFinder(executor, step);
    if (finder == null) return null;

    // Prefer the same visibility rules as taps: current route, on-screen, and
    // hit-testable for user actions. Never fall back to off-route finder.first.
    final requireHitTestable = _isUserActionStep(step);
    final rect = executor.assertions.rectForVisuallyActionable(
      finder,
      requireHitTestable: requireHitTestable,
    );
    if (rect != null) return rect;

    // Non-action asserts may highlight a visible but non-hit-testable widget.
    if (!requireHitTestable) {
      return executor.assertions.rectForVisuallyActionable(finder);
    }
    return null;
  }

  Future<void> _ensureHighlightTargetVisible(
    TestStepExecutor executor,
    TestStep step,
  ) async {
    if (!_shouldHighlightStep(step)) return;

    final finder = _highlightFinder(executor, step);
    if (finder == null) return;

    final requireHitTestable = _isUserActionStep(step);
    final visibleElement = executor.assertions.firstVisuallyActionableElement(
      finder,
      requireHitTestable: requireHitTestable,
    );
    if (visibleElement != null) {
      if (_isTextVerificationStep(step)) {
        await Scrollable.ensureVisible(
          visibleElement,
          alignment: 0.45,
          duration: Duration.zero,
        );
        await executor.tester.pump();
      }
      return;
    }

    // Scroll a current-route match into view when it exists but is off-screen.
    Element? currentRouteMatch;
    for (final candidate in finder.evaluate()) {
      final route = ModalRoute.of(candidate);
      if (route != null && !route.isCurrent) continue;
      currentRouteMatch = candidate;
      break;
    }
    if (currentRouteMatch == null) return;

    var visibilityTarget = find.byWidget(currentRouteMatch.widget);
    if (step.type == 'toggle' ||
        step.type == 'check' ||
        step.type == 'uncheck') {
      final control = find.descendant(
        of: visibilityTarget,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Switch ||
              widget is CupertinoSwitch ||
              widget is Checkbox,
        ),
      );
      if (control.evaluate().isNotEmpty) {
        visibilityTarget = control.first;
      }
    }

    await executor.tester.ensureVisible(visibilityTarget);
    await executor.tester.pump();
  }

  Finder? _highlightFinder(TestStepExecutor executor, TestStep step) {
    final id = step.args['id']?.toString();
    if (id != null && id.isNotEmpty) {
      return executor.assertions.finderForId(id);
    }
    final texts = <String>[
      if (step.args['text']?.toString().trim().isNotEmpty == true)
        step.args['text'].toString(),
      if (step.args['anyOf'] is List)
        for (final item in step.args['anyOf'] as List)
          if (item != null && item.toString().trim().isNotEmpty)
            item.toString(),
    ];
    for (final text in texts) {
      if (step.type == 'expectTextContains') {
        final hitTestableText = find.textContaining(text).hitTestable();
        if (hitTestableText.evaluate().isNotEmpty) {
          return hitTestableText;
        }
        final containing = find.textContaining(text);
        if (containing.evaluate().isNotEmpty) return containing;
      } else {
        final hitTestableText = find.text(text).hitTestable();
        if (hitTestableText.evaluate().isNotEmpty) {
          return hitTestableText;
        }
        final exact = find.text(text);
        if (exact.evaluate().isNotEmpty) return exact;
      }
    }
    return null;
  }

  bool _shouldHighlightStep(TestStep step) {
    if (step.type == 'waitForText' ||
        step.type == 'expectText' ||
        step.type == 'waitFor' ||
        step.type == 'expectTextContains' ||
        step.type == 'scrollUntilVisible' ||
        step.type == 'expectVisible') {
      final text = step.args['text']?.toString();
      final anyOf = step.args['anyOf'];
      final id = step.args['id']?.toString();
      final hasAnyOf = anyOf is List && anyOf.isNotEmpty;
      return (text != null && text.isNotEmpty) ||
          hasAnyOf ||
          (id != null && id.isNotEmpty);
    }
    return _isUserActionStep(step);
  }

  bool _isUserActionStep(TestStep step) {
    switch (step.type) {
      case 'tap':
      case 'doubleTap':
      case 'longPress':
      case 'toggle':
      case 'check':
      case 'uncheck':
      case 'enterText':
      case 'clearText':
      case 'replaceText':
      case 'submitText':
      case 'focus':
      case 'select':
      case 'selectIndex':
      case 'setSlider':
        return true;
      default:
        return false;
    }
  }

  Future<ui.Image> _highlightScreenshotImage({
    required WidgetTester tester,
    required ui.Image image,
    required ui.Rect rect,
    required TestStep step,
  }) async {
    final renderView = tester.binding.renderViews.first;
    final paintBounds = renderView.paintBounds;
    final scaleX = image.width / paintBounds.width;
    final scaleY = image.height / paintBounds.height;
    final scaledRect = ui.Rect.fromLTRB(
      (rect.left - paintBounds.left) * scaleX,
      (rect.top - paintBounds.top) * scaleY,
      (rect.right - paintBounds.left) * scaleX,
      (rect.bottom - paintBounds.top) * scaleY,
    ).inflate(6 * scaleX);

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    );
    canvas.drawImage(image, ui.Offset.zero, ui.Paint());

    final isTapStep = step.type == 'tap' ||
        step.type == 'doubleTap' ||
        step.type == 'longPress' ||
        step.type == 'tapAt';

    void drawCornerBrackets(
        ui.Canvas canvas, ui.Rect rect, ui.Paint paint, double scale) {
      final left = rect.left;
      final top = rect.top;
      final right = rect.right;
      final bottom = rect.bottom;
      final maxLen = math.min(rect.width, rect.height) / 2.0;
      final len = math.min(math.max(24.0 * scale, rect.width / 4.0), maxLen);

      // Top-Left
      canvas.drawLine(ui.Offset(left, top), ui.Offset(left + len, top), paint);
      canvas.drawLine(ui.Offset(left, top), ui.Offset(left, top + len), paint);

      // Top-Right
      canvas.drawLine(
          ui.Offset(right - len, top), ui.Offset(right, top), paint);
      canvas.drawLine(
          ui.Offset(right, top), ui.Offset(right, top + len), paint);

      // Bottom-Left
      canvas.drawLine(
          ui.Offset(left, bottom), ui.Offset(left + len, bottom), paint);
      canvas.drawLine(
          ui.Offset(left, bottom - len), ui.Offset(left, bottom), paint);

      // Bottom-Right
      canvas.drawLine(
          ui.Offset(right - len, bottom), ui.Offset(right, bottom), paint);
      canvas.drawLine(
          ui.Offset(right, bottom - len), ui.Offset(right, bottom), paint);
    }

    if (!isTapStep) {
      // 1. Verification/Wait/Scroll: Thick Mint green HUD corner brackets
      final paint = ui.Paint()
        ..color = const ui.Color(0xFF10B981) // Emerald green
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 4.0 * scaleX;

      // Distinct green overlay (~15% opacity) to immediately highlight the element block
      canvas.drawRect(
        scaledRect,
        ui.Paint()
          ..color = const ui.Color(0x2610B981)
          ..style = ui.PaintingStyle.fill,
      );

      drawCornerBrackets(canvas, scaledRect, paint, scaleX);
    } else {
      // 2. Taps/Gestures: Thick Neon Rose HUD corner brackets, concentric ripple circles & crosshair reticle
      final paint = ui.Paint()
        ..color = const ui.Color(0xFFF43F5E) // Rose red
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 3.5 * scaleX;

      // Translucent rose overlay (~10% opacity)
      canvas.drawRect(
        scaledRect,
        ui.Paint()
          ..color = const ui.Color(0x1AD51F5E)
          ..style = ui.PaintingStyle.fill,
      );

      drawCornerBrackets(canvas, scaledRect, paint, scaleX);

      final center = scaledRect.center;

      // Outer concentric ripple ring (larger and thicker)
      canvas.drawCircle(
        center,
        35 * scaleX,
        ui.Paint()
          ..color = const ui.Color(0x4DF43F5E) // ~30% opacity
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 2.0 * scaleX,
      );

      // Inner concentric ripple ring
      canvas.drawCircle(
        center,
        20 * scaleX,
        ui.Paint()
          ..color = const ui.Color(0x88F43F5E) // ~53% opacity
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 3.0 * scaleX,
      );

      // Precision target dot
      canvas.drawCircle(
        center,
        5.0 * scaleX,
        ui.Paint()
          ..color = const ui.Color(0xFFF43F5E)
          ..style = ui.PaintingStyle.fill,
      );

      // Horizontal crosshair line of "+"
      canvas.drawLine(
        ui.Offset(center.dx - 10 * scaleX, center.dy),
        ui.Offset(center.dx + 10 * scaleX, center.dy),
        ui.Paint()
          ..color = const ui.Color(0xFFF43F5E)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 3.0 * scaleX,
      );

      // Vertical crosshair line of "+"
      canvas.drawLine(
        ui.Offset(center.dx, center.dy - 10 * scaleX),
        ui.Offset(center.dx, center.dy + 10 * scaleX),
        ui.Paint()
          ..color = const ui.Color(0xFFF43F5E)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 3.0 * scaleX,
      );
    }

    final picture = recorder.endRecording();
    final highlighted = await picture.toImage(image.width, image.height);
    picture.dispose();
    return highlighted;
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

  /// Writes apiCalls / storage / appLogs for a single test onto [ctx.logger].
  Future<void> _attachPerTestDebugArtifacts(EnsembleTestContext ctx) async {
    // Always write API calls so HTML Step Details can attribute them per step.
    final apiPath = await writeApiCallsLog(ctx);
    _replaceArtifactLog(ctx.logger, 'apiCalls', apiPath);

    // Always write storage (keys + per-step diffs) for Step Details.
    final storagePath = await writeStorageLog(ctx);
    _replaceArtifactLog(ctx.logger, 'storage', storagePath);

    final appLogPath = await writeAppConsoleLog(ctx);
    _replaceArtifactLog(ctx.logger, 'appLogs', appLogPath);
  }

  void _recordStorageStepDiff({
    required EnsembleTestContext ctx,
    required int stepIndex,
    required Map<String, dynamic> before,
  }) {
    final changes = diffStorage(before, capturePublicStorage());
    if (changes.isEmpty) return;
    ctx.runtime.storageStepDiffs.add(
      StorageStepDiff(
        stepIndex: stepIndex,
        timestamp: DateTime.now(),
        changes: changes,
      ),
    );
  }

  void _replaceArtifactLog(TestLogger logger, String label, String path) {
    logger.logs.removeWhere((entry) {
      final separator = entry.indexOf(':');
      if (separator <= 0) return false;
      return entry.substring(0, separator).trim() == label;
    });
    logger.log('$label: $path');
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
      final path = await writePerformanceLog(
        logger: logger,
        filePrefix: '',
        name: 'app_performance',
        frames: frames,
        markers: markers,
        apiCalls: apiCalls,
      );
      logs.add('appPerformance: $path');
    }

    if (config.dumpTree.enabled && lastContext != null) {
      final path = await writeDumpTreeLogFile(logger: logger, filePrefix: '');
      logs.add('dumpTree: $path');
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
    _drainPendingFlutterExceptions(tester);
  }

  void _drainPendingFlutterExceptions(WidgetTester tester) {
    while (tester.takeException() != null) {
      // The app may catch/report async framework errors itself. Draining here
      // prevents Flutter's test binding from failing the YAML suite with a raw
      // framework dump after the declarative assertions have already decided
      // the test result.
    }
  }

  String _formatFlutterError(FlutterErrorDetails details) {
    final context = details.context?.toDescription();
    final exception = details.exceptionAsString();
    if (context == null || context.isEmpty) return exception;
    return '$context: $exception';
  }

  String _failureMessageWithFlutterErrors(
    String message,
    EnsembleTestContext ctx,
  ) {
    final errors = ctx.runtime.flutterErrors;
    if (errors.isEmpty) return message;
    return '$message\nFlutter errors:\n- ${errors.take(3).join('\n- ')}';
  }

  Future<void> _flushPendingScreenshots(
    EnsembleTestContext ctx, {
    required TestStatus status,
    required int durationMs,
    int? failedStepIndex,
    String? failedStepLabel,
    String? failureMessage,
  }) async {
    final sheetFrames = List<ScreenshotSheetFrame>.from(
      ctx.runtime.screenshotSheetFrames,
    );
    ctx.runtime.screenshotSheetFrames.clear();
    if (sheetFrames.isEmpty && !ctx.config.hasDeviceMatrix) {
      return;
    }

    final path = await _screenshotSheetsFor(ctx.config).completeRun(
      testCase: ctx.testCase,
      frames: sheetFrames,
      status: status,
      durationMs: durationMs,
      failedStepIndex: failedStepIndex,
      failedStepLabel: failedStepLabel,
      failureMessage: failureMessage,
    );
    if (path != null) {
      // Primary artifact is the frames manifest; HTML builds the gallery from it.
      ctx.logger.log('screenshots: $path');
      ctx.logger.log('screenshotFrames: $path');
    }
  }

  Future<List<String>> _writeEmergencyFailureScreenshot({
    required WidgetTester tester,
    required EnsembleTestCase test,
    required EnsembleTestConfig config,
    required Object error,
  }) async {
    if (!config.screenshots.enabled) return const [];
    try {
      final image = ExtendedStepHandlers.captureScreenshotImage(tester);
      final path = await writeScreenshotFrames(
        testId: test.resolvedScreenshotSheetId,
        config: config.screenshots,
        frames: [
          ScreenshotSheetFrame(
            stepIndex: 0,
            label: 'Runner failure',
            image: image,
            deviceId: test.deviceTarget?.id,
            deviceLabel: test.deviceTarget?.displayLabel,
            platform: test.deviceTarget?.platform ??
                (config.devices.isNotEmpty
                    ? config.devices.first.platform
                    : 'ios'),
            model: test.deviceTarget?.model ??
                (config.devices.isNotEmpty
                    ? config.devices.first.model
                    : 'iPhone 15 Pro'),
          ),
        ],
        status: TestStatus.failed,
        failedStepIndex: 0,
        failedStepLabel: 'Runner failure',
        failureMessage: error.toString(),
        failedDeviceId: test.deviceTarget?.id,
      );
      return path == null
          ? const []
          : ['screenshots: $path', 'screenshotFrames: $path'];
    } catch (_) {
      return const [];
    }
  }
}
