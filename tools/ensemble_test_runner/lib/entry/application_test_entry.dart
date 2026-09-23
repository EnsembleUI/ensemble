library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble_test_runner/actions/http_request_action.dart';
import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'package:ensemble_test_runner/application/application_test_driver.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/discovery/ensemble_test_execution_planner.dart';
import 'package:ensemble_test_runner/entry/host_test_artifacts.dart';
import 'package:ensemble_test_runner/entry/observe_entry.dart';
import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/reporters/test_reporter.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/runner/failure_observer_capture.dart';
import 'package:ensemble_test_runner/runner/flutter_error_filters.dart';
import 'package:ensemble_test_runner/runner/live_async_call.dart';
import 'package:ensemble_test_runner/runner/test_artifacts.dart';
import 'package:ensemble_test_runner/runner/test_service_manager.dart';
import 'package:ensemble_test_runner/session/errors/test_execution_error.dart';
import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:ensemble_test_runner/session/observation/observe_formatter.dart';
import 'package:ensemble_test_runner/session/observation/observe_screenshot.dart';
import 'package:ensemble_test_runner/session/observation/suggested_locator.dart';
import 'package:ensemble_test_runner/session/observation/ui_observation.dart';
import 'package:ensemble_test_runner/session/session_capabilities.dart';
import 'package:ensemble_test_runner/session/yaml/yaml_step_dispatcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Registers and executes YAML tests against an application-provided driver.
///
/// Mode comes from `--dart-define=ensembleTestExecutionMode=` (set by the CLI
/// for `--mode=integration`). Hosts only need:
/// ```dart
/// Future<void> main() => runApplicationYamlTests(driver: MyDriver());
/// ```
///
/// When `ensembleTestObserveOnly=true`, launches once, observes the UI, and
/// exits without running YAML steps.
Future<void> runApplicationYamlTests({
  required ApplicationTestDriver driver,
  String? testsAssetPrefix,
}) async {
  final mode = _executionModeFromEnvironment();
  _ensureApplicationTestBinding(mode);
  return registerApplicationYamlTests(
    driver: driver,
    mode: mode,
    testsAssetPrefix: testsAssetPrefix,
  );
}

/// Registers a host suite after the caller selected the Flutter test binding.
Future<void> registerApplicationYamlTests({
  required ApplicationTestDriver driver,
  required ExecutionMode mode,
  String? testsAssetPrefix,
}) async {
  final prefix = _normalizedPrefix(
    testsAssetPrefix ??
        const String.fromEnvironment(
          'ensembleTestTestsAssetPrefix',
          defaultValue: 'tests/',
        ),
  );

  final resolved = _resolvedExecutionMode(mode);
  final transport =
      resolved == ExecutionMode.integration && usesDeviceArtifactTransport;
  var transportCompleted = false;
  void completeTransportIfNeeded() {
    if (!transport || transportCompleted) return;
    transportCompleted = true;
    emitEnsembleTestArtifactTransportComplete();
  }

  // Uncaught plugin errors can finish the Flutter test before the suite
  // `finally` runs. tearDown still emits complete so the CLI gets a report.
  tearDown(completeTransportIfNeeded);

  if (isApplicationObserveOnly) {
    testWidgets('Application observe', (tester) async {
      if (transport) {
        emitEnsembleTestArtifactTransportBegin();
      }
      try {
        await _runApplicationObserveOnly(
          driver: driver,
          tester: tester,
          mode: resolved,
          testsAssetPrefix: prefix,
        );
      } finally {
        completeTransportIfNeeded();
      }
    });
    return;
  }

  testWidgets('Application *.test.yaml', (tester) async {
    if (transport) {
      emitEnsembleTestArtifactTransportBegin();
    }
    try {
      final plan = await EnsembleTestExecutionPlanner.build(
        testsAssetPrefix: prefix,
        inputs: _inputsFromEnvironment(),
        selection: _selectionFromEnvironment(),
      );
      final runResult = await runApplicationTestPlan(
        driver: driver,
        plan: plan,
        tester: tester,
        mode: resolved,
      );
      final reporter = TestReporter();
      print(reporter.formatSummary(runResult, testFile: '$prefix*.test.yaml'));
      _emitMachineReport(runResult);
      if (runResult.failedCount > 0) {
        fail(reporter.formatFailureSummary(runResult));
      }
    } finally {
      completeTransportIfNeeded();
    }
  });
}

