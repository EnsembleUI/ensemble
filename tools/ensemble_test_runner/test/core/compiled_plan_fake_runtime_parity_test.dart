import 'package:ensemble_test_runner/parser/ensemble_test_parser.dart';
import 'package:ensemble_test_runner/src/core/execution_kernel_runner.dart';
import 'package:ensemble_test_runner/src/core/kernel.dart';
import 'package:ensemble_test_runner/src/core/operation.dart';
import 'package:ensemble_test_runner/src/core/plan.dart';
import 'package:ensemble_test_runner/src/core/runtime.dart';
import 'package:ensemble_test_runner/src/runtime/compiled_plan.dart';
import 'package:ensemble_test_runner/src/runtime/operation_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('observation exceptions keep branch failure semantics after wire decode',
      () async {
    final testCase = EnsembleTestParser.parseString('''
id: branch_observation_failure
startScreen: Home
steps:
  - ifVisible:
      id: marker
      steps:
        - setEnv: {key: visible_branch, value: true}
  - setEnv: {key: after_branch, value: true}
''');
    final compiled = CompiledPlanCompiler().compile(testCase);
    final plans = [compiled, ExecutionPlan.fromWire(compiled.toWire())];
    final results = <({
      AttemptResult result,
      List<String> operations,
      List<(ExecutionEventKind, String?, String?, String?)> events,
      int observations,
      int closeCalls,
    })>[];

    for (final plan in plans) {
      final runtime = _RecordingRuntime(
        visible: true,
        failedOperation: null,
        failObservation: true,
      );
      final events = <ExecutionEvent>[];
      final result = await ExecutionKernelRunner(
        plan: plan,
        runtime: runtime,
        eventSubscribers: [events.add],
      ).run();
      results.add((
        result: result,
        operations: runtime.operations,
        events: events
            .map((event) => (
                  event.kind,
                  event.nodeId,
                  event.operation,
                  event.detail,
                ))
            .toList(),
        observations: runtime.observeCalls,
        closeCalls: runtime.closeCalls,
      ));
    }

    expect(results[0].result.outcome, AttemptOutcome.failed);
    expect(results[1].result.outcome, results[0].result.outcome);
    expect(results[1].result.operations, results[0].result.operations);
    expect(results[1].result.primaryFailure, results[0].result.primaryFailure);
    expect(results[1].operations, results[0].operations);
    expect(results[1].events, results[0].events);
    expect(results.map((result) => result.observations), [1, 1]);
    expect(results.map((result) => result.closeCalls), [1, 1]);
    expect(results[0].operations, isEmpty);
  });

  test('cancellation during observation has the same direct and wire outcome',
      () async {
    final testCase = EnsembleTestParser.parseString('''
id: branch_observation_cancellation
startScreen: Home
steps:
  - ifVisible:
      id: marker
      steps:
        - setEnv: {key: visible_branch, value: true}
  - setEnv: {key: after_branch, value: true}
''');
    final compiled = CompiledPlanCompiler().compile(testCase);
    final plans = [compiled, ExecutionPlan.fromWire(compiled.toWire())];
    final results = <({
      AttemptResult result,
      List<String> operations,
      List<(ExecutionEventKind, String?, String?, String?)> events,
      int observations,
      int closeCalls,
    })>[];

    for (final plan in plans) {
      final cancellation = ExecutionCancellation();
      final runtime = _RecordingRuntime(
        visible: true,
        failedOperation: null,
        onObserve: cancellation.cancel,
      );
      final events = <ExecutionEvent>[];
      final result = await ExecutionKernelRunner(
        plan: plan,
        runtime: runtime,
        cancellation: cancellation,
        eventSubscribers: [events.add],
      ).run();
      results.add((
        result: result,
        operations: runtime.operations,
        events: events
            .map((event) => (
                  event.kind,
                  event.nodeId,
                  event.operation,
                  event.detail,
                ))
            .toList(),
        observations: runtime.observeCalls,
        closeCalls: runtime.closeCalls,
      ));
    }

    for (final run in results) {
      expect(run.result.outcome, AttemptOutcome.cancelled);
      expect(run.result.failureCode, 'cancelled');
      expect(run.result.primaryFailure, 'Execution cancelled.');
      expect(run.result.operations, 0);
      expect(run.operations, isEmpty);
      expect(run.observations, 1);
      expect(run.closeCalls, 1);
      expect(
        run.events.map((event) => event.$1),
        [
          ExecutionEventKind.attemptStarted,
          ExecutionEventKind.directiveSelected,
          ExecutionEventKind.stepStarted,
          ExecutionEventKind.directiveSelected,
          ExecutionEventKind.attemptFinished,
        ],
      );
    }
    expect(results[1].result.outcome, results[0].result.outcome);
    expect(results[1].result.failureCode, results[0].result.failureCode);
    expect(results[1].result.primaryFailure, results[0].result.primaryFailure);
    expect(results[1].result.operations, results[0].result.operations);
    expect(results[1].operations, results[0].operations);
    expect(results[1].events, results[0].events);
    expect(results[1].observations, results[0].observations);
    expect(results[1].closeCalls, results[0].closeCalls);
  });

  test('operation kinds keep recovery and branch semantics after wire decode',
      () async {
    final testCase = EnsembleTestParser.parseString('''
id: mixed_operation_control_flow
startScreen: Home
steps:
  - repeat:
      times: 2
      steps:
        - optional:
            steps:
              - group:
                  steps:
                    - setEnv: {key: before, value: true}
                    - ifVisible:
                        id: marker
                        steps:
                          - waitFor: {id: wait}
                          - expectVisible: {id: assertion}
                          - tap: {id: interaction}
                          - openScreen: {screen: lifecycle}
                    - setEnv: {key: optional_tail, value: true}
              - setEnv: {key: optional_after_group, value: true}
        - setEnv: {key: iteration_tail, value: true}
  - setEnv: {key: after_repeat, value: true}
''');
    final compiled = CompiledPlanCompiler().compile(testCase);
    final plans = {
      'compiled': compiled,
      'wire-decoded': ExecutionPlan.fromWire(compiled.toWire()),
    };

    for (final visible in [false, true]) {
      for (final failedOperation in [
        null,
        'before',
        'wait',
        'assertion',
        'interaction',
        'lifecycle',
      ]) {
        final results = <({
          AttemptResult result,
          List<String> operations,
          List<(ExecutionEventKind, String?, String?, String?)> events,
          int observations,
          int closeCalls,
        })>[];

        for (final entry in plans.entries) {
          final runtime = _RecordingRuntime(
            visible: visible,
            failedOperation: failedOperation,
          );
          final events = <ExecutionEvent>[];
          final result = await ExecutionKernelRunner(
            plan: entry.value,
            runtime: runtime,
            eventSubscribers: [events.add],
          ).run();
          results.add((
            result: result,
            operations: runtime.operations,
            events: events
                .map((event) => (
                      event.kind,
                      event.nodeId,
                      event.operation,
                      event.detail,
                    ))
                .toList(),
            observations: runtime.observeCalls,
            closeCalls: runtime.closeCalls,
          ));
        }

        final reason = 'visible=$visible, failedOperation=$failedOperation';
        expect(results[0].result.outcome, AttemptOutcome.passed,
            reason: reason);
        expect(results[1].result.outcome, results[0].result.outcome,
            reason: reason);
        expect(results[1].result.operations, results[0].result.operations,
            reason: reason);
        expect(
            results[1].result.primaryFailure, results[0].result.primaryFailure,
            reason: reason);
        expect(results[1].operations, results[0].operations, reason: reason);
        expect(results[1].events, results[0].events, reason: reason);
        final expectedObservations = failedOperation == 'before' ? 0 : 2;
        expect(
            results.map((result) => result.observations),
            [
              expectedObservations,
              expectedObservations,
            ],
            reason: reason);
        expect(results.map((result) => result.closeCalls), [1, 1],
            reason: reason);
        expect(
            results[0].operations,
            _expectedOperations(
              visible: visible,
              failedOperation: failedOperation,
            ),
            reason: reason);
      }
    }
  });

  test(
      'thrown failures do not recover inside nested controls after wire decode',
      () async {
    final testCase = EnsembleTestParser.parseString('''
id: nested_thrown_operation_failure
startScreen: Home
steps:
  - repeat:
      times: 2
      steps:
        - optional:
            steps:
              - group:
                  steps:
                    - setEnv: {key: before, value: true}
                    - ifVisible:
                        id: marker
                        steps:
                          - waitFor: {id: wait}
                          - expectVisible: {id: assertion}
                          - tap: {id: interaction}
                          - openScreen: {screen: lifecycle}
              - setEnv: {key: optional_tail, value: true}
        - setEnv: {key: iteration_tail, value: true}
  - setEnv: {key: after_repeat, value: true}
''');
    final compiled = CompiledPlanCompiler().compile(testCase);
    final plans = [compiled, ExecutionPlan.fromWire(compiled.toWire())];
    const failingOperations = {
      'before': [
        'environment:setEnv:before',
      ],
      'wait': [
        'environment:setEnv:before',
        'wait:waitFor:wait',
      ],
      'assertion': [
        'environment:setEnv:before',
        'wait:waitFor:wait',
        'assertion:expectVisible:assertion',
      ],
      'interaction': [
        'environment:setEnv:before',
        'wait:waitFor:wait',
        'assertion:expectVisible:assertion',
        'interaction:tap:interaction',
      ],
      'lifecycle': [
        'environment:setEnv:before',
        'wait:waitFor:wait',
        'assertion:expectVisible:assertion',
        'interaction:tap:interaction',
        'lifecycle:openScreen:lifecycle',
      ],
    };

    for (final scenario in failingOperations.entries) {
      final results = <({
        AttemptResult result,
        List<String> operations,
        List<(ExecutionEventKind, String?, String?, String?)> events,
        int observations,
        int closeCalls,
      })>[];

      for (final plan in plans) {
        final runtime = _RecordingRuntime(
          visible: true,
          failedOperation: scenario.key,
          throwOnFailure: true,
        );
        final events = <ExecutionEvent>[];
        final result = await ExecutionKernelRunner(
          plan: plan,
          runtime: runtime,
          eventSubscribers: [events.add],
        ).run();
        results.add((
          result: result,
          operations: runtime.operations,
          events: events
              .map((event) => (
                    event.kind,
                    event.nodeId,
                    event.operation,
                    event.detail,
                  ))
              .toList(),
          observations: runtime.observeCalls,
          closeCalls: runtime.closeCalls,
        ));
      }

      for (final run in results) {
        expect(run.result.outcome, AttemptOutcome.failed, reason: scenario.key);
        expect(run.result.cause, isA<StateError>(), reason: scenario.key);
        expect(run.operations, scenario.value, reason: scenario.key);
        expect(run.observations, scenario.key == 'before' ? 0 : 1,
            reason: scenario.key);
        expect(run.closeCalls, 1, reason: scenario.key);
      }
      expect(results[1].result.failureCode, results[0].result.failureCode,
          reason: scenario.key);
      expect(results[1].result.primaryFailure, results[0].result.primaryFailure,
          reason: scenario.key);
      expect(results[1].result.failureOperation,
          results[0].result.failureOperation,
          reason: scenario.key);
      expect(
        (
          results[1].result.failureSource?.path,
          results[1].result.failureSource?.stepPath,
        ),
        (
          results[0].result.failureSource?.path,
          results[0].result.failureSource?.stepPath,
        ),
        reason: scenario.key,
      );
      expect(results[1].operations, results[0].operations,
          reason: scenario.key);
      expect(results[1].events, results[0].events, reason: scenario.key);
      expect(results[1].observations, results[0].observations,
          reason: scenario.key);
    }
  });
}

