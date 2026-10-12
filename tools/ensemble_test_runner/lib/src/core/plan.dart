import 'dart:collection';

import 'operation.dart';

sealed class PlanNode {
  const PlanNode(this.id);

  final String id;
}

final class OperationNode extends PlanNode {
  const OperationNode(super.id, this.operation, this.next, {this.onFailure});

  final TestOperation operation;
  final String next;

  /// Recovery edge for an optional block. A failed operation remains an event.
  final String? onFailure;
}

final class BranchNode extends PlanNode {
  BranchNode(
    super.id, {
    required Map<String, Object?> target,
    required this.whenVisible,
    required this.whenHidden,
    this.onFailure,
    this.source,
  }) : target = freezeInput(target);

  final Map<String, Object?> target;
  final String whenVisible;
  final String whenHidden;
  final String? onFailure;
  final SourceLocation? source;
}

final class LoopNode extends PlanNode {
  const LoopNode(
    super.id, {
    required this.times,
    required this.body,
    required this.next,
  });

  final int times;
  final String body;
  final String next;
}

/// Exits an optional block after a recoverable operation failure.
final class RecoveryNode extends PlanNode {
  RecoveryNode(
    super.id, {
    required this.next,
    required Iterable<String> resetLoops,
  }) : resetLoops = Set.unmodifiable(resetLoops);

  final String next;
  final Set<String> resetLoops;
}

final class EndNode extends PlanNode {
  const EndNode(super.id);
}

/// Marks the boundary of one authored top-level test step for reporting.
final class StepBoundaryNode extends PlanNode {
  const StepBoundaryNode(
    super.id, {
    required this.stepIndex,
    required this.started,
    required this.next,
  });

  final int stepIndex;
  final bool started;
  final String next;
}

/// Immutable, validated graph produced before an application is launched.
final class ExecutionPlan {
  ExecutionPlan({
    required this.id,
    required this.start,
    required Map<String, PlanNode> nodes,
  }) : nodes = UnmodifiableMapView(Map.of(nodes)) {
    _validateIdentity(id, 'Plan id');
    _validateIdentity(start, 'Plan start node id');
    if (!this.nodes.containsKey(start)) {
      throw FormatException('Plan "$id" has no start node "$start".');
    }
    if (!this.nodes.values.any((node) => node is EndNode)) {
      throw FormatException('Plan "$id" has no end node.');
    }
    final incoming = <String, int>{
      for (final nodeId in this.nodes.keys) nodeId: 0,
    };
    for (final entry in this.nodes.entries) {
      _validateIdentity(entry.key, 'Plan node id');
      _validateIdentity(entry.value.id, 'Plan node id');
      if (entry.key != entry.value.id) {
        throw FormatException(
            'Plan node key "${entry.key}" does not match id.');
      }
      final node = entry.value;
      if (node case OperationNode(:final operation)
          when operation.id != node.id) {
        throw FormatException(
          'Operation node "${node.id}" contains operation '
          '"${operation.id}".',
        );
      }
      if (node case OperationNode(:final operation)) {
        _validateIdentity(operation.id, 'Operation id in node "${node.id}"');
        _validateIdentity(
          operation.name,
          'Operation name in node "${node.id}"',
        );
      }
      if (node case OperationNode(:final operation)) {
        _validateIdentity(
          operation.handlerKey,
          'Handler key in node "${node.id}"',
        );
      }
      if (node case StepBoundaryNode(:final stepIndex) when stepIndex < 0) {
        throw FormatException(
          'Step boundary "${node.id}" has negative step index $stepIndex.',
        );
      }
      final edges = switch (node) {
        OperationNode(:final next, :final onFailure) => [
            next,
            if (onFailure != null) onFailure,
          ],
        BranchNode(:final whenVisible, :final whenHidden, :final onFailure) => [
            whenVisible,
            whenHidden,
            if (onFailure != null) onFailure,
          ],
        LoopNode(:final body, :final next) => [body, next],
        RecoveryNode(:final next) => [next],
        StepBoundaryNode(:final next) => [next],
        EndNode() => const <String>[],
      };
      for (final edge in edges) {
        _validateIdentity(edge, 'Destination from node "${node.id}"');
        if (!this.nodes.containsKey(edge)) {
          throw FormatException('Node "${node.id}" points to missing "$edge".');
        }
        // Loop body edges are bounded iteration edges, not control-flow cycles
        // that can bypass the kernel's loop counter.
        if (node is! LoopNode || edge != node.body) {
          incoming[edge] = incoming[edge]! + 1;
        }
      }
      if (node is LoopNode && node.times < 0) {
        throw FormatException('Loop "${node.id}" has negative repeat count.');
      }
      if (node case LoopNode(:final body, :final next) when body == next) {
        throw FormatException(
          'Loop "${node.id}" has identical body and continuation "$body".',
        );
      }
      if (node is RecoveryNode) {
        for (final loopId in node.resetLoops) {
          if (this.nodes[loopId] is! LoopNode) {
            throw FormatException(
                'Recovery "${node.id}" references non-loop "$loopId".');
          }
        }
      }
    }
    for (final recovery in this.nodes.values.whereType<RecoveryNode>()) {
      for (final loopId in recovery.resetLoops) {
        if (_continuationContainsLoop(recovery.next, loopId)) {
          throw FormatException(
            'Recovery "${recovery.id}" resets enclosing loop "$loopId".',
          );
        }
      }
    }
    final reachable = <String>{};
    final pending = <String>[start];
    while (pending.isNotEmpty) {
      final id = pending.removeLast();
      if (!reachable.add(id)) continue;
      final node = this.nodes[id]!;
      switch (node) {
        case OperationNode(:final next, :final onFailure):
          pending.add(next);
          if (onFailure != null) pending.add(onFailure);
        case BranchNode(
            :final whenVisible,
            :final whenHidden,
            :final onFailure
          ):
          pending
            ..add(whenVisible)
            ..add(whenHidden);
          if (onFailure != null) pending.add(onFailure);
        case LoopNode(:final body, :final next):
          pending
            ..add(body)
            ..add(next);
        case RecoveryNode(:final next):
          pending.add(next);
        case StepBoundaryNode(:final next):
          pending.add(next);
        case EndNode():
          break;
      }
    }
    final unreachable = this.nodes.keys.toSet()..removeAll(reachable);
    if (unreachable.isNotEmpty) {
      throw FormatException(
        'Plan "$id" contains unreachable nodes: ${unreachable.join(', ')}.',
      );
    }
    for (final node in this.nodes.values.whereType<LoopNode>()) {
      if (!_loopBodyAlwaysReturnsTo(node.body, node.id, node.next)) {
        throw FormatException(
          'Loop "${node.id}" has a body path that exits without a loop '
          'iteration or scoped recovery.',
        );
      }
    }
    _validateStructuredCycles(id, reachable, incoming);
  }

