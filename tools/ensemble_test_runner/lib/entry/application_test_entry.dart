library;

import 'dart:ui' as ui;

import 'package:ensemble/framework/screen_tracker.dart';
export 'application_test_entry_support.dart'
    show ensureHostFixturesSupported, hostProcessServiceConfigs;

import 'package:ensemble_test_runner/src/benchmark_measurement.dart';

import 'package:ensemble_test_runner/application/application_test_driver.dart';
import 'package:ensemble_test_runner/application/application_suite_execution_boundary.dart';
import 'package:ensemble_test_runner/discovery/ensemble_test_execution_planner.dart';
import 'package:ensemble_test_runner/discovery/flutter_test_execution_planner.dart';
import 'package:ensemble_test_runner/entry/host_test_artifacts.dart';
import 'package:ensemble_test_runner/entry/test_entry_environment.dart';
import 'package:ensemble_test_runner/entry/test_execution_mode.dart';
import 'package:ensemble_test_runner/entry/application_test_entry_support.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/reporters/test_reporter.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/flutter_error_isolation.dart';
import 'package:ensemble_test_runner/runner/test_artifacts.dart';
import 'package:ensemble_test_runner/runner/app_performance_log.dart';
import 'package:ensemble_test_runner/runner/test_runtime_state.dart';
import 'package:ensemble_test_runner/mocks/firebase_remote_config_test_setup.dart';
import 'package:ensemble_test_runner/runner/storage_step_diff.dart';
import 'package:ensemble_test_runner/runner/test_artifact_coordinator.dart';
import 'package:ensemble_test_runner/src/integrations/firebase/firebase_test_registration.dart';
import 'package:ensemble_test_runner/runner/test_service_manager.dart';
import 'package:ensemble_test_runner/runner/retry_execution.dart';
import 'package:ensemble_test_runner/runner/attempt_lifecycle_coordinator.dart';
import 'package:ensemble_test_runner/runner/setup_step_executor.dart';
import 'package:ensemble_test_runner/session/errors/test_execution_error.dart';
import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:ensemble_test_runner/session/observation/observation_options.dart';
import 'package:ensemble_test_runner/session/session_capabilities.dart';
import 'package:ensemble_test_runner/src/runtime/compiled_plan.dart';
import 'package:ensemble_test_runner/src/core/kernel.dart';
import 'package:ensemble_test_runner/src/core/operation.dart';
import 'package:ensemble_test_runner/src/core/attempt_coordinator.dart';
import 'package:ensemble_test_runner/src/core/execution_kernel_runner.dart';
import 'package:ensemble_test_runner/runner/suite_case_coordinator.dart';
import 'package:ensemble_test_runner/src/runtime/step_evidence_subscriber.dart';
import 'package:ensemble_test_runner/src/runtime/step_evidence_policy.dart';
import 'package:ensemble_test_runner/src/core/step_execution_tracker.dart';
import 'package:ensemble_test_runner/src/core/step_context_subscriber.dart';
import 'package:ensemble_test_runner/runtime/serialized_plan_batch_loader.dart';
import 'package:ensemble_test_runner/src/runtime/flutter_test_runtime.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/scheduler.dart';

/// Registers and executes declarative tests against an application-provided driver.
///
/// Mode comes from `--dart-define=ensembleTestExecutionMode=` (set by the CLI
/// for `--mode=integration`). Hosts only need:
/// ```dart
/// Future<void> main() => runApplicationTests(driver: MyDriver());
/// ```
///
Future<void> runApplicationTests({
  required ApplicationTestDriver driver,
  String? testsAssetPrefix,
}) async {
  final mode = executionModeFromEnvironment();
  ensureApplicationTestBinding(mode);
  return registerApplicationTests(
    driver: driver,
    mode: mode,
    testsAssetPrefix: testsAssetPrefix,
  );
}

