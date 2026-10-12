import 'dart:async';

import 'package:ensemble_test_runner/discovery/ensemble_test_execution_planner.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/reporters/test_reporter.dart';
import 'package:ensemble_test_runner/src/runtime/compiled_plan.dart';
import 'package:ensemble_test_runner/src/core/suite_checkpoint_scheduler.dart';
import 'package:ensemble_test_runner/runner/test_session.dart';

/// Executes the ordered cases in a suite while keeping dependency and
/// checkpoint rules in one place.
///
/// Entry adapters provide only the case operation and optional checkpoint
/// capture. This keeps hosted and standalone execution on the same scheduling
/// path without making either adapter know how the other launches an app.
typedef SuiteCaseRunner<T> = Future<EnsembleSingleTestResult> Function({
  required EnsembleTestCase test,
  required T? checkpoint,
  required CompiledPlanReuse planReuse,
  required void Function(T checkpoint) onCheckpoint,
});

typedef SuiteCaseFailure<T> = FutureOr<EnsembleSingleTestResult> Function(
  EnsembleTestCase test,
  Object error,
  StackTrace stackTrace,
);

typedef SuiteCheckpointCapture<T> = Future<T> Function(
  EnsembleTestCase test,
);

typedef SuiteCaseProgress = FutureOr<void> Function(
  EnsembleTestDefinition definition,
  EnsembleSingleTestResult result,
);

typedef SuiteCaseStart = FutureOr<void> Function(
  EnsembleTestDefinition definition,
);

final class SuiteCaseRunResult {
  const SuiteCaseRunResult({
    required this.resultsById,
    this.suiteLogs = const [],
  });

  final Map<String, EnsembleSingleTestResult> resultsById;
  final List<String> suiteLogs;
}

final class SuiteCaseCoordinator<T> {
  const SuiteCaseCoordinator({this.requireKnownDependencies = true});

  /// Preserves the legacy standalone behavior for a missing selected
  /// dependency. Application-owned suites can opt into the historical
  /// best-effort behavior by setting this to false.
  final bool requireKnownDependencies;

  Future<SuiteCaseRunResult> execute(
    EnsembleTestExecutionPlan plan, {
    required SuiteCaseRunner<T> runCase,
    SuiteCheckpointCapture<T>? captureCheckpoint,
    SuiteCaseStart? onCaseStart,
    SuiteCaseProgress? onCaseComplete,
    SuiteCaseFailure<T>? onCaseFailure,
    Map<String, String> serializedPlans = const {},
  }) async {
    // Keep the checkpoint invariant at the execution boundary as well as in
    // the planner. Callers may construct plans directly in integrations.
    final orderedDefinitions = _orderByDependency(plan.ordered);
    final resultsById = <String, EnsembleSingleTestResult>{};
    final scheduler = SuiteCheckpointScheduler<T>();
    final requestedSessions = orderedDefinitions
        .map((definition) => definition.testCase.session)
        .whereType<String>()
        .toSet();
    final compiledPlans = CompiledPlanBatch(
      orderedDefinitions.map((definition) => definition.testCase),
      serializedPlans: serializedPlans,
    );
    final suiteLogs = <String>[];

    for (final definition in orderedDefinitions) {
      final test = definition.testCase;
      try {
        await onCaseStart?.call(definition);
      } catch (error) {
        suiteLogs.add('Could not publish start for ${test.id}: $error');
      }
      try {
        final dependency = test.session;
        T? checkpoint;
        if (dependency != null) {
          final dependencyResult = resultsById[dependency];
          if (dependencyResult == null && requireKnownDependencies) {
            throw EnsembleTestFailure(
              'Internal error: session "$dependency" for "${test.id}" '
              'was not scheduled',
            );
          }
          if (dependencyResult?.status == TestStatus.failed) {
            resultsById[test.id] = EnsembleSingleTestResult.failed(
              testId: test.id,
              metadata: test.metadataJson,
              message: 'Session "$dependency" failed',
              durationMs: 0,
              // This case never opened an attempt. Do not project navigation
              // history left behind by the failed dependency or another case.
              report: buildTestReportDetails(
                test,
                navigationFlow: NavigationFlowRecorder(),
              ),
            );
          } else {
            checkpoint = scheduler.checkpointFor(dependency);
            if (checkpoint == null && requireKnownDependencies) {
              throw EnsembleTestFailure(
                'Internal error: session "$dependency" for "${test.id}" '
                'completed without a snapshot',
              );
            }
          }
        }

        if (!resultsById.containsKey(test.id)) {
          final result = await runCase(
            test: test,
            checkpoint: checkpoint,
            planReuse: compiledPlans.forTest(test.id),
            onCheckpoint: (checkpoint) =>
                scheduler.recordCheckpoint(test.id, checkpoint),
          );
          resultsById[test.id] = result;
          scheduler.recordResult(
            test.id,
            failed: result.status == TestStatus.failed,
          );
          if (result.status == TestStatus.passed &&
              requestedSessions.contains(test.id) &&
              captureCheckpoint != null) {
            scheduler.recordCheckpoint(
              test.id,
              await captureCheckpoint(test),
            );
          }
        } else {
          scheduler.recordResult(
            test.id,
            failed: resultsById[test.id]!.status == TestStatus.failed,
          );
        }
      } catch (error, stackTrace) {
        resultsById[test.id] =
            await (onCaseFailure?.call(test, error, stackTrace) ??
                EnsembleSingleTestResult.failed(
                  testId: test.id,
                  metadata: test.metadataJson,
                  message: error.toString(),
                  stackTrace: stackTrace.toString(),
                  durationMs: 0,
                  // Suite-level failures have no attempt-owned recorder.
                  report: buildTestReportDetails(
                    test,
                    navigationFlow: NavigationFlowRecorder(),
                  ),
                ));
        scheduler.recordResult(test.id, failed: true);
      }

      final result = resultsById[test.id]!;
      try {
        await onCaseComplete?.call(definition, result);
      } catch (error) {
        suiteLogs.add('Could not publish progress for ${test.id}: $error');
      }
    }

    return SuiteCaseRunResult(
      resultsById: resultsById,
      suiteLogs: suiteLogs,
    );
  }