  bool _loopBodyAlwaysReturnsTo(
    String bodyId,
    String loopId,
    String loopNext,
  ) {
    final visited = <String>{};
    final pending = <String>[bodyId];
    var returnsToLoop = false;
    while (pending.isNotEmpty) {
      final nodeId = pending.removeLast();
      if (nodeId == loopId) {
        returnsToLoop = true;
        continue;
      }
      if (!visited.add(nodeId)) continue;
      switch (nodes[nodeId]!) {
        case OperationNode(:final next, :final onFailure):
          pending.add(next);
          if (onFailure != null) pending.add(onFailure);
        case BranchNode(
            :final whenVisible,
            :final whenHidden,
            :final onFailure
          ):
          pending
            ..add(whenVisible)
            ..add(whenHidden);
          if (onFailure != null) pending.add(onFailure);
        // A nested loop has its own invariant checked separately. At this
        // level its bounded execution eventually continues at `next`.
        case LoopNode(:final next):
          pending.add(next);
        case RecoveryNode(:final id, :final next, :final resetLoops):
          // Optional recovery is an authored escape from repeats compiled
          // inside that optional block. It is also used as a loop's normal
          // continuation when the optional block wraps the repeat.
          if (resetLoops.contains(loopId) || id == loopNext) {
            returnsToLoop = true;
          } else {
            pending.add(next);
          }
        case StepBoundaryNode(:final next):
          pending.add(next);
        case EndNode():
          return false;
      }
    }
    // A valid loop body has a route to its enclosing loop. Returning false
    // also rejects closed cycles, though the structured-cycle check reports
    // those with a more specific graph diagnostic.
    return returnsToLoop;
  }

  bool _continuationContainsLoop(String continuationId, String loopId) {
    final pending = <String>[continuationId];
    final visited = <String>{};
    while (pending.isNotEmpty) {
      final nodeId = pending.removeLast();
      if (nodeId == loopId) return true;
      if (!visited.add(nodeId)) continue;
      switch (nodes[nodeId]!) {
        case OperationNode(:final next):
          pending.add(next);
        case BranchNode(:final whenVisible, :final whenHidden):
          pending
            ..add(whenVisible)
            ..add(whenHidden);
        case LoopNode(:final next):
          pending.add(next);
        case RecoveryNode(:final next):
          pending.add(next);
        case StepBoundaryNode(:final next):
          pending.add(next);
        case EndNode():
          break;
      }
    }
    return false;
  }

