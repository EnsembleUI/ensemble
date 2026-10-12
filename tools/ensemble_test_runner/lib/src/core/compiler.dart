import 'operation.dart';
import 'operation_registry.dart';
import 'plan.dart';

/// Parser output normalized at the boundary before plan compilation.
final class PlanStep {
  PlanStep({
    required this.name,
    Map<String, Object?> input = const {},
    List<PlanStep> children = const [],
    required this.source,
  })  : input = freezeInput(input),
        children = List.unmodifiable(children);

  final String name;
  final Map<String, Object?> input;
  final List<PlanStep> children;
  final SourceLocation source;
}

/// Compiles control flow once so the runtime executes a validated plan.
final class PlanCompiler {
  PlanCompiler(
    this.registry, {
    int maxRepeatIterations = 1000,
  }) : maxRepeatIterations = _validateRepeatLimit(maxRepeatIterations);

  final OperationRegistry registry;

  /// Upper bound for one authored repeat block.
  ///
  /// A repeat is expanded at runtime, so accepting an unbounded integer here
  /// would allow a malformed plan to consume the whole attempt budget before
  /// the normal operation limit can provide a useful diagnostic.
  final int maxRepeatIterations;
  final Map<String, PlanNode> _nodes = {};
  final List<String> _loopIds = [];
  final Set<String> _recoveryTargets = {};
  int _nextId = 0;

  static int _validateRepeatLimit(int value) {
    if (value <= 0) {
      throw ArgumentError.value(
        value,
        'maxRepeatIterations',
        'must be greater than zero',
      );
    }
    return value;
  }

  ExecutionPlan compile(String id, List<PlanStep> steps) {
    if (steps.isEmpty) throw const FormatException('A plan needs steps.');
    _nodes.clear();
    _loopIds.clear();
    _recoveryTargets.clear();
    _nextId = 0;
    const end = 'end';
    _nodes[end] = const EndNode(end);
    var next = end;
    for (var index = steps.length - 1; index >= 0; index--) {
      final finishId = 'step${index}End';
      _nodes[finishId] = StepBoundaryNode(
        finishId,
        stepIndex: index,
        started: false,
        next: next,
      );
      final body = _compileSequence([steps[index]], finishId, null);
      final startId = 'step${index}Start';
      _nodes[startId] = StepBoundaryNode(
        startId,
        stepIndex: index,
        started: true,
        next: body,
      );
      next = startId;
    }
    final start = next;
    return ExecutionPlan(id: id, start: start, nodes: _nodes);
  }

  String _compileSequence(
    List<PlanStep> steps,
    String next,
    String? onFailure,
  ) {
    var cursor = next;
    for (final step in steps.reversed) {
      final nodeId = 'n${_nextId++}';
      final control = registry.controlKind(step.name);
      if (control != null && step.children.isEmpty) {
        throw FormatException(
          '${step.source}: ${step.name} requires at least one child step.',
        );
      }
      switch (control) {
        case ControlKind.group:
          cursor = _compileSequence(step.children, cursor, onFailure);
        case ControlKind.optional:
          final recoveryId = nodeId;
          final firstBodyLoop = _loopIds.length;
          final body = _compileSequence(step.children, cursor, recoveryId);
          final resetLoops = _loopIds.skip(firstBodyLoop).toSet();
          if (_recoveryTargets.contains(recoveryId)) {
            _nodes[recoveryId] = RecoveryNode(
              recoveryId,
              next: cursor,
              resetLoops: resetLoops,
            );
          }
          cursor = body;
        case ControlKind.repeat:
          final times = step.input['times'] ?? 1;
          if (times is! int || times < 0 || times > maxRepeatIterations) {
            throw FormatException(
              '${step.source}: repeat.times must be an integer from 0 to '
              '$maxRepeatIterations.',
            );
          }
          final loopId = nodeId;
          final body = _compileSequence(step.children, loopId, onFailure);
          _nodes[loopId] =
              LoopNode(loopId, times: times, body: body, next: cursor);
          _loopIds.add(loopId);
          cursor = loopId;
        case ControlKind.ifVisible:
          final target = step.input['target'];
          final id = step.input['id'];
          final Map<String, Object?> targetMap;
          if (target is Map) {
            targetMap = {
              'target': {
                for (final entry in target.entries)
                  entry.key.toString(): entry.value,
              },
            };
          } else if (id != null) {
            targetMap = {'id': id};
          } else {
            throw FormatException('${step.source}: ifVisible needs a target.');
          }
          final visible = _compileSequence(step.children, cursor, onFailure);
          _nodes[nodeId] = BranchNode(nodeId,
              target: targetMap,
              whenVisible: visible,
              whenHidden: cursor,
              onFailure: onFailure,
              source: step.source);
          if (onFailure != null) _recoveryTargets.add(onFailure);
          cursor = nodeId;
        case null:
          final definition = registry.lookup(step.name);
          if (definition == null) {
            throw FormatException(
                '${step.source}: unknown step "${step.name}".');
          }
          if (step.children.isNotEmpty) {
            throw FormatException(
              '${step.source}: operation "${step.name}" cannot contain '
              'nested steps.',
            );
          }
          final operation = TestOperation(
            id: nodeId,
            name: definition.name,
            kind: definition.kind,
            handlerKey: definition.handlerKey,
            input: step.input,
            source: step.source,
          );
          _nodes[nodeId] =
              OperationNode(nodeId, operation, cursor, onFailure: onFailure);
          if (onFailure != null) _recoveryTargets.add(onFailure);
          cursor = nodeId;
      }
    }
    return cursor;
  }
}
