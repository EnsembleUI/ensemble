import 'package:ensemble_test_runner/application/application_test_driver.dart';
import 'package:ensemble_test_runner/discovery/ensemble_test_execution_planner.dart';
import 'package:ensemble_test_runner/entry/application_test_entry.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal Login → Home → Settings app used as the pure-Flutter host fixture.
class FlutterHostApp extends StatefulWidget {
  const FlutterHostApp({super.key});

  @override
  State<FlutterHostApp> createState() => _FlutterHostAppState();
}

class _FlutterHostAppState extends State<FlutterHostApp> {
  var route = 'login';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: switch (route) {
          'home' => Column(
              key: const ValueKey('home_screen'),
              children: [
                const Text('Home', key: ValueKey('home_title')),
                ElevatedButton(
                  key: const ValueKey('open_settings'),
                  onPressed: () => setState(() => route = 'settings'),
                  child: const Text('Settings'),
                ),
              ],
            ),
          'settings' => const Column(
              key: ValueKey('settings_screen'),
              children: [
                Text('Settings', key: ValueKey('settings_title')),
              ],
            ),
          _ => Column(
              key: const ValueKey('login_screen'),
              children: [
                const TextField(
                  key: ValueKey('email_field'),
                  decoration: InputDecoration(labelText: 'Email'),
                ),
                ElevatedButton(
                  key: const ValueKey('login_button'),
                  onPressed: () => setState(() => route = 'home'),
                  child: const Text('Continue'),
                ),
              ],
            ),
        },
      ),
    );
  }
}

class FlutterHostTestDriver implements ApplicationTestDriver {
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
    await tester.pumpWidget(const FlutterHostApp());
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

void main() {
  testWidgets('flutter host Login → Home → Settings with id and target',
      (tester) async {
    final driver = FlutterHostTestDriver();
    const plan = EnsembleTestExecutionPlan(
      ordered: [
        EnsembleTestDefinition(
          assetPath:
              'tests/fixtures/flutter_host/login_home_settings.test.yaml',
          testCase: EnsembleTestCase(
            id: 'login_home_settings',
            steps: [
              TestStep(type: 'expectVisible', args: {'id': 'login_screen'}),
              TestStep(
                type: 'expectVisible',
                args: {
                  'target': {'label': 'Continue', 'role': 'button'},
                },
              ),
              TestStep(type: 'tap', args: {'id': 'login_button'}),
              TestStep(type: 'expectVisible', args: {'id': 'home_title'}),
              TestStep(type: 'tap', args: {'id': 'open_settings'}),
              TestStep(type: 'expectVisible', args: {'id': 'settings_title'}),
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
    expect(result.results.single.report?.startScreen, isNull);
    expect(result.results.single.report?.navigationKnown, isFalse);
  });

  testWidgets('missing target fails with structured elementNotFound',
      (tester) async {
    final driver = FlutterHostTestDriver();
    const plan = EnsembleTestExecutionPlan(
      ordered: [
        EnsembleTestDefinition(
          assetPath: 'tests/fixtures/flutter_host/missing.test.yaml',
          testCase: EnsembleTestCase(
            id: 'missing_target',
            steps: [
              TestStep(type: 'tap', args: {'id': 'does_not_exist'}),
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
      TestFailureKind.elementNotFound,
    );
  });

  testWidgets('missing storage capability fails explicitly', (tester) async {
    final driver = FlutterHostTestDriver();
    const plan = EnsembleTestExecutionPlan(
      ordered: [
        EnsembleTestDefinition(
          assetPath: 'tests/fixtures/flutter_host/storage.test.yaml',
          testCase: EnsembleTestCase(
            id: 'needs_storage',
            steps: [
              TestStep(
                type: 'expectStorage',
                args: {'key': 'token', 'equals': 'x'},
              ),
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
      anyOf(
        TestFailureKind.unsupportedCapability,
        TestFailureKind.assertion,
      ),
    );
  });
}
