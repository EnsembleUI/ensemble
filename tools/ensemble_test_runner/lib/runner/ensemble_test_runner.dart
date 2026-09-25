import 'dart:async';
import 'dart:ui' as ui;

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/screen_tracker.dart';
import 'package:ensemble_test_runner/application/application_test_driver.dart';
import 'package:ensemble_test_runner/application/standalone_ensemble_test_driver.dart';
import 'package:ensemble_test_runner/actions/extended_step_handlers.dart';
import 'package:ensemble_test_runner/actions/http_request_action.dart';
import 'package:ensemble_test_runner/actions/screenshot_device.dart';
import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/discovery/ensemble_test_execution_planner.dart';
import 'package:ensemble_test_runner/entry/application_test_entry.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/mocks/test_logger.dart';
import 'package:ensemble_test_runner/mocks/wifi_test_setup.dart';
import 'package:ensemble_test_runner/reporters/test_reporter.dart';
import 'package:ensemble_test_runner/runner/app_performance_log.dart';
import 'package:ensemble_test_runner/runner/app_session_snapshot.dart';
import 'package:ensemble_test_runner/runner/debug_artifact_logs.dart';
import 'package:ensemble_test_runner/runner/diagnostic_ui_snapshot.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/runner/failure_observer_capture.dart';
import 'package:ensemble_test_runner/runner/flutter_error_filters.dart';
import 'package:ensemble_test_runner/runner/live_async_call.dart';
import 'package:ensemble_test_runner/runner/screenshot_capture.dart';
import 'package:ensemble_test_runner/runner/screenshot_contact_sheet.dart';
import 'package:ensemble_test_runner/runner/screenshot_lottie_ready.dart';
import 'package:ensemble_test_runner/runner/screenshot_sheet_aggregator.dart';
import 'package:ensemble_test_runner/runner/step_highlight_finder.dart';
import 'package:ensemble_test_runner/runner/step_report_capture.dart';
import 'package:ensemble_test_runner/runner/storage_step_diff.dart';
import 'package:ensemble_test_runner/runner/test_artifacts.dart';
import 'package:ensemble_test_runner/runner/test_runtime_state.dart';
import 'package:ensemble_test_runner/runner/test_service_manager.dart';
import 'package:ensemble_test_runner/runner/yaml_test_session.dart';
import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:ensemble_test_runner/session/local/modal_route_lookup.dart';
import 'package:ensemble_test_runner/session/yaml/yaml_step_dispatcher.dart';
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
  final EnsembleTestHarness? _legacyHarness;
  final ApplicationTestDriver? _applicationDriver;
  final StandaloneEnsembleTestDriver? _standaloneDriver;
  ScreenshotSheetAggregator? _activeScreenshotSheets;

  /// Creates a runner backed by [harness].
  EnsembleTestRunner({required EnsembleTestHarness harness})
      : _legacyHarness = harness,
        _applicationDriver = null,
        _standaloneDriver = StandaloneEnsembleTestDriver(harness: harness);

  /// Creates a runner backed by an application-owned lifecycle.
  EnsembleTestRunner.application({required ApplicationTestDriver driver})
      : _legacyHarness = null,
        _applicationDriver = driver,
        _standaloneDriver = null;

  EnsembleTestHarness get harness {
    final value = _legacyHarness;
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
  Future<EnsembleTestPlanRunResult> runPlan(
    EnsembleTestExecutionPlan plan,
    WidgetTester tester, {
    EnsembleTestProgressListener? onTestComplete,
  }) async {
    final applicationDriver = _applicationDriver;
    if (applicationDriver != null) {
      final result = await runApplicationTestPlan(
        driver: applicationDriver,
        plan: plan,
        tester: tester,
        mode: plan.config.mode,
      );
      final byId = {for (final item in result.results) item.testId: item};
      if (onTestComplete != null) {
        for (final definition in plan.ordered) {
          final item = byId[definition.testCase.id];
          if (item != null) await onTestComplete(definition, item);
        }
      }
      return EnsembleTestPlanRunResult(
        resultsById: byId,
        suiteLogs: result.suiteLogs,
      );
    }
    const hostOwnsServices = bool.fromEnvironment(
      'ensembleTestHostOwnsServices',
    );
    final services = TestServiceManager(
      hostOwnsServices ? const [] : plan.config.services,
    );
    await tester.runAsync(services.startAll);
    _activeScreenshotSheets = ScreenshotSheetAggregator(
      screenshots: plan.config.screenshots,
      devices: plan.config.devices,
    );
    final suiteContext = TestSuiteContext(
      runId: 'run_${DateTime.now().microsecondsSinceEpoch}',
      config: plan.config,
      launchKind: TestApplicationLaunchKind.standaloneEnsemble,
    );
    await standaloneDriver.setUpSuite(suiteContext);
    try {
      return await _runPlan(
        plan,
        tester,
        onTestComplete: onTestComplete,
      );
    } finally {
      await _activeScreenshotSheets?.flushRemaining();
      _activeScreenshotSheets = null;
      await standaloneDriver.tearDownSuite();
      await LiveAsyncCallSupport.run<void>(services.stopAll);
    }
  }

  Future<EnsembleTestPlanRunResult> _runPlan(
    EnsembleTestExecutionPlan plan,
    WidgetTester tester, {
    EnsembleTestProgressListener? onTestComplete,
  }) async {
    final resultsById = <String, EnsembleSingleTestResult>{};
    final sessionSnapshots = <String, AppSessionSnapshot>{};
    final requestedSessions = plan.ordered
        .map((definition) => definition.testCase.session)
        .whereType<String>()
        .toSet();

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
      if (out.result.status == TestStatus.passed &&
          requestedSessions.contains(test.id)) {
        sessionSnapshots[test.id] = await AppSessionSnapshot.capture();
      }
    }

    return EnsembleTestPlanRunResult(
      resultsById: resultsById,
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

    final previousLiveAsyncRunner = LiveAsyncCallSupport.runner;
    final previousDrainPendingExceptions =
        LiveAsyncCallSupport.drainPendingExceptions;
    try {
      FlutterError.onError = (details) {
        final formatted = _formatFlutterError(details);
        if (isNonFatalFlutterDiagnostic(formatted) ||
            isTransientNavigationDiagnostic(formatted)) {
          return;
        }
        ctx.runtime.flutterErrors.add(formatted);
      };
      applyWifiTestConfig(suiteConfig.wifi);
      timingsCallback = (List<ui.FrameTiming> timings) {
        ctx.runtime.addFrameTimings(timings);
      };

      SchedulerBinding.instance.addTimingsCallback(timingsCallback);
      ctx.apiOverlay.liveAsyncRunner = tester.runAsync;
      LiveAsyncCallSupport.runner = tester.runAsync;
      // Inspect pending framework exceptions at explicit lifecycle boundaries;
      // do not discard them from async-call cleanup.
      LiveAsyncCallSupport.drainPendingExceptions = null;

      return await runZoned(
        () async {
          final startupStartFrame = ctx.runtime.appFrameTimings.length + 1;
          final startupStartTime = DateTime.now();

          final launchContext = TestLaunchContext(
            attemptId: '${test.id}_${stopwatch.elapsedMicroseconds}',
            attempt: 0,
            testCase: test,
            config: suiteConfig,
          );
          await standaloneDriver.prepareTest(launchContext);

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
          _throwIfUnexpectedFlutterExceptions(
            tester,
            ctx: ctx,
            phase: 'during startup/setup',
          );
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
        zoneSpecification: ctx.runtime.consoleCaptureZone,
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
      final callback = timingsCallback;
      if (callback != null) {
        SchedulerBinding.instance.removeTimingsCallback(callback);
      }
      FlutterError.onError = previousOnError;
      LiveAsyncCallSupport.runner = previousLiveAsyncRunner;
      LiveAsyncCallSupport.drainPendingExceptions =
          previousDrainPendingExceptions;
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
    final executorServices = StandaloneEnsembleApplicationHandle(
      context: ctx,
      configDescription: const {},
    ).services;
    final assertions = AssertionEngine(
      tester: tester,
      context: ctx,
      services: executorServices,
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: ctx,
      assertions: assertions,
      harness: harness,
      services: executorServices,
      config: config,
    );
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      harness: harness,
      context: ctx,
      services: executorServices,
      sessionId: test.id,
      assertions: assertions,
      executor: executor,
    );
    final dispatcher = YamlStepDispatcher(session: session);
    final stepDurationsMs = <int>[];
    final stepStartTimes = <String>[];
    try {
      for (var i = 0; i < test.steps.length; i++) {
        final step = test.steps[i];
        final startFrame = ctx.runtime.appFrameTimings.length + 1;
        final startTime = DateTime.now();
        ctx.runtime.currentStepIndex = i;
        stepStartTimes.add(startTime.toIso8601String());
        final storageBefore = capturePublicStorage();
        final secureStorageBefore = captureSecureStorage();
        final keychainBefore = await captureKeychainStorage();
        var capturedStep = false;
        try {
          _throwIfUnexpectedFlutterExceptions(
            tester,
            ctx: ctx,
            phase: 'before this step',
          );
          if (i == 0 && ctx.config.screenshots.enabled) {
            await executor.settle();
          }
          final captureBeforeStep = _shouldCaptureBeforeStep(step);
          if (captureBeforeStep) {
            final didCapture = await _captureStepReportArtifacts(
              session: session,
              executor: executor,
              step: step,
              stepIndex: i,
              options: StepScreenshotOptions.beforeAction(),
            );
            if (didCapture) capturedStep = true;
          }
          if (step.type == 'waitForText') {
            executor.onWaitForTextMatched = (matchedStep) async {
              if (capturedStep) return;
              await _waitForHighlightTargetToPaint(executor, matchedStep);
              final didCapture = await _captureStepReportArtifacts(
                session: session,
                executor: executor,
                step: matchedStep,
                stepIndex: i,
                options: StepScreenshotOptions.waitForTextMatched(),
              );
              if (didCapture) capturedStep = true;
            };
          }
          if (step.type == 'waitForNavigation') {
            // Capture while the target screen is still the current route.
            // Immediate pixels are wrong for durable screens (Home) whose tracker
            // updates before paint; long waits are wrong for transient screens
            // (AutoSignIn_Gateway → Home). Paint briefly, then choose.
            executor.onWaitForNavigationMatched = (matchedStep) async {
              if (capturedStep) return;
              final didCapture = await _captureStepReportArtifacts(
                session: session,
                executor: executor,
                step: matchedStep,
                stepIndex: i,
                options: StepScreenshotOptions.waitForNavigationMatched(),
                captureScreenshot: () => _captureWaitForNavigationScreenshot(
                  session: session,
                  executor: executor,
                  step: matchedStep,
                  stepIndex: i,
                ),
              );
              if (didCapture) capturedStep = true;
            };
          }
          final optionalActionStep = _singleNestedOptionalAction(step);
          if (optionalActionStep != null) {
            Future<void> captureOptionalAction(TestStep matchedStep) async {
              if (capturedStep) return;
              final didCapture = await _captureStepReportArtifacts(
                session: session,
                executor: executor,
                step: matchedStep,
                labelStep: step,
                stepIndex: i,
                // Optional taps often fire on empty loading frames — keep the
                // contrast gate so phantom rings never become report shots.
                options: StepScreenshotOptions.beforeAction(
                  requireVisibleActionHighlight: true,
                ),
              );
              if (didCapture) capturedStep = true;
            }

            if (_shouldCaptureBeforeStep(optionalActionStep)) {
              executor.onBeforeActionStep = captureOptionalAction;
            } else {
              executor.onAfterActionStep = captureOptionalAction;
            }
          }
          try {
            await dispatcher.execute(step);
          } finally {
            executor.onWaitForTextMatched = null;
            executor.onWaitForNavigationMatched = null;
            executor.onBeforeActionStep = null;
            executor.onAfterActionStep = null;
          }
          if (ctx.config.screenshots.enabled && _isUserActionStep(step)) {
            await _paintAfterUserAction(executor);
          }
          _throwIfUnexpectedFlutterExceptions(
            tester,
            ctx: ctx,
            phase: 'after this step',
          );
          if (!captureBeforeStep &&
              !capturedStep &&
              optionalActionStep == null) {
            final didCapture = await _captureStepReportArtifacts(
              session: session,
              executor: executor,
              step: step,
              stepIndex: i,
              options: StepScreenshotOptions.afterCondition(step),
            );
            if (didCapture) capturedStep = true;
          }
          // Pairs already wrote Observer. Fill only when a shot exists without
          // overlays (should be rare after mid-wait allowWhileQueueBusy).
          if (capturedStep && !hasStepObserver(ctx, i)) {
            await captureStepObserverBestEffort(
              session: session,
              executor: executor,
              stepIndex: i,
              allowWhileQueueBusy: true,
            );
          }
          await YamlTestSession.navigationFlow.flushPending();
          await _recordStorageStepDiff(
            ctx: ctx,
            stepIndex: i,
            before: storageBefore,
            secureBefore: secureStorageBefore,
            keychainBefore: keychainBefore,
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
          _captureScreenArtifacts(ctx);
        } catch (error, stackTrace) {
          await _recordStorageStepDiff(
            ctx: ctx,
            stepIndex: i,
            before: storageBefore,
            secureBefore: secureStorageBefore,
            keychainBefore: keychainBefore,
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
          _captureScreenArtifacts(ctx);
          final idleStartFrame = ctx.runtime.appFrameTimings.length + 1;
          final idleStartTime = DateTime.now();
          // Freeze failure evidence before settle/pumps advance the tree.
          final frameworkErrors = _takeUnexpectedFlutterExceptions(tester);
          if (!capturedStep) {
            await _captureStepReportArtifacts(
              session: session,
              executor: executor,
              step: step,
              stepIndex: i,
              options: StepScreenshotOptions.onFailure(),
            );
          } else if (!hasStepObserver(ctx, i)) {
            await captureStepObserverBestEffort(
              session: session,
              executor: executor,
              stepIndex: i,
              allowWhileQueueBusy: true,
            );
          }
          await _settleLiveApiWorkBestEffort(tester, ctx);
          var failureMessage = _failureMessageWithFlutterErrors(
            error.toString(),
            ctx,
          );
          if (frameworkErrors.isNotEmpty) {
            failureMessage = '$failureMessage\n'
                'Unexpected Flutter framework error: '
                '${_compactDiagnostic(frameworkErrors.first)}';
          }
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
            failure: TestFailureDetails.fromMessage(
              failureMessage,
              phase: 'execution',
              target: {
                if (step.args['id'] != null) 'id': step.args['id'],
                if (step.args['target'] is Map)
                  'target': Map<String, dynamic>.from(
                    step.args['target'] as Map,
                  ),
              },
            ),
            report: buildTestReportDetails(
              test,
              stepDurationsMs: stepDurationsMs,
              stepStartTimes: stepStartTimes,
              screens: ctx.runtime.screenArtifacts,
            ),
          );
        }
      }
      ctx.runtime.currentStepIndex = null;

      await YamlTestSession.navigationFlow.flushPending();
      final idleStartFrame = ctx.runtime.appFrameTimings.length + 1;
      final idleStartTime = DateTime.now();
      await _settleLiveApiWorkBestEffort(tester, ctx);
      // Steps already passed — live API/JS often races dispose during idle
      // settle (null-check / deactivated ancestor). Only fail if the tree
      // was replaced with ErrorWidget.
      try {
        _assertNoErrorWidgetAfterSuccess(tester, ctx);
      } catch (error) {
        final failureIndex =
            test.steps.isEmpty ? null : test.steps.length - 1;
        if (failureIndex != null) {
          await captureStepObserverBestEffort(
            session: session,
            executor: executor,
            stepIndex: failureIndex,
          );
        }
        final failureMessage = error.toString();
        await _flushPendingScreenshots(
          ctx,
          status: TestStatus.failed,
          durationMs: stopwatch.elapsedMilliseconds,
          failedStepIndex: failureIndex,
          failedStepLabel:
              test.steps.isEmpty ? null : formatStepBrief(test.steps.last),
          failureMessage: failureMessage,
        );
        await _attachPerTestDebugArtifacts(ctx);
        return EnsembleSingleTestResult.failed(
          testId: test.id,
          metadata: test.metadataJson,
          failedStepIndex: test.steps.isEmpty ? null : test.steps.length - 1,
          failedStep: test.steps.isEmpty ? null : test.steps.last,
          error: failureMessage,
          stackTrace: StackTrace.current.toString(),
          durationMs: stopwatch.elapsedMilliseconds,
          logs: ctx.logger.logs,
          failure: TestFailureDetails.fromMessage(
            failureMessage,
            phase: 'execution',
          ),
          report: buildTestReportDetails(
            test,
            stepDurationsMs: stepDurationsMs,
            stepStartTimes: stepStartTimes,
            screens: ctx.runtime.screenArtifacts,
          ),
        );
      }
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
          screens: ctx.runtime.screenArtifacts,
        ),
      );
    } finally {
      await session.close();
    }
  }

  /// Screenshots for [waitForNavigation]: durable screens need a paint pass;
  /// transient screens must keep a pre-navigation frame.
  ///
  /// Returns whether a frame was recorded. For transient (early-frame) paths,
  /// also writes Observer from a snapshot taken while the target was visible
  /// so overlays do not drift to the next route.
  Future<bool> _captureWaitForNavigationScreenshot({
    required LocalTestExecutionSession session,
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
    if (treeHasFlutterErrorWidget(executor.tester)) return false;

    // Hold a frame + Observer tree from the moment the tracker reports the
    // target. Transient screens (AutoSignIn_Gateway) often leave during the
    // paint pumps below — re-observing then would label the next route.
    ui.Image? earlyImage;
    DiagnosticUiSnapshot? earlySnap;
    try {
      earlyImage = ExtendedStepHandlers.captureScreenshotImage(
        executor.tester,
        secureContent: executor.context.config.screenshots.secureContent,
      );
      earlySnap = captureDiagnosticUiSnapshot(
        tester: executor.tester,
        assertions: session.assertions,
        navigation: session.services.navigation,
      );
    } catch (_) {
      earlyImage = null;
      earlySnap = null;
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
      earlySnap = null;
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
    if (earlySnap != null) {
      upsertStepObserverFromSnapshot(
        ctx: executor.context,
        tester: executor.tester,
        stepIndex: stepIndex,
        snap: earlySnap,
      );
    }
    return true;
  }

  /// Screenshot + Observer as one pair. Skipped shots never write Observer.
  Future<bool> _captureStepReportArtifacts({
    required LocalTestExecutionSession session,
    required TestStepExecutor executor,
    required TestStep step,
    required int stepIndex,
    required StepScreenshotOptions options,
    TestStep? labelStep,
    Future<bool> Function()? captureScreenshot,
  }) {
    return captureStepReportArtifacts(
      captureScreenshot: captureScreenshot ??
          () => _captureAutomaticScreenshotForStepBestEffort(
                executor: executor,
                step: step,
                stepIndex: stepIndex,
                labelStep: labelStep,
                pumpBeforeCapture: options.pumpBeforeCapture,
                ensureTargetVisible: options.ensureTargetVisible,
                waitForTarget: options.waitForTarget,
                waitForLottie: options.waitForLottie,
                stabilize: options.stabilize,
                forFailure: options.forFailure,
                requireVisibleActionHighlight:
                    options.requireVisibleActionHighlight,
              ),
      captureObserver: () async {
        // Transient waitForNavigation may have already paired Observer with
        // the early frame; do not overwrite with the next route's tree.
        if (hasStepObserver(executor.context, stepIndex)) return;
        await captureStepObserverBestEffort(
          session: session,
          executor: executor,
          stepIndex: stepIndex,
          allowWhileQueueBusy: options.allowObserveWhileQueueBusy,
        );
      },
    );
  }

  Future<bool> _captureAutomaticScreenshotForStep({
    required TestStepExecutor executor,
    required TestStep step,
    required int stepIndex,
    TestStep? labelStep,
    bool pumpBeforeCapture = false,
    bool ensureTargetVisible = true,
    bool waitForTarget = false,
    bool waitForLottie = true,
    bool stabilize = true,
    bool forFailure = false,
    /// When true, skip the frame unless an action highlight lands on pixels
    /// that are not a flat empty region (avoids phantom optional-tap rings).
    bool requireVisibleActionHighlight = false,
  }) async {
    final options = executor.context.config.screenshots;
    if (!options.shouldCaptureStep(step.type)) return false;

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

    final image = ExtendedStepHandlers.captureScreenshotImage(
      executor.tester,
      secureContent: executor.context.config.screenshots.secureContent,
    );
    final device = _screenshotDeviceTarget(executor.context);
    final highlight = _highlightForStep(
      executor: executor,
      image: image,
      step: step,
      device: device,
      forFailure: forFailure,
    );
    if (requireVisibleActionHighlight) {
      final logicalRect =
          _highlightRectForStep(executor, step, forFailure: forFailure);
      final renderView = executor.tester.binding.renderViews.first;
      final region = logicalRect == null
          ? null
          : screenshotLogicalRectToImagePixels(
              logicalRect: logicalRect,
              logicalSize: renderView.size,
              imageSize: Size(image.width.toDouble(), image.height.toDouble()),
            );
      final hasContrast = region != null &&
          highlight != null &&
          highlight.kind == 'action' &&
          await screenshotImageRegionHasContrast(
            image: image,
            region: region,
          );
      if (!hasContrast) {
        image.dispose();
        return false;
      }
    }
    executor.context.runtime.addScreenshotSheetFrame(
      ScreenshotSheetFrame(
        stepIndex: stepIndex,
        label: '${stepIndex + 1}. ${formatStepBrief(labelStep ?? step)}',
        image: image,
        deviceId: device?.id,
        deviceLabel: device?.displayLabel,
        platform: device?.platform,
        model: device?.model,
        highlight: highlight,
      ),
    );
    return true;
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

  Future<bool> _captureAutomaticScreenshotForStepBestEffort({
    required TestStepExecutor executor,
    required TestStep step,
    required int stepIndex,
    TestStep? labelStep,
    bool pumpBeforeCapture = false,
    bool ensureTargetVisible = true,
    bool waitForTarget = false,
    bool waitForLottie = true,
    bool stabilize = true,
    bool forFailure = false,
    bool requireVisibleActionHighlight = false,
  }) async {
    try {
      return await _captureAutomaticScreenshotForStep(
        executor: executor,
        step: step,
        stepIndex: stepIndex,
        labelStep: labelStep,
        pumpBeforeCapture: pumpBeforeCapture,
        ensureTargetVisible: ensureTargetVisible,
        waitForTarget: waitForTarget,
        waitForLottie: waitForLottie,
        stabilize: stabilize,
        forFailure: forFailure,
        requireVisibleActionHighlight: requireVisibleActionHighlight,
      );
    } catch (_) {
      // Screenshot capture must never replace the real test failure.
      return false;
    }
  }

  bool _shouldCaptureBeforeStep(TestStep step) =>
      _isUserActionStep(step) && !_isTextMutationStep(step);

  bool _isTextMutationStep(TestStep step) =>
      step.type == 'enterText' ||
      step.type == 'clearText' ||
      step.type == 'replaceText';

  TestStep? _singleNestedOptionalAction(TestStep step) {
    if (step.type != 'optional' || step.nestedSteps.length != 1) return null;
    final nested = step.nestedSteps.single;
    return _isUserActionStep(nested) ? nested : null;
  }

  bool _isTextVerificationStep(TestStep step) =>
      step.type == 'expectText' ||
      step.type == 'expectTextContains' ||
      step.type == 'waitForText' ||
      step.type == 'expectNoText';

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
    var scrolled = false;
    while (stopwatch.elapsedMilliseconds < timeoutMs) {
      if (_isScreenshotTargetReady(
            executor,
            finder,
            waitsForHitTestable,
          ) &&
          _isHighlightTargetPainted(executor, finder, waitsForHitTestable)) {
        return;
      }
      // Off-screen controls never become "ready" by pumping alone — scroll
      // once so before-action shots match tap's ensureVisible path.
      if (!scrolled && waitsForHitTestable) {
        scrolled = true;
        await _ensureHighlightTargetVisible(executor, step);
        continue;
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
      if (_effectiveOpacity(element) >= 0.85) {
        await executor.tester.pump();
        return;
      }

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

  ui.Rect? _highlightRectForStep(
    TestStepExecutor executor,
    TestStep step, {
    bool forFailure = false,
  }) {
    if (!_shouldHighlightStep(step, forFailure: forFailure)) return null;

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
      // Text asserts and user actions: bring the control fully on-screen.
      // A 1px intersection counts as "visible" for hit-testing, but the
      // before-action screenshot would otherwise crop/miss the control.
      if (_isTextVerificationStep(step) || requireHitTestable) {
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
      if (!isUnderCurrentModalRoute(candidate)) continue;
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
    return stepHighlightFinderForExecutor(executor, step);
  }

  bool _shouldHighlightStep(TestStep step, {bool forFailure = false}) {
    // On success there is nothing to point at for expectNoText; on failure the
    // unexpectedly visible text is exactly what the screenshot should mark.
    if (step.type == 'expectNoText' &&
        !forFailure &&
        (step.args['id']?.toString().isEmpty ?? true) &&
        step.args['target'] is! Map) {
      return false;
    }
    if (step.type == 'waitForText' ||
        step.type == 'expectText' ||
        step.type == 'expectNoText' ||
        step.type == 'waitFor' ||
        step.type == 'expectTextContains' ||
        step.type == 'scrollUntilVisible' ||
        step.type == 'expectVisible') {
      final text = step.args['text']?.toString();
      final anyOf = step.args['anyOf'];
      final id = step.args['id']?.toString();
      final hasAnyOf = anyOf is List && anyOf.isNotEmpty;
      final hasTarget = step.args['target'] is Map;
      return (text != null && text.isNotEmpty) ||
          hasAnyOf ||
          (id != null && id.isNotEmpty) ||
          hasTarget;
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

  Future<void> _paintAfterUserAction(TestStepExecutor executor) async {
    await executor.tester.pump();
    await executor.tester.pump(const Duration(milliseconds: 100));
    await executor.tester.pump();
  }

  ScreenshotHighlight? _highlightForStep({
    required TestStepExecutor executor,
    required ui.Image image,
    required TestStep step,
    required TestDeviceTarget? device,
    bool forFailure = false,
  }) {
    final rect = _highlightRectForStep(executor, step, forFailure: forFailure);
    if (rect == null) return null;

    final tester = executor.tester;
    final renderView = tester.binding.renderViews.first;
    final scaledRect = screenshotLogicalRectToImagePixels(
      logicalRect: Rect.fromLTRB(
        rect.left,
        rect.top,
        rect.right,
        rect.bottom,
      ),
      logicalSize: renderView.size,
      imageSize: Size(image.width.toDouble(), image.height.toDouble()),
    );

    final isTapStep = step.type == 'tap' ||
        step.type == 'doubleTap' ||
        step.type == 'longPress' ||
        step.type == 'tapAt';

    final frameDevice = !framesScreenshotsWithDeviceBezel || device == null
        ? null
        : resolveScreenshotDevice({
            'platform': device.platform,
            'model': device.model,
          });
    final framedRect = screenshotHighlightPercentRect(
      rectInImagePixels: Rect.fromLTRB(
        scaledRect.left,
        scaledRect.top,
        scaledRect.right,
        scaledRect.bottom,
      ),
      imageSize: Size(image.width.toDouble(), image.height.toDouble()),
      frameDevice: frameDevice,
    );

    return ScreenshotHighlight(
      kind: forFailure
          ? 'failure'
          : isTapStep
              ? 'action'
              : 'assertion',
      left: framedRect.left,
      top: framedRect.top,
      width: framedRect.width,
      height: framedRect.height,
    );
  }

  void _captureScreenArtifacts(EnsembleTestContext ctx) {
    final screenName = ScreenTracker().getCurrentScreenIdentifier();
    if (screenName == null || screenName.isEmpty) return;

    String? debugTree;
    if (ctx.config.dumpTree.enabled) {
      try {
        debugTree = captureDebugDumpApp();
      } catch (_) {}
    }

    Map<String, dynamic>? performance;
    if (ctx.config.performance.enabled) {
      try {
        performance = buildScreenPerformanceJson(
          screenName: screenName,
          frames: ctx.runtime.appFrameTimings,
          markers: ctx.runtime.performanceMarkers,
        );
      } catch (_) {}
    }

    if (debugTree != null || performance != null) {
      ctx.runtime.screenArtifacts[screenName] = {
        if (debugTree != null) 'debugTree': debugTree,
        if (performance != null) 'performance': performance,
      };
    }
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

  /// Writes apiCalls / storage / appLogs for one test.
  Future<void> _attachPerTestDebugArtifacts(EnsembleTestContext ctx) async {
    // Isolate each writer so one JSON encoding failure cannot drop the rest
    // (failed tests are when these logs matter most).
    try {
      final apiPath = await writeApiCallsLog(ctx);
      _replaceArtifactLog(ctx.logger, 'apiCalls', apiPath);
    } catch (error) {
      ctx.logger.log('apiCallsError: $error');
    }

    try {
      final storagePath = await writeStorageLog(ctx);
      _replaceArtifactLog(ctx.logger, 'storage', storagePath);
    } catch (error) {
      ctx.logger.log('storageError: $error');
    }

    try {
      final appLogPath = await writeAppConsoleLog(ctx);
      _replaceArtifactLog(ctx.logger, 'appLogs', appLogPath);
    } catch (error) {
      ctx.logger.log('appLogsError: $error');
    }
  }

  Future<void> _recordStorageStepDiff({
    required EnsembleTestContext ctx,
    required int stepIndex,
    required Map<String, dynamic> before,
    required Map<String, dynamic> secureBefore,
    required Map<String, dynamic> keychainBefore,
  }) async {
    final changes = diffStorage(before, capturePublicStorage());
    final secureChanges = diffStorage(secureBefore, captureSecureStorage());
    final keychainChanges = diffStorage(
      keychainBefore,
      await captureKeychainStorage(),
    );
    if (changes.isNotEmpty) {
      ctx.runtime.storageStepDiffs.add(StorageStepDiff(
        stepIndex: stepIndex,
        timestamp: DateTime.now(),
        changes: changes,
      ));
    }
    if (secureChanges.isNotEmpty) {
      ctx.runtime.secureStorageStepDiffs.add(StorageStepDiff(
        stepIndex: stepIndex,
        timestamp: DateTime.now(),
        changes: secureChanges,
      ));
    }
    if (keychainChanges.isNotEmpty) {
      ctx.runtime.keychainStepDiffs.add(StorageStepDiff(
        stepIndex: stepIndex,
        timestamp: DateTime.now(),
        changes: keychainChanges,
      ));
    }
  }

  void _replaceArtifactLog(TestLogger logger, String label, String path) {
    logger.logs.removeWhere((entry) {
      final separator = entry.indexOf(':');
      if (separator <= 0) return false;
      return entry.substring(0, separator).trim() == label;
    });
    logger.log('$label: $path');
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
  }

  List<Object> _takeUnexpectedFlutterExceptions(WidgetTester tester) {
    final errors = <Object>[];
    Object? error;
    while ((error = tester.takeException()) != null) {
      if (!isNonFatalFlutterDiagnostic(error!) &&
          !isTransientNavigationDiagnostic(error)) {
        errors.add(error);
      }
    }
    return errors;
  }

  /// After all YAML steps passed, discard async dispose/API races from idle
  /// settle. Still fail when Flutter painted an [ErrorWidget] (red screen).
  void _assertNoErrorWidgetAfterSuccess(
    WidgetTester tester,
    EnsembleTestContext ctx,
  ) {
    while (tester.takeException() != null) {}
    ctx.runtime.flutterErrors.clear();
    if (!treeHasFlutterErrorWidget(tester)) return;
    throw EnsembleTestFailure(
      'Unexpected Flutter ErrorWidget after the final step. '
      'Hint: inspect the previous step and fix the async work or widget '
      'lifecycle before continuing.',
    );
  }

  void _throwIfUnexpectedFlutterExceptions(
    WidgetTester tester, {
    required EnsembleTestContext ctx,
    required String phase,
  }) {
    final pending = _takeUnexpectedFlutterExceptions(tester);
    ctx.runtime.flutterErrors.removeWhere(isNonFatalFlutterDiagnostic);
    ctx.runtime.flutterErrors.removeWhere(isTransientNavigationDiagnostic);
    final recorded = List<String>.from(ctx.runtime.flutterErrors);
    if (pending.isEmpty && recorded.isEmpty) return;

    // Fail fast — do not keep stepping on a corrupted element tree.
    ctx.runtime.flutterErrors.clear();
    final first = pending.isNotEmpty
        ? _compactDiagnostic(pending.first)
        : _compactDiagnostic(recorded.first);
    throw EnsembleTestFailure(
      'Unexpected Flutter framework error $phase: $first '
      'Hint: inspect the previous step and fix the async work or widget '
      'lifecycle before continuing.',
    );
  }

  String _compactDiagnostic(Object error, {int maxLength = 600}) {
    final normalized = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxLength) return normalized;
    return '${normalized.substring(0, maxLength - 3)}...';
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
    return '$message\nFlutter framework error: '
        '${_compactDiagnostic(errors.first)}';
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
    final stepObservers = List<StepObserverArtifact>.from(
      ctx.runtime.stepObservers,
    );
    ctx.runtime.stepObservers.clear();
    if (sheetFrames.isEmpty &&
        stepObservers.isEmpty &&
        !ctx.config.hasDeviceMatrix) {
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
      stepObservers: stepObservers,
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
      final image = ExtendedStepHandlers.captureScreenshotImage(
        tester,
        secureContent: config.screenshots.secureContent,
      );
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
