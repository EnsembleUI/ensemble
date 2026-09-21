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

  test('pendingHostApplicationError ignores screenshot diagnostics', () {
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'errors', steps: []),
    );
    context.runtime.flutterErrors.addAll([
      'Screenshot skipped because secure content is visible',
      'Null check operator used on a null value',
    ]);
    expect(
      pendingHostApplicationError(context),
      'Null check operator used on a null value',
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
    expect(driver.events, ['suite+', 'prepare:0', 'launch:0', 'cleanup:0', 'suite-']);
  });

  testWidgets(
      'host ApiMockingTestService accepts suite-level API mocks',
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

  test('pending application errors after screenshots classify as crashes', () {
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'late-error', steps: []),
    );
    context.runtime.flutterErrors.add('screenshot-frame application error');
    expect(
      () => assertNoPendingHostApplicationError(context),
      throwsA(
        isA<ApplicationTestCrash>().having(
          (error) => error.message,
          'message',
          contains('screenshot-frame application error'),
        ),
      ),
    );
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
