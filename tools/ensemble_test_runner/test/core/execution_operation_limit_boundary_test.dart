import 'package:ensemble_test_runner/src/core/execution_kernel_runner.dart';
import 'package:ensemble_test_runner/src/core/kernel.dart';
import 'package:ensemble_test_runner/src/core/operation.dart';
import 'package:ensemble_test_runner/src/core/plan.dart';
import 'package:ensemble_test_runner/src/core/runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('runtime capabilities use registry-selected dispatch keys', () {
    final operation = _tap('first', 'end').operation;

    expect(
        RuntimeCapabilities({'interaction.tap'}).supports(operation), isTrue);
    expect(RuntimeCapabilities({'tap'}).supports(operation), isFalse);
  });

  test('operation limit permits the exact budget and rejects the next action',
      () async {
    final exactBudgetRuntime = _RecordingRuntime();
    final exactBudgetResult = await ExecutionKernelRunner(
      plan: _twoOperationPlan(),
      runtime: exactBudgetRuntime,
      limits: const ExecutionLimits(maxOperations: 2),
    ).run();

    expect(exactBudgetResult.outcome, AttemptOutcome.passed);
    expect(exactBudgetResult.operations, 2);
    expect(exactBudgetRuntime.operationIds, ['first', 'second']);
    expect(exactBudgetRuntime.closeCalls, 1);

    final exceededRuntime = _RecordingRuntime();
    final exceededResult = await ExecutionKernelRunner(
      plan: _twoOperationPlan(),
      runtime: exceededRuntime,
      limits: const ExecutionLimits(maxOperations: 1),
    ).run();

    expect(exceededResult.outcome, AttemptOutcome.limitExceeded);
    expect(exceededResult.failureCode, 'limitExceeded');
    expect(exceededResult.primaryFailure, 'Operation limit exceeded.');
    expect(exceededResult.failureOperation, 'tap');
    expect(exceededResult.operations, 1);
    expect(exceededRuntime.operationIds, ['first']);
    expect(exceededRuntime.closeCalls, 1);
  });
}

ExecutionPlan _twoOperationPlan() => ExecutionPlan(
      id: 'operation_limit',
      start: 'first',
      nodes: {
        'first': _tap('first', 'second'),
        'second': _tap('second', 'end'),
        'end': const EndNode('end'),
      },
    );

OperationNode _tap(String id, String next) => OperationNode(
      id,
      TestOperation(
        id: id,
        name: 'tap',
        kind: OperationKind.interaction,
        handlerKey: 'interaction.tap',
        input: {'id': id},
        source: SourceLocation('operation_limit.test.yaml', id),
      ),
      next,
    );

final class _RecordingRuntime implements TestRuntime {
  @override
  final capabilities = RuntimeCapabilities({'interaction.tap'});

  final operationIds = <String>[];
  int closeCalls = 0;

  @override
  Future<RuntimeView> observe(ObservationRequest request) async => RuntimeView(
        revision: 0,
        level: request.level,
        target: request.target,
        targetVisible: true,
      );

  @override
  Future<OperationResult> execute(TestOperation operation) async {
    operationIds.add(operation.input['id']! as String);
    return const OperationResult.success();
  }

  @override
  Future<void> close() async {
    closeCalls++;
  }
}
