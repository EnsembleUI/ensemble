import 'package:ensemble_test_runner/src/core/operation.dart';
import 'package:ensemble_test_runner/src/runtime/operation_registry.dart'
    show operationRegistry;
import 'package:ensemble_test_runner/session/operation_target.dart';

int _requestId = 0;

TestOperation sessionOperation(
  String name, {
  Map<String, Object?> input = const {},
}) {
  final descriptor = operationRegistry.lookup(name);
  if (descriptor == null) {
    throw ArgumentError.value(name, 'name', 'Unknown operation.');
  }
  return TestOperation(
    id: 'test_${_requestId++}',
    name: name,
    kind: descriptor.kind,
    handlerKey: descriptor.handlerKey,
    input: input,
    source: const SourceLocation('test', 'session'),
  );
}

TestOperation targetedOperation(
  String name,
  ElementTarget target, {
  Map<String, Object?> input = const {},
}) =>
    sessionOperation(
      name,
      input: {...input, 'target': target.toJson()},
    );

TestOperation actionOperation(
  String name, {
  ElementTarget? target,
  Map<String, Object?> input = const {},
}) =>
    sessionOperation(
      name,
      input: {
        ...input,
        if (target != null) 'target': target.toJson(),
      },
    );
