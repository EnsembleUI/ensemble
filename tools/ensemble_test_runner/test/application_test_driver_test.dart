// Dart 3.8 reports deprecated_member_use at RegExp construction sites even though
// the deprecation is specifically about implementing RegExp. Keep construction compatible
// with this SDK without suppressing diagnostics in unrelated files.
// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'dart:io';

import 'package:ensemble_device_preview/ensemble_device_preview.dart';
import 'package:ensemble_test_runner/application/application_test_driver.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/discovery/ensemble_test_execution_planner.dart';
import 'package:ensemble_test_runner/entry/application_test_entry.dart';
import 'package:ensemble_test_runner/entry/host_test_artifacts.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_runner.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/retry_execution.dart';
import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'application driver compatibility runner preserves execution behavior',
      (tester) async {
    const testCase = EnsembleTestCase(
      id: 'driver-compatibility',
      steps: [
        TestStep(type: 'expectText', args: {'text': 'Continue'}),
      ],
    );
    const plan = EnsembleTestExecutionPlan(
      ordered: [
        EnsembleTestDefinition(
          assetPath: 'tests/driver-compatibility.test.yaml',
          testCase: testCase,
        ),
      ],
    );
    final directDriver = _FlutterDriver();
    final direct = await runApplicationTestPlan(
      driver: directDriver,
      plan: plan,
      tester: tester,
      mode: ExecutionMode.widget,
    );

    final compatibilityDriver = _FlutterDriver();
    final compatible = await EnsembleTestRunner.application(
      driver: compatibilityDriver,
    ).runPlan(plan, tester);

    expect(direct.failedCount, 0, reason: direct.toJson().toString());
    expect(compatible.resultsById.keys, ['driver-compatibility']);
    expect(compatible.resultsById['driver-compatibility']!.status,
        TestStatus.passed);
    expect(compatibilityDriver.events, directDriver.events);
    expect(compatibilityDriver.events, [
      'suite+',
      'prepare:0',
      'launch:0',
      'cleanup:0',
      'suite-',
    ]);
  });

  testWidgets(
      'host progress publishes at each case boundary and logs callback failures',
      (tester) async {
    const plan = EnsembleTestExecutionPlan(
      ordered: [
        EnsembleTestDefinition(
          assetPath: 'tests/first.test.yaml',
          testCase: EnsembleTestCase(id: 'first', steps: []),
        ),
        EnsembleTestDefinition(
          assetPath: 'tests/second.test.yaml',
          testCase: EnsembleTestCase(id: 'second', steps: []),
        ),
      ],
    );
    final driver = _FlutterDriver();
    final progress = <String>[];

    final result = await EnsembleTestRunner.application(driver: driver).runPlan(
      plan,
      tester,
      onTestComplete: (definition, _) async {
        final launches =
            driver.events.where((event) => event.startsWith('launch:')).length;
        progress.add('${definition.testCase.id}:$launches');
        if (definition.testCase.id == 'first') {
          throw StateError('progress unavailable');
        }
      },
    );

    expect(progress, ['first:1', 'second:2']);
    expect(result.suiteLogs, [
      'Could not publish progress for first: Bad state: progress unavailable'
    ]);
    expect(result.resultsById.keys, ['first', 'second']);
  });

  testWidgets(
      'application driver runs structured Flutter targets in lifecycle order',
      (tester) async {
    final driver = _FlutterDriver();
    const testCase = EnsembleTestCase(
      id: 'flutter-login',
      steps: [
        TestStep(
          type: 'expectVisible',
          args: {
            'target': {'label': 'Continue', 'role': 'button'},
          },
        ),
        TestStep(
          type: 'tap',
          args: {
            'target': {'label': 'Continue', 'role': 'button'},
          },
        ),
        TestStep(type: 'expectText', args: {'text': 'Home'}),
      ],
    );
    const plan = EnsembleTestExecutionPlan(
      ordered: [
        EnsembleTestDefinition(
          assetPath: 'tests/login.test.yaml',
          testCase: testCase,
        ),
      ],
    );

    final result = await runApplicationTestPlan(
      driver: driver,
      plan: plan,
      tester: tester,
      mode: ExecutionMode.widget,
    );

    expect(result.failedCount, 0, reason: result.toJson().toString());
    expect(driver.events,
        ['suite+', 'prepare:0', 'launch:0', 'cleanup:0', 'suite-']);
    expect(result.results.single.capabilityStatus['navigation'], isFalse);
    expect(result.results.single.report?.navigationKnown, isFalse);
    expect(result.results.single.report?.startScreen, isNull);
  });

  testWidgets('retry repeats preparation, launch, and cleanup', (tester) async {
    final driver = _FlutterDriver(failFirstLaunch: true);
    const testCase = EnsembleTestCase(
      id: 'retry',
      retry: 1,
      steps: [
        TestStep(type: 'expectText', args: {'text': 'Continue'})
      ],
    );
    const plan = EnsembleTestExecutionPlan(
      ordered: [
        EnsembleTestDefinition(
          assetPath: 'tests/retry.test.yaml',
          testCase: testCase,
        ),
      ],
    );

    final result = await runApplicationTestPlan(
      driver: driver,
      plan: plan,
      tester: tester,
      mode: ExecutionMode.widget,
    );

    expect(result.failedCount, 0, reason: result.toJson().toString());
    expect(result.results.single.attempts, 2);
    expect(driver.events, [
      'suite+',
      'prepare:0',
      'launch:0',
      'cleanup:0',
      'prepare:1',
      'launch:1',
      'cleanup:1',
      'suite-',
    ]);
    expect(driver.cleanupHandles[0], isNull);
    expect(driver.cleanupHandles[1], isA<_Handle>());
  });

  testWidgets('operation failure closes the session before driver cleanup',
      (tester) async {
    final driver = _FlutterDriver();
    const plan = EnsembleTestExecutionPlan(
      ordered: [
        EnsembleTestDefinition(
          assetPath: 'tests/operation-failure.test.yaml',
          testCase: EnsembleTestCase(
            id: 'operation-failure',
            steps: [
              TestStep(type: 'expectText', args: {'text': 'Not on screen'}),
            ],
          ),
        ),
      ],
    );

    final result = await runApplicationTestPlan(
      driver: driver,
      plan: plan,
      tester: tester,
      mode: ExecutionMode.widget,
    );

    expect(result.failedCount, 1);
    expect(result.results.single.message, contains('Not on screen'));
    expect(result.results.single.failureOperation, isNotNull);
    expect(
      driver.events,
      ['suite+', 'prepare:0', 'launch:0', 'cleanup:0', 'suite-'],
    );
    expect(driver.cleanupHandles.single, isA<_Handle>());
  });

  testWidgets('cleanup-only attempt failure keeps cleanup result projection',
      (tester) async {
    final driver = _FlutterDriver(failCleanup: true);
    const plan = EnsembleTestExecutionPlan(
      ordered: [
        EnsembleTestDefinition(
          assetPath: 'tests/cleanup-failure.test.yaml',
          testCase: EnsembleTestCase(
            id: 'cleanup-failure',
            steps: [
              TestStep(type: 'expectText', args: {'text': 'Continue'})
            ],
          ),
        ),
      ],
    );

    final result = await runApplicationTestPlan(
      driver: driver,
      plan: plan,
      tester: tester,
      mode: ExecutionMode.widget,
    );

    final failure = result.results.single;
    expect(result.failedCount, 1);
    expect(failure.message,
        contains('Cleanup failed: Bad state: attempt cleanup failed'));
    expect(failure.failure?.kind, TestFailureKind.cleanup);
    expect(failure.failure?.message, 'Bad state: attempt cleanup failed');
    expect(failure.failure?.phase, 'cleanup');
    expect(failure.stackTrace, isNotEmpty);
    expect(driver.events, contains('cleanup:0'));
  });

  testWidgets('body failure remains primary when attempt cleanup fails',
      (tester) async {
    final driver = _FlutterDriver(failCleanup: true);
    const plan = EnsembleTestExecutionPlan(
      ordered: [
        EnsembleTestDefinition(
          assetPath: 'tests/body-and-cleanup-failure.test.yaml',
          testCase: EnsembleTestCase(
            id: 'body-and-cleanup-failure',
            steps: [
              TestStep(type: 'expectText', args: {'text': 'Never visible'})
            ],
          ),
        ),
      ],
    );

    final result = await runApplicationTestPlan(
      driver: driver,
      plan: plan,
      tester: tester,
      mode: ExecutionMode.widget,
    );

    final failure = result.results.single;
    expect(result.failedCount, 1);
    expect(failure.message, contains('Never visible'));
    expect(failure.message,
        contains('Cleanup failed: Bad state: attempt cleanup failed'));
    expect(failure.failure?.phase, 'execution');
    expect(failure.secondaryFailures, hasLength(1));
    expect(failure.secondaryFailures.single.kind, TestFailureKind.cleanup);
  });

  testWidgets('host cleanup result matches the shared adapter projection',
      (tester) async {
    final cleanupOnlyDriver = _FlutterDriver(failCleanup: true);
    const cleanupOnlyPlan = EnsembleTestExecutionPlan(
      ordered: [
        EnsembleTestDefinition(
          assetPath: 'tests/cleanup-only.test.yaml',
          testCase: EnsembleTestCase(
            id: 'cleanup-only',
            steps: [
              TestStep(type: 'expectText', args: {'text': 'Continue'})
            ],
          ),
        ),
      ],
    );
    final cleanupOnlyHost = (await runApplicationTestPlan(
      driver: cleanupOnlyDriver,
      plan: cleanupOnlyPlan,
      tester: tester,
      mode: ExecutionMode.widget,
    ))
        .results
        .single;
    final cleanupOnlyStandaloneProjection =
        RetryExecutionCoordinator.withAttemptCleanupFailures(
      EnsembleSingleTestResult.passed(
        testId: cleanupOnlyHost.testId,
        metadata: cleanupOnlyHost.metadata,
        durationMs: cleanupOnlyHost.durationMs,
        attempts: cleanupOnlyHost.attempts,
        retry: cleanupOnlyHost.retry,
        logs: cleanupOnlyHost.logs,
        report: cleanupOnlyHost.report,
        capabilityStatus: cleanupOnlyHost.capabilityStatus,
      ),
      failures: [
        (
          error: cleanupOnlyDriver.cleanupFailure,
          stackTrace: cleanupOnlyDriver.cleanupStackTrace!,
        ),
      ],
      phase: 'cleanup',
    );
    expect(cleanupOnlyHost.status, cleanupOnlyStandaloneProjection.status);
    expect(cleanupOnlyHost.message, cleanupOnlyStandaloneProjection.message,
        reason:
            'host=${cleanupOnlyHost.message} standalone=${cleanupOnlyStandaloneProjection.message}');
    expect(cleanupOnlyHost.failure?.toJson(),
        cleanupOnlyStandaloneProjection.failure?.toJson());
    expect(
        cleanupOnlyHost.secondaryFailures.map((failure) => failure.toJson()),
        cleanupOnlyStandaloneProjection.secondaryFailures
            .map((failure) => failure.toJson()));
    expect(cleanupOnlyHost.failure?.phase, 'cleanup');
    expect(cleanupOnlyHost.capabilityStatus,
        cleanupOnlyStandaloneProjection.capabilityStatus);

    final bodyAndCleanupDriver = _FlutterDriver(failCleanup: true);
    const bodyAndCleanupPlan = EnsembleTestExecutionPlan(
      ordered: [
        EnsembleTestDefinition(
          assetPath: 'tests/body-and-cleanup.test.yaml',
          testCase: EnsembleTestCase(
            id: 'body-and-cleanup',
            steps: [
              TestStep(type: 'expectText', args: {'text': 'Never visible'}),
            ],
          ),
        ),
      ],
    );
    final bodyAndCleanupHost = (await runApplicationTestPlan(
      driver: bodyAndCleanupDriver,
      plan: bodyAndCleanupPlan,
      tester: tester,
      mode: ExecutionMode.widget,
    ))
        .results
        .single;
    final cleanupMessage =
        'Cleanup failed: ${bodyAndCleanupDriver.cleanupFailure}';
    final standaloneBase = EnsembleSingleTestResult.failed(
      testId: bodyAndCleanupHost.testId,
      metadata: bodyAndCleanupHost.metadata,
      durationMs: bodyAndCleanupHost.durationMs,
      attempts: bodyAndCleanupHost.attempts,
      retry: bodyAndCleanupHost.retry,
      failedStepIndex: bodyAndCleanupHost.failedStepIndex,
      failedStep: bodyAndCleanupHost.failedStep,
      message:
          bodyAndCleanupHost.message!.replaceFirst('\n$cleanupMessage', ''),
      stackTrace: bodyAndCleanupHost.stackTrace,
      failureOperation: bodyAndCleanupHost.failureOperation,
      failureSource: bodyAndCleanupHost.failureSource,
      logs: bodyAndCleanupHost.logs,
      report: bodyAndCleanupHost.report,
      failure: bodyAndCleanupHost.failure,
      secondaryFailures: bodyAndCleanupHost.secondaryFailures
          .where((failure) =>
              failure.kind != TestFailureKind.cleanup ||
              failure.message != bodyAndCleanupDriver.cleanupFailure.toString())
          .toList(),
      capabilityStatus: bodyAndCleanupHost.capabilityStatus,
    );
    final bodyAndCleanupStandaloneProjection =
        RetryExecutionCoordinator.withAttemptCleanupFailures(
      standaloneBase,
      failures: [
        (
          error: bodyAndCleanupDriver.cleanupFailure,
          stackTrace: bodyAndCleanupDriver.cleanupStackTrace!,
        ),
      ],
      phase: 'cleanup',
    );
    expect(
        bodyAndCleanupHost.status, bodyAndCleanupStandaloneProjection.status);
    expect(
        bodyAndCleanupHost.message, bodyAndCleanupStandaloneProjection.message);
    expect(bodyAndCleanupHost.failure?.toJson(),
        bodyAndCleanupStandaloneProjection.failure?.toJson());
    expect(
        bodyAndCleanupHost.secondaryFailures.map((failure) => failure.toJson()),
        bodyAndCleanupStandaloneProjection.secondaryFailures
            .map((failure) => failure.toJson()));
    expect(bodyAndCleanupHost.capabilityStatus,
        bodyAndCleanupStandaloneProjection.capabilityStatus);
    expect(bodyAndCleanupHost.failure?.phase, 'execution');
    expect(bodyAndCleanupHost.secondaryFailures, hasLength(1));
  });

  testWidgets('preparation failure receives cleanup before its retry',
      (tester) async {
    final driver = _FlutterDriver(failFirstPreparation: true);
    const testCase = EnsembleTestCase(
      id: 'retry-after-prepare-failure',
      retry: 1,
      steps: [
        TestStep(type: 'expectText', args: {'text': 'Continue'}),
      ],
    );
    const plan = EnsembleTestExecutionPlan(
      ordered: [
        EnsembleTestDefinition(
          assetPath: 'tests/retry-after-prepare-failure.test.yaml',
          testCase: testCase,
        ),
      ],
    );

    final result = await runApplicationTestPlan(
      driver: driver,
      plan: plan,
      tester: tester,
      mode: ExecutionMode.widget,
    );

    expect(result.failedCount, 0, reason: result.toJson().toString());
    expect(result.results.single.attempts, 2);
    expect(driver.events, [
      'suite+',
      'prepare:0',
      'cleanup:0',
      'prepare:1',
      'launch:1',
      'cleanup:1',
      'suite-',
    ]);
  });

  testWidgets('optional swallows missing-target failures and continues',
      (tester) async {
    final driver = _FlutterDriver();
    const testCase = EnsembleTestCase(
      id: 'optional-continue',
      steps: [
        TestStep(
          type: 'optional',
          args: {},
          nestedSteps: [
            TestStep(type: 'tap', args: {'id': 'missing_banner'}),
          ],
        ),
        TestStep(type: 'expectText', args: {'text': 'Continue'}),
      ],
    );
    const plan = EnsembleTestExecutionPlan(
      ordered: [
        EnsembleTestDefinition(
          assetPath: 'tests/optional.test.yaml',
          testCase: testCase,
        ),
      ],
    );

    final result = await runApplicationTestPlan(
      driver: driver,
      plan: plan,
      tester: tester,
      mode: ExecutionMode.widget,
    );

    expect(result.failedCount, 0, reason: result.toJson().toString());
  });

  testWidgets('quality assertions are permitted without host services',
      (tester) async {
    final driver = _FlutterDriver();
    const testCase = EnsembleTestCase(
      id: 'quality-semantics',
      steps: [
        TestStep(
          type: 'expectSemanticsLabel',
          args: {'id': 'continue_btn', 'label': 'Continue'},
        ),
      ],
    );
    const plan = EnsembleTestExecutionPlan(
      ordered: [
        EnsembleTestDefinition(
          assetPath: 'tests/quality.test.yaml',
          testCase: testCase,
        ),
      ],
    );

    final result = await runApplicationTestPlan(
      driver: driver,
      plan: plan,
      tester: tester,
      mode: ExecutionMode.widget,
    );

    expect(result.failedCount, 0, reason: result.toJson().toString());
  });

  testWidgets('host results attach screenshots and debug logs', (tester) async {
    final driver = _FlutterDriver();
    const testCase = EnsembleTestCase(
      id: 'artifact-probe',
      steps: [
        TestStep(type: 'expectText', args: {'text': 'Continue'}),
      ],
    );
    const plan = EnsembleTestExecutionPlan(
      ordered: [
        EnsembleTestDefinition(
          assetPath: 'tests/artifacts.test.yaml',
          testCase: testCase,
        ),
      ],
      config: EnsembleTestConfig(
        screenshots: ScreenshotConfig(enabled: true),
        logApiCalls: LogApiCallsConfig(enabled: true),
      ),
    );

    final result = await runApplicationTestPlan(
      driver: driver,
      plan: plan,
      tester: tester,
      mode: ExecutionMode.widget,
    );

    expect(result.failedCount, 0, reason: result.toJson().toString());
    final logs = result.results.single.logs;
    expect(logs.any((line) => line.startsWith('appLogs:')), isTrue);
    expect(logs.any((line) => line.startsWith('apiCalls:')), isTrue);
    expect(logs.any((line) => line.startsWith('storage:')), isTrue);
    expect(logs.any((line) => line.startsWith('screenshotFrames:')), isTrue);
  });

  testWidgets('disabled host screenshots skip screenshot capture work',
      (tester) async {
    final plan = EnsembleTestExecutionPlan(
      ordered: const [
        EnsembleTestDefinition(
          assetPath: 'tests/no_screenshots.test.yaml',
          testCase: EnsembleTestCase(
            id: 'no-screenshots',
            steps: [
              TestStep(type: 'expectText', args: {'text': 'Continue'})
            ],
          ),
        ),
      ],
      config: const EnsembleTestConfig(
        screenshots: ScreenshotConfig(enabled: false),
      ),
    );
    final collector = BenchmarkCollector(
      caseId: 'no-screenshots',
      sample: 0,
      processId: 'test',
    );

    final result = await RunnerBenchmark.collect(
      collector,
      () => runApplicationTestPlan(
        driver: _FlutterDriver(),
        plan: plan,
        tester: tester,
        mode: ExecutionMode.widget,
      ),
    );

    expect(result.failedCount, 0, reason: result.toJson().toString());
    const evidenceStages = {
      'captureHostStepReportArtifactsSafely',
      'captureHostStepScreenshotSafely',
      'captureDiagnosticUiSnapshot',
      'encodeHostWebP',
    };
    expect(
      collector.spans.where((span) => evidenceStages.contains(span.operation)),
      isEmpty,
      reason: 'disabled screenshot capture must skip snapshot and encoding',
    );
    expect(
      result.results.single.logs
          .where((line) => line.startsWith('screenshotFrames:')),
      isEmpty,
    );
  });

  testWidgets('host tap evidence captures the screen before navigation',
      (tester) async {
    final driver = _FlutterDriver();
    const plan = EnsembleTestExecutionPlan(
      ordered: [
        EnsembleTestDefinition(
          assetPath: 'tests/pre_tap.test.yaml',
          testCase: EnsembleTestCase(
            id: 'pre-tap-evidence',
            steps: [
              TestStep(
                type: 'tap',
                args: {
                  'target': {'id': 'continue_btn'},
                },
              ),
              TestStep(type: 'expectText', args: {'text': 'Home'}),
            ],
          ),
        ),
      ],
      config: EnsembleTestConfig(
        screenshots: ScreenshotConfig(enabled: true),
        logApiCalls: LogApiCallsConfig(enabled: true),
      ),
    );

    final result = await runApplicationTestPlan(
      driver: driver,
      plan: plan,
      tester: tester,
      mode: ExecutionMode.widget,
    );

    expect(result.failedCount, 0, reason: result.toJson().toString());
    final framesLine = result.results.single.logs.firstWhere(
      (line) => line.startsWith('screenshotFrames:'),
    );
    final manifestPath =
        framesLine.substring('screenshotFrames:'.length).trim();
    final manifest = jsonDecode(File(manifestPath).readAsStringSync())
        as Map<String, dynamic>;
    final observer = (manifest['frames'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .firstWhere((frame) => frame['role'] == 'observer');
    final tapObservers = (manifest['frames'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .where(
            (frame) => frame['role'] == 'observer' && frame['stepIndex'] == 0)
        .toList();
    expect(tapObservers, hasLength(1));
    final observation = observer['observationJson'] as Map<String, dynamic>;
    final elements = jsonEncode(observation['elements']);
    expect(elements, contains('Continue'));
    expect(elements, isNot(contains('Home')));
    expect(
      result.results.single.logs.any((line) => line.startsWith('apiCalls:')),
      isTrue,
    );
  });

  testWidgets('host console capture records debugPrint once', (tester) async {
    final driver = _FlutterDriver();
    const testCase = EnsembleTestCase(
      id: 'console-once',
      steps: [
        TestStep(type: 'expectText', args: {'text': 'Continue'}),
        TestStep(
          type: 'tap',
          args: {
            'target': {'label': 'Continue', 'role': 'button'},
          },
        ),
      ],
    );
    const plan = EnsembleTestExecutionPlan(
      ordered: [
        EnsembleTestDefinition(
          assetPath: 'tests/console_once.test.yaml',
          testCase: testCase,
        ),
      ],
    );

    final result = await runApplicationTestPlan(
      driver: driver,
      plan: plan,
      tester: tester,
      mode: ExecutionMode.widget,
    );

    expect(result.failedCount, 0, reason: result.toJson().toString());
    final appLogsLine = result.results.single.logs.firstWhere(
      (line) => line.startsWith('appLogs:'),
    );
    final content = File(appLogsLine.substring('appLogs:'.length).trim())
        .readAsStringSync();
    expect(
      RegExp(r'host: Continue tapped').allMatches(content),
      hasLength(1),
    );
  });

  testWidgets('secure content does not fail a host test', (tester) async {
    final driver = _SecureFlutterDriver();
    const testCase = EnsembleTestCase(
      id: 'secure-skip',
      steps: [
        TestStep(type: 'expectText', args: {'text': 'Continue'}),
      ],
    );
    const plan = EnsembleTestExecutionPlan(
      ordered: [
        EnsembleTestDefinition(
          assetPath: 'tests/secure.test.yaml',
          testCase: testCase,
        ),
      ],
      config: EnsembleTestConfig(
        screenshots: ScreenshotConfig(
          enabled: true,
        ),
      ),
    );

    final result = await runApplicationTestPlan(
      driver: driver,
      plan: plan,
      tester: tester,
      mode: ExecutionMode.widget,
    );

    expect(result.failedCount, 0, reason: result.toJson().toString());
  });

  testWidgets('host screenshot with secure content captures observation',
      (tester) async {
    await tester.pumpWidget(const _SecureFlutterFixture());
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'secure-observation', steps: []),
      config: const EnsembleTestConfig(
        screenshots: ScreenshotConfig(
          enabled: true,
        ),
      ),
    );
    final collector = BenchmarkCollector(
      caseId: 'secure-observation',
      sample: 0,
      processId: 'test',
    );

    await RunnerBenchmark.collect(
      collector,
      () => captureHostStepScreenshot(
        tester: tester,
        context: context,
        assertions: AssertionEngine(tester: tester, context: context),
        step: const TestStep(type: 'expectText', args: {'text': 'Continue'}),
        stepIndex: 0,
      ),
    );

    expect(context.runtime.screenshotSheetFrames, hasLength(1));
    expect(context.runtime.stepObservers, hasLength(1));
    expect(
      collector.spans.where(
        (span) =>
            span.service == 'observer' &&
            span.operation == 'captureDiagnosticUiSnapshot',
      ),
      isNotEmpty,
    );
  });

  testWidgets('host screenshot keeps legacy tapAt classified as an action',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: ElevatedButton(
            key: const ValueKey('continue'),
            onPressed: () {},
            child: const Text('Continue'),
          ),
        ),
      ),
    ));
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'legacy-tap-at', steps: []),
      config: const EnsembleTestConfig(
        screenshots: ScreenshotConfig(enabled: true),
      ),
    );

    await captureHostStepScreenshot(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      step: const TestStep(type: 'tapAt', args: {'id': 'continue'}),
      stepIndex: 0,
    );

    expect(context.runtime.screenshotSheetFrames, hasLength(1));
    expect(
        context.runtime.screenshotSheetFrames.single.highlight?.kind, 'action');
  });

  testWidgets('host screenshot viewport matches the report device',
      (tester) async {
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'viewport', steps: []),
      config: const EnsembleTestConfig(
        screenshots: ScreenshotConfig(enabled: true),
      ),
    );
    await applyHostScreenshotViewport(tester, context);
    addTearDown(() => resetHostScreenshotViewport(tester));

    expect(tester.view.physicalSize, Devices.ios.iPhone15Pro.screenSize);
    expect(tester.view.devicePixelRatio, 1.0);
  });

  testWidgets('integration mode preserves the physical viewport',
      (tester) async {
    final original = tester.view.physicalSize;
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'viewport-integration', steps: []),
      config: const EnsembleTestConfig(
        screenshots: ScreenshotConfig(enabled: true),
      ),
    );
    await applyHostScreenshotViewport(
      tester,
      context,
      mode: ExecutionMode.integration,
    );
    await resetHostScreenshotViewport(tester, mode: ExecutionMode.integration);

    expect(tester.view.physicalSize, original);
    expect(context.runtime.deviceSize, original);
  });

  test('host process services are skipped when the CLI owns fixtures', () {
    const sample = [
      TestServiceConfig(
        name: 'api',
        command: 'dart',
        arguments: ['run', 'fake'],
      ),
    ];
    expect(
      hostProcessServiceConfigs(sample, hostOwnsServices: true),
      isEmpty,
    );
    expect(
      hostProcessServiceConfigs(sample, hostOwnsServices: false),
      sample,
    );
  });

  test('suite and test API mocks fail closed without a host mocking capability',
      () {
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(
        id: 'needs-mocks',
        mocks: TestMocks(
          apis: {
            'hostLogin': MockAPIResponse(body: {'token': 'x'}),
          },
        ),
        steps: [],
      ),
      config: const EnsembleTestConfig(
        inlineMocks: {
          'hostLogin': {
            'statusCode': 200,
            'body': {'token': 'x'},
          },
        },
      ),
    );

    expect(
      () => ensureHostFixturesSupported(context, requireResolved: true),
      throwsA(
        isA<UnsupportedApplicationCapability>().having(
          (error) => error.capability,
          'capability',
          'apiMocking',
        ),
      ),
    );
  });

  testWidgets(
      'declared API mocks without host capability fail before steps run',
      (tester) async {
    final driver = _FlutterDriver();
    const plan = EnsembleTestExecutionPlan(
      config: EnsembleTestConfig(
        inlineMocks: {
          'hostLogin': {
            'statusCode': 200,
            'body': {'token': 'x'},
          },
        },
      ),
      ordered: [
        EnsembleTestDefinition(
          assetPath: 'tests/config.yaml',
          testCase: EnsembleTestCase(
            id: 'unused-mocks',
            mocks: TestMocks(
              apis: {
                'hostLogin': MockAPIResponse(body: {'token': 'x'}),
              },
            ),
            steps: [
              TestStep(type: 'expectText', args: {'text': 'Continue'}),
            ],
          ),
        ),
      ],
    );

    final result = await runApplicationTestPlan(
      driver: driver,
      plan: plan,
      tester: tester,
      mode: ExecutionMode.widget,
    );

    expect(result.failedCount, 1);
    expect(
      result.results.single.failure?.kind,
      TestFailureKind.unsupportedCapability,
    );
    expect(driver.events,
        ['suite+', 'prepare:0', 'launch:0', 'cleanup:0', 'suite-']);
  });

  testWidgets('host ApiMockingTestService accepts suite-level API mocks',
      (tester) async {
    final driver = _MockingApiDriver();
    const plan = EnsembleTestExecutionPlan(
      config: EnsembleTestConfig(
        inlineMocks: {
          'hostLogin': {
            'statusCode': 200,
            'body': {'token': 'x'},
          },
        },
      ),
      ordered: [
        EnsembleTestDefinition(
          assetPath: 'tests/config.yaml',
          testCase: EnsembleTestCase(
            id: 'mocked',
            mocks: TestMocks(
              apis: {
                'hostLogin': MockAPIResponse(body: {'token': 'x'}),
              },
            ),
            steps: [
              TestStep(type: 'expectText', args: {'text': 'Continue'}),
            ],
          ),
        ),
      ],
    );

    final result = await runApplicationTestPlan(
      driver: driver,
      plan: plan,
      tester: tester,
      mode: ExecutionMode.widget,
    );

    expect(result.failedCount, 0, reason: result.toJson().toString());
    expect(driver.api.applied?.apis.keys, ['hostLogin']);
  });
}