List<String> _expectedOperations({
  required bool visible,
  required String? failedOperation,
}) {
  final perIteration = <String>['environment:setEnv:before'];
  if (visible && failedOperation != 'before') {
    const branchOperations = [
      ('wait:waitFor:wait', 'wait'),
      ('assertion:expectVisible:assertion', 'assertion'),
      ('interaction:tap:interaction', 'interaction'),
      ('lifecycle:openScreen:lifecycle', 'lifecycle'),
    ];
    for (final (operation, label) in branchOperations) {
      perIteration.add(operation);
      if (failedOperation == label) break;
    }
  }

  final failedInsideOptional =
      failedOperation != null && (failedOperation == 'before' || visible);
  if (!failedInsideOptional) {
    perIteration.add('environment:setEnv:optional_tail');
    perIteration.add('environment:setEnv:optional_after_group');
  }
  perIteration.add('environment:setEnv:iteration_tail');

  return [
    ...perIteration,
    ...perIteration,
    'environment:setEnv:after_repeat',
  ];
}

final class _RecordingRuntime implements TestRuntime {
  _RecordingRuntime({
    required this.visible,
    required this.failedOperation,
    this.failObservation = false,
    this.throwOnFailure = false,
    this.onObserve,
  });

  final bool visible;
  final String? failedOperation;
  final bool failObservation;
  final bool throwOnFailure;
  final void Function()? onObserve;
  final List<String> operations = [];
  int observeCalls = 0;
  int closeCalls = 0;

  @override
  RuntimeCapabilities get capabilities =>
      RuntimeCapabilities(operationRegistry.handlerKeys);

  @override
  Future<RuntimeView> observe(ObservationRequest request) async {
    observeCalls++;
    onObserve?.call();
    if (failObservation) throw StateError('observation failed');
    return RuntimeView(
      revision: observeCalls,
      level: request.level,
      target: request.target,
      targetVisible: visible,
    );
  }

  @override
  Future<OperationResult> execute(TestOperation operation) async {
    final label = operation.input['key'] ??
        operation.input['id'] ??
        operation.input['screen'];
    operations.add('${operation.kind.name}:${operation.name}:$label');
    if (label == failedOperation) {
      if (throwOnFailure) throw StateError('operation threw');
      return const OperationResult.failure(
        'recoverable operation failure',
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