/// Registers a host suite after the caller selected the Flutter test binding.
Future<void> registerApplicationTests({
  required ApplicationTestDriver driver,
  required ExecutionMode mode,
  String? testsAssetPrefix,
}) async {
  final prefix = normalizedTestAssetPrefix(
    testsAssetPrefix ??
        const String.fromEnvironment(
          'ensembleTestTestsAssetPrefix',
          defaultValue: 'tests/',
        ),
  );

  final resolved = resolveExecutionMode(mode);
  // Match the standard Ensemble entry point: Firebase is ready by default for
  // widget-mode host apps. Integration mode uses the native host plugins.
  EnsembleTestHarness.configureTestIntegrations(
    resolved == ExecutionMode.widget
        ? const [firebaseTestIntegration]
        : const [],
  );
  if (resolved == ExecutionMode.integration) {
    // Keep integration runs deterministic and offline-capable for Remote
    // Config, just like widget runs. The adapter preserves app defaults and
    // avoids Firebase Installations network calls that are unrelated to the
    // UI under test.
    ensureRemoteConfigForTest();
  }
  configureArtifactTransport(resolved);
  final transport = resolved == ExecutionMode.integration;
  var transportCompleted = false;
  void completeTransportIfNeeded() {
    if (!transport || transportCompleted) return;
    transportCompleted = true;
    emitEnsembleTestArtifactTransportComplete();
  }

  // Uncaught plugin errors can finish the Flutter test before the suite
  // `finally` runs. tearDown still emits complete so the CLI gets a report.
  tearDown(() {
    completeTransportIfNeeded();
    EnsembleTestHarness.disposeTestStorage();
  });

  testWidgets('Application *.test.yaml', (tester) async {
    await EnsembleTestHarness.runWithRealNetworkHttpOverrides(() =>
        withFlutterErrorIsolation(() async {
          if (transport) {
            emitEnsembleTestArtifactTransportBegin();
          }
          var emittedResult = false;
          try {
            final workerBatch = await workerBatchFromEnvironment();
            final plan = workerBatch?.plan ??
                await FlutterTestExecutionPlanner.build(
                  testsAssetPrefix: prefix,
                  inputs: testInputsFromEnvironment(),
                  selection: testSelectionFromEnvironment(),
                );
            final serializedPlans = workerBatch?.serializedPlans ?? const {};
            final runResult = await runApplicationTestPlan(
              driver: driver,
              plan: plan,
              tester: tester,
              mode: resolved,
              serializedPlans: serializedPlans,
              onTestStart: emitTestProgressStart,
              onTestComplete: emitTestProgressComplete,
            );
            final reporter = TestReporter();
            print(
              reporter.formatSummary(runResult, testFile: '$prefix*.test.yaml'),
            );
            emitMachineTestReport(runResult);
            emittedResult = true;
            if (runResult.failedCount > 0) {
              fail(reporter.formatFailureSummary(runResult));
            }
          } catch (error, stackTrace) {
            // A failing case is intentionally surfaced to flutter_test after its
            // detailed result has been emitted. Do not replace that report with a
            // synthetic test-process row when catching the assertion used to fail
            // the suite.
            if (emittedResult) rethrow;
            final runResult = EnsembleTestRunResult(
              results: [
                EnsembleSingleTestResult.failed(
                  testId: 'test-process',
                  durationMs: 0,
                  message: error.toString(),
                  stackTrace: stackTrace.toString(),
                ),
              ],
              suiteLogs: const [],
              metadata: {
                'mode': resolved.name,
                'launchKind': 'applicationProvided',
              },
            );
            final reporter = TestReporter();
            print(reporter.formatSummary(runResult,
                testFile: '$prefix*.test.yaml'));
            emitMachineTestReport(runResult);
            fail(reporter.formatFailureSummary(runResult));
          } finally {
            completeTransportIfNeeded();
          }
        }));
  });
}

/// Executes an already-resolved plan through an application driver.
Future<EnsembleTestRunResult> runApplicationTestPlan({
  required ApplicationTestDriver driver,
  required EnsembleTestExecutionPlan plan,
  required WidgetTester tester,
  required ExecutionMode mode,
  Map<String, String> serializedPlans = const {},
  SuiteCaseStart? onTestStart,
  SuiteCaseProgress? onTestComplete,
}) {
  return withFlutterErrorIsolation(() => _runApplicationTestPlanIsolated(
        driver: driver,
        plan: plan,
        tester: tester,
        mode: mode,
        serializedPlans: serializedPlans,
        onTestStart: onTestStart,
        onTestComplete: onTestComplete,
      ));
}

