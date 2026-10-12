import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/src/core/execution_kernel_runner.dart';
import 'package:ensemble_test_runner/src/core/kernel.dart';
import 'package:ensemble_test_runner/src/core/plan.dart';
import 'package:ensemble_test_runner/src/core/operation.dart';
import 'package:ensemble_test_runner/src/core/plan_wire_transport.dart';
import 'package:ensemble_test_runner/src/core/runtime.dart';
import 'package:ensemble_test_runner/src/runtime/compiled_plan.dart';
import 'package:ensemble_test_runner/src/runtime/operation_registry.dart';
import 'package:ensemble_test_runner/vocabulary/test_step_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Drive this product from the canonical registry, not a hand-picked sample
  // list. A new operation must retain its dispatch metadata through every
  // control node and the wire format without requiring a second test edit.
  final operationCases = [
    for (final descriptor in operationRegistry.descriptors)
      (
        name: descriptor.name,
        input: Map<String, dynamic>.from(
          TestStepRegistry.entries[descriptor.name]!.example,
        ),
      ),
  ];
  final controlCases =
      <({String name, String label, Map<String, dynamic> args})>[
    (name: 'group', label: 'group', args: const {}),
    (name: 'optional', label: 'optional', args: const {}),
    (name: 'repeat', label: 'repeat twice', args: {'times': 2}),
    (name: 'repeat', label: 'repeat zero times', args: {'times': 0}),
    (name: 'ifVisible', label: 'ifVisible', args: {'id': 'branch-target'}),
  ];

  test('registered operation metadata survives controls and plan wire',
      () async {
    for (final operationCase in operationCases) {
      for (final controlCase in controlCases) {
        final descriptor = operationRegistry.lookup(operationCase.name)!;
        final plan = CompiledPlanCompiler().compile(
          EnsembleTestCase(
            id: '${controlCase.name}_${operationCase.name}',
            steps: [
              TestStep(
                type: controlCase.name,
                args: controlCase.args,
                nestedSteps: [
                  TestStep(
                    type: operationCase.name,
                    args: operationCase.input,
                  ),
                ],
              ),
              const TestStep(type: 'tap', args: {'id': 'after_control'}),
            ],
          ),
        );
        final receivedPlan = ExecutionPlanWireTransport.decode(
          ExecutionPlanWireTransport.encode(plan),
        );
        for (final visible in [true, false]) {
          final directRuntime = _RecordingRuntime(
            visible: controlCase.name != 'ifVisible' || visible,
          );
          final wireRuntime = _RecordingRuntime(
            visible: controlCase.name != 'ifVisible' || visible,
          );
          final directEvents = <ExecutionEvent>[];
          final wireEvents = <ExecutionEvent>[];
          final directResult = await ExecutionKernelRunner(
            plan: plan,
            runtime: directRuntime,
            eventSubscribers: [directEvents.add],
          ).run();
          final wireResult = await ExecutionKernelRunner(
            plan: receivedPlan,
            runtime: wireRuntime,
            eventSubscribers: [wireEvents.add],
          ).run();

          final expectedCount = switch (controlCase.name) {
            'repeat' => controlCase.args['times'] as int,
            'ifVisible' when !visible => 0,
            _ => 1,
          };
          expect(directResult.outcome, AttemptOutcome.passed,
              reason: 'visible=$visible');
          expect(wireResult.outcome, directResult.outcome,
              reason: 'visible=$visible');
          expect(directResult.operations, expectedCount + 1,
              reason: 'visible=$visible');
          expect(wireResult.operations, directResult.operations,
              reason: 'visible=$visible');
          expect(directRuntime.executed.length, expectedCount + 1,
              reason: 'visible=$visible');
          expect(
            wireRuntime.executed.map(_operationSignature),
            directRuntime.executed.map(_operationSignature),
            reason: 'visible=$visible',
          );
          expect(
            wireEvents.map(_eventSignature),
            directEvents.map(_eventSignature),
            reason: 'visible=$visible',
          );
          for (final executed in directRuntime.executed.take(expectedCount)) {
            expect(executed.name, descriptor.name);
            expect(executed.kind, descriptor.kind);
            expect(executed.handlerKey, descriptor.handlerKey);
            expect(executed.input, operationCase.input);
          }
          expect(directRuntime.executed.last.name, 'tap');
          expect(wireRuntime.executed.last.name, 'tap');
          expect(directRuntime.closeCalls, 1);
          expect(wireRuntime.closeCalls, 1);
        }
      }
    }
  });

  test('nested control pairs preserve direct and wire traversal semantics',
      () async {
    TestStep wrap(
      ({String name, String label, Map<String, dynamic> args}) control,
      TestStep child,
    ) =>
        TestStep(
          type: control.name,
          args: control.args,
          nestedSteps: [child],
        );

    for (final outer in controlCases) {
      for (final inner in controlCases) {
        for (final visible in [true, false]) {
          final plan = CompiledPlanCompiler().compile(
            EnsembleTestCase(
              id: 'nested_${outer.name}_${inner.name}',
              steps: [
                wrap(
                  outer,
                  wrap(
                    inner,
                    const TestStep(type: 'tap', args: {'id': 'nested_leaf'}),
                  ),
                ),
              ],
            ),
          );
          final decoded = ExecutionPlanWireTransport.decode(
            ExecutionPlanWireTransport.encode(plan),
          );
          final runs = <({
            AttemptResult result,
            _RecordingRuntime runtime,
            List<ExecutionEvent> events,
          })>[];

          for (final executionPlan in [plan, decoded]) {
            final runtime = _RecordingRuntime(visible: visible);
            final events = <ExecutionEvent>[];
            final result = await ExecutionKernelRunner(
              plan: executionPlan,
              runtime: runtime,
              eventSubscribers: [events.add],
            ).run();
            runs.add((result: result, runtime: runtime, events: events));
          }

          int visits(
              ({String name, String label, Map<String, dynamic> args}) c) {
            if (c.name == 'ifVisible' && !visible) return 0;
            if (c.name == 'repeat') return c.args['times'] as int;
            return 1;
          }

          final expectedExecutions = visits(outer) * visits(inner);
          for (final run in runs) {
            expect(run.result.outcome, AttemptOutcome.passed,
                reason: '${outer.label} → ${inner.label}, visible=$visible');
            expect(run.result.operations, expectedExecutions);
            expect(run.runtime.executed, hasLength(expectedExecutions));
            expect(run.runtime.closeCalls, 1);
          }
          expect(runs[1].result.failureCode, runs[0].result.failureCode);
          expect(runs[1].result.operations, runs[0].result.operations);
          expect(
            runs[1].runtime.executed.map(_operationSignature),
            runs[0].runtime.executed.map(_operationSignature),
          );
          expect(
            runs[1].events.map(_eventSignature),
            runs[0].events.map(_eventSignature),
          );
        }
      }
    }
  });

  test('nested optional blocks recover at the nearest boundary', () async {
    final plan = CompiledPlanCompiler().compile(
      const EnsembleTestCase(
        id: 'nested_optional_recovery',
        steps: [
          TestStep(
            type: 'optional',
            args: {},
            nestedSteps: [
              TestStep(
                type: 'optional',
                args: {},
                nestedSteps: [
                  TestStep(type: 'tap', args: {'id': 'inner_failure'}),
                ],
              ),
            ],
          ),
          TestStep(type: 'tap', args: {'id': 'after_optional'}),
        ],
      ),
    );
    final decoded = ExecutionPlanWireTransport.decode(
      ExecutionPlanWireTransport.encode(plan),
    );
    final runs = <({
      AttemptResult result,
      _RecordingRuntime runtime,
      List<ExecutionEvent> events,
    })>[];

    for (final executionPlan in [plan, decoded]) {
      final runtime = _RecordingRuntime(
        visible: true,
        failOperationId: 'inner_failure',
      );
      final events = <ExecutionEvent>[];
      final result = await ExecutionKernelRunner(
        plan: executionPlan,
        runtime: runtime,
        eventSubscribers: [events.add],
      ).run();
      runs.add((result: result, runtime: runtime, events: events));
    }

    for (final run in runs) {
      expect(run.result.outcome, AttemptOutcome.passed);
      expect(run.result.operations, 2);
      expect(run.runtime.executed.map((op) => op.input['id']), [
        'inner_failure',
        'after_optional',
      ]);
      expect(run.runtime.closeCalls, 1);
    }
    expect(runs[1].result.failureCode, runs[0].result.failureCode);
    expect(runs[1].result.operations, runs[0].result.operations);
    expect(
      runs[1].runtime.executed.map(_operationSignature),
      runs[0].runtime.executed.map(_operationSignature),
    );
    expect(
      runs[1].events.map(_eventSignature),
      runs[0].events.map(_eventSignature),
    );
  });

  // Success-only cases above prove that operation metadata survives every
  // control node. Also cross recoverable operation failures with each control
  // node: only optional should recover, while the other controls propagate the
  // failure (unless an ifVisible branch is skipped).
  test('control failures preserve direct and wire traversal semantics',
      () async {
    for (final controlCase in controlCases) {
      final plan = CompiledPlanCompiler().compile(
        EnsembleTestCase(
          id: '${controlCase.name}_recoverable_failure',
          steps: [
            TestStep(
              type: controlCase.name,
              args: controlCase.args,
              nestedSteps: [
                const TestStep(
                  type: 'tap',
                  args: {'id': 'recoverable_failure'},
                ),
              ],
            ),
            const TestStep(type: 'tap', args: {'id': 'after_control'}),
          ],
        ),
      );
      final receivedPlan = ExecutionPlanWireTransport.decode(
        ExecutionPlanWireTransport.encode(plan),
      );

      for (final visible in [true, false]) {
        final directRuntime = _RecordingRuntime(
          visible: controlCase.name != 'ifVisible' || visible,
          failOperationId: 'recoverable_failure',
        );
        final wireRuntime = _RecordingRuntime(
          visible: controlCase.name != 'ifVisible' || visible,
          failOperationId: 'recoverable_failure',
        );
        final directEvents = <ExecutionEvent>[];
        final wireEvents = <ExecutionEvent>[];
        final directResult = await ExecutionKernelRunner(
          plan: plan,
          runtime: directRuntime,
          eventSubscribers: [directEvents.add],
        ).run();
        final wireResult = await ExecutionKernelRunner(
          plan: receivedPlan,
          runtime: wireRuntime,
          eventSubscribers: [wireEvents.add],
        ).run();

        final skippedBranch = controlCase.name == 'ifVisible' && !visible;
        final zeroRepeat =
            controlCase.name == 'repeat' && controlCase.args['times'] == 0;
        final recovered = controlCase.name == 'optional' || zeroRepeat;
        final shouldPass = skippedBranch || recovered;
        expect(directResult.outcome,
            shouldPass ? AttemptOutcome.passed : AttemptOutcome.failed,
            reason: 'direct plan, visible=$visible');
        expect(wireResult.outcome, directResult.outcome,
            reason: 'wire plan, visible=$visible');
        expect(wireResult.operations, directResult.operations);
        expect(wireResult.failureCode, directResult.failureCode);
        expect(
          wireRuntime.executed.map(_operationSignature),
          directRuntime.executed.map(_operationSignature),
        );
        expect(
          wireEvents.map(_eventSignature),
          directEvents.map(_eventSignature),
        );
        expect(directRuntime.closeCalls, 1);
        expect(wireRuntime.closeCalls, 1);

        if (shouldPass) {
          expect(
              directRuntime.executed.map((operation) => operation.input['id']),
              skippedBranch || zeroRepeat
                  ? ['after_control']
                  : ['recoverable_failure', 'after_control']);
        } else {
          expect(
              directRuntime.executed.map((operation) => operation.input['id']),
              ['recoverable_failure']);
          expect(directResult.failureCode, 'elementNotFound');
        }
      }
    }
  });

  test('thrown operation failures preserve direct and wire control semantics',
      () async {
    for (final controlCase in controlCases) {
      final plan = CompiledPlanCompiler().compile(
        EnsembleTestCase(
          id: '${controlCase.name}_thrown_failure',
          steps: [
            TestStep(
              type: controlCase.name,
              args: controlCase.args,
              nestedSteps: [
                const TestStep(
                  type: 'tap',
                  args: {'id': 'thrown_failure'},
                ),
              ],
            ),
            const TestStep(type: 'tap', args: {'id': 'after_control'}),
          ],
        ),
      );
      final receivedPlan = ExecutionPlanWireTransport.decode(
        ExecutionPlanWireTransport.encode(plan),
      );

      for (final visible in [true, false]) {
        final branchSkipped = controlCase.name == 'ifVisible' && !visible;
        final zeroRepeat =
            controlCase.name == 'repeat' && controlCase.args['times'] == 0;
        final shouldPass = branchSkipped || zeroRepeat;
        final directRuntime = _RecordingRuntime(
          visible: controlCase.name != 'ifVisible' || visible,
          throwOperationId: 'thrown_failure',
        );
        final wireRuntime = _RecordingRuntime(
          visible: controlCase.name != 'ifVisible' || visible,
          throwOperationId: 'thrown_failure',
        );
        final directEvents = <ExecutionEvent>[];
        final wireEvents = <ExecutionEvent>[];
        final directResult = await ExecutionKernelRunner(
          plan: plan,
          runtime: directRuntime,
          eventSubscribers: [directEvents.add],
        ).run();
        final wireResult = await ExecutionKernelRunner(
          plan: receivedPlan,
          runtime: wireRuntime,
          eventSubscribers: [wireEvents.add],
        ).run();

        expect(
          directResult.outcome,
          shouldPass ? AttemptOutcome.passed : AttemptOutcome.failed,
          reason: 'direct plan: ${controlCase.label}, visible=$visible',
        );
        expect(wireResult.outcome, directResult.outcome);
        expect(wireResult.operations, directResult.operations);
        expect(wireResult.failureCode, directResult.failureCode);
        expect(wireResult.failureOperation, directResult.failureOperation);
        expect(
          wireRuntime.executed.map(_operationSignature),
          directRuntime.executed.map(_operationSignature),
        );
        expect(
          wireEvents.map(_eventSignature),
          directEvents.map(_eventSignature),
        );
        expect(directRuntime.closeCalls, 1);
        expect(wireRuntime.closeCalls, 1);

        if (shouldPass) {
          expect(
              directRuntime.executed.map((operation) => operation.input['id']),
              ['after_control']);
          expect(directResult.failureCode, isNull);
        } else {
          expect(
            directRuntime.executed.map((operation) => operation.input['id']),
            ['thrown_failure'],
          );
          expect(directResult.failureCode, 'operationException');
          expect(directResult.failureOperation, 'tap');
          expect(directResult.cause, isA<StateError>());
          expect(
            directEvents
                .where((event) =>
                    event.kind == ExecutionEventKind.operationFinished)
                .map((event) => event.detail),
            ['Bad state: operation unavailable'],
          );
        }
      }
    }
  });

  test('optional recovery exits a nested repeat identically after wire decode',
      () async {
    final plan = CompiledPlanCompiler().compile(
      const EnsembleTestCase(
        id: 'optional_repeat_recovery',
        steps: [
          TestStep(
            type: 'optional',
            args: {},
            nestedSteps: [
              TestStep(
                type: 'repeat',
                args: {'times': 3},
                nestedSteps: [
                  TestStep(type: 'tap', args: {'id': 'repeat_failure'}),
                ],
              ),
            ],
          ),
          TestStep(type: 'tap', args: {'id': 'after_optional'}),
        ],
      ),
    );
    final receivedPlan = ExecutionPlanWireTransport.decode(
      ExecutionPlanWireTransport.encode(plan),
    );
    final directRuntime = _RecordingRuntime(
      visible: true,
      failOperationId: 'repeat_failure',
    );
    final wireRuntime = _RecordingRuntime(
      visible: true,
      failOperationId: 'repeat_failure',
    );
    final directEvents = <ExecutionEvent>[];
    final wireEvents = <ExecutionEvent>[];

    final directResult = await ExecutionKernelRunner(
      plan: plan,
      runtime: directRuntime,
      eventSubscribers: [directEvents.add],
    ).run();
    final wireResult = await ExecutionKernelRunner(
      plan: receivedPlan,
      runtime: wireRuntime,
      eventSubscribers: [wireEvents.add],
    ).run();

    expect(directResult.outcome, AttemptOutcome.passed);
    expect(wireResult.outcome, directResult.outcome);
    expect(wireResult.operations, directResult.operations);
    expect(wireResult.failureCode, directResult.failureCode);
    expect(
      directRuntime.executed.map((operation) => operation.input['id']),
      ['repeat_failure', 'after_optional'],
    );
    expect(
      wireRuntime.executed.map((operation) => operation.input['id']),
      directRuntime.executed.map((operation) => operation.input['id']),
    );
    expect(wireEvents.map(_eventSignature), directEvents.map(_eventSignature));
    expect(directRuntime.closeCalls, 1);
    expect(wireRuntime.closeCalls, 1);
  });

  test('explicit operation failure recovery matches after wire decoding',
      () async {
    TestOperation operation(String id) => TestOperation(
          id: id,
          name: 'tap',
          kind: OperationKind.interaction,
          handlerKey: 'interaction.tap',
          input: {'id': id},
          source: SourceLocation('explicit-recovery', 'steps.$id'),
        );

    final plan = ExecutionPlan(
      id: 'explicit_operation_recovery',
      start: 'primary',
      nodes: {
        'primary': OperationNode(
          'primary',
          operation('primary'),
          'end',
          onFailure: 'recovery',
        ),
        'recovery':
            RecoveryNode('recovery', next: 'tail', resetLoops: const []),
        'tail': OperationNode('tail', operation('tail'), 'end'),
        'end': const EndNode('end'),
      },
    );
    final decoded = ExecutionPlanWireTransport.decode(
      ExecutionPlanWireTransport.encode(plan),
    );
    final runs = <({
      AttemptResult result,
      _RecordingRuntime runtime,
      List<ExecutionEvent> events,
    })>[];

    for (final executionPlan in [plan, decoded]) {
      final runtime = _RecordingRuntime(
        visible: true,
        failOperationId: 'primary',
      );
      final events = <ExecutionEvent>[];
      final result = await ExecutionKernelRunner(
        plan: executionPlan,
        runtime: runtime,
        eventSubscribers: [events.add],
      ).run();
      runs.add((result: result, runtime: runtime, events: events));
    }

    for (final run in runs) {
      expect(run.result.outcome, AttemptOutcome.passed);
      expect(run.result.operations, 2);
      expect(run.result.failureCode, isNull);
      expect(
        run.runtime.executed.map((operation) => operation.input['id']),
        ['primary', 'tail'],
      );
      expect(run.runtime.closeCalls, 1);
      expect(
        run.events
            .where(
                (event) => event.kind == ExecutionEventKind.operationFinished)
            .map((event) => event.detail),
        ['recoverable failure', null],
      );
      expect(run.events.last.kind, ExecutionEventKind.attemptFinished);
      expect(run.events.last.detail, AttemptOutcome.passed.name);
    }
    expect(runs[1].result.operations, runs[0].result.operations);
    expect(
      runs[1].runtime.executed.map(_operationSignature),
      runs[0].runtime.executed.map(_operationSignature),
    );
    expect(
      runs[1].events.map(_eventSignature),
      runs[0].events.map(_eventSignature),
    );
  });

  test('loop-entry limit preserves direct and wire control-flow semantics',
      () async {
    final plan = CompiledPlanCompiler().compile(
      const EnsembleTestCase(
        id: 'loop_entry_limit_parity',
        steps: [
          TestStep(
            type: 'repeat',
            args: {'times': 3},
            nestedSteps: [
              TestStep(type: 'tap', args: {'id': 'repeat_body'}),
            ],
          ),
          TestStep(type: 'tap', args: {'id': 'after_repeat'}),
        ],
      ),
    );
    final receivedPlan = ExecutionPlanWireTransport.decode(
      ExecutionPlanWireTransport.encode(plan),
    );
    final results = <({
      AttemptResult result,
      _RecordingRuntime runtime,
      List<ExecutionEvent> events,
    })>[];

    for (final executionPlan in [plan, receivedPlan]) {
      final runtime = _RecordingRuntime(visible: true);
      final events = <ExecutionEvent>[];
      final result = await ExecutionKernelRunner(
        plan: executionPlan,
        runtime: runtime,
        limits: const ExecutionLimits(maxLoopEntries: 1),
        eventSubscribers: [events.add],
      ).run();
      results.add((result: result, runtime: runtime, events: events));
    }

    for (final attempt in results) {
      expect(attempt.result.outcome, AttemptOutcome.limitExceeded);
      expect(attempt.result.failureCode, 'loopLimitExceeded');
      expect(attempt.result.operations, 1);
      expect(
        attempt.runtime.executed.map((operation) => operation.input['id']),
        ['repeat_body'],
      );
      expect(attempt.runtime.closeCalls, 1);
      expect(attempt.events.last.kind, ExecutionEventKind.attemptFinished);
      expect(attempt.events.last.detail, AttemptOutcome.limitExceeded.name);
    }
    expect(results[1].result.primaryFailure, results[0].result.primaryFailure);
    expect(results[1].result.failureCode, results[0].result.failureCode);
    expect(results[1].result.operations, results[0].result.operations);
    expect(
      results[1].events.map(_eventSignature),
      results[0].events.map(_eventSignature),
    );
  });

  test('directive limit preserves partial repeat traversal after wire decode',
      () async {
    final plan = CompiledPlanCompiler().compile(
      const EnsembleTestCase(
        id: 'directive_limit_repeat_parity',
        steps: [
          TestStep(
            type: 'repeat',
            args: {'times': 4},
            nestedSteps: [
              TestStep(type: 'tap', args: {'id': 'repeat_body'}),
            ],
          ),
          TestStep(type: 'tap', args: {'id': 'after_repeat'}),
        ],
      ),
    );
    final decoded = ExecutionPlanWireTransport.decode(
      ExecutionPlanWireTransport.encode(plan),
    );
    final attempts = <({
      AttemptResult result,
      _RecordingRuntime runtime,
      List<ExecutionEvent> events,
    })>[];

    for (final executionPlan in [plan, decoded]) {
      final runtime = _RecordingRuntime(visible: true);
      final events = <ExecutionEvent>[];
      final result = await ExecutionKernelRunner(
        plan: executionPlan,
        runtime: runtime,
        limits: const ExecutionLimits(maxDirectives: 5),
        eventSubscribers: [events.add],
      ).run();
      attempts.add((result: result, runtime: runtime, events: events));
    }

    for (final attempt in attempts) {
      expect(attempt.result.outcome, AttemptOutcome.limitExceeded);
      expect(attempt.result.failureCode, 'limitExceeded');
      expect(attempt.result.primaryFailure, 'Execution limit exceeded.');
      expect(attempt.result.operations, greaterThan(0));
      expect(
        attempt.runtime.executed.map((operation) => operation.input['id']),
        isNot(contains('after_repeat')),
      );
      expect(attempt.runtime.closeCalls, 1);
      expect(attempt.events.last.kind, ExecutionEventKind.attemptFinished);
      expect(attempt.events.last.detail, AttemptOutcome.limitExceeded.name);
    }
    expect(
        attempts[1].result.primaryFailure, attempts[0].result.primaryFailure);
    expect(attempts[1].result.failureCode, attempts[0].result.failureCode);
    expect(attempts[1].result.operations, attempts[0].result.operations);
    expect(
      attempts[1].runtime.executed.map(_operationSignature),
      attempts[0].runtime.executed.map(_operationSignature),
    );
    expect(
      attempts[1].events.map(_eventSignature),
      attempts[0].events.map(_eventSignature),
    );
  });
}

String _eventSignature(ExecutionEvent event) =>
    '${event.kind.name}:${event.nodeId}:${event.operation}:${event.detail}:'
    '${event.stepIndex}';

String _operationSignature(TestOperation operation) =>
    '${operation.name}:${operation.handlerKey}:${operation.input}';

final class _RecordingRuntime implements TestRuntime {
  _RecordingRuntime({
    required this.visible,
    this.failOperationId,
    this.throwOperationId,
  });

  final bool visible;
  final String? failOperationId;
  final String? throwOperationId;
  final List<TestOperation> executed = [];
  int closeCalls = 0;

  @override
  RuntimeCapabilities get capabilities => RuntimeCapabilities(
        operationRegistry.handlerKeys,
      );

  @override
  Future<RuntimeView> observe(ObservationRequest request) async => RuntimeView(
        revision: 0,
        level: request.level,
        target: request.target,
        targetVisible: visible,
      );

  @override
  Future<OperationResult> execute(TestOperation operation) async {
    executed.add(operation);
    if (throwOperationId != null && operation.input['id'] == throwOperationId) {
      throw StateError('operation unavailable');
    }
    if (failOperationId != null && operation.input['id'] == failOperationId) {
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
