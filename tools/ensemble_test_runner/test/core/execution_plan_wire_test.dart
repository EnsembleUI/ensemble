import 'dart:convert';

import 'package:ensemble_test_runner/src/core/operation.dart';
import 'package:ensemble_test_runner/src/core/plan.dart';
import 'package:ensemble_test_runner/src/core/plan_wire_transport.dart';
import 'package:ensemble_test_runner/src/runtime/plan_batch_wire_transport.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round-trips every plan node through a JSON process boundary', () {
    final original = _plan();

    final encoded = jsonEncode(original.toWire());
    final restored = ExecutionPlan.fromWire(
      Map<String, Object?>.from(jsonDecode(encoded) as Map),
    );

    expect(restored.toWire(), equals(original.toWire()));
    expect(restored.node('operation'), isA<OperationNode>());
    final operation = restored.node('operation') as OperationNode;
    expect(operation.operation.source.toString(), 'login.yaml:steps[0]');
    expect(operation.operation.input, {
      'target': {'id': 'login'},
      'attempts': [1, 2],
    });
  });

  test('wire output is stable for equivalent node map insertion orders', () {
    final original = _plan();
    final reorderedNodes = Map<String, PlanNode>.fromEntries(
      original.nodes.entries.toList().reversed,
    );
    final reordered = ExecutionPlan(
      id: original.id,
      start: original.start,
      nodes: reorderedNodes,
    );

    final reorderedWire = original.toWire();
    final originalWireNodes = reorderedWire['nodes']! as Map<String, Object?>;
    reorderedWire['nodes'] = Map<String, Object?>.fromEntries(
      originalWireNodes.entries.toList().reversed,
    );
    final decodedReordered = ExecutionPlan.fromWire(reorderedWire);

    expect(jsonEncode(reordered.toWire()), jsonEncode(original.toWire()));
    expect(
      jsonEncode(decodedReordered.toWire()),
      jsonEncode(original.toWire()),
    );
  });

  test('rejects non-string keys in nested operation input maps', () {
    expect(
      () => TestOperation(
        id: 'operation',
        name: 'httpRequest',
        kind: OperationKind.interaction,
        handlerKey: 'http.request.direct',
        input: {
          'body': {1: 'numeric key', '1': 'string key'},
        },
        source: const SourceLocation('case', 'steps[0]'),
      ),
      throwsA(isA<ArgumentError>().having(
        (error) => error.message,
        'message',
        contains('Operation inputs must use string map keys.'),
      )),
    );
  });

  test('rejects malformed wire data before runtime execution', () {
    expect(
      () => ExecutionPlan.fromWire({
        'version': 1,
        'id': 'invalid',
        'start': 'end',
        'nodes': {
          'end': {'type': 'unknown', 'id': 'end'},
        },
      }),
      throwsFormatException,
    );

    expect(
      () => ExecutionPlan.fromWire({
        'version': 1,
        'id': 'invalid-edge',
        'start': 'operation',
        'nodes': {
          'operation': {
            'type': 'operation',
            'id': 'operation',
            'next': 'missing',
            'operation': {
              'id': 'operation',
              'name': 'tap',
              'handlerKey': 'interaction.tap',
              'kind': 'interaction',
              'input': {},
              'source': {'path': 'test.yaml', 'stepPath': 'steps[0]'},
            },
          },
          'end': {'type': 'end', 'id': 'end'},
        },
      }),
      throwsFormatException,
    );

    expect(
      () => ExecutionPlan.fromWire({
        'version': 1,
        'id': 'operation-id-drift',
        'start': 'operation',
        'nodes': {
          'operation': {
            'type': 'operation',
            'id': 'operation',
            'next': 'end',
            'operation': {
              'id': 'different-operation',
              'name': 'tap',
              'handlerKey': 'interaction.tap',
              'kind': 'interaction',
              'input': {},
              'source': {'path': 'test.yaml', 'stepPath': 'steps[0]'},
            },
          },
          'end': {'type': 'end', 'id': 'end'},
        },
      }),
      throwsFormatException,
    );
  });

  test('requires an integer wire version for plans and batches', () {
    final planWire = _plan().toWire()..['version'] = 1.0;
    expect(() => ExecutionPlan.fromWire(planWire), throwsFormatException);

    final planPayload =
        base64Url.encode(utf8.encode(jsonEncode(planWire))).replaceAll('=', '');
    expect(
      () => ExecutionPlanWireTransport.decode(planPayload),
      throwsFormatException,
    );

    final batchWire = {
      'version': 1.0,
      'plans': {'wire-plan': _plan().toWire()},
    };
    final batchPayload = base64Url
        .encode(utf8.encode(jsonEncode(batchWire)))
        .replaceAll('=', '');
    expect(
      () => ExecutionPlanBatchWireTransport.decode(batchPayload),
      throwsFormatException,
    );
  });

  test('rejects empty operation dispatch metadata on wire decode', () {
    for (final field in ['name', 'handlerKey']) {
      final wire = _plan().toWire();
      final nodes = wire['nodes']! as Map<String, Object?>;
      final operationNode = nodes['operation']! as Map<String, Object?>;
      final operation = operationNode['operation']! as Map<String, Object?>;
      operation[field] = ' ';

      expect(
        () => ExecutionPlan.fromWire(wire),
        throwsFormatException,
        reason: field,
      );
    }
  });

  test('rejects compiled wire operations without a dispatch key', () {
    final wire = _plan().toWire();
    final nodes = wire['nodes']! as Map<String, Object?>;
    final operationNode = nodes['operation']! as Map<String, Object?>;
    final operation = operationNode['operation']! as Map<String, Object?>;
    operation.remove('handlerKey');

    expect(() => ExecutionPlan.fromWire(wire), throwsFormatException);
  });

  test('rejects the retired flattened operation payload shape', () {
    final wire = _plan().toWire();
    final nodes = wire['nodes']! as Map<String, Object?>;
    final operationNode = nodes['operation']! as Map<String, Object?>;
    final operation = operationNode.remove('operation')! as Map;
    operationNode.addAll(Map<String, Object?>.from(operation));

    expect(
      () => ExecutionPlan.fromWire(wire),
      throwsFormatException,
    );
  });

  test('rejects every missing control-flow destination after wire decode', () {
    final operation = {
      'id': 'operation',
      'name': 'tap',
      'handlerKey': 'interaction.tap',
      'kind': 'interaction',
      'input': <String, Object?>{},
      'source': {'path': 'case.yaml', 'stepPath': 'steps[0]'},
    };
    final cases = <String, Map<String, Object?>>{
      'operation continuation': {
        'type': 'operation',
        'id': 'operation',
        'next': 'missing',
        'operation': operation,
      },
      'operation failure': {
        'type': 'operation',
        'id': 'operation',
        'next': 'end',
        'onFailure': 'missing',
        'operation': operation,
      },
      'visible branch': {
        'type': 'branch',
        'id': 'branch',
        'target': {'id': 'target'},
        'whenVisible': 'missing',
        'whenHidden': 'end',
      },
      'hidden branch': {
        'type': 'branch',
        'id': 'branch',
        'target': {'id': 'target'},
        'whenVisible': 'end',
        'whenHidden': 'missing',
      },
      'branch failure': {
        'type': 'branch',
        'id': 'branch',
        'target': {'id': 'target'},
        'whenVisible': 'end',
        'whenHidden': 'end',
        'onFailure': 'missing',
      },
      'loop body': {
        'type': 'loop',
        'id': 'loop',
        'times': 2,
        'body': 'missing',
        'next': 'end',
      },
      'loop continuation': {
        'type': 'loop',
        'id': 'loop',
        'times': 2,
        'body': 'end',
        'next': 'missing',
      },
      'recovery continuation': {
        'type': 'recovery',
        'id': 'recovery',
        'next': 'missing',
        'resetLoops': <String>[],
      },
      'step boundary continuation': {
        'type': 'stepBoundary',
        'id': 'boundary',
        'stepIndex': 0,
        'started': true,
        'next': 'missing',
      },
    };

    for (final entry in cases.entries) {
      final node = entry.value;
      final id = node['id']! as String;
      expect(
        () => ExecutionPlan.fromWire({
          'version': 1,
          'id': entry.key,
          'start': id,
          'nodes': {
            id: node,
            'end': {'type': 'end', 'id': 'end'},
          },
        }),
        throwsA(isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('points to missing "missing"'),
        )),
        reason: entry.key,
      );
    }
  });

  test('rejects an unbounded cycle identically before and after wire decode',
      () {
    final operation = TestOperation(
      id: 'operation',
      name: 'tap',
      kind: OperationKind.interaction,
      handlerKey: 'interaction.tap',
      input: const {},
      source: const SourceLocation('case.test', 'steps[0]'),
    );
    final directError = _formatErrorMessage(() => ExecutionPlan(
          id: 'cycle',
          start: 'branch',
          nodes: {
            'branch': BranchNode(
              'branch',
              target: const {'id': 'target'},
              whenVisible: 'operation',
              whenHidden: 'end',
            ),
            'operation': OperationNode(operation.id, operation, 'branch'),
            'end': const EndNode('end'),
          },
        ));
    final wireError = _formatErrorMessage(() => ExecutionPlan.fromWire({
          'version': 1,
          'id': 'cycle',
          'start': 'branch',
          'nodes': {
            'branch': {
              'type': 'branch',
              'id': 'branch',
              'target': {'id': 'target'},
              'whenVisible': 'operation',
              'whenHidden': 'end',
            },
            'operation': {
              'type': 'operation',
              'id': 'operation',
              'next': 'branch',
              'operation': {
                'id': 'operation',
                'name': 'tap',
                'handlerKey': 'interaction.tap',
                'kind': 'interaction',
                'input': {},
                'source': {'path': 'case.test', 'stepPath': 'steps[0]'},
              },
            },
            'end': {'type': 'end', 'id': 'end'},
          },
        }));

    expect(directError, contains('cycle outside a loop iteration'));
    expect(wireError, directError);
  });

  test('rejects cycles through nested recovery edges identically on the wire',
      () {
    final operation = TestOperation(
      id: 'operation',
      name: 'tap',
      kind: OperationKind.interaction,
      handlerKey: 'interaction.tap',
      input: const {},
      source: const SourceLocation('case.test', 'steps[0]'),
    );
    final cases = <String,
        ({
      String start,
      Map<String, PlanNode> nodes,
      Map<String, Object?> wireNodes
    })>{
      'operation failure': (
        start: 'branch',
        nodes: {
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
        wireNodes: {
          'branch': {
            'type': 'branch',
            'id': 'branch',
            'target': {'id': 'target'},
            'whenVisible': 'operation',
            'whenHidden': 'end',
          },
          'operation': {
            'type': 'operation',
            'id': 'operation',
            'next': 'end',
            'onFailure': 'branch',
            'operation': {
              'id': 'operation',
              'name': 'tap',
              'handlerKey': 'interaction.tap',
              'kind': 'interaction',
              'input': {},
              'source': {'path': 'case.test', 'stepPath': 'steps[0]'},
            },
          },
          'end': {'type': 'end', 'id': 'end'},
        },
      ),
      'recovery continuation': (
        start: 'branch',
        nodes: {
          'branch': BranchNode(
            'branch',
            target: const {'id': 'target'},
            whenVisible: 'recovery',
            whenHidden: 'end',
          ),
          'recovery': RecoveryNode(
            'recovery',
            next: 'branch',
            resetLoops: const [],
          ),
          'end': const EndNode('end'),
        },
        wireNodes: {
          'branch': {
            'type': 'branch',
            'id': 'branch',
            'target': {'id': 'target'},
            'whenVisible': 'recovery',
            'whenHidden': 'end',
          },
          'recovery': {
            'type': 'recovery',
            'id': 'recovery',
            'next': 'branch',
            'resetLoops': <String>[],
          },
          'end': {'type': 'end', 'id': 'end'},
        },
      ),
      'step boundary continuation': (
        start: 'branch',
        nodes: {
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
        wireNodes: {
          'branch': {
            'type': 'branch',
            'id': 'branch',
            'target': {'id': 'target'},
            'whenVisible': 'boundary',
            'whenHidden': 'end',
          },
          'boundary': {
            'type': 'stepBoundary',
            'id': 'boundary',
            'stepIndex': 0,
            'started': true,
            'next': 'branch',
          },
          'end': {'type': 'end', 'id': 'end'},
        },
      ),
      'branch failure': (
        start: 'branch',
        nodes: {
          'branch': BranchNode(
            'branch',
            target: const {'id': 'target'},
            whenVisible: 'end',
            whenHidden: 'end',
            onFailure: 'branch',
          ),
          'end': const EndNode('end'),
        },
        wireNodes: {
          'branch': {
            'type': 'branch',
            'id': 'branch',
            'target': {'id': 'target'},
            'whenVisible': 'end',
            'whenHidden': 'end',
            'onFailure': 'branch',
          },
          'end': {'type': 'end', 'id': 'end'},
        },
      ),
    };

    for (final entry in cases.entries) {
      final directError = _formatErrorMessage(() => ExecutionPlan(
            id: entry.key,
            start: entry.value.start,
            nodes: entry.value.nodes,
          ));
      final wireError = _formatErrorMessage(() => ExecutionPlan.fromWire({
            'version': 1,
            'id': entry.key,
            'start': entry.value.start,
            'nodes': entry.value.wireNodes,
          }));

      expect(directError, contains('cycle outside a loop iteration'),
          reason: entry.key);
      expect(wireError, directError, reason: entry.key);
    }
  });

  test('matches direct and wire diagnostics for scalar graph invariants', () {
    final operation = TestOperation(
      id: 'operation',
      name: 'tap',
      kind: OperationKind.interaction,
      handlerKey: 'interaction.tap',
      input: const {},
      source: const SourceLocation('case.test', 'steps[0]'),
    );
    final cases = <String,
        ({
      String start,
      Map<String, PlanNode> nodes,
      Map<String, Object?> wireNodes
    })>{
      'negative loop count': (
        start: 'loop',
        nodes: {
          'loop': const LoopNode(
            'loop',
            times: -1,
            body: 'operation',
            next: 'end',
          ),
          'operation': OperationNode(operation.id, operation, 'loop'),
          'end': const EndNode('end'),
        },
        wireNodes: {
          'loop': {
            'type': 'loop',
            'id': 'loop',
            'times': -1,
            'body': 'operation',
            'next': 'end',
          },
          'operation': {
            'type': 'operation',
            'id': 'operation',
            'next': 'loop',
            'operation': {
              'id': 'operation',
              'name': 'tap',
              'handlerKey': 'interaction.tap',
              'kind': 'interaction',
              'input': {},
              'source': {'path': 'case.test', 'stepPath': 'steps[0]'},
            },
          },
          'end': {'type': 'end', 'id': 'end'},
        },
      ),
      'negative step boundary index': (
        start: 'boundary',
        nodes: {
          'boundary': const StepBoundaryNode(
            'boundary',
            stepIndex: -1,
            started: true,
            next: 'end',
          ),
          'end': const EndNode('end'),
        },
        wireNodes: {
          'boundary': {
            'type': 'stepBoundary',
            'id': 'boundary',
            'stepIndex': -1,
            'started': true,
            'next': 'end',
          },
          'end': {'type': 'end', 'id': 'end'},
        },
      ),
      'operation identity drift': (
        start: 'operation',
        nodes: {
          'operation': OperationNode(
            'operation',
            TestOperation(
              id: 'different-operation',
              name: 'tap',
              kind: OperationKind.interaction,
              handlerKey: 'interaction.tap',
              input: const {},
              source: const SourceLocation('case.test', 'steps[0]'),
            ),
            'end',
          ),
          'end': const EndNode('end'),
        },
        wireNodes: {
          'operation': {
            'type': 'operation',
            'id': 'operation',
            'next': 'end',
            'operation': {
              'id': 'different-operation',
              'name': 'tap',
              'handlerKey': 'interaction.tap',
              'kind': 'interaction',
              'input': {},
              'source': {'path': 'case.test', 'stepPath': 'steps[0]'},
            },
          },
          'end': {'type': 'end', 'id': 'end'},
        },
      ),
      'unreachable node': (
        start: 'end',
        nodes: {
          'end': const EndNode('end'),
          'orphan': const EndNode('orphan'),
        },
        wireNodes: {
          'end': {'type': 'end', 'id': 'end'},
          'orphan': {'type': 'end', 'id': 'orphan'},
        },
      ),
    };

    for (final entry in cases.entries) {
      final directError = _formatErrorMessage(() => ExecutionPlan(
            id: entry.key,
            start: entry.value.start,
            nodes: entry.value.nodes,
          ));
      final wireError = _formatErrorMessage(() => ExecutionPlan.fromWire({
            'version': 1,
            'id': entry.key,
            'start': entry.value.start,
            'nodes': entry.value.wireNodes,
          }));

      expect(wireError, directError, reason: entry.key);
    }
  });

  test('matches direct and wire diagnostics for graph container invariants',
      () {
    final cases = <String,
        ({
      String start,
      Map<String, PlanNode> nodes,
      Map<String, Object?> wireNodes,
    })>{
      'unknown start node': (
        start: 'missing',
        nodes: {'end': const EndNode('end')},
        wireNodes: {
          'end': {'type': 'end', 'id': 'end'},
        },
      ),
      'missing end node': (
        start: 'boundary',
        nodes: {
          'boundary': const StepBoundaryNode(
            'boundary',
            stepIndex: 0,
            started: true,
            next: 'boundary',
          ),
        },
        wireNodes: {
          'boundary': {
            'type': 'stepBoundary',
            'id': 'boundary',
            'stepIndex': 0,
            'started': true,
            'next': 'boundary',
          },
        },
      ),
      'node map key and id mismatch': (
        start: 'boundary',
        nodes: {
          'boundary': const StepBoundaryNode(
            'other',
            stepIndex: 0,
            started: true,
            next: 'end',
          ),
          'end': const EndNode('end'),
        },
        wireNodes: {
          'boundary': {
            'type': 'stepBoundary',
            'id': 'other',
            'stepIndex': 0,
            'started': true,
            'next': 'end',
          },
          'end': {'type': 'end', 'id': 'end'},
        },
      ),
    };

    for (final entry in cases.entries) {
      final directError = _formatErrorMessage(() => ExecutionPlan(
            id: entry.key,
            start: entry.value.start,
            nodes: entry.value.nodes,
          ));
      final wireError = _formatErrorMessage(() => ExecutionPlan.fromWire({
            'version': 1,
            'id': entry.key,
            'start': entry.value.start,
            'nodes': entry.value.wireNodes,
          }));

      expect(wireError, directError, reason: entry.key);
    }
  });

  test('transports a compiled plan through a URL-safe process payload', () {
    final original = _plan();
    final payload = ExecutionPlanWireTransport.encode(original);

    expect(payload, isNot(contains('=')));
    expect(
      ExecutionPlanWireTransport.decode(payload).toWire(),
      equals(original.toWire()),
    );
  });

  test('rejects empty, invalid, and oversized transport payloads', () {
    expect(
      () => ExecutionPlanWireTransport.decode(''),
      throwsFormatException,
    );
    expect(
      () => ExecutionPlanWireTransport.decode('not-base64'),
      throwsFormatException,
    );
    expect(
      () => ExecutionPlanWireTransport.decode(
        base64Url.encode(List<int>.filled(
          ExecutionPlanWireTransport.maxPayloadBytes + 1,
          65,
        )),
      ),
      throwsFormatException,
    );
  });

  test('round-trips a worker batch with selection identity', () {
    final first = _plan();
    final second = _planWithId('second-plan');
    final payload = ExecutionPlanBatchWireTransport.encode({
      first.id: first,
      second.id: second,
    });

    final decoded = ExecutionPlanBatchWireTransport.decode(payload);
    expect(decoded.keys, containsAll(<String>[first.id, second.id]));
    expect(decoded[first.id]!.toWire(), equals(first.toWire()));
    expect(decoded[second.id]!.toWire(), equals(second.toWire()));
  });

  test('rejects pre-compression worker batches', () {
    final rawBatch = jsonEncode({
      'version': 1,
      'plans': {'wire-plan': _plan().toWire()},
    });
    final payload = base64Url.encode(utf8.encode(rawBatch)).replaceAll('=', '');

    expect(
      () => ExecutionPlanBatchWireTransport.decode(payload),
      throwsFormatException,
    );
  });

  test('compresses and round-trips a batch larger than the legacy 4 MiB cap',
      () {
    final repeatedInput = 'shared operation metadata ' * 3200;
    final plans = <String, ExecutionPlan>{
      for (var index = 0; index < 70; index++)
        'large-$index': _planWithInput('large-$index', repeatedInput),
    };
    final rawBatch = jsonEncode({
      'version': 1,
      'plans': {
        for (final entry in plans.entries) entry.key: entry.value.toWire()
      },
    });

    expect(utf8.encode(rawBatch).length, greaterThan(4 * 1024 * 1024));
    final payload = ExecutionPlanBatchWireTransport.encode(plans);
    final decoded = ExecutionPlanBatchWireTransport.decode(payload);

    expect(decoded.keys, plans.keys);
    expect(decoded['large-69']!.toWire(), plans['large-69']!.toWire());
  });

  test('rejects a batch whose producer key differs from the plan id', () {
    expect(
      () => ExecutionPlanBatchWireTransport.encode({'wrong': _plan()}),
      throwsFormatException,
    );
  });

  test('rejects a batch whose consumer key differs from the plan id', () {
    final wire = {
      'version': 1,
      'plans': {'wrong': _plan().toWire()},
    };
    final payload =
        base64Url.encode(utf8.encode(jsonEncode(wire))).replaceAll('=', '');
    expect(
      () => ExecutionPlanBatchWireTransport.decode(payload),
      throwsFormatException,
    );
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

ExecutionPlan _plan() => ExecutionPlan(
      id: 'wire-plan',
      start: 'boundary',
      nodes: {
        'boundary': const StepBoundaryNode(
          'boundary',
          stepIndex: 0,
          started: true,
          next: 'operation',
        ),
        'operation': OperationNode(
          'operation',
          TestOperation(
            id: 'operation',
            name: 'tap',
            kind: OperationKind.interaction,
            handlerKey: 'interaction.tap',
            input: {
              'target': {'id': 'login'},
              'attempts': [1, 2],
            },
            source: const SourceLocation('login.yaml', 'steps[0]'),
          ),
          'branch',
          onFailure: 'recovery',
        ),
        'branch': BranchNode(
          'branch',
          target: const {'id': 'welcome'},
          whenVisible: 'loop',
          whenHidden: 'recovery',
          onFailure: 'recovery',
        ),
        'loop': const LoopNode(
          'loop',
          times: 2,
          body: 'loop-operation',
          next: 'recovery',
        ),
        'loop-operation': OperationNode(
          'loop-operation',
          TestOperation(
            id: 'loop-operation',
            name: 'expectVisible',
            kind: OperationKind.assertion,
            handlerKey: 'expectVisible',
            input: const {'target': 'welcome'},
            source: const SourceLocation('login.yaml', 'steps[1]'),
          ),
          'loop',
        ),
        'recovery': RecoveryNode(
          'recovery',
          next: 'end',
          resetLoops: const {'loop'},
        ),
        'end': const EndNode('end'),
      },
    );

ExecutionPlan _planWithId(String id) => ExecutionPlan(
      id: id,
      start: 'end',
      nodes: {'end': EndNode('end')},
    );

ExecutionPlan _planWithInput(String id, String repeatedInput) => ExecutionPlan(
      id: id,
      start: 'operation',
      nodes: {
        'operation': OperationNode(
          'operation',
          TestOperation(
            id: 'operation',
            name: 'expectText',
            kind: OperationKind.assertion,
            handlerKey: 'assertion.text',
            input: {'text': repeatedInput},
            source: const SourceLocation('large.test', 'steps[0]'),
          ),
          'end',
        ),
        'end': const EndNode('end'),
      },
    );
