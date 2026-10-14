import 'package:ensemble_test_runner/discovery/ensemble_test_execution_planner.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/suite_case_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('publishes a case start before execution', () async {
    final events = <String>[];
    final definition = EnsembleTestDefinition(
      assetPath: 'login.test.yaml',
      testCase: EnsembleTestCase(id: 'login', steps: const []),
    );

    await const SuiteCaseCoordinator<String>().execute(
      EnsembleTestExecutionPlan(ordered: [definition]),
      onCaseStart: (started) => events.add('start:${started.testCase.id}'),
      runCase: ({
        required test,
        required checkpoint,
        required planReuse,
        required onCheckpoint,
      }) async {
        events.add('run:${test.id}');
        return EnsembleSingleTestResult.passed(testId: test.id, durationMs: 1);
      },
    );

    expect(events, ['start:login', 'run:login']);
  });

  test('reuses a producer checkpoint for dependent cases', () async {
    final producer = EnsembleTestCase(id: 'login', steps: const []);
    final dependent = EnsembleTestCase(
      id: 'settings',
      session: 'login',
      steps: const [],
    );
    final plan = EnsembleTestExecutionPlan(
      ordered: [
        EnsembleTestDefinition(
            assetPath: 'login.test.yaml', testCase: producer),
        EnsembleTestDefinition(
          assetPath: 'settings.test.yaml',
          testCase: dependent,
        ),
      ],
    );
    final checkpointsSeen = <Object?>[];

    final result = await const SuiteCaseCoordinator<String>().execute(
      plan,
      runCase: (
          {required test,
          required checkpoint,
          required planReuse,
          required onCheckpoint}) async {
        checkpointsSeen.add(checkpoint);
        if (test.id == 'login') onCheckpoint('after-login');
        return EnsembleSingleTestResult.passed(
          testId: test.id,
          durationMs: 1,
        );
      },
      captureCheckpoint: (_) async => 'captured-after-login',
    );

    expect(result.resultsById.keys, ['login', 'settings']);
    expect(checkpointsSeen, [null, 'captured-after-login']);
  });

  test('contains a case failure and continues the ordered suite', () async {
    final first = EnsembleTestCase(id: 'first', steps: const []);
    final second = EnsembleTestCase(id: 'second', steps: const []);
    final plan = EnsembleTestExecutionPlan(
      ordered: [
        EnsembleTestDefinition(assetPath: 'first.test.yaml', testCase: first),
        EnsembleTestDefinition(assetPath: 'second.test.yaml', testCase: second),
      ],
    );
    final executed = <String>[];

    final result = await const SuiteCaseCoordinator<String>().execute(
      plan,
      runCase: (
          {required test,
          required checkpoint,
          required planReuse,
          required onCheckpoint}) async {
        executed.add(test.id);
        if (test.id == 'first') throw StateError('broken case');
        return EnsembleSingleTestResult.passed(testId: test.id, durationMs: 1);
      },
    );

    expect(executed, ['first', 'second']);
    expect(result.resultsById['first']?.status, TestStatus.failed);
    expect(result.resultsById['second']?.status, TestStatus.passed);
  });

  test('suite-generated dependent failure excludes prior attempt navigation',
      () async {
    final dependency = EnsembleTestCase(id: 'login', steps: const []);
    final dependent = EnsembleTestCase(
      id: 'settings',
      session: 'login',
      startScreen: 'SettingsStart',
      steps: const [],
    );
    final result = await const SuiteCaseCoordinator<String>().execute(
      EnsembleTestExecutionPlan(
        ordered: [
          EnsembleTestDefinition(
            assetPath: 'login.test.yaml',
            testCase: dependency,
          ),
          EnsembleTestDefinition(
            assetPath: 'settings.test.yaml',
            testCase: dependent,
          ),
        ],
      ),
      runCase: ({
        required test,
        required checkpoint,
        required planReuse,
        required onCheckpoint,
      }) async {
        if (test.id == 'login') throw StateError('login failed');
        return EnsembleSingleTestResult.passed(
          testId: test.id,
          durationMs: 1,
        );
      },
    );

    expect(
      result.resultsById['settings']?.report?.screensVisited,
      ['SettingsStart'],
    );
  });

  test('orders a checkpoint producer before a dependent case', () async {
    final producer = EnsembleTestCase(id: 'login', steps: const []);
    final dependent = EnsembleTestCase(
      id: 'settings',
      session: 'login',
      steps: const [],
    );
    final executed = <String>[];
    final checkpoints = <Object?>[];
    final result = await const SuiteCaseCoordinator<String>().execute(
      EnsembleTestExecutionPlan(
        // Deliberately bypass the planner to verify the execution boundary.
        ordered: [
          EnsembleTestDefinition(
            assetPath: 'settings.test.yaml',
            testCase: dependent,
          ),
          EnsembleTestDefinition(
            assetPath: 'login.test.yaml',
            testCase: producer,
          ),
        ],
      ),
      runCase: ({
        required test,
        required checkpoint,
        required planReuse,
        required onCheckpoint,
      }) async {
        executed.add(test.id);
        checkpoints.add(checkpoint);
        if (test.id == 'login') onCheckpoint('from-run');
        return EnsembleSingleTestResult.passed(
          testId: test.id,
          durationMs: 1,
        );
      },
      captureCheckpoint: (_) async => 'from-capture',
    );

    expect(executed, ['login', 'settings']);
    expect(checkpoints, [null, 'from-capture']);
    expect(result.resultsById.keys, ['login', 'settings']);
  });
}
