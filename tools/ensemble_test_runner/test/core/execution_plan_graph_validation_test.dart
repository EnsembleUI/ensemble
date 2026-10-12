import 'package:ensemble_test_runner/src/core/operation.dart';
import 'package:ensemble_test_runner/src/core/plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rejects a control-flow cycle that is not a bounded loop edge', () {
    expect(
      () => ExecutionPlan(id: 'unbounded', start: 'branch', nodes: {
        'branch': BranchNode(
          'branch',
          target: const {'id': 'visible'},
          whenVisible: 'branch',
          whenHidden: 'end',
        ),
        'end': const EndNode('end'),
      }),
      throwsA(isA<FormatException>().having(
        (error) => error.message,
        'message',
        contains('cycle outside a loop iteration'),
      )),
    );
  });

  test('rejects cycles through every unbounded node edge kind', () {
    final operation = TestOperation(
      id: 'operation',
      name: 'tap',
      kind: OperationKind.interaction,
      handlerKey: 'interaction.tap',
      input: const {},
      source: const SourceLocation('case.yaml', 'steps[0]'),
    );
    final cases = <String, Map<String, PlanNode>>{
      'operation continuation': {
        'branch': BranchNode(
          'branch',
          target: const {'id': 'target'},
          whenVisible: 'operation',
          whenHidden: 'end',
        ),
        'operation': OperationNode('operation', operation, 'branch'),
        'end': const EndNode('end'),
      },
      'operation failure recovery': {
        'branch': BranchNode(
          'branch',
          target: const {'id': 'target'},
          whenVisible: 'operation',
          whenHidden: 'end',
        ),
        'operation': OperationNode(
          'operation',
          operation,
          'end',
          onFailure: 'branch',
        ),
        'end': const EndNode('end'),
      },
      'recovery continuation': {
        'branch': BranchNode(
          'branch',
          target: const {'id': 'target'},
          whenVisible: 'recovery',
          whenHidden: 'end',
        ),
        'recovery':
            RecoveryNode('recovery', next: 'branch', resetLoops: const []),
        'end': const EndNode('end'),
      },
      'step boundary continuation': {
        'branch': BranchNode(
          'branch',
          target: const {'id': 'target'},
          whenVisible: 'boundary',
          whenHidden: 'end',
        ),
        'boundary': const StepBoundaryNode(
          'boundary',
          stepIndex: 0,
          started: true,
          next: 'branch',
        ),
        'end': const EndNode('end'),
      },
    };

    for (final entry in cases.entries) {
      expect(
        () => ExecutionPlan(
          id: entry.key,
          start: 'branch',
          nodes: entry.value,
        ),
        throwsA(isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('cycle outside a loop iteration'),
        )),
        reason: entry.key,
      );
    }
  });

  test('rejects missing destinations for every control-flow edge kind', () {
    final operation = TestOperation(
      id: 'operation',
      name: 'tap',
      kind: OperationKind.interaction,
      handlerKey: 'interaction.tap',
      input: const {},
      source: const SourceLocation('case.yaml', 'steps[0]'),
    );
    final cases = <String, PlanNode>{
      'operation continuation':
          OperationNode('operation', operation, 'missing'),
      'operation failure': OperationNode(
        'operation',
        operation,
        'end',
        onFailure: 'missing',
      ),
      'visible branch': BranchNode(
        'branch',
        target: const {'id': 'target'},
        whenVisible: 'missing',
        whenHidden: 'end',
      ),
      'hidden branch': BranchNode(
        'branch',
        target: const {'id': 'target'},
        whenVisible: 'end',
        whenHidden: 'missing',
      ),
      'branch failure': BranchNode(
        'branch',
        target: const {'id': 'target'},
        whenVisible: 'end',
        whenHidden: 'end',
        onFailure: 'missing',
      ),
      'loop body': const LoopNode(
        'loop',
        times: 2,
        body: 'missing',
        next: 'end',
      ),
      'loop continuation': const LoopNode(
        'loop',
        times: 2,
        body: 'end',
        next: 'missing',
      ),
      'recovery continuation': RecoveryNode(
        'recovery',
        next: 'missing',
        resetLoops: const [],
      ),
      'step boundary continuation': const StepBoundaryNode(
        'boundary',
        stepIndex: 0,
        started: true,
        next: 'missing',
      ),
    };

    for (final entry in cases.entries) {
      expect(
        () => ExecutionPlan(
          id: entry.key,
          start: entry.value.id,
          nodes: {entry.value.id: entry.value, 'end': const EndNode('end')},
        ),
        throwsA(isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('points to missing "missing"'),
        )),
        reason: entry.key,
      );
    }
  });

  test('direct and wire plans diagnose every missing edge identically', () {
    final operation = TestOperation(
      id: 'operation',
      name: 'tap',
      kind: OperationKind.interaction,
      handlerKey: 'interaction.tap',
      input: const {},
      source: const SourceLocation('case.yaml', 'steps[0]'),
    );
    final wireOperation = {
      'id': 'operation',
      'name': 'tap',
      'kind': 'interaction',
      'handlerKey': 'interaction.tap',
      'input': <String, Object?>{},
      'source': {'path': 'case.yaml', 'stepPath': 'steps[0]'},
    };
    final cases =
        <String, ({String id, PlanNode node, Map<String, Object?> wireNode})>{
      'operation continuation': (
        id: 'operation',
        node: OperationNode('operation', operation, 'missing'),
        wireNode: {
          'type': 'operation',
          'id': 'operation',
          'next': 'missing',
          'operation': wireOperation,
        },
      ),
      'operation failure': (
        id: 'operation',
        node: OperationNode(
          'operation',
          operation,
          'end',
          onFailure: 'missing',
        ),
        wireNode: {
          'type': 'operation',
          'id': 'operation',
          'next': 'end',
          'onFailure': 'missing',
          'operation': wireOperation,
        },
      ),
      'visible branch': (
        id: 'branch',
        node: BranchNode(
          'branch',
          target: const {'id': 'target'},
          whenVisible: 'missing',
          whenHidden: 'end',
        ),
        wireNode: {
          'type': 'branch',
          'id': 'branch',
          'target': {'id': 'target'},
          'whenVisible': 'missing',
          'whenHidden': 'end',
        },
      ),
      'hidden branch': (
        id: 'branch',
        node: BranchNode(
          'branch',
          target: const {'id': 'target'},
          whenVisible: 'end',
          whenHidden: 'missing',
        ),
        wireNode: {
          'type': 'branch',
          'id': 'branch',
          'target': {'id': 'target'},
          'whenVisible': 'end',
          'whenHidden': 'missing',
        },
      ),
      'branch failure': (
        id: 'branch',
        node: BranchNode(
          'branch',
          target: const {'id': 'target'},
          whenVisible: 'end',
          whenHidden: 'end',
          onFailure: 'missing',
        ),
        wireNode: {
          'type': 'branch',
          'id': 'branch',
          'target': {'id': 'target'},
          'whenVisible': 'end',
          'whenHidden': 'end',
          'onFailure': 'missing',
        },
      ),
      'loop body': (
        id: 'loop',
        node: const LoopNode(
          'loop',
          times: 2,
          body: 'missing',
          next: 'end',
        ),
        wireNode: {
          'type': 'loop',
          'id': 'loop',
          'times': 2,
          'body': 'missing',
          'next': 'end',
        },
      ),
      'loop continuation': (
        id: 'loop',
        node: const LoopNode(
          'loop',
          times: 2,
          body: 'end',
          next: 'missing',
        ),
        wireNode: {
          'type': 'loop',
          'id': 'loop',
          'times': 2,
          'body': 'end',
          'next': 'missing',
        },
      ),
      'recovery continuation': (
        id: 'recovery',
        node: RecoveryNode('recovery', next: 'missing', resetLoops: const []),
        wireNode: {
          'type': 'recovery',
          'id': 'recovery',
          'next': 'missing',
          'resetLoops': <String>[],
        },
      ),
      'step boundary continuation': (
        id: 'boundary',
        node: const StepBoundaryNode(
          'boundary',
          stepIndex: 0,
          started: true,
          next: 'missing',
        ),
        wireNode: {
          'type': 'stepBoundary',
          'id': 'boundary',
          'stepIndex': 0,
          'started': true,
          'next': 'missing',
        },
      ),
    };

    for (final entry in cases.entries) {
      final directError = _formatErrorMessage(() => ExecutionPlan(
            id: entry.key,
            start: entry.value.id,
            nodes: {
              entry.value.id: entry.value.node,
              'end': const EndNode('end'),
            },
          ));
      final wireError = _formatErrorMessage(() => ExecutionPlan.fromWire({
            'version': 1,
            'id': entry.key,
            'start': entry.value.id,
            'nodes': {
              entry.value.id: entry.value.wireNode,
              'end': {'type': 'end', 'id': 'end'},
            },
          }));

      expect(directError, contains('points to missing "missing"'),
          reason: entry.key);
      expect(wireError, directError, reason: entry.key);
    }
  });

  test('accepts a cycle formed by the loop iteration edge', () {
    final plan = ExecutionPlan(id: 'bounded', start: 'loop', nodes: {
      'loop': const LoopNode('loop', times: 2, body: 'operation', next: 'end'),
      'operation': OperationNode(
        'operation',
        TestOperation(
          id: 'operation',
          name: 'tap',
          kind: OperationKind.interaction,
          handlerKey: 'interaction.tap',
          input: const {},
          source: const SourceLocation('case.yaml', 'steps[0]'),
        ),
        'loop',
      ),
      'end': const EndNode('end'),
    });

    expect(plan.node('loop'), isA<LoopNode>());
  });

  test('rejects a loop body that exits without returning to the loop', () {
    final directError = _formatErrorMessage(() => ExecutionPlan(
          id: 'loop-body-exits-early',
          start: 'loop',
          nodes: {
            'loop': const LoopNode(
              'loop',
              times: 2,
              body: 'body-end',
              next: 'after-loop',
            ),
            'body-end': const EndNode('body-end'),
            'after-loop': const EndNode('after-loop'),
          },
        ));
    final wireError = _formatErrorMessage(() => ExecutionPlan.fromWire({
          'version': 1,
          'id': 'loop-body-exits-early',
          'start': 'loop',
          'nodes': {
            'loop': {
              'type': 'loop',
              'id': 'loop',
              'times': 2,
              'body': 'body-end',
              'next': 'after-loop',
            },
            'body-end': {'type': 'end', 'id': 'body-end'},
            'after-loop': {'type': 'end', 'id': 'after-loop'},
          },
        }));

    expect(directError,
        contains('exits without a loop iteration or scoped recovery'));
    expect(wireError, directError);
  });

  test('rejects a loop branch with any path that exits before returning', () {
    final directError = _formatErrorMessage(() => ExecutionPlan(
          id: 'loop-branch-exits-early',
          start: 'loop',
          nodes: {
            'loop': const LoopNode(
              'loop',
              times: 2,
              body: 'branch',
              next: 'after-loop',
            ),
            'branch': BranchNode(
              'branch',
              target: const {'id': 'visible'},
              whenVisible: 'loop',
              whenHidden: 'early-end',
            ),
            'early-end': const EndNode('early-end'),
            'after-loop': const EndNode('after-loop'),
          },
        ));
    final wireError = _formatErrorMessage(() => ExecutionPlan.fromWire({
          'version': 1,
          'id': 'loop-branch-exits-early',
          'start': 'loop',
          'nodes': {
            'loop': {
              'type': 'loop',
              'id': 'loop',
              'times': 2,
              'body': 'branch',
              'next': 'after-loop',
            },
            'branch': {
              'type': 'branch',
              'id': 'branch',
              'target': {'id': 'visible'},
              'whenVisible': 'loop',
              'whenHidden': 'early-end',
            },
            'early-end': {'type': 'end', 'id': 'early-end'},
            'after-loop': {'type': 'end', 'id': 'after-loop'},
          },
        }));

    expect(directError,
        contains('exits without a loop iteration or scoped recovery'));
    expect(wireError, directError);
  });

  test('rejects loops whose body aliases their continuation', () {
    final directError = _formatErrorMessage(() => ExecutionPlan(
          id: 'ambiguous-loop-edge',
          start: 'loop',
          nodes: {
            'loop': const LoopNode(
              'loop',
              times: 2,
              body: 'end',
              next: 'end',
            ),
            'end': const EndNode('end'),
          },
        ));
    final wireError = _formatErrorMessage(() => ExecutionPlan.fromWire({
          'version': 1,
          'id': 'ambiguous-loop-edge',
          'start': 'loop',
          'nodes': {
            'loop': {
              'type': 'loop',
              'id': 'loop',
              'times': 2,
              'body': 'end',
              'next': 'end',
            },
            'end': {'type': 'end', 'id': 'end'},
          },
        }));

    expect(directError, contains('identical body and continuation "end"'));
    expect(wireError, directError);
  });

  test('rejects recovery loop resets that reference a non-loop node', () {
    final directError = _formatErrorMessage(() => ExecutionPlan(
          id: 'invalid-recovery-reset',
          start: 'recovery',
          nodes: {
            'recovery': RecoveryNode(
              'recovery',
              next: 'end',
              resetLoops: const {'end'},
            ),
            'end': const EndNode('end'),
          },
        ));
    final wireError = _formatErrorMessage(() => ExecutionPlan.fromWire({
          'version': 1,
          'id': 'invalid-recovery-reset',
          'start': 'recovery',
          'nodes': {
            'recovery': {
              'type': 'recovery',
              'id': 'recovery',
              'next': 'end',
              'resetLoops': ['end'],
            },
            'end': {'type': 'end', 'id': 'end'},
          },
        }));

    expect(directError, contains('references non-loop "end"'));
    expect(wireError, directError);
  });

  test('rejects recovery resets for an enclosing loop', () {
    final operation = TestOperation(
      id: 'operation',
      name: 'tap',
      kind: OperationKind.interaction,
      handlerKey: 'interaction.tap',
      input: const {'id': 'target'},
      source: const SourceLocation('case.yaml', 'steps[0]'),
    );
    final directError = _formatErrorMessage(() => ExecutionPlan(
          id: 'out_of_scope_recovery_reset',
          start: 'loop',
          nodes: {
            'loop': const LoopNode(
              'loop',
              times: 2,
              body: 'operation',
              next: 'end',
            ),
            'operation': OperationNode(
              'operation',
              operation,
              'loop',
              onFailure: 'recovery',
            ),
            'recovery': RecoveryNode(
              'recovery',
              next: 'loop',
              resetLoops: const {'loop'},
            ),
            'end': const EndNode('end'),
          },
        ));
    final wireError = _formatErrorMessage(() => ExecutionPlan.fromWire({
          'version': 1,
          'id': 'out_of_scope_recovery_reset',
          'start': 'loop',
          'nodes': {
            'loop': {
              'type': 'loop',
              'id': 'loop',
              'times': 2,
              'body': 'operation',
              'next': 'end',
            },
            'operation': {
              'type': 'operation',
              'id': 'operation',
              'next': 'loop',
              'onFailure': 'recovery',
              'operation': {
                'id': 'operation',
                'name': 'tap',
                'kind': 'interaction',
                'handlerKey': 'interaction.tap',
                'input': {'id': 'target'},
                'source': {'path': 'case.yaml', 'stepPath': 'steps[0]'},
              },
            },
            'recovery': {
              'type': 'recovery',
              'id': 'recovery',
              'next': 'loop',
              'resetLoops': ['loop'],
            },
            'end': {'type': 'end', 'id': 'end'},
          },
        }));

    expect(directError, contains('resets enclosing loop "loop"'));
    expect(wireError, directError);
  });

  test('rejects padded plan and node identities before execution', () {
    final canonicalGraph = {
      'start': const StepBoundaryNode(
        'start',
        stepIndex: 0,
        started: true,
        next: 'end',
      ),
      'end': const EndNode('end'),
    };

    expect(
      () => ExecutionPlan(
        id: ' plan ',
        start: 'start',
        nodes: canonicalGraph,
      ),
      throwsA(isA<FormatException>().having(
        (error) => error.message,
        'message',
        contains('Plan id must not have surrounding whitespace'),
      )),
    );
    expect(
      () => ExecutionPlan(
        id: 'plan',
        start: 'start',
        nodes: {
          'start': const StepBoundaryNode(
            'start',
            stepIndex: 0,
            started: true,
            next: 'end',
          ),
          ' spare ': const StepBoundaryNode(
            ' spare ',
            stepIndex: 1,
            started: true,
            next: 'end',
          ),
          'end': const EndNode('end'),
        },
      ),
      throwsA(isA<FormatException>().having(
        (error) => error.message,
        'message',
        contains('Plan node id must not have surrounding whitespace'),
      )),
    );
  });

  test('direct and wire plans reject malformed graph identities equally', () {
    final cases =
        <String, ({String id, String start, Map<String, Object?> nodes})>{
      'padded plan id': (
        id: ' plan ',
        start: 'start',
        nodes: {
          'start': {
            'type': 'stepBoundary',
            'id': 'start',
            'stepIndex': 0,
            'started': true,
            'next': 'end',
          },
          'end': {'type': 'end', 'id': 'end'},
        },
      ),
      'padded start id': (
        id: 'plan',
        start: ' start ',
        nodes: {
          'start': {
            'type': 'stepBoundary',
            'id': 'start',
            'stepIndex': 0,
            'started': true,
            'next': 'end',
          },
          'end': {'type': 'end', 'id': 'end'},
        },
      ),
      'padded node map key': (
        id: 'plan',
        start: 'start',
        nodes: {
          ' start ': {
            'type': 'stepBoundary',
            'id': ' start ',
            'stepIndex': 0,
            'started': true,
            'next': 'end',
          },
          'end': {'type': 'end', 'id': 'end'},
        },
      ),
      'padded node id': (
        id: 'plan',
        start: 'start',
        nodes: {
          'start': {
            'type': 'stepBoundary',
            'id': ' start ',
            'stepIndex': 0,
            'started': true,
            'next': 'end',
          },
          'end': {'type': 'end', 'id': 'end'},
        },
      ),
    };

    for (final entry in cases.entries) {
      final plan = entry.value;
      final wireError = _formatErrorMessage(() => ExecutionPlan.fromWire({
            'version': 1,
            'id': plan.id,
            'start': plan.start,
            'nodes': plan.nodes,
          }));

      // Direct construction accepts typed nodes, so decode the valid graph
      // shape first and change only the invariant under test.
      final directError = _formatErrorMessage(() {
        final decoded = ExecutionPlan.fromWire({
          'version': 1,
          'id': 'plan',
          'start': 'start',
          'nodes': {
            'start': {
              'type': 'stepBoundary',
              'id': 'start',
              'stepIndex': 0,
              'started': true,
              'next': 'end',
            },
            'end': {'type': 'end', 'id': 'end'},
          },
        });
        ExecutionPlan(
          id: plan.id,
          start: plan.start,
          nodes: {
            for (final nodeEntry in decoded.nodes.entries)
              if (entry.key == 'padded node map key' &&
                  nodeEntry.key == 'start')
                ' start ': StepBoundaryNode(
                  ' start ',
                  stepIndex: 0,
                  started: true,
                  next: 'end',
                )
              else if (entry.key == 'padded node id' &&
                  nodeEntry.key == 'start')
                'start': StepBoundaryNode(
                  ' start ',
                  stepIndex: 0,
                  started: true,
                  next: 'end',
                )
              else
                nodeEntry.key: nodeEntry.value,
          },
        );
      });

      expect(directError, isNotEmpty, reason: entry.key);
      expect(wireError, directError, reason: entry.key);
    }
  });

  test(
      'rejects padded operation dispatch identities from direct and wire plans',
      () {
    final operation = TestOperation(
      id: 'operation',
      name: ' tap ',
      kind: OperationKind.interaction,
      handlerKey: 'ui.tap',
      input: const {},
      source: const SourceLocation('case.yaml', 'steps[0]'),
    );
    final directError = _formatErrorMessage(() => ExecutionPlan(
          id: 'invalid-operation-name',
          start: 'operation',
          nodes: {
            'operation': OperationNode(operation.id, operation, 'end'),
            'end': const EndNode('end'),
          },
        ));
    final wireError = _formatErrorMessage(() => ExecutionPlan.fromWire({
          'version': 1,
          'id': 'invalid-operation-name',
          'start': 'operation',
          'nodes': {
            'operation': {
              'type': 'operation',
              'id': 'operation',
              'next': 'end',
              'operation': {
                'id': 'operation',
                'name': ' tap ',
                'kind': 'interaction',
                'handlerKey': 'ui.tap',
                'input': <String, Object?>{},
                'source': {'path': 'case.yaml', 'stepPath': 'steps[0]'},
              },
            },
            'end': {'type': 'end', 'id': 'end'},
          },
        }));

    expect(directError, contains('Operation name in node "operation"'));
    expect(wireError, directError);
  });

  test('direct and wire plans reject padded destinations on every edge', () {
    final operation = TestOperation(
      id: 'node',
      name: 'tap',
      kind: OperationKind.interaction,
      handlerKey: 'interaction.tap',
      input: {},
      source: SourceLocation('case.yaml', 'steps[0]'),
    );
    final wireOperation = {
      'id': 'node',
      'name': 'tap',
      'kind': 'interaction',
      'handlerKey': 'interaction.tap',
      'input': <String, Object?>{},
      'source': {'path': 'case.yaml', 'stepPath': 'steps[0]'},
    };
    PlanNode directNode(String type, String edge) => switch (type) {
          'operation' => OperationNode(
              'node',
              operation,
              edge == 'next' ? ' end ' : 'end',
              onFailure: edge == 'onFailure' ? ' end ' : null,
            ),
          'branch' => BranchNode(
              'node',
              target: const {'id': 'target'},
              whenVisible: edge == 'whenVisible' ? ' end ' : 'end',
              whenHidden: edge == 'whenHidden' ? ' end ' : 'end',
              onFailure: edge == 'onFailure' ? ' end ' : null,
            ),
          'loop' => LoopNode(
              'node',
              times: 2,
              body: edge == 'body' ? ' end ' : 'end',
              next: edge == 'next' ? ' end ' : 'end',
            ),
          'recovery' => RecoveryNode(
              'node',
              next: ' end ',
              resetLoops: const {},
            ),
          'stepBoundary' => const StepBoundaryNode(
              'node',
              stepIndex: 0,
              started: true,
              next: ' end ',
            ),
          _ => throw StateError('Unknown edge owner "$type".'),
        };
    Map<String, Object?> wireNode(String type, String edge) => switch (type) {
          'operation' => {
              'type': type,
              'id': 'node',
              'next': edge == 'next' ? ' end ' : 'end',
              if (edge == 'onFailure') 'onFailure': ' end ',
              'operation': wireOperation,
            },
          'branch' => {
              'type': type,
              'id': 'node',
              'target': {'id': 'target'},
              'whenVisible': edge == 'whenVisible' ? ' end ' : 'end',
              'whenHidden': edge == 'whenHidden' ? ' end ' : 'end',
              if (edge == 'onFailure') 'onFailure': ' end ',
            },
          'loop' => {
              'type': type,
              'id': 'node',
              'times': 2,
              'body': edge == 'body' ? ' end ' : 'end',
              'next': edge == 'next' ? ' end ' : 'end',
            },
          'recovery' => {
              'type': type,
              'id': 'node',
              'next': ' end ',
              'resetLoops': <String>[],
            },
          'stepBoundary' => {
              'type': type,
              'id': 'node',
              'stepIndex': 0,
              'started': true,
              'next': ' end ',
            },
          _ => throw StateError('Unknown edge owner "$type".'),
        };
    const edges = <(String, String)>[
      ('operation', 'next'),
      ('operation', 'onFailure'),
      ('branch', 'whenVisible'),
      ('branch', 'whenHidden'),
      ('branch', 'onFailure'),
      ('loop', 'body'),
      ('loop', 'next'),
      ('recovery', 'next'),
      ('stepBoundary', 'next'),
    ];

    for (final (type, edge) in edges) {
      final directError = _formatErrorMessage(() => ExecutionPlan(
            id: 'invalid-$type-$edge',
            start: 'node',
            nodes: {
              'node': directNode(type, edge),
              'end': const EndNode('end'),
            },
          ));
      final wireError = _formatErrorMessage(() => ExecutionPlan.fromWire({
            'version': 1,
            'id': 'invalid-$type-$edge',
            'start': 'node',
            'nodes': {
              'node': wireNode(type, edge),
              'end': {'type': 'end', 'id': 'end'},
            },
          }));

      expect(directError, contains('Destination from node "node"'),
          reason: '$type.$edge');
      expect(directError, contains('surrounding whitespace'),
          reason: '$type.$edge');
      expect(wireError, directError, reason: '$type.$edge');
    }
  });

  test('rejects empty operation dispatch metadata before runtime execution',
      () {
    final cases = <String, TestOperation>{
      'operation name': TestOperation(
        id: 'operation',
        name: ' ',
        kind: OperationKind.interaction,
        handlerKey: 'interaction.tap',
        input: const {},
        source: const SourceLocation('case.yaml', 'steps[0]'),
      ),
      'handler key': TestOperation(
        id: 'operation',
        name: 'tap',
        kind: OperationKind.interaction,
        handlerKey: ' ',
        input: const {},
        source: const SourceLocation('case.yaml', 'steps[0]'),
      ),
    };

    for (final entry in cases.entries) {
      expect(
        () => ExecutionPlan(id: entry.key, start: 'operation', nodes: {
          'operation': OperationNode(entry.value.id, entry.value, 'end'),
          'end': const EndNode('end'),
        }),
        throwsFormatException,
        reason: entry.key,
      );
    }
  });
}

String _formatErrorMessage(void Function() action) {
  try {
    action();
  } on FormatException catch (error) {
    return error.message;
  }
  throw StateError('Expected malformed plan to throw FormatException.');
}
