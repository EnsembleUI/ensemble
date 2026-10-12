import 'dart:convert';

import 'package:ensemble_test_runner/src/core/kernel.dart';
import 'package:ensemble_test_runner/src/core/operation.dart';
import 'package:ensemble_test_runner/src/core/plan.dart';
import 'package:ensemble_test_runner/src/core/policy.dart';
import 'package:ensemble_test_runner/src/core/runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('same plan and runtime sequence produce the same ordered replay',
      () async {
    final plan = ExecutionPlan(
      id: 'deterministic-replay',
      start: 'branch',
      nodes: {
        'branch': BranchNode(
          'branch',
          target: const {'id': 'ready'},
          whenVisible: 'tap',
          whenHidden: 'end',
        ),
        'tap': OperationNode(
          'tap',
          TestOperation(
            id: 'tap',
            name: 'tap',
            kind: OperationKind.interaction,
            handlerKey: 'interaction.tap',
            input: const {'id': 'continue'},
            source: const SourceLocation('tests/replay.test.yaml', 'steps[0]'),
          ),
          'step-finished',
        ),
        'step-finished': const StepBoundaryNode(
          'step-finished',
          stepIndex: 0,
          started: false,
          next: 'end',
        ),
        'end': const EndNode('end'),
      },
    );

    Future<_Replay> replay() async {
      final events = <ExecutionEvent>[];
      final runtime = _DeterministicRuntime();
      final result = await ExecutionKernel(
        plan: plan,
        policy: CompiledExecutionPolicy(plan),
        runtime: runtime,
        eventSubscribers: [(event) => events.add(event)],
      ).run();
      return _Replay(
        result,
        events,
        List.unmodifiable(runtime.trace),
        List.unmodifiable(runtime.operationResults),
        runtime.closeCount,
      );
    }

    final first = await replay();
    final second = await replay();

    expect(_project(first), _project(second));
    expect(_canonicalJson(_project(first)), _canonicalJson(_project(second)));
    expect(first.events.map((event) => event.sequence),
        List<int>.generate(first.events.length, (index) => index + 1));
    expect(first.events.map((event) => event.kind), [
      ExecutionEventKind.attemptStarted,
      ExecutionEventKind.directiveSelected,
      ExecutionEventKind.observationCaptured,
      ExecutionEventKind.directiveSelected,
      ExecutionEventKind.directiveSelected,
      ExecutionEventKind.operationStarted,
      ExecutionEventKind.operationFinished,
      ExecutionEventKind.directiveSelected,
      ExecutionEventKind.stepFinished,
      ExecutionEventKind.directiveSelected,
      ExecutionEventKind.attemptFinished,
    ]);
    expect(first.runtimeTrace, ['observe:ready', 'execute:tap', 'close']);
    expect(first.operationResults, [
      {
        'operation': 'tap',
        'succeeded': true,
        'error': null,
        'errorCode': null,
        'recoverable': false,
      },
    ]);
    expect(first.closeCount, 1);
    expect(second.closeCount, 1);
  });

  test('same failed operation sequence replays the same result and events',
      () async {
    final plan = ExecutionPlan(
      id: 'deterministic-failure-replay',
      start: 'tap',
      nodes: {
        'tap': OperationNode(
          'tap',
          TestOperation(
            id: 'tap',
            name: 'tap',
            kind: OperationKind.interaction,
            handlerKey: 'interaction.tap',
            input: const {'id': 'continue'},
            source: const SourceLocation('tests/replay.test.yaml', 'steps[0]'),
          ),
          'step-finished',
        ),
        'step-finished': const StepBoundaryNode(
          'step-finished',
          stepIndex: 0,
          started: false,
          next: 'end',
        ),
        'end': const EndNode('end'),
      },
    );

    Future<_Replay> replay() async {
      final events = <ExecutionEvent>[];
      final runtime = _DeterministicRuntime(failOperation: true);
      final result = await ExecutionKernel(
        plan: plan,
        policy: CompiledExecutionPolicy(plan),
        runtime: runtime,
        eventSubscribers: [(event) => events.add(event)],
      ).run();
      return _Replay(
        result,
        events,
        List.unmodifiable(runtime.trace),
        List.unmodifiable(runtime.operationResults),
        runtime.closeCount,
      );
    }

    final first = await replay();
    final second = await replay();

    expect(first.result.outcome, AttemptOutcome.failed);
    expect(first.result.primaryFailure, 'tap failed');
    expect(first.result.failureCode, 'operationFailed');
    expect(first.events.map((event) => event.kind), [
      ExecutionEventKind.attemptStarted,
      ExecutionEventKind.directiveSelected,
      ExecutionEventKind.operationStarted,
      ExecutionEventKind.operationFinished,
      ExecutionEventKind.attemptFinished,
    ]);
    expect(_canonicalJson(_project(first)), _canonicalJson(_project(second)));
    expect(first.runtimeTrace, ['execute:tap', 'close']);
    expect(first.closeCount, 1);
    expect(second.closeCount, 1);
  });
}

String _canonicalJson(Object? value) => jsonEncode(_sortJson(value));

Object? _sortJson(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _sortJson(value[key])};
  }
  if (value is List) return value.map(_sortJson).toList();
  return value;
}

Object _project(_Replay replay) => {
      'outcome': replay.result.outcome.name,
      'operations': replay.result.operations,
      'eventCount': replay.result.events,
      'failure': replay.result.primaryFailure,
      'events': [
        for (final event in replay.events)
          {
            'sequence': event.sequence,
            'kind': event.kind.name,
            'nodeId': event.nodeId,
            'detail': event.detail,
            'operation': event.operation,
            'source': event.source?.toString(),
            'stepIndex': event.stepIndex,
          },
      ],
      'runtime': replay.runtimeTrace,
      'operationResults': replay.operationResults,
      'closeCount': replay.closeCount,
    };

final class _Replay {
  const _Replay(
    this.result,
    this.events,
    this.runtimeTrace,
    this.operationResults,
    this.closeCount,
  );

  final AttemptResult result;
  final List<ExecutionEvent> events;
  final List<String> runtimeTrace;
  final List<Map<String, Object?>> operationResults;
  final int closeCount;
}

final class _DeterministicRuntime implements TestRuntime {
  _DeterministicRuntime({this.failOperation = false});

  final bool failOperation;
  final trace = <String>[];
  final operationResults = <Map<String, Object?>>[];
  var closeCount = 0;

  @override
  RuntimeCapabilities get capabilities =>
      RuntimeCapabilities(['interaction.tap']);

  @override
  Future<RuntimeView> observe(ObservationRequest request) async {
    final id = request.target['id'] as String;
    trace.add('observe:$id');
    return RuntimeView(
      revision: 1,
      level: request.level,
      target: request.target,
      targetVisible: true,
    );
  }

  @override
  Future<OperationResult> execute(TestOperation operation) async {
    trace.add('execute:${operation.name}');
    final result = failOperation
        ? const OperationResult.failure('tap failed')
        : const OperationResult.success();
    operationResults.add({
      'operation': operation.name,
      'succeeded': result.succeeded,
      'error': result.error,
      'errorCode': result.errorCode,
      'recoverable': result.recoverable,
    });
    return result;
  }

  @override
  Future<void> close() async {
    closeCount++;
    trace.add('close');
  }
}