  /// Loop nodes are the only nodes allowed to create a graph cycle: their
  /// body edge is revisited by the kernel's bounded loop counter. Removing
  /// those iteration edges must leave an acyclic control-flow graph. This
  /// rejects malformed wire graphs that could otherwise spin until a runtime
  /// budget is exhausted.
  void _validateStructuredCycles(
    String planId,
    Set<String> reachable,
    Map<String, int> incoming,
  ) {
    final ready = Queue<String>()
      ..addAll(incoming.entries
          .where((entry) => entry.value == 0)
          .map((entry) => entry.key));
    var visited = 0;
    void release(String edge) {
      final count = incoming[edge]! - 1;
      incoming[edge] = count;
      if (count == 0) ready.add(edge);
    }

    while (ready.isNotEmpty) {
      final nodeId = ready.removeFirst();
      visited++;
      switch (nodes[nodeId]!) {
        case OperationNode(:final next, :final onFailure):
          release(next);
          if (onFailure != null) release(onFailure);
        case BranchNode(
            :final whenVisible,
            :final whenHidden,
            :final onFailure
          ):
          release(whenVisible);
          release(whenHidden);
          if (onFailure != null) release(onFailure);
        case LoopNode(:final next):
          release(next);
        case RecoveryNode(:final next):
          release(next);
        case StepBoundaryNode(:final next):
          release(next);
        case EndNode():
          break;
      }
    }
    if (visited != reachable.length) {
      final cyclic = incoming.entries
          .where((entry) => entry.value > 0)
          .map((entry) => entry.key)
          .toList()
        ..sort();
      throw FormatException(
        'Plan "$planId" contains a cycle outside a loop iteration: '
        '${cyclic.join(', ')}.',
      );
    }
  }

  final String id;
  final String start;
  final Map<String, PlanNode> nodes;

  /// Stable, JSON-compatible representation for moving an already compiled
  /// plan across a process boundary. The runtime still validates the decoded
  /// graph before it can execute it.
  Map<String, Object?> toWire() => {
        'version': 1,
        'id': id,
        'start': start,
        'nodes': {
          for (final id in (nodes.keys.toList()..sort()))
            id: _nodeToWire(nodes[id]!),
        },
      };

  /// Restores a plan produced by [toWire]. This is intentionally separate
  /// from parsing: a worker receives an immutable execution graph, never a
  /// source document to interpret again.
  factory ExecutionPlan.fromWire(Map<String, Object?> wire) {
    const context = 'Execution plan wire format';
    final version = wire['version'];
    if (version is! int || version != 1) {
      throw FormatException('$context has unsupported version "$version".');
    }
    final encodedNodes = _map(wire['nodes'], '$context.nodes');
    final nodes = <String, PlanNode>{
      for (final entry in encodedNodes.entries)
        entry.key: _nodeFromWire(
          entry.key,
          _map(entry.value, '$context.nodes.${entry.key}'),
        ),
    };
    return ExecutionPlan(
      id: _string(wire['id'], '$context.id'),
      start: _string(wire['start'], '$context.start'),
      nodes: nodes,
    );
  }

  PlanNode node(String id) =>
      nodes[id] ??
      (throw FormatException('Plan "${this.id}" has no node "$id".'));
}

void _validateIdentity(String value, String context) {
  if (value.trim().isEmpty) {
    throw FormatException('$context must not be empty.');
  }
  if (value != value.trim()) {
    throw FormatException('$context must not have surrounding whitespace.');
  }
}

Map<String, Object?> _nodeToWire(PlanNode node) => switch (node) {
      OperationNode(
        :final id,
        :final operation,
        :final next,
        :final onFailure
      ) =>
        {
          'type': 'operation',
          'id': id,
          'next': next,
          if (onFailure != null) 'onFailure': onFailure,
          'operation': {
            'id': operation.id,
            'name': operation.name,
            'kind': operation.kind.name,
            'handlerKey': operation.handlerKey,
            'input': operation.input,
            'source': {
              'path': operation.source.path,
              'stepPath': operation.source.stepPath,
            },
          },
        },
      BranchNode(
        :final id,
        :final target,
        :final whenVisible,
        :final whenHidden,
        :final onFailure,
        :final source,
      ) =>
        {
          'type': 'branch',
          'id': id,
          'target': target,
          'whenVisible': whenVisible,
          'whenHidden': whenHidden,
          if (onFailure != null) 'onFailure': onFailure,
          if (source != null)
            'source': {'path': source.path, 'stepPath': source.stepPath},
        },
      LoopNode(:final id, :final times, :final body, :final next) => {
          'type': 'loop',
          'id': id,
          'times': times,
          'body': body,
          'next': next,
        },
      RecoveryNode(:final id, :final next, :final resetLoops) => {
          'type': 'recovery',
          'id': id,
          'next': next,
          'resetLoops': resetLoops.toList()..sort(),
        },
      EndNode(:final id) => {'type': 'end', 'id': id},
      StepBoundaryNode(
        :final id,
        :final stepIndex,
        :final started,
        :final next
      ) =>
        {
          'type': 'stepBoundary',
          'id': id,
          'stepIndex': stepIndex,
          'started': started,
          'next': next,
        },
    };

