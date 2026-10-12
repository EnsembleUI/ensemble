import 'package:ensemble_test_runner/discovery/ensemble_test_execution_planner.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/test_plan_executor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('contains a case failure and still publishes progress',
      (tester) async {
    final testCase = EnsembleTestCase(id: 'broken', steps: const []);
    final plan = EnsembleTestExecutionPlan(
      ordered: [
        EnsembleTestDefinition(
          assetPath: 'tests/broken.test.yaml',
          testCase: testCase,
        ),
      ],
    );
    final published = <String>[];
    final executor = TestPlanExecutor(
      runTest: (test, tester,
          {required suiteConfig, sessionSnapshot, planReuse}) async {
        throw StateError('case failure');
      },
    );

    final result = await executor.execute(
      plan,
      tester,
      onTestComplete: (definition, caseResult) {
        published.add('${definition.testCase.id}:${caseResult.status.name}');
      },
    );

    expect(result.resultsById['broken']?.status, TestStatus.failed);
    expect(
      result.resultsById['broken']?.report?.screensVisited,
      isNot(contains('StaleSuiteRoute')),
    );
    expect(published, ['broken:failed']);
    expect(result.suiteLogs, isEmpty);
  });
}