Future<void> _runApplicationObserveOnly({
  required ApplicationTestDriver driver,
  required WidgetTester tester,
  required ExecutionMode mode,
  required String testsAssetPrefix,
}) async {
  final suiteConfig =
      await loadInspectUiSuiteConfig(testsAssetPrefix: testsAssetPrefix);
  final devices = resolveInspectUiDevices(
    suiteConfig.devices,
    forScreenshots: inspectUiScreenshotEnabled,
  );
  final suiteContext = TestSuiteContext(
    runId: 'observe_${DateTime.now().microsecondsSinceEpoch}',
    config: suiteConfig,
    launchKind: TestApplicationLaunchKind.applicationProvided,
  );

  var suiteSetupStarted = false;
  try {
    suiteSetupStarted = true;
    await driver.setUpSuite(suiteContext);

    final usedNames = <String>{};
    final screenshotPaths = <String>[];
    UiObservation? observation;

    for (var i = 0; i < devices.length; i++) {
      final device = devices[i];
      final launchContext = TestLaunchContext(
        attemptId: 'observe_$i',
        attempt: i,
        testCase: EnsembleTestCase(
          id: 'observe',
          steps: const [],
          deviceTarget: device,
          initialState: {
            if ((device.locale ?? '').trim().isNotEmpty)
              'env': {'APP_LOCALE': device.locale},
          },
        ),
        config: suiteConfig,
      );
      final context = EnsembleTestContext.fromTestCase(
        launchContext.testCase,
        config: suiteConfig,
      );
      TestApplicationHandle? handle;
      LocalTestExecutionSession? session;
      var prepareAttempted = false;
      try {
        if (mode == ExecutionMode.widget) {
          await applyInspectUiScreenshotViewport(tester, device);
        }
        prepareAttempted = true;
        await driver.prepareTest(launchContext);
        handle = await driver.launch(tester, launchContext);
        await tester.pump();
        session = LocalTestExecutionSession.attach(
          tester: tester,
          context: context,
          services: handle.services,
          sessionId: 'observe_${device.id}',
          permissions: SessionPermissions.restrictedUi,
        );
        observation =
            await session.observe(options: inspectUiObservationOptions);
        observation = enrichSuggestedLocators(
          observation: observation,
          resolver: session.resolver,
          registry: session.registry,
        );
        if (inspectUiScreenshotEnabled && mode == ExecutionMode.widget) {
          final dir = inspectUiScreenshotDirFromEnvironment();
          if (dir != null) {
            final screenLabel = observation.screen.name ??
                observation.screen.routeId ??
                'screen';
            var basename = inspectUiScreenshotBasename(
              screen: screenLabel,
              theme: device.theme,
              locale: device.locale,
            );
            if (!usedNames.add(basename)) {
              basename = inspectUiScreenshotBasename(
                screen: screenLabel,
                theme: device.theme,
                locale: device.locale,
                deviceId: device.id,
                includeDeviceId: true,
              );
              usedNames.add(basename);
            }
            final path = await writeInspectUiScreenshotForDevice(
              tester: tester,
              observation: observation,
              device: device,
              outputPath: '$dir${Platform.pathSeparator}$basename.png',
              secureContent: suiteConfig.screenshots.secureContent,
            );
            if (path != null) screenshotPaths.add(path);
          }
        }
      } finally {
        try {
          await session?.close();
        } catch (_) {}
        if (prepareAttempted) {
          try {
            await driver.tearDownTest(tester, launchContext, handle);
          } catch (_) {}
        }
      }
    }

    if (observation == null) {
      fail('Application observe produced no observation.');
    }
    const ObserveFormatter().emit(
      observation,
      format: applicationObserveFormat(),
      screenshotPaths: screenshotPaths,
    );
  } finally {
    if (suiteSetupStarted) {
      try {
        await driver.tearDownSuite();
      } catch (_) {}
    }
    if (mode != ExecutionMode.integration) {
      await resetHostScreenshotViewport(tester);
    }
  }
}

void _ensureApplicationTestBinding(ExecutionMode mode) {
  if (mode == ExecutionMode.integration) {
    IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  } else {
    LiveTestWidgetsFlutterBinding.ensureInitialized();
  }
}

