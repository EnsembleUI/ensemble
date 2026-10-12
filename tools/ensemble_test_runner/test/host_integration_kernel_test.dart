import 'dart:convert';
import 'dart:async';

import 'package:ensemble/framework/screen_tracker.dart';
import 'package:ensemble_test_runner/application/application_test_driver.dart';
import 'package:ensemble_test_runner/discovery/ensemble_test_execution_planner.dart';
import 'package:ensemble_test_runner/entry/application_test_entry.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/test_artifacts.dart';
import 'package:ensemble_test_runner/src/runtime/test_execution_binding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exercises the application host contract with the integration binding.
///
/// Keeping this as an integration test catches accidental divergence between
/// the host entry and the widget test entry while still using the same kernel
/// and driver lifecycle. The fixture is intentionally local so it never
/// changes an application under test.
void main() {
  ensureExecutionBinding(ExecutionMode.integration);

  testWidgets('host navigation timeout is counted once in step timing',
      (tester) async {
    ScreenTracker().clearAll();
    const plan = EnsembleTestExecutionPlan(
      ordered: [
        EnsembleTestDefinition(
          assetPath: 'tests/host/navigation-timeout.test.yaml',
          testCase: EnsembleTestCase(
            id: 'host-navigation-timeout',
            steps: [
              TestStep(
                type: 'waitForNavigation',
                args: {
                  'screen': 'NeverAppears',
                  'timeoutMs': 250,
                },
              ),
            ],
          ),
        ),
      ],
    );
    final result = await runApplicationTestPlan(
      driver: _IntegrationDriver(),
      plan: plan,
      tester: tester,
      mode: ExecutionMode.integration,
    );
    expect(result.failedCount, 1, reason: result.toJson().toString());
    final report = result.results.single.report!;
    expect(report.stepDurationsMs, hasLength(1));
    expect(report.stepDurationsMs.single, greaterThanOrEqualTo(200));
    expect(report.stepDurationsMs.single, lessThan(1000));
    // The authored step duration is the relevant contract. Whole-test wall
    // time includes host setup and can vary with unrelated test concurrency.
  });

  testWidgets('host integration execution uses the shared kernel',
      (tester) async {
    const plan = EnsembleTestExecutionPlan(
      ordered: [
        EnsembleTestDefinition(
          assetPath: 'tests/host/integration.test.yaml',
          testCase: EnsembleTestCase(
            id: 'host-integration',
            steps: [
              TestStep(type: 'expectVisible', args: {'id': 'host_home'}),
              TestStep(type: 'tap', args: {'id': 'advance'}),
              TestStep(type: 'expectText', args: {'text': 'Ready'}),
            ],
          ),
        ),
      ],
    );

    final driver = _IntegrationDriver();
    final result = await runApplicationTestPlan(
      driver: driver,
      plan: plan,
      tester: tester,
      mode: ExecutionMode.integration,
    );

    expect(result.failedCount, 0, reason: result.toJson().toString());
    expect(driver.events,
        ['suite+', 'prepare:0', 'launch:0', 'cleanup:0', 'suite-']);
    expect(result.results.single.capabilityStatus['navigation'], isFalse);
  });

  testWidgets('integration evidence pairs screenshot with matched Observer',
      (tester) async {
    const testId = 'host-integration-evidence';
    final manifest =
        ensembleTestArtifactFile('frames', '${testId}_frames.json');
    if (manifest.existsSync()) manifest.deleteSync();

    const plan = EnsembleTestExecutionPlan(
      config: EnsembleTestConfig(
        screenshots: ScreenshotConfig(enabled: true),
      ),
      ordered: [
        EnsembleTestDefinition(
          assetPath: 'tests/host/integration-evidence.test.yaml',
          testCase: EnsembleTestCase(
            id: testId,
            steps: [
              TestStep(type: 'tap', args: {'id': 'advance'})
            ],
          ),
        ),
      ],
    );

    final result = await runApplicationTestPlan(
      driver: _IntegrationDriver(),
      plan: plan,
      tester: tester,
      mode: ExecutionMode.integration,
    );

    expect(result.failedCount, 0, reason: result.toJson().toString());
    expect(manifest.existsSync(), isTrue);
    final decoded = jsonDecode(manifest.readAsStringSync()) as Map;
    final frames = (decoded['frames'] as List).cast<Map>();
    final screenshot = frames.singleWhere((entry) => entry['role'] == null);
    final observer = frames.singleWhere((entry) => entry['role'] == 'observer');

    expect(screenshot['stepIndex'], 0);
    expect(observer['stepIndex'], screenshot['stepIndex']);
    // The button changes Home to Ready when tapped. Seeing Home in the paired
    // Observer snapshot proves both artifacts belong to the pre-tap frame.
    expect(observer['observationJson'].toString(), contains('Home'));
    expect(observer['observationJson'].toString(), isNot(contains('Ready')));
  });

  testWidgets('host integration captures successful condition evidence',
      (tester) async {
    const testId = 'host-integration-condition-evidence';
    final manifest =
        ensembleTestArtifactFile('frames', '${testId}_frames.json');
    if (manifest.existsSync()) manifest.deleteSync();

    const plan = EnsembleTestExecutionPlan(
      config: EnsembleTestConfig(
        screenshots: ScreenshotConfig(enabled: true),
      ),
      ordered: [
        EnsembleTestDefinition(
          assetPath: 'tests/host/integration-condition-evidence.test.yaml',
          testCase: EnsembleTestCase(
            id: testId,
            steps: [
              TestStep(type: 'tap', args: {'id': 'advance'}),
              TestStep(type: 'expectText', args: {'text': 'Ready'}),
            ],
          ),
        ),
      ],
    );

    final result = await runApplicationTestPlan(
      driver: _IntegrationDriver(),
      plan: plan,
      tester: tester,
      mode: ExecutionMode.integration,
    );

    expect(result.failedCount, 0, reason: result.toJson().toString());
    final decoded =
        jsonDecode(manifest.readAsStringSync()) as Map<String, dynamic>;
    final frames = (decoded['frames'] as List).cast<Map>();
    final conditionObserver = frames.singleWhere(
      (entry) => entry['role'] == 'observer' && entry['stepIndex'] == 1,
    );
    expect(conditionObserver['observationJson'].toString(), contains('Ready'));
  });

  testWidgets('host navigation wait captures evidence at the matched route',
      (tester) async {
    const testId = 'host-navigation-match-evidence';
    final manifest =
        ensembleTestArtifactFile('frames', '${testId}_frames.json');
    if (manifest.existsSync()) manifest.deleteSync();
    ScreenTracker().clearAll();

    const plan = EnsembleTestExecutionPlan(
      config: EnsembleTestConfig(
        screenshots: ScreenshotConfig(enabled: true),
      ),
      ordered: [
        EnsembleTestDefinition(
          assetPath: 'tests/host/navigation-match.test.yaml',
          testCase: EnsembleTestCase(
            id: testId,
            steps: [
              TestStep(type: 'tap', args: {'id': 'begin-target-navigation'}),
              TestStep(
                type: 'waitForNavigation',
                args: {'screen': 'Target', 'timeoutMs': 500},
              ),
            ],
          ),
        ),
      ],
    );

    final result = await runApplicationTestPlan(
      driver: _DelayedNavigationDriver(),
      plan: plan,
      tester: tester,
      mode: ExecutionMode.integration,
    );

    expect(result.failedCount, 0, reason: result.toJson().toString());
    final decoded = jsonDecode(manifest.readAsStringSync()) as Map;
    final frames = (decoded['frames'] as List).cast<Map>();
    final observer = frames.singleWhere(
      (entry) => entry['role'] == 'observer' && entry['stepIndex'] == 1,
    );
    expect(observer['observationJson'].toString(), contains('Target screen'));
    expect(
        observer['observationJson'].toString(), isNot(contains('Home screen')));
  });

  testWidgets('host navigation evidence stays aligned after an unpainted route',
      (tester) async {
    const testId = 'host-navigation-unpainted-transient-evidence';
    final manifest =
        ensembleTestArtifactFile('frames', '${testId}_frames.json');
    if (manifest.existsSync()) manifest.deleteSync();
    ScreenTracker().clearAll();

    const plan = EnsembleTestExecutionPlan(
      config: EnsembleTestConfig(
        screenshots: ScreenshotConfig(enabled: true),
      ),
      ordered: [
        EnsembleTestDefinition(
          assetPath: 'tests/host/navigation-transient.test.yaml',
          testCase: EnsembleTestCase(
            id: testId,
            steps: [
              TestStep(type: 'tap', args: {'id': 'begin-navigation'}),
              TestStep(
                type: 'waitForNavigation',
                args: {'screen': 'Transient', 'timeoutMs': 3000},
              ),
            ],
          ),
        ),
      ],
    );

    final result = await runApplicationTestPlan(
      driver: _UnpaintedTransientNavigationDriver(),
      plan: plan,
      tester: tester,
      mode: ExecutionMode.integration,
    );

    expect(result.failedCount, 0, reason: result.toJson().toString());
    final decoded = jsonDecode(manifest.readAsStringSync()) as Map;
    final frames = (decoded['frames'] as List).cast<Map>();
    final screenshot = frames.singleWhere(
      (entry) => entry['role'] == null && entry['stepIndex'] == 1,
    );
    final observer = frames.singleWhere(
      (entry) => entry['role'] == 'observer' && entry['stepIndex'] == 1,
    );
    final observation = (observer['observationJson'] as Map).toString();
    expect(screenshot['stepIndex'], 1);
    expect(observation, contains('Final screen'));
    expect(observation, isNot(contains('Transient screen')));
    expect(observer['stepIndex'], 1);
  });

  testWidgets('host integration failure still closes the attempt',
      (tester) async {
    const plan = EnsembleTestExecutionPlan(
      ordered: [
        EnsembleTestDefinition(
          assetPath: 'tests/host/integration-failure.test.yaml',
          testCase: EnsembleTestCase(
            id: 'host-integration-failure',
            steps: [
              TestStep(
                type: 'tap',
                args: {'id': 'missing-control', 'timeoutMs': 1},
              ),
            ],
          ),
        ),
      ],
    );

    final driver = _IntegrationDriver();
    final result = await runApplicationTestPlan(
      driver: driver,
      plan: plan,
      tester: tester,
      mode: ExecutionMode.integration,
    );

    expect(result.failedCount, 1);
    expect(
        result.results.single.failure?.kind, TestFailureKind.elementNotFound);
    expect(driver.events,
        ['suite+', 'prepare:0', 'launch:0', 'cleanup:0', 'suite-']);
  });

  testWidgets('excluded host failure step does not capture screenshot evidence',
      (tester) async {
    const testId = 'host-integration-excluded-failure-evidence';
    final manifest =
        ensembleTestArtifactFile('frames', '${testId}_frames.json');
    if (manifest.existsSync()) manifest.deleteSync();

    const plan = EnsembleTestExecutionPlan(
      config: EnsembleTestConfig(
        screenshots: ScreenshotConfig(
          enabled: true,
          includeSteps: ['expectVisible'],
        ),
      ),
      ordered: [
        EnsembleTestDefinition(
          assetPath: 'tests/host/excluded-failure.test.yaml',
          testCase: EnsembleTestCase(
            id: testId,
            steps: [
              TestStep(
                type: 'tap',
                args: {'id': 'missing-control', 'timeoutMs': 1},
              ),
            ],
          ),
        ),
      ],
    );

    final result = await runApplicationTestPlan(
      driver: _IntegrationDriver(),
      plan: plan,
      tester: tester,
      mode: ExecutionMode.integration,
    );

    expect(result.failedCount, 1, reason: result.toJson().toString());
    expect(manifest.existsSync(), isFalse);
  });
}

