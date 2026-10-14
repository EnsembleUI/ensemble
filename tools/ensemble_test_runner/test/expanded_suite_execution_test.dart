import 'package:ensemble_test_runner/discovery/ensemble_test_execution_planner.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/retry_execution.dart';
import 'package:ensemble_test_runner/runner/suite_case_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile/scenario/device expansion preserves retries and checkpoints',
      () async {
    final plan = await EnsembleTestExecutionPlanner.buildForTest(
      assetContents: {
        'suite/tests/sign_in.test.yaml': '''
id: sign_in
startScreen: Login
steps:
  - expectVisible: {id: login}
''',
        'suite/tests/detail.test.yaml': r'''
id: detail
session: sign_in
profiles: [modern, legacy]
retry: 1
scenarios:
  - id: online
    vars: {state: online}
  - id: offline
    vars: {state: offline}
startScreen: Detail
steps:
  - expectText: {text: "${scenario.state}"}
''',
      },
      config: const EnsembleTestConfig(
        defaultProfile: 'profileGroup',
        profileGroups: {
          'profileGroup': ['modern', 'legacy'],
        },
        profiles: {
          'modern': TestProfile(
            initialState: {
              'storage': {'deviceType': 'modern'}
            },
          ),
          'legacy': TestProfile(
            initialState: {
              'storage': {'deviceType': 'legacy'}
            },
          ),
        },
        devices: [
          TestDeviceTarget(
            id: 'android_nl',
            platform: 'android',
            model: 'Samsung Galaxy S20',
            locale: 'nl',
          ),
          TestDeviceTarget(
            id: 'iphone_en',
            platform: 'ios',
            model: 'iPhone 15 Pro',
            locale: 'en',
          ),
        ],
      ),
    );

    expect(plan.ordered, hasLength(12));
    final selected = plan.ordered
        .map((definition) => definition.testCase)
        .singleWhere((test) => test.id == 'detail[online][modern][android_nl]');
    expect(selected.profile, 'modern');
    expect(selected.scenarioId, 'online');
    expect(selected.deviceTarget?.id, 'android_nl');
    expect(selected.retry, 1);
    expect(selected.session, 'sign_in[modern][android_nl]');
    expect(
      (selected.initialState['storage'] as Map)['deviceType'],
      'modern',
    );
    expect((selected.initialState['env'] as Map)['APP_LOCALE'], 'nl');
    expect(selected.steps.single.args['text'], 'online');

    final attemptsByCase = <String, List<int>>{};
    final checkpointByCase = <String, Object?>{};
    final result = await const SuiteCaseCoordinator<String>().execute(
      plan,
      runCase: ({
        required test,
        required checkpoint,
        required planReuse,
        required onCheckpoint,
      }) async {
        if (test.id.startsWith('detail[')) {
          expect(checkpoint, 'checkpoint:${test.session}');
          checkpointByCase[test.id] = checkpoint;
          final attemptNumbers = attemptsByCase.putIfAbsent(
            test.id,
            () => [],
          );
          final attempts = await RetryExecutionCoordinator.collect<int>(
            retries: test.retry,
            executeAttempt: (attempt) async {
              attemptNumbers.add(attempt.number);
              return attempt.number == 2 ? 1 : 0;
            },
            succeeded: (outcome) => outcome == 1,
            durationMs: (_) => 1,
            logs: (attempt) => ['attempt-$attempt'],
          );
          return EnsembleSingleTestResult.passed(
            testId: test.id,
            durationMs: attempts.durationMs,
          );
        }
        return EnsembleSingleTestResult.passed(
          testId: test.id,
          durationMs: 1,
        );
      },
      captureCheckpoint: (test) async => 'checkpoint:${test.id}',
    );

    expect(checkpointByCase, hasLength(8));
    expect(attemptsByCase, hasLength(8));
    for (final entry in attemptsByCase.entries) {
      expect(entry.value, [1, 2], reason: entry.key);
      expect(result.resultsById[entry.key]?.status, TestStatus.passed);
    }
    expect(result.resultsById, hasLength(12));
  });
}