ExecutionMode _executionModeFromEnvironment() {
  const envMode = String.fromEnvironment('ensembleTestExecutionMode');
  if (envMode == ExecutionMode.integration.name) {
    return ExecutionMode.integration;
  }
  return ExecutionMode.widget;
}

/// Services started inside the test process.
///
/// When [ensembleTestHostOwnsServices] is true (CLI integration backend), the
/// development machine already started fixtures and the device must not spawn
/// them again.
List<TestServiceConfig> hostProcessServiceConfigs(
  List<TestServiceConfig> configured, {
  bool hostOwnsServices = const bool.fromEnvironment(
    'ensembleTestHostOwnsServices',
  ),
}) =>
    hostOwnsServices ? const [] : configured;

/// Executes an already-resolved plan through an application driver.
Future<EnsembleTestRunResult> runApplicationTestPlan({
  required ApplicationTestDriver driver,
  required EnsembleTestExecutionPlan plan,
  required WidgetTester tester,
  required ExecutionMode mode,
}) async {
  _validateHostPlan(plan, driver);
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
  final results = <EnsembleSingleTestResult>[];
  final checkpoints = <String, Object>{};
  final requestedSessions = plan.ordered
      .map((definition) => definition.testCase.session)
      .whereType<String>()
      .toSet();
  Object? suiteFailure;
  StackTrace? suiteStack;
  var servicesStarted = false;
  var suiteSetupStarted = false;
  try {
    await tester.runAsync(services.startAll);
    servicesStarted = true;
    suiteSetupStarted = true;
    await driver.setUpSuite(suiteContext);
    for (final definition in plan.ordered) {
      final test = definition.testCase;
      final dependency = test.session;
      if (dependency != null &&
          results.any((result) =>
              result.testId == dependency &&
              result.status == TestStatus.failed)) {
        results.add(EnsembleSingleTestResult.failed(
          testId: test.id,
          metadata: test.metadataJson,
          durationMs: 0,
          error: 'Session "$dependency" failed',
        ));
        continue;
      }
      final checkpoint = dependency == null ? null : checkpoints[dependency];
      results.add(await _runHostTestWithRetries(
        tester: tester,
        driver: driver,
        test: test,
        config: plan.config,
        runId: runId,
        mode: mode,
        checkpoint: checkpoint,
        captureCheckpoint: requestedSessions.contains(test.id),
        onCheckpoint: (value) => checkpoints[test.id] = value,
      ));
    }
  } catch (error, stackTrace) {
    suiteFailure = error;
    suiteStack = stackTrace;
  } finally {
    if (suiteSetupStarted) {
      try {
        await driver.tearDownSuite();
      } catch (error, stackTrace) {
        suiteFailure ??= error;
        suiteStack ??= stackTrace;
      }
    }
    if (servicesStarted) {
      try {
        await services.stopAll();
      } catch (error, stackTrace) {
        suiteFailure ??= error;
        suiteStack ??= stackTrace;
      }
    }
  }

  if (suiteFailure != null) {
    results.add(EnsembleSingleTestResult.failed(
      testId: 'test-process',
      durationMs: 0,
      error: suiteFailure.toString(),
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
    metadata: {
      'mode': _resolvedExecutionMode(mode).name,
      'launchKind': suiteContext.launchKind.name,
    },
  );
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
}) async {
  EnsembleSingleTestResult? last;
  var totalDurationMs = 0;
  for (var attempt = 0; attempt <= test.retry; attempt++) {
    last = await _runHostAttempt(
      tester: tester,
      driver: driver,
      test: test,
      config: config,
      runId: runId,
      mode: mode,
      attempt: attempt,
      checkpoint: checkpoint,
      captureCheckpoint: captureCheckpoint,
      onCheckpoint: onCheckpoint,
    );
    totalDurationMs += last.durationMs;
    if (last.status == TestStatus.passed) {
      return EnsembleSingleTestResult.passed(
        testId: last.testId,
        metadata: last.metadata,
        durationMs: totalDurationMs,
        attempts: attempt + 1,
        retry: test.retry,
        logs: last.logs,
        report: last.report,
        capabilityStatus: last.capabilityStatus,
      );
    }
  }
  return EnsembleSingleTestResult.failed(
    testId: last!.testId,
    metadata: last.metadata,
    durationMs: totalDurationMs,
    attempts: test.retry + 1,
    retry: test.retry,
    failedStepIndex: last.failedStepIndex,
    failedStep: last.failedStep,
    error: last.message,
    stackTrace: last.stackTrace,
    logs: last.logs,
    report: last.report,
    failure: last.failure,
    secondaryFailures: last.secondaryFailures,
    capabilityStatus: last.capabilityStatus,
  );
}

Future<EnsembleSingleTestResult> _runHostAttempt({
  required WidgetTester tester,
  required ApplicationTestDriver driver,
  required EnsembleTestCase test,
  required EnsembleTestConfig config,
  required String runId,
  required ExecutionMode mode,
  required int attempt,
  required Object? checkpoint,
  required bool captureCheckpoint,
  required void Function(Object checkpoint) onCheckpoint,
}) async {
  final stopwatch = Stopwatch()..start();
  final launchContext = TestLaunchContext(
    attemptId: '${runId}_${test.id}_$attempt',
    attempt: attempt,
    testCase: test,
    config: config,
    checkpoint: checkpoint,
  );
  final context = EnsembleTestContext.fromTestCase(test, config: config);
  TestApplicationHandle? handle;
  LocalTestExecutionSession? session;
  Object? primaryError;
  StackTrace? primaryStack;
  Object? cleanupError;
  StackTrace? cleanupStack;
  final secondaryFailures = <TestFailureDetails>[];
  var prepareAttempted = false;
  var failedStepIndex = -1;
  final stepDurationsMs = <int>[];
  final stepStartTimes = <String>[];
  final previousOnError = FlutterError.onError;
  final previousLiveAsyncRunner = LiveAsyncCallSupport.runner;
  FlutterError.onError = (details) {
    final message = details.exceptionAsString();
    if (isHostScreenshotDiagnostic(message) ||
        isNonFatalFlutterDiagnostic(message) ||
        isTransientNavigationDiagnostic(message)) {
      return;
    }
    context.runtime.flutterErrors.add(message);
    previousOnError?.call(details);
  };
  context.apiOverlay.liveAsyncRunner = tester.runAsync;
  LiveAsyncCallSupport.runner = tester.runAsync;
  context.runtime.consoleLogs.add(
    context.runtime.formatConsoleLine('Started ${test.id}'),
  );
  try {
    await applyHostScreenshotViewport(tester, context, mode: mode);
    await tester.runAsync(EnsembleTestHarness.ensureAppFontsLoaded);
    await runZoned(
      () async {
        try {
          prepareAttempted = true;
          await driver.prepareTest(launchContext);
          if (checkpoint != null) {
            await (driver as ApplicationCheckpointDriver).restoreCheckpoint(
              launchContext,
              checkpoint,
            );
          }
          await _executeHostSetup(test);
          await tester.runAsync(
            () => EnsembleTestHarness.applyInPlaceSetup(context),
          );
          // Ensemble overlay path can be verified before launch. Pure Flutter
          // ApiMockingTestService attachment is confirmed right after launch.
          ensureHostFixturesSupported(context);
          final launched = await driver.launch(tester, launchContext);
          handle = launched;
          await tester.pump();
          ensureHostFixturesSupported(
            context,
            services: launched.services,
            requireResolved: true,
          );

          final assertions = AssertionEngine(
            tester: tester,
            context: context,
            services: launched.services,
          );
          final executor = TestStepExecutor(
            tester: tester,
            context: context,
            assertions: assertions,
            services: launched.services,
          );
          final attached = LocalTestExecutionSession.attach(
            tester: tester,
            context: context,
            services: launched.services,
            sessionId: test.id,
            permissions: SessionPermissions.yamlController,
            assertions: assertions,
            executor: executor,
          );
          session = attached;
          final dispatcher = YamlStepDispatcher(session: attached);
          for (var i = 0; i < test.steps.length; i++) {
            failedStepIndex = i;
            context.runtime.currentStepIndex = i;
            final step = test.steps[i];
            final startedAt = DateTime.now();
            final stepWatch = Stopwatch()..start();
            try {
              await dispatcher.execute(step);
              _throwIfHostApplicationError(context);
              await _captureHostStepScreenshotSafely(
                tester: tester,
                context: context,
                step: step,
                stepIndex: i,
                secondaryFailures: secondaryFailures,
              );
              _throwIfHostApplicationError(context);
            } catch (error, stackTrace) {
              await _captureHostStepScreenshotSafely(
                tester: tester,
                context: context,
                step: step,
                stepIndex: i,
                secondaryFailures: secondaryFailures,
              );
              try {
                await captureFailureObserverBestEffort(
                  session: attached,
                  executor: executor,
                  stepIndex: i,
                );
              } catch (_) {}
              // Preserve the step failure — screenshot diagnostics are secondary.
              Error.throwWithStackTrace(error, stackTrace);
            } finally {
              stepDurationsMs.add(stepWatch.elapsedMilliseconds);
              stepStartTimes.add(startedAt.toIso8601String());
            }
          }
          failedStepIndex = -1;
          context.runtime.currentStepIndex = null;
          _throwIfHostApplicationError(context);
          if (captureCheckpoint) {
            final checkpointDriver = driver as ApplicationCheckpointDriver;
            onCheckpoint(
              await checkpointDriver.captureCheckpoint(launchContext, launched),
            );
          }
        } catch (error, stackTrace) {
          primaryError = error;
          primaryStack = stackTrace;
        }
      },
      zoneSpecification: context.runtime.consoleCaptureZone,
    );
  } finally {
    try {
      if (primaryError != null &&
          handle != null &&
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
        // Errors raised while pumping for the emergency frame must not vanish
        // or replace the original step failure.
        final emergencyAppError = pendingHostApplicationError(context);
        if (emergencyAppError != null) {
          secondaryFailures.add(
            TestFailureDetails(
              kind: TestFailureKind.crash,
              message: 'Application error: $emergencyAppError',
              phase: 'screenshot',
            ),
          );
        }
      }
      await attachHostDebugArtifacts(
        tester: tester,
        context: context,
        status: primaryError == null ? TestStatus.passed : TestStatus.failed,
        durationMs: stopwatch.elapsedMilliseconds,
        failedStepIndex: failedStepIndex < 0 ? null : failedStepIndex,
        failedStepLabel: failedStepIndex < 0
            ? null
            : formatStepBrief(test.steps[failedStepIndex]),
        failureMessage: primaryError?.toString(),
      );
    } catch (_) {}
    final openSession = session;
    if (openSession != null) {
      try {
        await openSession.close();
      } catch (error, stackTrace) {
        cleanupError ??= error;
        cleanupStack ??= stackTrace;
      }
    }
    if (prepareAttempted) {
      try {
        await driver.tearDownTest(tester, launchContext, handle);
      } catch (error, stackTrace) {
        cleanupError ??= error;
        cleanupStack ??= stackTrace;
      }
    }
    FlutterError.onError = previousOnError;
    LiveAsyncCallSupport.runner = previousLiveAsyncRunner;
    context.apiOverlay.liveAsyncRunner = null;
    if (mode != ExecutionMode.integration) {
      await resetHostScreenshotViewport(tester);
    }
  }
  stopwatch.stop();
  // Final gate: screenshot pumps after the last step must not leave a pass.
  if (primaryError == null) {
    final lateAppError = pendingHostApplicationError(context);
    if (lateAppError != null) {
      primaryError = ApplicationTestCrash('Application error: $lateAppError');
      primaryStack = StackTrace.current;
    }
  }
  final report = _hostReport(
    test,
    handle?.services,
    stepDurationsMs: stepDurationsMs,
    stepStartTimes: stepStartTimes,
  );
  if (primaryError == null && cleanupError == null) {
    return EnsembleSingleTestResult.passed(
      testId: test.id,
      metadata: test.metadataJson,
      durationMs: stopwatch.elapsedMilliseconds,
      capabilityStatus: _capabilityStatus(handle?.services),
      logs: context.logger.logs,
      report: report,
    );
  }
  final message = [
    if (primaryError != null) primaryError.toString(),
    if (cleanupError != null) 'Cleanup failed: $cleanupError',
  ].join('\n');
  final caughtError = primaryError;
  final executionError = caughtError is TestExecutionError ? caughtError : null;
  Map<String, dynamic> failureTarget = const {};
  final locator = executionError?.details['locator'];
  if (locator is Map) {
    failureTarget = Map<String, dynamic>.from(locator);
  }
  final secondaries = <TestFailureDetails>[
    ...secondaryFailures,
    if (cleanupError != null && primaryError != null)
      TestFailureDetails(
        kind: TestFailureKind.cleanup,
        message: cleanupError.toString(),
        phase: 'cleanup',
      ),
  ];
  return EnsembleSingleTestResult.failed(
    testId: test.id,
    metadata: test.metadataJson,
    durationMs: stopwatch.elapsedMilliseconds,
    failedStepIndex: failedStepIndex < 0 ? null : failedStepIndex,
    failedStep: failedStepIndex < 0 ? null : test.steps[failedStepIndex],
    error: message,
    stackTrace: primaryStack?.toString() ?? cleanupStack?.toString(),
    logs: context.logger.logs,
    failure: TestFailureDetails(
      kind: primaryError == null
          ? TestFailureKind.cleanup
          : _failureKind(primaryError, handle: handle),
      message: primaryError?.toString() ?? cleanupError.toString(),
      phase: primaryError == null ? 'cleanup' : 'execution',
      target: failureTarget,
    ),
    secondaryFailures: secondaries,
    capabilityStatus: _capabilityStatus(handle?.services),
    report: report,
  );
}

EnsembleTestReportDetails _hostReport(
  EnsembleTestCase test,
  ApplicationTestServices? services, {
  List<int> stepDurationsMs = const [],
  List<String> stepStartTimes = const [],
}) {
  final navigation = services?.navigation;
  final history = navigation?.routeHistory ?? const <String>[];
  return EnsembleTestReportDetails(
    startScreen: history.isEmpty ? null : history.first,
    endScreen: navigation?.currentRoute,
    navigationKnown: navigation != null,
    session: test.session,
    screensVisited: history,
    stepsOutline: outlineSteps(test.steps),
    stepDurationsMs: stepDurationsMs,
    stepStartTimes: stepStartTimes,
  );
}

Map<String, bool> _capabilityStatus(ApplicationTestServices? services) => {
      'navigation': services?.navigation != null,
      'api': services?.api != null,
      'storage': services?.storage != null,
      'metadata': services?.metadata != null,
    };

TestFailureKind _failureKind(
  Object? error, {
  TestApplicationHandle? handle,
}) {
  if (error is UnsupportedApplicationCapability) {
    return TestFailureKind.unsupportedCapability;
  }
  if (error is ApplicationTestCrash) return TestFailureKind.crash;
  if (handle == null) return TestFailureKind.bootstrap;
  if (error is TestExecutionError) {
    switch (error.code) {
      case TestExecutionErrorCode.elementNotFound:
        return TestFailureKind.elementNotFound;
      case TestExecutionErrorCode.ambiguousTarget:
        return TestFailureKind.ambiguousTarget;
      case TestExecutionErrorCode.unsupportedAction:
      case TestExecutionErrorCode.executionUnavailable:
        return TestFailureKind.unsupportedCapability;
      default:
        return TestFailureKind.assertion;
    }
  }
  return TestFailureKind.assertion;
}

Future<void> _executeHostSetup(EnsembleTestCase test) async {
  for (final step in test.setupSteps) {
    if (step.type != 'httpRequest') {
      throw EnsembleTestFailure(
        'Unsupported host setup action "${step.type}".',
      );
    }
    await HttpRequestAction.execute(step.args);
  }
}

/// True when suite config.yaml declares API mocks (files or inline).
bool suiteDeclaresApiMocks(EnsembleTestConfig config) =>
    config.inlineMocks.isNotEmpty || config.mockFiles.isNotEmpty;

/// True when the test or suite declares storage fixtures.
bool hostDeclaresStorageFixtures(EnsembleTestContext context) {
  bool hasStorageKeys(Map<String, dynamic> state) =>
      state.containsKey('storage') ||
      state.containsKey('secureStorage') ||
      state.containsKey('keychain');
  return hasStorageKeys(context.testCase.initialState) ||
      hasStorageKeys(context.config.initialState) ||
      context.setup.initialPublicStorage != null ||
      context.setup.initialSecureStorage != null ||
      context.setup.initialKeychain != null;
}

/// Effective API mocks after suite + test composition (planner-merged).
Map<String, MockAPIResponse> effectiveHostApiMocks(
  EnsembleTestContext context,
) =>
    Map<String, MockAPIResponse>.from(context.testCase.mocks.apis);

/// Whether Ensemble's HTTP provider currently carries the test API overlay.
bool ensembleApiOverlayAttached(EnsembleTestContext context) {
  final providers = Ensemble().getConfig()?.apiProviders;
  final http = providers?['http'];
  return identical(http, context.apiOverlay) || http is TestApiProviderOverlay;
}

/// First non-diagnostic Flutter error recorded for this host attempt.
String? pendingHostApplicationError(EnsembleTestContext context) {
  context.runtime.flutterErrors.removeWhere(isHostScreenshotDiagnostic);
  context.runtime.flutterErrors.removeWhere(isNonFatalFlutterDiagnostic);
  context.runtime.flutterErrors.removeWhere(isTransientNavigationDiagnostic);
  if (context.runtime.flutterErrors.isEmpty) return null;
  return context.runtime.flutterErrors.first;
}

void _throwIfHostApplicationError(EnsembleTestContext context) {
  final pending = pendingHostApplicationError(context);
  if (pending == null) return;
  throw ApplicationTestCrash('Application error: $pending');
}

/// Test hook for the post-screenshot / end-of-attempt application-error gate.
void assertNoPendingHostApplicationError(EnsembleTestContext context) =>
    _throwIfHostApplicationError(context);

Future<void> _captureHostStepScreenshotSafely({
  required WidgetTester tester,
  required EnsembleTestContext context,
  required TestStep step,
  required int stepIndex,
  required List<TestFailureDetails> secondaryFailures,
}) async {
  try {
    await captureHostStepScreenshot(
      tester: tester,
      context: context,
      step: step,
      stepIndex: stepIndex,
    );
  } catch (error) {
    if (isHostScreenshotDiagnostic(error) ||
        isHostScreenshotCaptureFailure(error)) {
      return;
    }
    secondaryFailures.add(
      TestFailureDetails(
        kind: TestFailureKind.assertion,
        message: 'Screenshot failed: $error',
        phase: 'screenshot',
      ),
    );
  }
}

/// Rejects YAML mocks/fixtures that cannot attach to the application under test.
///
/// Effective fixtures come from suite `config.yaml` and the individual test
/// (already merged into [EnsembleTestContext.testCase] by the planner). A host
/// must either expose [ApiMockingTestService] / [StorageTestService] or have the
/// Ensemble API overlay installed on the real HTTP provider — otherwise we fail
/// closed before steps run.
///
/// When [requireResolved] is false (pre-launch), Ensemble overlay attachment is
/// checked immediately; pure-Flutter hosts may defer until launch returns
/// services. When [requireResolved] is true (post-launch), unresolved fixtures
/// always throw.
void ensureHostFixturesSupported(
  EnsembleTestContext context, {
  ApplicationTestServices? services,
  bool requireResolved = false,
}) {
  final apiMocks = effectiveHostApiMocks(context);
  final suiteDeclaresMocks = suiteDeclaresApiMocks(context.config);
  final needsApiMocking = apiMocks.isNotEmpty || suiteDeclaresMocks;
  final needsStorage = hostDeclaresStorageFixtures(context);

  if (suiteDeclaresMocks && apiMocks.isEmpty) {
    throw EnsembleTestFailure(
      'Suite config declares API mocks but none were resolved onto the test. '
      'Check suite mocks / profiles composition.',
    );
  }

  if (needsApiMocking) {
    final api = services?.api;
    if (api is ApiMockingTestService) {
      api.applyMocks(TestMocks(apis: apiMocks));
    } else if (api != null) {
      throw const UnsupportedApplicationCapability('apiMocking');
    } else if (ensembleApiOverlayAttached(context)) {
      // Ensemble HTTP provider owns the overlay installed by applyInPlaceSetup.
      for (final entry in apiMocks.entries) {
        context.apiOverlay.setMock(entry.key, entry.value);
      }
    } else if (requireResolved || Ensemble().getConfig() != null) {
      // Ensemble was initialized but the overlay never attached, or we are
      // past launch with no host ApiMockingTestService.
      throw const UnsupportedApplicationCapability('apiMocking');
    }
    // else: pure Flutter pre-launch — wait for services after launch.
  }

  if (needsStorage) {
    if (services?.storage != null) {
      // Host-owned storage fixtures are applied by the driver's storage service
      // during prepare/launch; presence of the capability is enough here.
      return;
    }
    if (Ensemble().getConfig() != null) {
      // applyInPlaceSetup already ran applyYamlTestBootstrap when config exists.
      return;
    }
    if (requireResolved) {
      throw const UnsupportedApplicationCapability('storage');
    }
  }
}

void _validateHostPlan(
  EnsembleTestExecutionPlan plan,
  ApplicationTestDriver driver,
) {
  for (final definition in plan.ordered) {
    final test = definition.testCase;
    if (test.hasStartScreen && driver is! ScreenLaunchApplicationTestDriver) {
      throw EnsembleTestFailure(
        'Host test "${test.id}" must not define startScreen; launch state is '
        'owned by ApplicationTestDriver.',
      );
    }
    if (test.session != null && driver is! ApplicationCheckpointDriver) {
      throw EnsembleTestFailure(
        'Host test "${test.id}" uses session but its driver does not implement '
        'ApplicationCheckpointDriver.',
      );
    }
  }
}

String _normalizedPrefix(String value) {
  final normalized =
      value.replaceAll('\\', '/').replaceFirst(RegExp(r'^/+'), '');
  return normalized.endsWith('/') ? normalized : '$normalized/';
}

Map<String, dynamic> _inputsFromEnvironment() {
  const encoded = String.fromEnvironment('ensembleTestInputs');
  if (encoded.isEmpty) return const {};
  try {
    final value = json.decode(utf8.decode(base64Url.decode(encoded)));
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
  } catch (_) {}
  throw EnsembleTestFailure('Invalid ensembleTestInputs dart-define payload.');
}

EnsembleTestSelection _selectionFromEnvironment() => EnsembleTestSelection(
      ids: _csvSet(const String.fromEnvironment('ensembleTestId')),
      exactIds: _csvSet(const String.fromEnvironment('ensembleTestShardId')),
      features: _csvSet(const String.fromEnvironment('ensembleTestFeature')),
      profiles: _csvSet(const String.fromEnvironment('ensembleTestProfile')),
      tags: _csvSet(const String.fromEnvironment('ensembleTestTag')),
      paths: _csvSet(const String.fromEnvironment('ensembleTestPath')),
    );

Set<String> _csvSet(String value) => value.isEmpty
    ? const {}
    : value
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toSet();

void _emitMachineReport(EnsembleTestRunResult result) {
  const reportMode = String.fromEnvironment('ensembleTestReport');
  const reportFile = String.fromEnvironment('ensembleTestReportFile');
  const emitJsonReport = bool.fromEnvironment('ensembleTestEmitJsonReport');
  final encoded = json.encode(result.toJson());
  final junit = _junitReport(result);
  if (reportFile.isNotEmpty) {
    final file = File(reportFile);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(reportMode == 'junit' ? junit : encoded);
  }
  if (usesDeviceArtifactTransport) {
    emitEnsembleTestMachineReport(encoded);
  } else if (reportMode == 'json' || emitJsonReport) {
    print('ENSEMBLE_TEST_JSON_REPORT:$encoded');
  }
  if (reportMode == 'junit') {
    print('ENSEMBLE_TEST_JUNIT_REPORT:${junit.replaceAll('\n', r'\n')}');
  }
}

ExecutionMode _resolvedExecutionMode(ExecutionMode mode) {
  const envMode = String.fromEnvironment('ensembleTestExecutionMode');
  if (envMode == ExecutionMode.integration.name) {
    return ExecutionMode.integration;
  }
  return mode;
}

String _junitReport(EnsembleTestRunResult result) {
  final totalMs =
      result.results.fold<int>(0, (sum, item) => sum + item.durationMs);
  final buffer = StringBuffer()
    ..writeln(
      '<testsuite name="ensemble_yaml_tests" tests="${result.results.length}" '
      'failures="${result.failedCount}" time="${(totalMs / 1000).toStringAsFixed(3)}">',
    );
  for (final item in result.results) {
    buffer.writeln(
      '  <testcase name="${_xmlEscape(item.testId)}" '
      'time="${(item.durationMs / 1000).toStringAsFixed(3)}">',
    );
    if (item.status == TestStatus.failed) {
      buffer
        ..writeln(
          '    <failure message="${_xmlEscape(item.message ?? 'failed')}">',
        )
        ..writeln(_xmlEscape(item.stackTrace ?? item.message ?? 'failed'))
        ..writeln('    </failure>');
    }
    buffer.writeln('  </testcase>');
  }
  return '${buffer.toString()}</testsuite>\n';
}

String _xmlEscape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');
