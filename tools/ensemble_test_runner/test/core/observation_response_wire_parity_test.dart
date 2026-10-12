import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/src/core/execution_kernel_runner.dart';
import 'package:ensemble_test_runner/src/core/kernel.dart';
import 'package:ensemble_test_runner/src/core/operation.dart';
import 'package:ensemble_test_runner/src/core/plan.dart';
import 'package:ensemble_test_runner/src/core/plan_wire_transport.dart';
import 'package:ensemble_test_runner/src/core/runtime.dart';
import 'package:ensemble_test_runner/src/runtime/compiled_plan.dart';
import 'package:ensemble_test_runner/src/runtime/operation_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final plan = CompiledPlanCompiler().compile(
    EnsembleTestCase(
      id: 'observation_response_contract',
      steps: [
        TestStep(
          type: 'ifVisible',
          args: const {'id': 'branch-target'},
          nestedSteps: const [
            TestStep(type: 'tap', args: {'id': 'visible-arm'}),
          ],
        ),
        TestStep(type: 'tap', args: const {'id': 'continuation'}),
      ],
    ),
  );
  final wirePlan = ExecutionPlanWireTransport.decode(
    ExecutionPlanWireTransport.encode(plan),
  );

  for (final level in ObservationLevel.values) {
    for (final targetVisible in [false, true]) {
      test(
        'compiled and wire plans agree for ${level.name} view, '
        'targetVisible=$targetVisible',
        () async {
          final direct = await _run(
            plan,
            level: level,
            targetVisible: targetVisible,
          );
          final transported = await _run(
            wirePlan,
            level: level,
            targetVisible: targetVisible,
          );

          expect(transported.outcome, direct.outcome);
          expect(transported.failureCode, direct.failureCode);
          expect(transported.primaryFailure, direct.primaryFailure);
          expect(transported.operations, direct.operations);
          expect(transported.runtime.executedIds, direct.runtime.executedIds);
          expect(transported.runtime.closeCalls, 1);
          expect(direct.runtime.closeCalls, 1);
          expect(transported.eventTrace, direct.eventTrace);
          expect(transported.runtime.observationLevels,
              [ObservationLevel.minimal]);

          if (level == ObservationLevel.minimal) {
            expect(direct.outcome, AttemptOutcome.passed);
            expect(
              direct.runtime.executedIds,
              targetVisible
                  ? ['visible-arm', 'continuation']
                  : ['continuation'],
            );
          } else {
            expect(direct.outcome, AttemptOutcome.failed);
            expect(direct.failureCode, 'internalError');
            expect(direct.primaryFailure,
                contains('Runtime returned observation level'));
            expect(direct.runtime.executedIds, isEmpty,
                reason: 'a mismatched view must not select either branch');
          }
        },
      );
    }
  }
}

Future<_RunSnapshot> _run(
  ExecutionPlan plan, {
  required ObservationLevel level,
  required bool targetVisible,
}) async {
  final runtime = _ObservationRuntime(
    responseLevel: level,
    targetVisible: targetVisible,
  );
  final events = <ExecutionEvent>[];
  final result = await ExecutionKernelRunner(
    plan: plan,
    runtime: runtime,
    eventSubscribers: [events.add],
  ).run();
  return _RunSnapshot(
    outcome: result.outcome,
    failureCode: result.failureCode,
    primaryFailure: result.primaryFailure,
    operations: result.operations,
    runtime: runtime,
    eventTrace: [
      for (final event in events)
        '${event.sequence}:${event.kind.name}:${event.nodeId}:'
            '${event.detail}:${event.operation}:${event.stepIndex}',
    ],
  );
}

final class _RunSnapshot {
  const _RunSnapshot({
    required this.outcome,
    required this.failureCode,
    required this.primaryFailure,
    required this.operations,
    required this.runtime,
    required this.eventTrace,
  });

  final AttemptOutcome outcome;
  final String? failureCode;
  final String? primaryFailure;
  final int operations;
  final _ObservationRuntime runtime;
  final List<String> eventTrace;
}

final class _ObservationRuntime implements TestRuntime {
  _ObservationRuntime({
    required this.responseLevel,
    required this.targetVisible,
  });

  final ObservationLevel responseLevel;
  final bool targetVisible;
  final List<String> executedIds = [];
  final List<ObservationLevel> observationLevels = [];
  int closeCalls = 0;

  @override
  RuntimeCapabilities get capabilities =>
      RuntimeCapabilities(operationRegistry.handlerKeys);

  @override
  Future<RuntimeView> observe(ObservationRequest request) async {
    observationLevels.add(request.level);
    return RuntimeView(
      revision: 0,
      level: responseLevel,
      target: request.target,
      targetVisible: targetVisible,
    );
  }

  @override
  Future<OperationResult> execute(TestOperation operation) async {
    executedIds.add(operation.input['id']! as String);
    return const OperationResult.success();
  }

  @override
  Future<void> close() async {
    closeCalls++;
  }
}