class _FlutterDriver implements ApplicationTestDriver {
  _FlutterDriver({
    this.failFirstLaunch = false,
    this.failFirstPreparation = false,
    this.failCleanup = false,
  });

  final bool failFirstLaunch;
  final bool failFirstPreparation;
  final bool failCleanup;
  final StateError cleanupFailure = StateError('attempt cleanup failed');
  StackTrace? cleanupStackTrace;
  final List<String> events = [];
  final List<TestApplicationHandle?> cleanupHandles = [];

  @override
  Future<void> setUpSuite(TestSuiteContext context) async {
    events.add('suite+');
  }

  @override
  Future<void> prepareTest(TestLaunchContext context) async {
    events.add('prepare:${context.attempt}');
    if (failFirstPreparation && context.attempt == 0) {
      throw StateError('first preparation failed');
    }
  }

  @override
  Future<TestApplicationHandle> launch(
    WidgetTester tester,
    TestLaunchContext context,
  ) async {
    events.add('launch:${context.attempt}');
    if (failFirstLaunch && context.attempt == 0) {
      throw StateError('first launch failed');
    }
    await tester.pumpWidget(const _FlutterFixture());
    return const _Handle();
  }

  @override
  Future<void> tearDownTest(
    WidgetTester tester,
    TestLaunchContext context,
    TestApplicationHandle? handle,
  ) async {
    events.add('cleanup:${context.attempt}');
    cleanupHandles.add(handle);
    await tester.pumpWidget(const SizedBox.shrink());
    if (failCleanup) {
      cleanupStackTrace = StackTrace.current;
      Error.throwWithStackTrace(cleanupFailure, cleanupStackTrace!);
    }
  }

