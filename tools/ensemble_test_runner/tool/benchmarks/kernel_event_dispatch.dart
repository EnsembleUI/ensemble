import 'dart:async';

import 'package:ensemble_test_runner/src/core/kernel.dart';
import 'package:ensemble_test_runner/src/core/operation.dart';
import 'package:ensemble_test_runner/src/core/plan.dart';
import 'package:ensemble_test_runner/src/core/policy.dart';
import 'package:ensemble_test_runner/src/core/runtime.dart';

const _operationsPerAttempt = 2000;
const _warmupAttempts = 5;
const _measuredAttempts = 20;

Future<void> main() async {
  final plan = _makePlan(_operationsPerAttempt);
  final samples = {
    for (final mode in _DispatchMode.values) mode: <double>[],
  };
  final orders = <List<_DispatchMode>>[
    _DispatchMode.values,
    [_DispatchMode.subscriber, _DispatchMode.noBridge, _DispatchMode.bridge],
    [_DispatchMode.bridge, _DispatchMode.subscriber, _DispatchMode.noBridge],
  ];

  for (var round = 0; round < _warmupAttempts + _measuredAttempts; round++) {
    final order = orders[round % orders.length];
    for (final mode in order) {
      final elapsed = await _measureOne(plan, mode);
      if (round >= _warmupAttempts) samples[mode]!.add(elapsed);
    }
  }

  final disabled = _median(samples[_DispatchMode.noBridge]!);
  final boundaryOnly = _median(samples[_DispatchMode.bridge]!);
  final enabled = _median(samples[_DispatchMode.subscriber]!);
  final bridgeOverheads = [
    for (var index = 0; index < _measuredAttempts; index++)
      samples[_DispatchMode.bridge]![index] -
          samples[_DispatchMode.noBridge]![index],
  ];
  final subscriberOverheads = [
    for (var index = 0; index < _measuredAttempts; index++)
      samples[_DispatchMode.subscriber]![index] -
          samples[_DispatchMode.bridge]![index],
  ];

  print('Kernel event dispatch benchmark');
  print('Operations per attempt: $_operationsPerAttempt');
  print(
      'Measured attempts: $_measuredAttempts (after $_warmupAttempts warmups)');
  print(
      'No subscribers or evidence bridge: ${disabled.toStringAsFixed(2)} ms/attempt');
  print(
      'Evidence bridge, no subscribers: ${boundaryOnly.toStringAsFixed(2)} ms/attempt');
  print(
      'Evidence bridge plus no-op subscriber: ${enabled.toStringAsFixed(2)} ms/attempt');
  print(
    'Evidence bridge cost without subscribers: '
    '${_median(bridgeOverheads).toStringAsFixed(2)} ms/attempt (paired median)',
  );
  print(
    'Subscriber overhead: '
    '${_median(subscriberOverheads).toStringAsFixed(2)} ms/attempt (paired median)',
  );
}

Future<double> _measureOne(ExecutionPlan plan, _DispatchMode mode) async {
  final policy = CompiledExecutionPolicy(plan);
  final clock = Stopwatch()..start();
  final result = await ExecutionKernel(
    plan: plan,
    policy: policy,
    runtime: mode == _DispatchMode.noBridge
        ? _BenchmarkRuntime()
        : _BenchmarkRuntimeWithBoundaries(),
    limits: const ExecutionLimits(
      maxOperations: _operationsPerAttempt,
      maxDirectives: _operationsPerAttempt * 4,
    ),
    eventSubscribers:
        mode == _DispatchMode.subscriber ? [_ignoreEvent] : const [],
  ).run();
  clock.stop();
  if (result.outcome != AttemptOutcome.passed ||
      result.operations != _operationsPerAttempt) {
    throw StateError(
      'Benchmark did not execute the full plan in $mode: '
      '${result.outcome}, ${result.operations}/$_operationsPerAttempt '
      'operations (${result.primaryFailure ?? 'no failure detail'}).',
    );
  }
  final expectedEvents = 3 +
      (_operationsPerAttempt * 3) +
      (mode == _DispatchMode.noBridge ? 0 : _operationsPerAttempt);
  if (result.events != expectedEvents) {
    throw StateError(
      'Benchmark event count mismatch in $mode: '
      '${result.events}, expected $expectedEvents.',
    );
  }
  return clock.elapsedMicroseconds / 1000;
}

enum _DispatchMode { noBridge, bridge, subscriber }

double _median(List<double> samples) {
  final ordered = [...samples]..sort();
  return ordered[ordered.length ~/ 2];
}

ExecutionPlan _makePlan(int operationCount) {
  final nodes = <String, PlanNode>{};
  for (var index = 0; index < operationCount; index++) {
    final id = 'operation-$index';
    final next = index + 1 == operationCount ? 'end' : 'operation-${index + 1}';
    nodes[id] = OperationNode(
      id,
      TestOperation(
        id: id,
        name: 'tap',
        kind: OperationKind.interaction,
        handlerKey: 'interaction.tap',
        input: const {},
        source: const SourceLocation('benchmark', 'steps'),
      ),
      next,
    );
  }
  nodes['end'] = const EndNode('end');
  return ExecutionPlan(
      id: 'event-dispatch', start: 'operation-0', nodes: nodes);
}

void _ignoreEvent(ExecutionEvent event) {}

class _BenchmarkRuntime implements TestRuntime {
  @override
  final capabilities = RuntimeCapabilities({'interaction.tap'});

  @override
  Future<RuntimeView> observe(ObservationRequest request) async => RuntimeView(
        revision: 0,
        level: request.level,
        target: request.target,
        targetVisible: true,
      );

  @override
  Future<OperationResult> execute(TestOperation operation) async =>
      const OperationResult.success();

  @override
  Future<void> close() async {}
}

final class _BenchmarkRuntimeWithBoundaries extends _BenchmarkRuntime
    implements EvidenceBoundaryEventSource {
  EvidenceBoundaryEmitter? _emitter;

  @override
  void bindEvidenceBoundaryEmitter(EvidenceBoundaryEmitter? emitter) {
    _emitter = emitter;
  }

  @override
  Future<OperationResult> execute(TestOperation operation) async {
    await _emitter?.call(null, operation.name);
    return const OperationResult.success();
  }
}
