import 'package:ensemble_test_runner/application/application_test_driver.dart';
import 'package:ensemble_test_runner/discovery/ensemble_test_execution_planner.dart';
import 'package:ensemble_test_runner/entry/application_test_entry.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
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
                  onPressed: () => setState(() => home = true),
                  child: const Text('Continue'),
                ),
        ),
      );
}
