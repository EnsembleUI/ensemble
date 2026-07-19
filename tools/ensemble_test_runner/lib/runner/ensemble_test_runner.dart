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
import 'package:ensemble_test_runner/reporters/test_reporter.dart';
import 'package:ensemble_test_runner/runner/app_performance_log.dart';
import 'package:ensemble_test_runner/runner/app_session_snapshot.dart';
import 'package:ensemble_test_runner/runner/debug_artifact_logs.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/runner/live_async_call.dart';
import 'package:ensemble_test_runner/runner/screenshot_contact_sheet.dart';
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
    try {
      return await _runPlan(
        plan,
        tester,
        onTestComplete: onTestComplete,
      );
    } finally {
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
    var config = await harness.buildConfig();

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
          existingConfig: config,
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

    try {
      FlutterError.onError = (details) {
        ctx.runtime.flutterErrors.add(_formatFlutterError(details));
      };
      timingsCallback = (List<ui.FrameTiming> timings) {
        ctx.runtime.addFrameTimings(timings);
      };

      SchedulerBinding.instance.addTimingsCallback(timingsCallback);
      ctx.apiOverlay.liveAsyncRunner = tester.runAsync;
      LiveAsyncCallSupport.runner = tester.runAsync;
      LiveAsyncCallSupport.drainPendingExceptions = () {
        while (tester.takeException() != null) {}
      };
      final startupStartFrame = ctx.runtime.appFrameTimings.length + 1;
      final startupStartTime = DateTime.now();

      late final EnsembleConfig config;
      if (sessionSnapshot != null) {
        if (!YamlTestSession.runtimeBootstrapped) {
          throw EnsembleTestFailure(
            'Test "${test.id}" requires a mounted session runtime',
          );
        }
        await sessionSnapshot.restore();
        await _executeSetup(test);
        await EnsembleTestHarness.applyInPlaceSetup(ctx);
        config = existingConfig ?? Ensemble().getConfig()!;
        await EnsembleTestHarness.openSessionScreen(tester, test);
      } else {
        config = await harness.loadScreen(
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
      }
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
      return (result: result, config: config, context: ctx);
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
    for (var i = 0; i < test.steps.length; i++) {
      final step = test.steps[i];
      final startFrame = ctx.runtime.appFrameTimings.length + 1;
      final startTime = DateTime.now();
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
            );
            capturedStep = true;
          };
        }
        try {
          await executor.execute(step);
        } finally {
          executor.onWaitForTextMatched = null;
        }
        _drainPendingFlutterExceptions(tester);
        if (!captureBeforeStep && !capturedStep) {
          await _captureAutomaticScreenshotForStep(
            executor: executor,
            step: step,
            stepIndex: i,
            pumpBeforeCapture: _shouldPumpBeforePostStepCapture(step),
          );
          capturedStep = true;
        }
        await YamlTestSession.navigationFlow.flushPending();
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
        await _flushPendingScreenshots(
          ctx,
          status: TestStatus.failed,
          durationMs: stopwatch.elapsedMilliseconds,
          failedStepIndex: i,
          failedStepLabel: formatStepBrief(step),
          failureMessage: error.toString(),
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
    bool pumpBeforeCapture = false,
    bool ensureTargetVisible = true,
    bool waitForTarget = false,
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

    executor.context.runtime.addScreenshotSheetFrame(
      ScreenshotSheetFrame(
        stepIndex: stepIndex,
        label: '${stepIndex + 1}. ${formatStepBrief(step)}',
        image: image,
      ),
    );

    _updatePendingScreenshotSheet(executor.context);
  }

  Future<void> _captureAutomaticScreenshotForStepBestEffort({
    required TestStepExecutor executor,
    required TestStep step,
    required int stepIndex,
    bool pumpBeforeCapture = false,
    bool ensureTargetVisible = true,
    bool waitForTarget = false,
  }) async {
    try {
      await _captureAutomaticScreenshotForStep(
        executor: executor,
        step: step,
        stepIndex: stepIndex,
        pumpBeforeCapture: pumpBeforeCapture,
        ensureTargetVisible: ensureTargetVisible,
        waitForTarget: waitForTarget,
      );
    } catch (_) {
      // Screenshot capture must never replace the real test failure.
    }
  }

  bool _shouldCaptureBeforeStep(TestStep step) => _isUserActionStep(step);

  bool _shouldPumpBeforePostStepCapture(TestStep step) =>
      step.type != 'waitForText';

  Future<void> _waitForScreenshotTarget(
    TestStepExecutor executor,
    TestStep step,
  ) async {
    if (!_shouldHighlightStep(step)) return;

    final finder = _highlightFinder(executor, step);
    if (finder == null) return;
    if (finder.evaluate().isNotEmpty) return;

    final waitsForHitTestable = _isUserActionStep(step);
    final timeoutMs = step.args['timeoutMs'] as int? ??
        executor.config.defaultWaitTimeout.inMilliseconds;
    final stopwatch = Stopwatch()..start();
    while (stopwatch.elapsedMilliseconds < timeoutMs) {
      await executor.tester.pump(executor.config.waitPollInterval);
      if (_isScreenshotTargetReady(finder, waitsForHitTestable)) return;
    }
  }

  bool _isScreenshotTargetReady(Finder finder, bool waitsForHitTestable) {
    if (waitsForHitTestable) {
      return finder.hitTestable().evaluate().isNotEmpty;
    }
    return finder.evaluate().isNotEmpty;
  }

  Future<void> _waitForHighlightTargetToPaint(
    TestStepExecutor executor,
    TestStep step,
  ) async {
    if (step.type != 'waitForText') return;

    for (var i = 0; i < 8; i++) {
      final finder = _highlightFinder(executor, step);
      final elements = finder?.evaluate().toList() ?? const <Element>[];
      if (elements.isEmpty) return;
      if (_effectiveOpacity(elements.first) >= 0.85) return;

      await executor.tester.pump(const Duration(milliseconds: 50));
    }
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
    final elements = finder.evaluate();
    if (elements.isEmpty) return null;

    try {
      final rect = executor.tester.getRect(finder.first);
      if (rect.isFinite && !rect.isEmpty) {
        return rect;
      }
    } catch (_) {
      // Fall back to render-object traversal below.
    }

    return _rectForElement(elements.first);
  }

  Future<void> _ensureHighlightTargetVisible(
    TestStepExecutor executor,
    TestStep step,
  ) async {
    if (!_shouldHighlightStep(step)) return;

    final finder = _highlightFinder(executor, step);
    if (finder == null) return;
    if (finder.evaluate().isEmpty) return;

    var visibilityTarget = finder;
    if (step.type == 'toggle' ||
        step.type == 'check' ||
        step.type == 'uncheck') {
      final control = find.descendant(
        of: finder,
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

    if (visibilityTarget.hitTestable().evaluate().isNotEmpty) return;

    await executor.tester.ensureVisible(visibilityTarget);
    await executor.tester.pump();
  }

  Finder? _highlightFinder(TestStepExecutor executor, TestStep step) {
    final id = step.args['id']?.toString();
    if (id != null && id.isNotEmpty) {
      return executor.assertions.finderForId(id);
    }
    final text = step.args['text']?.toString();
    if (text != null && text.isNotEmpty) {
      if (step.type == 'expectTextContains') {
        final hitTestableText = find.textContaining(text).hitTestable();
        if (hitTestableText.evaluate().isNotEmpty) {
          return hitTestableText;
        }
        return find.textContaining(text);
      } else {
        final hitTestableText = find.text(text).hitTestable();
        if (hitTestableText.evaluate().isNotEmpty) {
          return hitTestableText;
        }
        return find.text(text);
      }
    }
    return null;
  }

  ui.Rect? _rectForElement(Element element) {
    final renderObject = element.renderObject;
    if (renderObject != null) {
      final rect = _rectForRenderObject(renderObject);
      if (rect != null) return rect;
    }

    final rects = <ui.Rect>[];

    void collect(Element child) {
      final childRenderObject = child.renderObject;
      if (childRenderObject != null) {
        final rect = _rectForRenderObject(childRenderObject);
        if (rect != null) rects.add(rect);
      }
      child.visitChildren(collect);
    }

    element.visitChildren(collect);
    if (rects.isEmpty) return null;
    return rects.reduce((a, b) => a.expandToInclude(b));
  }

  ui.Rect? _rectForRenderObject(RenderObject renderObject) {
    if (renderObject is RenderBox &&
        renderObject.hasSize &&
        renderObject.size.longestSide > 0) {
      final topLeft = renderObject.localToGlobal(ui.Offset.zero);
      final rect = topLeft & renderObject.size;
      if (rect.isFinite && !rect.isEmpty) {
        return rect;
      }
    }

    final rects = <ui.Rect>[];

    void collect(RenderObject object) {
      if (object is RenderBox &&
          object.hasSize &&
          object.size.longestSide > 0) {
        final topLeft = object.localToGlobal(ui.Offset.zero);
        final rect = topLeft & object.size;
        if (rect.isFinite && !rect.isEmpty) {
          rects.add(rect);
        }
      }
      object.visitChildren(collect);
    }

    collect(renderObject);
    if (rects.isEmpty) return null;

    return rects.reduce((a, b) => a.expandToInclude(b));
  }

  bool _shouldHighlightStep(TestStep step) {
    if (step.type == 'waitForText' ||
        step.type == 'expectText' ||
        step.type == 'waitFor' ||
        step.type == 'expectTextContains' ||
        step.type == 'scrollUntilVisible' ||
        step.type == 'expectVisible') {
      final text = step.args['text']?.toString();
      final id = step.args['id']?.toString();
      return (text != null && text.isNotEmpty) || (id != null && id.isNotEmpty);
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

    if (config.logApiCalls.enabled) {
      final path = await writeApiCallsLogFile(
        logger: logger,
        filePrefix: '',
        calls: apiCalls,
      );
      logs.add('apiCalls: $path');
    }

    if (config.logStorage.enabled && lastContext != null) {
      final key = config.logStorage.key;
      final path = await writeStorageLogFile(
        logger: logger,
        filePrefix: '',
        key: key,
      );
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
    if (sheetFrames.isEmpty) return;

    final path = await LiveAsyncCallSupport.run<String?>(
      () => writeScreenshotContactSheet(
        testId: ctx.testCase.id,
        config: ctx.config.screenshots,
        frames: sheetFrames,
        status: status,
        durationMs: durationMs,
        failedStepIndex: failedStepIndex,
        failedStepLabel: failedStepLabel,
        failureMessage: failureMessage,
      ),
    );
    if (path != null) {
      ctx.logger.log('screenshots: $path');
    }
  }

  void _updatePendingScreenshotSheet(EnsembleTestContext ctx) {
    if (!ctx.config.screenshots.enabled) return;
    final frames = List<ScreenshotSheetFrame>.from(
      ctx.runtime.screenshotSheetFrames,
    );
    if (frames.isEmpty) return;

    final testId = ctx.testCase.id;
    final config = ctx.config.screenshots;

    LiveAsyncCallSupport.run<String?>(
      () => writeScreenshotContactSheet(
        testId: testId,
        config: config,
        frames: frames,
        status: TestStatus.pending,
        durationMs: 0,
      ),
    ).catchError((_) => null);
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
      final path = await LiveAsyncCallSupport.run<String?>(
        () => writeScreenshotContactSheet(
          testId: test.id,
          config: config.screenshots,
          frames: [
            ScreenshotSheetFrame(
              stepIndex: 0,
              label: 'Runner failure',
              image: image,
            ),
          ],
          status: TestStatus.failed,
          durationMs: 0,
          failedStepIndex: 0,
          failedStepLabel: 'Runner failure',
          failureMessage: error.toString(),
        ),
      );
      return path == null ? const [] : ['screenshots: $path'];
    } catch (_) {
      return const [];
    }
  }
}