class _IntegrationDriver implements ApplicationTestDriver {
  final events = <String>[];

  @override
  Future<void> setUpSuite(TestSuiteContext context) async =>
      events.add('suite+');

  @override
  Future<void> prepareTest(TestLaunchContext context) async {
    events.add('prepare:${context.attempt}');
  }

  @override
  Future<TestApplicationHandle> launch(
    WidgetTester tester,
    TestLaunchContext context,
  ) async {
    events.add('launch:${context.attempt}');
    await tester.pumpWidget(const _HostFixture());
    return const _Handle();
  }

  @override
  Future<void> tearDownTest(
    WidgetTester tester,
    TestLaunchContext context,
    TestApplicationHandle? handle,
  ) async {
    events.add('cleanup:${context.attempt}');
    await tester.pumpWidget(const SizedBox.shrink());
  }

  @override
  Future<void> tearDownSuite() async => events.add('suite-');
}

class _DelayedNavigationDriver implements ApplicationTestDriver {
  @override
  Future<void> setUpSuite(TestSuiteContext context) async {}

  @override
  Future<void> prepareTest(TestLaunchContext context) async {}

  @override
  Future<TestApplicationHandle> launch(
    WidgetTester tester,
    TestLaunchContext context,
  ) async {
    await tester.pumpWidget(const _DelayedNavigationFixture());
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

class _DelayedNavigationFixture extends StatefulWidget {
  const _DelayedNavigationFixture();

  @override
  State<_DelayedNavigationFixture> createState() =>
      _DelayedNavigationFixtureState();
}

class _DelayedNavigationFixtureState extends State<_DelayedNavigationFixture> {
  var targetVisible = false;

  void beginNavigation() {
    Timer(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      setState(() => targetVisible = true);
      ScreenTracker().trackScreen(screenName: 'Target');
    });
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Text(targetVisible ? 'Target screen' : 'Home screen'),
                ElevatedButton(
                  key: const ValueKey('begin-target-navigation'),
                  onPressed: beginNavigation,
                  child: const Text('Begin'),
                ),
              ],
            ),
          ),
        ),
      );
}