  @override
  Future<void> tearDownSuite() async {
    events.add('suite-');
  }
}

class _MockApiService implements ApiMockingTestService {
  TestMocks? applied;

  @override
  void applyMocks(TestMocks mocks) => applied = mocks;

  @override
  void resetCalls() {}

  @override
  int callCount(String name) => 0;
}

class _MockingApiDriver extends _FlutterDriver {
  final api = _MockApiService();

  @override
  Future<TestApplicationHandle> launch(
    WidgetTester tester,
    TestLaunchContext context,
  ) async {
    events.add('launch:${context.attempt}');
    await tester.pumpWidget(const _FlutterFixture());
    return _MockingHandle(api);
  }
}

class _MockingHandle implements TestApplicationHandle {
  const _MockingHandle(this._api);

  final ApiMockingTestService _api;

  @override
  ApplicationTestServices get services => ApplicationTestServices(api: _api);
}

class _Handle implements TestApplicationHandle {
  const _Handle();

  @override
  ApplicationTestServices get services => const ApplicationTestServices();
}

class _FlutterFixture extends StatefulWidget {
  const _FlutterFixture();

  @override
  State<_FlutterFixture> createState() => _FlutterFixtureState();
}

class _FlutterFixtureState extends State<_FlutterFixture> {
  var home = false;

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: home
              ? const Text('Home')
              : ElevatedButton(
                  key: const ValueKey('continue_btn'),
                  onPressed: () {
                    debugPrint('host: Continue tapped');
                    setState(() => home = true);
                  },
                  child: const Text('Continue'),
                ),
        ),
      );
}

class _SecureFlutterDriver implements ApplicationTestDriver {
  @override
  Future<void> setUpSuite(TestSuiteContext context) async {}

  @override
  Future<void> prepareTest(TestLaunchContext context) async {}

  @override
  Future<TestApplicationHandle> launch(
    WidgetTester tester,
    TestLaunchContext context,
  ) async {
    await tester.pumpWidget(const _SecureFlutterFixture());
    return const _Handle();
  }

  @override
  Future<void> tearDownTest(
    WidgetTester tester,
    TestLaunchContext context,
    TestApplicationHandle? handle,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());
  }

  @override
  Future<void> tearDownSuite() async {}
}

class _SecureFlutterFixture extends StatelessWidget {
  const _SecureFlutterFixture();

  @override
  Widget build(BuildContext context) => const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TextField(obscureText: true),
              ElevatedButton(
                key: ValueKey('continue_btn'),
                onPressed: _noopSecureButton,
                child: Text('Continue'),
              ),
            ],
          ),
        ),
      );
}

void _noopSecureButton() {}
