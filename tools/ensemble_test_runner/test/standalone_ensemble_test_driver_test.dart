import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/definition_providers/provider.dart';
import 'package:ensemble/framework/screen_tracker.dart';
import 'package:ensemble_test_runner/application/application_test_driver.dart';
import 'package:ensemble_test_runner/application/standalone_ensemble_test_driver.dart';
import 'package:ensemble_test_runner/discovery/ensemble_test_execution_planner.dart';
import 'package:ensemble_test_runner/entry/application_test_entry.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('standalone driver records and detaches attempt navigation',
      (tester) async {
    EnsembleTestHarness.ensureTestPlugins();
    ScreenTracker().clearAll();
    final driver = StandaloneEnsembleTestDriver(harness: _Harness());
    const testCase = EnsembleTestCase(id: 'standalone', steps: []);
    const launchContext = TestLaunchContext(
      attemptId: 'standalone-1',
      attempt: 1,
      testCase: testCase,
      config: EnsembleTestConfig(),
    );

    final handle = await driver.launch(tester, launchContext);
    final navigation = handle.services.navigation!;
    expect(navigation.routeHistory, ['Ready']);

    final standaloneHandle = handle as StandaloneEnsembleApplicationHandle;
    await standaloneHandle.context.navigationFlow.stopListening();
    ScreenTracker().trackScreen(screenName: 'After teardown');
    await tester.pump();

    expect(navigation.routeHistory, ['Ready']);
    ScreenTracker().clearAll();
  });

  testWidgets('standalone launch failure releases its owned listener',
      (tester) async {
    EnsembleTestHarness.ensureTestPlugins();
    final harness = _Harness(failLoad: true);
    final driver = StandaloneEnsembleTestDriver(harness: harness);
    const testCase = EnsembleTestCase(id: 'standalone-failure', steps: []);
    const launchContext = TestLaunchContext(
      attemptId: 'standalone-failure-1',
      attempt: 0,
      testCase: testCase,
      config: EnsembleTestConfig(),
    );

    await expectLater(
      driver.launch(tester, launchContext),
      throwsA(isA<StateError>().having(
        (error) => error.message,
        'message',
        'load failed',
      )),
    );

    expect(harness.loadedContext, isNotNull);
    expect(harness.loadedContext!.navigationFlow.isListening, isFalse);
  });

  testWidgets('application plan reuses the shared attempt runtime context',
      (tester) async {
    EnsembleTestHarness.ensureTestPlugins();
    ScreenTracker().clearAll();
    const testCase = EnsembleTestCase(
      id: 'shared-runtime',
      steps: [
        TestStep(type: 'wait', args: {'durationMs': 0})
      ],
    );
    const plan = EnsembleTestExecutionPlan(
      ordered: [
        EnsembleTestDefinition(
          assetPath: 'tests/shared-runtime.test.yaml',
          testCase: testCase,
        ),
      ],
    );
    final harness = _Harness();
    final driver = _RecordingDriver(harness: harness);

    final result = await runApplicationTestPlan(
      driver: driver,
      plan: plan,
      tester: tester,
      mode: ExecutionMode.widget,
    );
    await tester.pump();

    expect(result.failedCount, 0, reason: result.toJson().toString());
    expect(driver.attemptState, same(harness.loadedContext));
    expect(driver.attemptState!.navigationFlow.isListening, isFalse);
    expect(driver.attemptState!.navigationFlow.flow, ['Ready']);
    ScreenTracker().clearAll();
  });

  testWidgets('disabled standalone screenshots skip snapshot and encoding',
      (tester) async {
    EnsembleTestHarness.ensureTestPlugins();
    ScreenTracker().clearAll();
    const testCase = EnsembleTestCase(
      id: 'standalone-no-screenshots',
      steps: [
        TestStep(type: 'wait', args: {'durationMs': 0})
      ],
    );
    const plan = EnsembleTestExecutionPlan(
      ordered: [
        EnsembleTestDefinition(
          assetPath: 'tests/standalone-no-screenshots.test.yaml',
          testCase: testCase,
        ),
      ],
      config: EnsembleTestConfig(
        screenshots: ScreenshotConfig(enabled: false),
      ),
    );
    final driver = _RecordingDriver(harness: _Harness());
    final collector = BenchmarkCollector(
      caseId: 'standalone-no-screenshots',
      sample: 0,
      processId: 'test',
    );

    final result = await RunnerBenchmark.collect(
      collector,
      () => runApplicationTestPlan(
        driver: driver,
        plan: plan,
        tester: tester,
        mode: ExecutionMode.widget,
      ),
    );

    expect(result.failedCount, 0, reason: result.toJson().toString());
    expect(driver.attemptState, isNotNull);
    const evidenceStages = {
      'captureStepReportArtifacts',
      'captureAutomaticScreenshotForStep',
      'captureDiagnosticUiSnapshot',
      'encodeWebP',
    };
    expect(
      collector.spans.where((span) => evidenceStages.contains(span.operation)),
      isEmpty,
      reason: 'disabled screenshot capture must skip snapshot and encoding',
    );
    expect(driver.attemptState!.runtime.screenshotSheetFrames, isEmpty);
    expect(
      result.results.single.logs
          .where((line) => line.startsWith('screenshotFrames:')),
      isEmpty,
    );
    ScreenTracker().clearAll();
  });
}

class _RecordingDriver extends StandaloneEnsembleTestDriver {
  _RecordingDriver({required super.harness});

  EnsembleTestContext? attemptState;

  @override
  Future<void> setUpSuite(TestSuiteContext context) async {}

  @override
  Future<void> prepareTest(TestLaunchContext context) async {}

  @override
  Future<TestApplicationHandle> launchWithAttemptState(
    WidgetTester tester,
    TestLaunchContext context,
    EnsembleTestContext attemptState,
  ) {
    this.attemptState = attemptState;
    return super.launchWithAttemptState(tester, context, attemptState);
  }

  @override
  Future<void> tearDownTest(
    WidgetTester tester,
    TestLaunchContext context,
    TestApplicationHandle? handle,
  ) async {}

  @override
  Future<void> tearDownSuite() async {}
}

class _Harness extends EnsembleTestHarness {
  _Harness({this.failLoad = false}) : super(appPath: '', appHome: '');

  final bool failLoad;

  EnsembleTestContext? loadedContext;

  @override
  Future<EnsembleConfig> loadScreen({
    required WidgetTester tester,
    required EnsembleTestCase testCase,
    EnsembleConfig? existingConfig,
    EnsembleTestContext? context,
    EnsembleTestConfig suiteConfig = const EnsembleTestConfig(),
    Future<void> Function()? beforeBootstrap,
    Locale? forcedLocale,
  }) async {
    loadedContext = context;
    if (failLoad) throw StateError('load failed');
    ScreenTracker().trackScreen(screenName: 'Ready');
    await tester.pump();
    return EnsembleConfig(definitionProvider: _UnusedDefinitionProvider());
  }
}

class _UnusedDefinitionProvider implements DefinitionProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