Future<EnsembleTestRunResult> _runApplicationTestPlanIsolated({
  required ApplicationTestDriver driver,
  required EnsembleTestExecutionPlan plan,
  required WidgetTester tester,
  required ExecutionMode mode,
  required Map<String, String> serializedPlans,
  SuiteCaseStart? onTestStart,
  SuiteCaseProgress? onTestComplete,
}) async {
  return await RunnerBenchmark.async(
      'workflow', 'runApplicationTestPlanIsolated', () async {
    // Direct host-plan execution must initialize the same runtime adapter as
    // the registered test entry. In widget mode this installs the plugin
    // channel doubles used by artifact capture (including secure storage).
    EnsembleTestHarness.runtimeAdapterFor(mode).initialize();
    validateHostPlan(plan, driver);
    final selectedIds =
        plan.ordered.map((definition) => definition.testCase.id).toSet();
    final unexpectedPlanIds = serializedPlans.keys.toSet()
      ..removeAll(selectedIds);
    if (unexpectedPlanIds.isNotEmpty) {
      throw ArgumentError(
        'Serialized plans contain unselected test ids: '
        '${unexpectedPlanIds.join(', ')}.',
      );
    }
    final runId = 'run_${DateTime.now().microsecondsSinceEpoch}';
    final suiteContext = TestSuiteContext(
      runId: runId,
      config: plan.config,
      launchKind: driver is ScreenLaunchApplicationTestDriver
          ? TestApplicationLaunchKind.standaloneEnsemble
          : TestApplicationLaunchKind.applicationProvided,
    );
    final services = TestServiceManager(
      hostProcessServiceConfigs(plan.config.services),
    );
    SuiteCaseRunResult? caseRun;
    final requestedSessions = plan.ordered
        .map((definition) => definition.testCase.session)
        .whereType<String>()
        .toSet();
    Object? suiteFailure;
    StackTrace? suiteStack;
    try {
      caseRun = await const ApplicationSuiteExecutionBoundary().run(
        tester: tester,
        services: services,
        driver: driver,
        context: suiteContext,
        execute: (_) async {
          caseRun = await const SuiteCaseCoordinator<Object>(
            requireKnownDependencies: false,
          ).execute(
            plan,
            serializedPlans: serializedPlans,
            onCaseStart: onTestStart,
            onCaseComplete: onTestComplete,
            runCase: ({
              required test,
              required checkpoint,
              required planReuse,
              required onCheckpoint,
            }) =>
                _runHostTestWithRetries(
              tester: tester,
              driver: driver,
              test: test,
              config: plan.config,
              runId: runId,
              mode: mode,
              checkpoint: checkpoint,
              captureCheckpoint: requestedSessions.contains(test.id),
              onCheckpoint: onCheckpoint,
              planReuse: planReuse,
            ),
            onCaseFailure: (test, error, stackTrace) =>
                EnsembleSingleTestResult.failed(
              testId: test.id,
              metadata: test.metadataJson,
              durationMs: 0,
              message: error.toString(),
              stackTrace: stackTrace.toString(),
              report: hostReport(test, null),
            ),
          );
          return caseRun!;
        },
      );
    } catch (error, stackTrace) {
      suiteFailure = error;
      suiteStack = stackTrace;
    }

    final results = <EnsembleSingleTestResult>[
      ...?caseRun?.resultsById.values,
    ];
    if (suiteFailure != null) {
      final recordedIds = results.map((result) => result.testId).toSet();
      for (final definition in plan.ordered) {
        final test = definition.testCase;
        if (recordedIds.contains(test.id)) continue;
        results.add(EnsembleSingleTestResult.failed(
          testId: test.id,
          metadata: test.metadataJson,
          durationMs: 0,
          message: 'Suite could not execute this case: $suiteFailure',
          stackTrace: suiteStack?.toString(),
          report: hostReport(test, null),
        ));
      }
      results.add(EnsembleSingleTestResult.failed(
        testId: 'test-process',
        durationMs: 0,
        message: suiteFailure.toString(),
        stackTrace: suiteStack?.toString(),
        failure: TestFailureDetails(
          kind: TestFailureKind.cleanup,
          message: suiteFailure.toString(),
          phase: 'suiteCleanup',
        ),
      ));
    }
    return EnsembleTestRunResult(
      results: results,
      suiteLogs: caseRun?.suiteLogs ?? const [],
      metadata: {
        'mode': resolveExecutionMode(mode).name,
        'launchKind': suiteContext.launchKind.name,
      },
    );
  });
}