PlanNode _nodeFromWire(String key, Map<String, Object?> wire) {
  final context = 'Execution plan wire node "$key"';
  final id = _string(wire['id'], '$context.id');
  final type = _string(wire['type'], '$context.type');
  return switch (type) {
    'operation' => _operationNodeFromWire(id, wire, context),
    'branch' => BranchNode(
        id,
        target: _map(wire['target'], '$context.target'),
        whenVisible: _string(wire['whenVisible'], '$context.whenVisible'),
        whenHidden: _string(wire['whenHidden'], '$context.whenHidden'),
        onFailure: _optionalString(wire['onFailure'], '$context.onFailure'),
        source: _optionalSource(wire['source'], '$context.source'),
      ),
    'loop' => LoopNode(
        id,
        times: _int(wire['times'], '$context.times'),
        body: _string(wire['body'], '$context.body'),
        next: _string(wire['next'], '$context.next'),
      ),
    'recovery' => RecoveryNode(
        id,
        next: _string(wire['next'], '$context.next'),
        resetLoops: _strings(wire['resetLoops'], '$context.resetLoops'),
      ),
    'end' => EndNode(id),
    'stepBoundary' => StepBoundaryNode(
        id,
        stepIndex: _int(wire['stepIndex'], '$context.stepIndex'),
        started: _bool(wire['started'], '$context.started'),
        next: _string(wire['next'], '$context.next'),
      ),
    _ => throw FormatException('$context has unknown type "$type".'),
  };
}

SourceLocation? _optionalSource(Object? value, String context) {
  if (value == null) return null;
  final source = _map(value, context);
  return SourceLocation(
    _string(source['path'], '$context.path'),
    _string(source['stepPath'], '$context.stepPath'),
  );
}

OperationNode _operationNodeFromWire(
  String id,
  Map<String, Object?> wire,
  String context,
) {
  final operation = _map(wire['operation'], '$context.operation');
  final source = _map(operation['source'], '$context.operation.source');
  final kindName = _string(operation['kind'], '$context.operation.kind');
  final kind = OperationKind.values.where((kind) => kind.name == kindName);
  if (kind.length != 1) {
    throw FormatException('$context has unknown operation kind "$kindName".');
  }
  return OperationNode(
    id,
    TestOperation(
      id: _string(operation['id'], '$context.operation.id'),
      name: _string(operation['name'], '$context.operation.name'),
      kind: kind.single,
      handlerKey: _string(
        operation['handlerKey'],
        '$context.operation.handlerKey',
      ),
      input: _map(operation['input'], '$context.operation.input'),
      source: SourceLocation(
        _string(source['path'], '$context.operation.source.path'),
        _string(source['stepPath'], '$context.operation.source.stepPath'),
      ),
    ),
    _string(wire['next'], '$context.next'),
    onFailure: _optionalString(wire['onFailure'], '$context.onFailure'),
  );
}

Map<String, Object?> _map(Object? value, String context) {
  if (value is! Map) throw FormatException('$context must be an object.');
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw FormatException('$context has a non-string key.');
    }
    result[entry.key as String] = entry.value;
  }
  return result;
}

String _string(Object? value, String context) {
  if (value is! String) throw FormatException('$context must be a string.');
  return value;
}

String? _optionalString(Object? value, String context) {
  if (value == null) return null;
  return _string(value, context);
}

int _int(Object? value, String context) {
  if (value is! int) throw FormatException('$context must be an integer.');
  return value;
}

bool _bool(Object? value, String context) {
  if (value is! bool) throw FormatException('$context must be a boolean.');
  return value;
}

List<String> _strings(Object? value, String context) {
  if (value is! List) throw FormatException('$context must be a list.');
  return [
    for (var index = 0; index < value.length; index++)
      _string(value[index], '$context[$index]'),
  ];
}