  List<EnsembleTestDefinition> _orderByDependency(
    List<EnsembleTestDefinition> definitions,
  ) {
    if (definitions.length < 2) return definitions;
    final byId = <String, EnsembleTestDefinition>{};
    final originalIndex = <String, int>{};
    for (var index = 0; index < definitions.length; index++) {
      final definition = definitions[index];
      final id = definition.testCase.id;
      if (byId.containsKey(id)) {
        throw EnsembleTestFailure('Duplicate test id "$id" in execution plan.');
      }
      byId[id] = definition;
      originalIndex[id] = index;
    }
    final dependents = <String, List<String>>{
      for (final id in byId.keys) id: <String>[],
    };
    final remaining = <String, int>{
      for (final id in byId.keys) id: 0,
    };
    for (final entry in byId.entries) {
      final dependency = entry.value.testCase.session;
      if (dependency == null) continue;
      if (!byId.containsKey(dependency)) {
        if (!requireKnownDependencies) continue;
        throw EnsembleTestFailure(
          'Test "${entry.key}" references unknown dependency "$dependency".',
        );
      }
      remaining[entry.key] = remaining[entry.key]! + 1;
      dependents[dependency]!.add(entry.key);
    }
    final ready = <String>[
      for (final entry in remaining.entries)
        if (entry.value == 0) entry.key,
    ]..sort((a, b) => originalIndex[a]!.compareTo(originalIndex[b]!));
    final orderedIds = <String>[];
    while (ready.isNotEmpty) {
      final id = ready.removeAt(0);
      orderedIds.add(id);
      for (final dependent in dependents[id]!) {
        final degree = remaining[dependent]! - 1;
        remaining[dependent] = degree;
        if (degree == 0) {
          ready.add(dependent);
          ready.sort((a, b) => originalIndex[a]!.compareTo(originalIndex[b]!));
        }
      }
    }
    if (orderedIds.length != definitions.length) {
      throw EnsembleTestFailure(
        'Circular test dependency in execution plan: '
        '${remaining.keys.where((id) => !orderedIds.contains(id)).join(', ')}',
      );
    }
    return orderedIds.map((id) => byId[id]!).toList(growable: false);
  }
}