Future<EnsembleSingleTestResult> _runHostTestWithRetries({
  required WidgetTester tester,
  required ApplicationTestDriver driver,
  required EnsembleTestCase test,
  required EnsembleTestConfig config,
  required String runId,
  required ExecutionMode mode,
  required Object? checkpoint,
  required bool captureCheckpoint,
  required void Function(Object checkpoint) onCheckpoint,
  required CompiledPlanReuse planReuse,
}) async {
  return await RunnerBenchmark.async('workflow', 'runHostTestWithRetries',
      () async {
    return RetryExecutionCoordinator.runResult(
      retries: test.retry,
      executeAttempt: (attemptDescriptor) async {
        return _runHostAttempt(
          tester: tester,
          driver: driver,
          test: test,
          config: config,
          runId: runId,
          mode: mode,
          attempt: attemptDescriptor,
          planReuse: planReuse,
          checkpoint: checkpoint,
          captureCheckpoint: captureCheckpoint,
          onCheckpoint: onCheckpoint,
        );
      },
    );
  });
}

Future<EnsembleSingleTestResult> _runHostAttempt({
  required WidgetTester tester,
  required ApplicationTestDriver driver,
  required EnsembleTestCase test,
  required EnsembleTestConfig config,
  required String runId,
  required ExecutionMode mode,
  required AttemptDescriptor attempt,
  required CompiledPlanReuse planReuse,
  required Object? checkpoint,
  required bool captureCheckpoint,
  required void Function(Object checkpoint) onCheckpoint,
}) async {
  return await RunnerBenchmark.async('workflow', 'runHostAttempt', () async {
    final stopwatch = Stopwatch()..start();
    final lifecycle = AttemptLifecycleCoordinator.forAttempt(
      attemptId: '${runId}_${test.id}_${attempt.index}',
      attempt: attempt,
      test: test,
      config: config,
      checkpoint: checkpoint,
      tester: tester,
    );
    final attemptContext = lifecycle.attemptContext;
    final launchContext = attemptContext.launch;
    final context = attemptContext.runtime;
    void Function(List<ui.FrameTiming>)? timingsCallback;
    final stopTimingsCallback = lifecycle.registerCleanupAfterStart(() async {
      final callback = timingsCallback;
      if (callback != null) {
        SchedulerBinding.instance.removeTimingsCallback(callback);
      }
    });
    final performanceStarts = <int, ({int startFrame, DateTime startTime})>{};
    TestApplicationHandle? handle;
    LocalTestExecutionSession? session;
    StepEvidenceSubscriber? stepEvidence;
    var kernelOwnsSession = false;
    final secondaryFailures = <TestFailureDetails>[];
    String? failureOperation;
    SourceLocation? failureSource;
    TestFailureDetails? kernelFailureDetails;
    // Register attempt-owned resources once, before entering the execution
    // body. The stack makes setup failure, kernel cancellation, and timeout
    // paths use the same idempotent cleanup boundary. Callbacks inspect the
    // ownership flags at close time so resources transferred to the kernel
    // are not closed twice.
    final markDriverSetupStarted = lifecycle.registerCleanupAfterStart(
      () => driver.tearDownTest(tester, launchContext, handle),
    );
    final markSessionSetupStarted = lifecycle.registerCleanupAfterStart(
      () async {
        if (!kernelOwnsSession) await session?.close();
      },
    );
    final indexedSteps = flattenTestSteps(test.steps);
    var failedStepIndex = -1;
    final stepTracker = StepExecutionTracker(
      onStepStarted: (index) {
        failedStepIndex = index;
      },
    );
    final artifactCoordinator = const TestArtifactCoordinator();
    final storageDiffs = StorageStepDiffSubscriber(
      enabled: config.logStorage.enabled,
      recordDiff: (stepIndex, before) =>
          artifactCoordinator.recordStorageStepDiff(
        context: context,
        stepIndex: stepIndex,
        before: before,
      ),
    );
    final stepContext = StepContextSubscriber(
      onStepStarted: (index) => context.runtime.currentStepIndex = index,
      onStepFinished: (index) {
        context.apiOverlay.recorder.observeStepEnd(index);
        context.runtime.currentStepIndex = null;
      },
    );
    context.runtime.consoleLogs.add(
      context.runtime.formatConsoleLine('Started ${test.id}'),
    );
    final attemptOutcome =
        await lifecycle.runCaptured<void, ExecutionKernelRunner, void>(
      prepare: () async {
        if (config.performance.enabled) {
          timingsCallback =
              (timings) => context.runtime.addFrameTimings(timings);
          SchedulerBinding.instance.addTimingsCallback(timingsCallback!);
          stopTimingsCallback();
        }
        await applyHostScreenshotViewport(tester, context, mode: mode);
        if (!EnsembleTestHarness.appFontsLoaded) {
          await context.runtime.runAsyncWithConsoleCapture(
            tester,
            EnsembleTestHarness.ensureAppFontsLoaded,
          );
        }
        markDriverSetupStarted();
        await driver.prepareTest(launchContext);
        if (checkpoint != null) {
          await (driver as ApplicationCheckpointDriver).restoreCheckpoint(
            launchContext,
            checkpoint,
          );
        }
        await const SetupStepExecutor().executeAttemptSetup(
          test,
          afterSteps: () {
            final setup = context.setup;
            final requiresPlatformAsync =
                (setup.initialPublicStorage?.isNotEmpty ?? false) ||
                    (setup.initialSecureStorage?.isNotEmpty ?? false) ||
                    (setup.initialKeychain?.isNotEmpty ?? false);
            final applySetup =
                () => EnsembleTestHarness.applyInPlaceSetup(context);
            // App launches can already have live network/plugin work using
            // WidgetTester.runAsync. Avoid opening a second runAsync scope for
            // the common empty setup (or env/mock-only setup); reserve it for
            // storage seeding, which may cross platform channels.
            return requiresPlatformAsync
                ? context.runtime.runAsyncWithConsoleCapture(tester, applySetup)
                : applySetup();
          },
        );
        // Ensemble overlay path can be verified before launch. Pure Flutter
        // ApiMockingTestService attachment is confirmed right after launch.
        ensureHostFixturesSupported(context);
      },
      launch: (_) async {
        final launched = driver
                is AttemptStateApplicationTestDriver<EnsembleTestContext>
            ? await (driver
                    as AttemptStateApplicationTestDriver<EnsembleTestContext>)
                .launchWithAttemptState(
                tester,
                launchContext,
                context,
              )
            : await driver.launch(tester, launchContext);
        handle = launched;
        await tester.pump();
        ensureHostFixturesSupported(
          context,
          services: launched.services,
          requireResolved: true,
        );

        final attached = LocalTestExecutionSession.attach(
          tester: tester,
          context: context,
          services: launched.services,
          sessionId: test.id,
          permissions: SessionPermissions.testController,
        );
        session = attached;
        markSessionSetupStarted();
        stepEvidence = StepEvidenceSubscriber(
          shouldCaptureStep: (stepIndex) => config.screenshots
              .shouldCaptureStep(indexedSteps[stepIndex].type),
          capture: (stepIndex) => captureHostStepReportArtifactsSafely(
            tester: tester,
            context: context,
            session: attached,
            step: indexedSteps[stepIndex],
            stepIndex: stepIndex,
            secondaryFailures: secondaryFailures,
          ),
          captureBeforeMutation: (event) {
            if (StepEvidencePolicy.classify(event.detail) ==
                StepEvidenceBoundary.navigation) {
              final stepIndex = event.stepIndex!;
              final step = indexedSteps[stepIndex];
              return captureHostStepReportArtifactsSafely(
                tester: tester,
                context: context,
                session: attached,
                step: step,
                stepIndex: stepIndex,
                secondaryFailures: secondaryFailures,
                atCurrentFrame: true,
                prepareCapture: () => prepareHostNavigationMatchCapture(
                  tester: tester,
                  screen: step.args['screen']?.toString(),
                ),
              );
            }
            return captureHostStepReportArtifactsSafely(
              tester: tester,
              context: context,
              session: attached,
              step: indexedSteps[event.stepIndex!],
              stepIndex: event.stepIndex!,
              secondaryFailures: secondaryFailures,
              atCurrentFrame: true,
            );
          },
        );
        final hostPlan = planReuse.plan;
        final kernel = ExecutionKernelRunner(
          plan: hostPlan,
          runtime: FlutterTestRuntime(attached),
          eventSubscriptions: [
            EventSubscription(
              kinds: {
                ExecutionEventKind.stepStarted,
                ExecutionEventKind.stepFinished,
              },
              handle: stepTracker.call,
            ),
            if (config.logStorage.enabled)
              EventSubscription(
                kinds: {
                  ExecutionEventKind.stepStarted,
                  ExecutionEventKind.stepFinished,
                  ExecutionEventKind.attemptFinished,
                },
                handle: storageDiffs.call,
              ),
            EventSubscription(
              kinds: {
                ExecutionEventKind.stepStarted,
                ExecutionEventKind.stepFinished,
              },
              handle: stepContext.call,
            ),
            if (config.screenshots.enabled)
              EventSubscription(
                kinds: {
                  ExecutionEventKind.evidenceBoundary,
                  ExecutionEventKind.stepFinished,
                },
                handle: stepEvidence!.call,
              ),
            if (config.performance.enabled)
              EventSubscription(
                kinds: {
                  ExecutionEventKind.stepStarted,
                  ExecutionEventKind.stepFinished,
                },
                handle: (event) {
                  final stepIndex = event.stepIndex;
                  if (stepIndex == null) return;
                  if (event.kind == ExecutionEventKind.stepStarted) {
                    performanceStarts[stepIndex] = (
                      startFrame: context.runtime.appFrameTimings.length + 1,
                      startTime: DateTime.now(),
                    );
                    return;
                  }

                  final started = performanceStarts.remove(stepIndex);
                  if (started == null) return;
                  final endedAt = DateTime.now();
                  final endFrame = context.runtime.appFrameTimings.length;
                  final screenName =
                      ScreenTracker().getCurrentScreenIdentifier() ??
                          handle?.services.navigation?.currentRoute;
                  if (screenName == null || screenName.isEmpty) return;
                  if (endFrame >= started.startFrame) {
                    context.runtime.recordPerformanceMarker(
                      PerformanceMarker(
                        testId: test.id,
                        stepIndex: stepIndex + 1,
                        label: '${test.id} step ${stepIndex + 1} '
                            '${formatStepBrief(indexedSteps[stepIndex])}',
                        screen: screenName,
                        phase: 'step',
                        startFrame: started.startFrame,
                        endFrame: endFrame,
                        startTime: started.startTime,
                        endTime: endedAt,
                      ),
                    );
                  }
                  final current = context.runtime.screenArtifacts[screenName] ??
                      <String, dynamic>{};
                  context.runtime.screenArtifacts[screenName] = {
                    ...current,
                    'performance': buildScreenPerformanceJson(
                      screenName: screenName,
                      frames: context.runtime.appFrameTimings,
                      markers: context.runtime.performanceMarkers,
                      apiCalls: context.apiOverlay.calls,
                      storageChanges: context.runtime.storageStepDiffs,
                      secureStorageChanges:
                          context.runtime.secureStorageStepDiffs,
                      keychainChanges: context.runtime.keychainStepDiffs,
                      storageDiagnosticsEnabled: config.logStorage.enabled,
                    ),
                  };
                },
              ),
          ],
        );
        // Once run starts, ExecutionKernel closes the runtime (and thus
        // this session) in its finally block. Keep entry cleanup for
        // failures that happen before ownership transfers.
        kernelOwnsSession = true;
        return kernel;
      },
      execute: (_, kernel) async {
        final hostResult = await kernel.run();
        if (hostResult.outcome != AttemptOutcome.passed) {
          failureOperation = hostResult.failureOperation;
          failureSource = hostResult.failureSource;
          final primaryMessage =
              hostResult.primaryFailure ?? 'Execution did not pass.';
          kernelFailureDetails = TestFailureDetails.fromExecutionCode(
            hostResult.failureCode,
            primaryMessage,
            phase: 'execution',
          );
          secondaryFailures.addAll(hostResult.secondaryFailures
              .map(TestFailureDetails.fromSecondaryMessage));
          final index = stepTracker.failureIndex();
          failedStepIndex = index;
          if (stepTracker.activeStepIndex >= 0) {
            await stepEvidence!.captureOnce(
              index,
              () => captureHostStepReportArtifactsSafely(
                tester: tester,
                context: context,
                session: session!,
                step: indexedSteps[index],
                stepIndex: index,
                observationDetail: ObservationDetailLevel.diagnostic,
                secondaryFailures: secondaryFailures,
              ),
              enabled: config.screenshots.shouldCaptureStep(
                indexedSteps[index].type,
              ),
            );
            stepTracker.recordActiveDuration();
          }
          Error.throwWithStackTrace(
            hostResult.cause ??
                EnsembleTestFailure(
                  hostResult.primaryFailure ?? 'Execution did not pass.',
                ),
            hostResult.stackTrace ?? StackTrace.current,
          );
        }
        failedStepIndex = -1;
        if (captureCheckpoint) {
          final checkpointDriver = driver as ApplicationCheckpointDriver;
          onCheckpoint(
            await checkpointDriver.captureCheckpoint(launchContext, handle!),
          );
        }
      },
      beforeClose: (bodyError, __) async {
        try {
          context.runtime.currentStepIndex = null;
          if (bodyError != null &&
              handle != null &&
              (failedStepIndex < 0 ||
                  failedStepIndex >= test.steps.length ||
                  config.screenshots.shouldCaptureStep(
                    indexedSteps[failedStepIndex].type,
                  )) &&
              context.runtime.screenshotSheetFrames.isEmpty) {
            try {
              await captureHostEmergencyScreenshot(
                tester: tester,
                context: context,
              );
            } catch (error) {
              if (!isHostScreenshotDiagnostic(error) &&
                  !isHostScreenshotCaptureFailure(error)) {
                secondaryFailures.add(
                  TestFailureDetails(
                    kind: TestFailureKind.assertion,
                    message: 'Screenshot failed: $error',
                    phase: 'screenshot',
                  ),
                );
              }
            }
          }
          await attachHostDebugArtifacts(
            tester: tester,
            context: context,
            status: bodyError == null ? TestStatus.passed : TestStatus.failed,
            durationMs: stopwatch.elapsedMilliseconds,
            failedStepIndex: failedStepIndex < 0 ? null : failedStepIndex,
            failedStepLabel: failedStepIndex < 0
                ? null
                : formatStepBrief(indexedSteps[failedStepIndex]),
            failureMessage: bodyError?.toString(),
          );
        } catch (_) {}
        await EnsembleTestHarness.runtimeAdapterFor(mode).resetViewport(tester);
      },
    );
    final bodyError = attemptOutcome.bodyError;
    stopwatch.stop();
    final report = hostReport(
      test,
      handle?.services,
      stepDurationsMs: stepTracker.stepDurationsMs,
      stepStartTimes: stepTracker.stepStartTimes,
      screens: context.runtime.screenArtifacts,
    );
    EnsembleSingleTestResult result;
    if (bodyError == null) {
      result = EnsembleSingleTestResult.passed(
        testId: test.id,
        metadata: test.metadataJson,
        durationMs: stopwatch.elapsedMilliseconds,
        capabilityStatus: capabilityStatus(handle?.services),
        logs: context.logger.logs,
        report: report,
      );
    } else {
      final executionError = bodyError is TestExecutionError ? bodyError : null;
      Map<String, dynamic> failureTarget = const {};
      final locator = executionError?.details['locator'];
      if (locator is Map) {
        failureTarget = Map<String, dynamic>.from(locator);
      }
      result = EnsembleSingleTestResult.failed(
        testId: test.id,
        metadata: test.metadataJson,
        durationMs: stopwatch.elapsedMilliseconds,
        failedStepIndex: failedStepIndex < 0 ? null : failedStepIndex,
        failedStep: failedStepIndex < 0 ? null : indexedSteps[failedStepIndex],
        message: bodyError.toString(),
        stackTrace: attemptOutcome.bodyStackTrace?.toString() ??
            StackTrace.current.toString(),
        failureOperation: failureOperation,
        failureSource: failureSource,
        logs: context.logger.logs,
        failure: kernelFailureDetails ??
            TestFailureDetails(
              kind: failureKind(bodyError, handle: handle),
              message: bodyError.toString(),
              phase: 'execution',
              target: failureTarget,
            ),
        secondaryFailures: secondaryFailures,
        capabilityStatus: capabilityStatus(handle?.services),
        report: report,
      );
    }
    return RetryExecutionCoordinator.withAttemptCleanupFailures(
      result,
      failures: attemptOutcome.closeFailures,
      phase: 'cleanup',
      excludeError: bodyError,
    );
  });
}
