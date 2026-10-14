import 'package:ensemble_test_runner/application/application_test_driver.dart';
import 'package:ensemble_test_runner/discovery/ensemble_test_execution_planner.dart';
import 'package:ensemble_test_runner/entry/application_test_entry.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mixed journey: Flutter login → embedded Ensemble-like dashboard → Flutter settings.
///
/// Uses a shared Flutter tree (no live Ensemble bootstrap) so the test can run
/// in package CI without loading the full Ensemble runtime. The dashboard
/// widgets carry the same ValueKey ids an Ensemble screen would expose.
class MixedHostApp extends StatefulWidget {
  const MixedHostApp({super.key});

  @override
  State<MixedHostApp> createState() => _MixedHostAppState();
}

class _MixedHostAppState extends State<MixedHostApp> {
  var route = 'flutter_login';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: switch (route) {
          'ensemble_dashboard' => Column(
              key: const ValueKey('ensemble_dashboard'),
              children: [
                const Text('Dashboard', key: ValueKey('greeting_text')),
                ElevatedButton(
                  key: const ValueKey('open_flutter_settings'),
                  onPressed: () => setState(() => route = 'flutter_settings'),
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          'flutter_settings' => const Text(
              'Settings',
              key: ValueKey('settings_title'),
            ),
          _ => ElevatedButton(
              key: const ValueKey('flutter_login_button'),
              onPressed: () => setState(() => route = 'ensemble_dashboard'),
              child: const Text('Sign in'),
            ),
        },
      ),
    );
  }
}

class _MixedDriver implements ApplicationTestDriver {
  @override
  Future<void> setUpSuite(TestSuiteContext context) async {}

  @override
  Future<void> prepareTest(TestLaunchContext context) async {}

  @override
  Future<TestApplicationHandle> launch(
    WidgetTester tester,
    TestLaunchContext context,
  ) async {
    await tester.pumpWidget(const MixedHostApp());
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

class _Handle implements TestApplicationHandle {
  const _Handle();

  @override
  ApplicationTestServices get services => const ApplicationTestServices();
}

void main() {
  testWidgets(
      'mixed Flutter login → Ensemble-surface dashboard → Flutter settings',
      (tester) async {
    const plan = EnsembleTestExecutionPlan(
      ordered: [
        EnsembleTestDefinition(
          assetPath: 'tests/fixtures/mixed_journey.test.yaml',
          testCase: EnsembleTestCase(
            id: 'mixed_journey',
            steps: [
              TestStep(type: 'tap', args: {'id': 'flutter_login_button'}),
              TestStep(type: 'expectVisible', args: {'id': 'greeting_text'}),
              TestStep(type: 'tap', args: {'id': 'open_flutter_settings'}),
              TestStep(type: 'expectVisible', args: {'id': 'settings_title'}),
            ],
          ),
        ),
      ],
    );

    final result = await runApplicationTestPlan(
      driver: _MixedDriver(),
      plan: plan,
      tester: tester,
      mode: ExecutionMode.widget,
    );
    expect(result.failedCount, 0, reason: result.toJson().toString());
    expect(result.results.single.capabilityStatus['navigation'], isFalse);
  });
}
