import 'dart:io';

import 'package:ensemble_device_preview/ensemble_device_preview.dart';
import 'package:ensemble_test_runner/application/application_test_driver.dart';
import 'package:ensemble_test_runner/discovery/ensemble_test_execution_planner.dart';
import 'package:ensemble_test_runner/entry/application_test_entry.dart';
import 'package:ensemble_test_runner/entry/host_test_artifacts.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  testWidgets('secureContent skip does not fail a host test', (tester) async {
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
          secureContent: SecureScreenshotPolicy.skip,
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
}

class _FlutterDriver implements ApplicationTestDriver {
  _FlutterDriver({this.failFirstLaunch = false});

  final bool failFirstLaunch;
  final List<String> events = [];

  @override
  Future<void> setUpSuite(TestSuiteContext context) async {
    events.add('suite+');
  }

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
    await tester.pumpWidget(const SizedBox.shrink());
  }

  @override
  Future<void> tearDownSuite() async {
    events.add('suite-');
  }
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
