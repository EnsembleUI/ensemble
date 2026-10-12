import 'package:ensemble_test_runner/parser/ensemble_test_parser.dart';
import 'package:ensemble_test_runner/src/core/kernel.dart';
import 'package:ensemble_test_runner/src/core/operation.dart';
import 'package:ensemble_test_runner/src/core/execution_kernel_runner.dart';
import 'package:ensemble_test_runner/src/core/runtime.dart';
import 'package:ensemble_test_runner/src/core/plan.dart';
import 'package:ensemble_test_runner/src/runtime/compiled_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('runtime exceptions do not become optional recoveries after wire decode',
      () async {
    final testCase = EnsembleTestParser.parseString('''
id: optional_runtime_exception
startScreen: Home
steps:
  - optional:
      steps:
        - tap: {id: runtime_exception}
        - tap: {id: skipped_optional_tail}
  - tap: {id: skipped_outer_tail}
''');
    final compiled = CompiledPlanCompiler().compile(testCase);
    final plans = [compiled, ExecutionPlan.fromWire(compiled.toWire())];
    final attempts = <({
      AttemptResult result,
      _ThrowingRuntime runtime,
      List<ExecutionEvent> events
    })>[];

    for (final plan in plans) {
      final runtime = _ThrowingRuntime();
      final events = <ExecutionEvent>[];
      final result = await ExecutionKernelRunner(
        plan: plan,
        runtime: runtime,
        eventSubscribers: [events.add],
      ).run();
      attempts.add((result: result, runtime: runtime, events: events));
    }

    for (final attempt in attempts) {
      expect(attempt.result.outcome, AttemptOutcome.failed);
      expect(attempt.result.failureCode, 'operationException');
      expect(attempt.result.failureOperation, 'tap');
      expect(attempt.result.cause, isA<StateError>());
      expect(attempt.runtime.executedIds, ['runtime_exception']);
      expect(attempt.runtime.closeCalls, 1);
      expect(
        attempt.events
            .where(
                (event) => event.kind == ExecutionEventKind.operationFinished)
            .map((event) => event.detail),
        ['Bad state: runtime unavailable'],
      );
      expect(attempt.events.last.kind, ExecutionEventKind.attemptFinished);
    }
    expect(
        attempts[1].result.primaryFailure, attempts[0].result.primaryFailure);
    expect(attempts[1].result.failureCode, attempts[0].result.failureCode);
    expect(
      attempts[1].events.map(_eventSignature),
      attempts[0].events.map(_eventSignature),
    );
  });

  test('observation exceptions inside optional blocks fail the attempt',
      () async {
    final testCase = EnsembleTestParser.parseString('''
id: optional_observation_failure
startScreen: Home
steps:
  - optional:
      steps:
        - ifVisible:
            id: target
            steps:
              - tap: {id: visible_branch}
  - tap: {id: after_optional}
''');
    final compiled = CompiledPlanCompiler().compile(testCase);
    final plans = [compiled, ExecutionPlan.fromWire(compiled.toWire())];
    final attempts = <({
      AttemptResult result,
      _RecoverableFailureRuntime runtime,
      List<ExecutionEvent> events,
    })>[];

    for (final plan in plans) {
      final runtime = _RecoverableFailureRuntime(failObservation: true);
      final events = <ExecutionEvent>[];
      final result = await ExecutionKernelRunner(
        plan: plan,
        runtime: runtime,
        eventSubscribers: [events.add],
      ).run();
      attempts.add((result: result, runtime: runtime, events: events));
    }

    for (final attempt in attempts) {
      expect(attempt.result.outcome, AttemptOutcome.failed);
      expect(attempt.result.failureCode, 'internalError');
      expect(attempt.result.cause, isA<StateError>());
      expect(attempt.runtime.executedIds, isEmpty);
      expect(attempt.runtime.observeCalls, 1);
      expect(attempt.runtime.closeCalls, 1);
      expect(
        attempt.events.where(
            (event) => event.kind == ExecutionEventKind.observationFailed),
        hasLength(1),
      );
      expect(attempt.events.last.kind, ExecutionEventKind.attemptFinished);
    }
    expect(attempts[1].result.outcome, attempts[0].result.outcome);
    expect(
        attempts[1].result.primaryFailure, attempts[0].result.primaryFailure);
    expect(attempts[1].result.failureCode, attempts[0].result.failureCode);
    expect(attempts[1].result.failureOperation,
        attempts[0].result.failureOperation);
    expect(attempts[1].result.cause.runtimeType,
        attempts[0].result.cause.runtimeType);
    expect(
      attempts[1].events.map(_eventSignature),
      attempts[0].events.map(_eventSignature),
    );
  });

  test('group propagates an unhandled operation failure and stops traversal',
      () async {
    final testCase = EnsembleTestParser.parseString('''
id: group_failure
startScreen: Home
steps:
  - group:
      steps:
        - tap: {id: recoverable_failure}
        - tap: {id: skipped_group_tail}
  - tap: {id: skipped_outer_tail}
''');
    final plan = CompiledPlanCompiler().compile(testCase);
    final runtime = _RecoverableFailureRuntime();
    final events = <ExecutionEvent>[];

    final result = await ExecutionKernelRunner(
      plan: plan,
      runtime: runtime,
      eventSubscribers: [events.add],
    ).run();

    expect(result.outcome, AttemptOutcome.failed);
    expect(result.failureOperation, 'tap');
    expect(runtime.executedIds, ['recoverable_failure']);
    expect(runtime.closeCalls, 1);
    expect(
      events
          .where((event) => event.kind == ExecutionEventKind.operationFinished)
          .map((event) => event.detail),
      ['recoverable failure'],
    );
    expect(events.last.kind, ExecutionEventKind.attemptFinished);
  });

  test('recoverable nested failure skips optional tail and resumes outer plan',
      () async {
    final testCase = EnsembleTestParser.parseString('''
id: optional_recovery_parity
startScreen: Home
steps:
  - optional:
      steps:
        - tap: {id: before_failure}
        - group:
            steps:
              - tap: {id: recoverable_failure}
              - tap: {id: skipped_after_failure}
        - tap: {id: skipped_optional_tail}
  - tap: {id: after_recovery}
''');
    final plan = CompiledPlanCompiler().compile(testCase);
    final runtime = _RecoverableFailureRuntime();
    final events = <ExecutionEvent>[];

    final result = await ExecutionKernelRunner(
      plan: plan,
      runtime: runtime,
      eventSubscribers: [events.add],
    ).run();

    expect(result.outcome, AttemptOutcome.passed);
    expect(result.operations, 3);
    expect(runtime.executedIds, [
      'before_failure',
      'recoverable_failure',
      'after_recovery',
    ]);
    expect(runtime.closeCalls, 1);
    expect(
      events
          .where((event) => event.kind == ExecutionEventKind.operationStarted)
          .map((event) => event.operation),
      ['tap', 'tap', 'tap'],
    );
    final finished = events
        .where((event) => event.kind == ExecutionEventKind.operationFinished)
        .toList();
    expect(finished, hasLength(3));
    expect(finished[0].detail, isNull);
    expect(finished[1].detail, 'recoverable failure');
    expect(finished[2].detail, isNull);
    expect(events.last.kind, ExecutionEventKind.attemptFinished);
  });
}