class _UnpaintedTransientNavigationDriver implements ApplicationTestDriver {
  @override
  Future<void> setUpSuite(TestSuiteContext context) async {}

  @override
  Future<void> prepareTest(TestLaunchContext context) async {}

  @override
  Future<TestApplicationHandle> launch(
    WidgetTester tester,
    TestLaunchContext context,
  ) async {
    await tester.pumpWidget(const _UnpaintedTransientNavigationFixture());
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

class _UnpaintedTransientNavigationFixture extends StatefulWidget {
  const _UnpaintedTransientNavigationFixture();

  @override
  State<_UnpaintedTransientNavigationFixture> createState() =>
      _UnpaintedTransientNavigationFixtureState();
}

class _UnpaintedTransientNavigationFixtureState
    extends State<_UnpaintedTransientNavigationFixture> {
  var screen = 'Home';

  void beginNavigation() {
    Timer(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      setState(() => screen = 'Transient');
      ScreenTracker().trackScreen(screenName: 'Transient');
      Timer(const Duration(milliseconds: 4), () {
        if (!mounted) return;
        setState(() => screen = 'Final');
        ScreenTracker().trackScreen(screenName: 'Final');
      });
    });
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Text('$screen screen'),
                ElevatedButton(
                  key: const ValueKey('begin-navigation'),
                  onPressed: beginNavigation,
                  child: const Text('Begin'),
                ),
              ],
            ),
          ),
        ),
      );
}

class _HostFixture extends StatefulWidget {
  const _HostFixture();

  @override
  State<_HostFixture> createState() => _HostFixtureState();
}

class _HostFixtureState extends State<_HostFixture> {
  var ready = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Text(ready ? 'Ready' : 'Home', key: const ValueKey('host_home')),
              ElevatedButton(
                key: const ValueKey('advance'),
                onPressed: () => setState(() => ready = true),
                child: const Text('Advance'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Handle implements TestApplicationHandle {
  const _Handle();

  @override
  ApplicationTestServices get services => const ApplicationTestServices();
}
