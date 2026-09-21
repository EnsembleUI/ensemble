library;

import 'dart:convert';
import 'dart:io';

import 'package:ensemble_test_runner/actions/http_request_action.dart';
import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'package:ensemble_test_runner/application/application_test_driver.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/discovery/ensemble_test_execution_planner.dart';
import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:ensemble_test_runner/mocks/test_logger.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/reporters/test_reporter.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/runner/test_artifacts.dart';
import 'package:ensemble_test_runner/runner/test_service_manager.dart';
import 'package:ensemble_test_runner/session/errors/test_execution_error.dart';
import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:ensemble_test_runner/session/session_capabilities.dart';
import 'package:ensemble_test_runner/session/yaml/yaml_step_dispatcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Registers and executes YAML tests against an application-provided driver.
Future<void> runApplicationYamlTests({
  required ApplicationTestDriver driver,
  String? testsAssetPrefix,
}) async {
  LiveTestWidgetsFlutterBinding.ensureInitialized();
  return registerApplicationYamlTests(
    driver: driver,
    mode: ExecutionMode.widget,
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

  testWidgets('Application *.test.yaml', (tester) async {
    final plan = await EnsembleTestExecutionPlanner.build(
      testsAssetPrefix: prefix,
      inputs: _inputsFromEnvironment(),
      selection: _selectionFromEnvironment(),
    );
    final runResult = await runApplicationTestPlan(
      driver: driver,
      plan: plan,
      tester: tester,
      mode: mode,
    );
    final reporter = TestReporter();
    print(reporter.formatSummary(runResult, testFile: '$prefix*.test.yaml'));
    _emitMachineReport(runResult);
    if (runResult.failedCount > 0) {
      fail(reporter.formatFailureSummary(runResult));
    }
  });
}

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
  final services = TestServiceManager(plan.config.services);
  final results = <EnsembleSingleTestResult>[];
  final checkpoints = <String, Object>{};
  final requestedSessions = plan.ordered
      .map((definition) => definition.testCase.session)
      .whereType<String>()
      .toSet();
  Object? suiteFailure;
  StackTrace? suiteStack;
  var servicesStarted = false;
  var suiteStarted = false;
  try {
    await tester.runAsync(services.startAll);
    servicesStarted = true;
    await driver.setUpSuite(suiteContext);
    suiteStarted = true;
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
        checkpoint: checkpoint,
        captureCheckpoint: requestedSessions.contains(test.id),
        onCheckpoint: (value) => checkpoints[test.id] = value,
      ));
    }
  } catch (error, stackTrace) {
    suiteFailure = error;
    suiteStack = stackTrace;
  } finally {
    if (suiteStarted) {
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
  required Object? checkpoint,
  required bool captureCheckpoint,
  required void Function(Object checkpoint) onCheckpoint,
}) async {
  EnsembleSingleTestResult? last;
  for (var attempt = 0; attempt <= test.retry; attempt++) {
    last = await _runHostAttempt(
      tester: tester,
      driver: driver,
      test: test,
      config: config,
      runId: runId,
      attempt: attempt,
      checkpoint: checkpoint,
      captureCheckpoint: captureCheckpoint,
      onCheckpoint: onCheckpoint,
    );
    if (last.status == TestStatus.passed) {
      return EnsembleSingleTestResult.passed(
        testId: last.testId,
        metadata: last.metadata,
        durationMs: last.durationMs,
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
    durationMs: last.durationMs,
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
  TestApplicationHandle? handle;
  LocalTestExecutionSession? session;
  Object? primaryError;
  StackTrace? primaryStack;
  Object? cleanupError;
  StackTrace? cleanupStack;
  var prepared = false;
  var failedStepIndex = -1;
  final flutterErrors = <String>[];
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    flutterErrors.add(details.exceptionAsString());
    previousOnError?.call(details);
  };
  try {
    await driver.prepareTest(launchContext);
    prepared = true;
    if (checkpoint != null) {
      await (driver as ApplicationCheckpointDriver).restoreCheckpoint(
        launchContext,
        checkpoint,
      );
    }
    await _executeHostSetup(test);
    handle = await driver.launch(tester, launchContext);
    await tester.pump();

    final context = EnsembleTestContext(
      testCase: test,
      config: config,
      apiOverlay: TestApiProviderOverlay(mocks: const {}),
      logger: TestLogger(),
      setup: const EnsembleTestSetup(),
    );
    final assertions = AssertionEngine(
      tester: tester,
      context: context,
      services: handle.services,
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: assertions,
      services: handle.services,
    );
    session = LocalTestExecutionSession.attach(
      tester: tester,
      context: context,
      services: handle.services,
      sessionId: test.id,
      permissions: SessionPermissions.yamlController,
      assertions: assertions,
      executor: executor,
    );
    final dispatcher = YamlStepDispatcher(session: session);
    for (var i = 0; i < test.steps.length; i++) {
      failedStepIndex = i;
      await dispatcher.execute(test.steps[i]);
      if (flutterErrors.isNotEmpty) {
        throw ApplicationTestCrash(
          'Application error: ${flutterErrors.first}',
        );
      }
    }
    failedStepIndex = -1;
    if (captureCheckpoint) {
      final checkpointDriver = driver as ApplicationCheckpointDriver;
      onCheckpoint(
        await checkpointDriver.captureCheckpoint(launchContext, handle),
      );
    }
  } catch (error, stackTrace) {
    primaryError = error;
    primaryStack = stackTrace;
  } finally {
    FlutterError.onError = previousOnError;
    if (session != null) {
      try {
        await session.close();
      } catch (error, stackTrace) {
        cleanupError ??= error;
        cleanupStack ??= stackTrace;
      }
    }
    if (prepared) {
      try {
        await driver.tearDownTest(tester, launchContext, handle);
      } catch (error, stackTrace) {
        cleanupError ??= error;
        cleanupStack ??= stackTrace;
      }
    }
  }
  stopwatch.stop();
  if (primaryError == null && cleanupError == null) {
    return EnsembleSingleTestResult.passed(
      testId: test.id,
      metadata: test.metadataJson,
      durationMs: stopwatch.elapsedMilliseconds,
      capabilityStatus: _capabilityStatus(handle?.services),
      report: _hostReport(test, handle?.services),
    );
  }
  final message = [
    if (primaryError != null) primaryError.toString(),
    if (cleanupError != null) 'Cleanup failed: $cleanupError',
  ].join('\n');
  return EnsembleSingleTestResult.failed(
    testId: test.id,
    metadata: test.metadataJson,
    durationMs: stopwatch.elapsedMilliseconds,
    failedStepIndex: failedStepIndex < 0 ? null : failedStepIndex,
    failedStep: failedStepIndex < 0 ? null : test.steps[failedStepIndex],
    error: message,
    stackTrace: primaryStack?.toString() ?? cleanupStack?.toString(),
    failure: TestFailureDetails(
      kind: primaryError == null
          ? TestFailureKind.cleanup
          : _failureKind(primaryError, handle: handle),
      message: primaryError?.toString() ?? cleanupError.toString(),
      phase: primaryError == null ? 'cleanup' : 'execution',
      target: primaryError is TestExecutionError
          ? primaryError.details['locator'] is Map
              ? Map<String, dynamic>.from(
                  primaryError.details['locator'] as Map,
                )
              : const {}
          : const {},
    ),
    secondaryFailures: cleanupError != null && primaryError != null
        ? [
            TestFailureDetails(
              kind: TestFailureKind.cleanup,
              message: cleanupError.toString(),
              phase: 'cleanup',
            ),
          ]
        : const [],
    capabilityStatus: _capabilityStatus(handle?.services),
    report: _hostReport(test, handle?.services),
  );
}

EnsembleTestReportDetails _hostReport(
  EnsembleTestCase test,
  ApplicationTestServices? services,
) {
  final navigation = services?.navigation;
  final history = navigation?.routeHistory ?? const <String>[];
  return EnsembleTestReportDetails(
    startScreen: history.isEmpty ? null : history.first,
    endScreen: navigation?.currentRoute,
    navigationKnown: navigation != null,
    session: test.session,
    screensVisited: history,
    stepsOutline: outlineSteps(test.steps),
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