String _eventSignature(ExecutionEvent event) =>
    '${event.kind.name}:${event.nodeId}:${event.operation}:${event.detail}:'
    '${event.stepIndex}';

final class _ThrowingRuntime implements TestRuntime {
  @override
  final capabilities = RuntimeCapabilities({'interaction.tap'});

  final executedIds = <String?>[];
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
    executedIds.add(operation.input['id'] as String?);
    throw StateError('runtime unavailable');
  }

  @override
  Future<void> close() async {
    closeCalls++;
  }
}

final class _RecoverableFailureRuntime implements TestRuntime {
  _RecoverableFailureRuntime({this.failObservation = false});

  final bool failObservation;
  @override
  final capabilities = RuntimeCapabilities({'interaction.tap'});

  final List<String?> executedIds = [];
  int observeCalls = 0;
  int closeCalls = 0;

  @override
  Future<RuntimeView> observe(ObservationRequest request) async {
    observeCalls++;
    if (failObservation) throw StateError('observer unavailable');
    return RuntimeView(
      revision: 0,
      level: request.level,
      target: request.target,
      targetVisible: true,
    );
  }

  @override
  Future<OperationResult> execute(TestOperation operation) async {
    final id = operation.input['id'] as String?;
    executedIds.add(id);
    if (id == 'recoverable_failure') {
      return const OperationResult.failure(
        'recoverable failure',
        errorCode: 'elementNotFound',
      );
    }
    return const OperationResult.success();
  }

  @override
  Future<void> close() async {
    closeCalls++;
  }
}
