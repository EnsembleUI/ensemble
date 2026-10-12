import 'dart:collection';

import 'operation.dart';
import 'plan.dart';
import 'runtime.dart';

final class RunState {
  RunState({
    required this.nodeId,
    required Map<String, int> loopCounts,
  }) : loopCounts = UnmodifiableMapView(Map.of(loopCounts));

  final String nodeId;
  final Map<String, int> loopCounts;
}

sealed class ExecutionDirective {
  const ExecutionDirective();
}

final class ExecuteDirective extends ExecutionDirective {
  const ExecuteDirective(this.nodeId);
  final String nodeId;
}

final class MoveDirective extends ExecutionDirective {
  const MoveDirective(this.nodeId, {this.enteredLoop});
  final String nodeId;
  final String? enteredLoop;
}

final class ObserveDirective extends ExecutionDirective {
  const ObserveDirective(this.request);
  final ObservationRequest request;
}

final class FinishDirective extends ExecutionDirective {
  const FinishDirective();
}

abstract interface class ExecutionPolicy {
  Future<ExecutionDirective> next(RunState state, RuntimeView? view);
}

/// Follows compiled plan edges without touching the application.
final class CompiledExecutionPolicy implements ExecutionPolicy {
  const CompiledExecutionPolicy(this.plan);

  final ExecutionPlan plan;

  @override
  Future<ExecutionDirective> next(RunState state, RuntimeView? view) async {
    final node = plan.node(state.nodeId);
    return switch (node) {
      OperationNode() => ExecuteDirective(node.id),
      EndNode() => const FinishDirective(),
      LoopNode(:final times, :final body, :final next) =>
        (state.loopCounts[node.id] ?? 0) < times
            ? MoveDirective(body, enteredLoop: node.id)
            : MoveDirective(next),
      RecoveryNode(:final next) => MoveDirective(next),
      StepBoundaryNode() => StepBoundaryDirective(node.id),
      BranchNode(:final target, :final whenVisible, :final whenHidden) =>
        view == null || !sameInput(view.target, target)
            ? ObserveDirective(ObservationRequest.minimal(target: target))
            : MoveDirective(view.targetVisible ? whenVisible : whenHidden),
    };
  }
}

final class StepBoundaryDirective extends ExecutionDirective {
  const StepBoundaryDirective(this.nodeId);

  final String nodeId;
}
