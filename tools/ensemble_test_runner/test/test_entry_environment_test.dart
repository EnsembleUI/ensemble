import 'package:ensemble_test_runner/discovery/ensemble_test_execution_planner.dart';
import 'package:ensemble_test_runner/entry/test_entry_environment.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('case-start progress payload is stable across entry modes', () {
    final definition = EnsembleTestDefinition(
      assetPath: 'tests/login.test.yaml',
      testCase: EnsembleTestCase(id: 'login', steps: const []),
    );

    expect(
      testProgressStartPayload(
        definition,
        startedAt: DateTime.fromMillisecondsSinceEpoch(1234),
      ),
      {
        'testId': 'login',
        'assetPath': 'tests/login.test.yaml',
        'status': 'running',
        'startedAtEpochMs': 1234,
      },
    );
  });
}
