import 'dart:collection';

import 'operation_input.dart';

enum OperationKind {
  interaction,
  wait,
  assertion,
  lifecycle,
  environment,
  diagnostic,
}

/// Location in the authored test, independent of the parser and Flutter.
final class SourceLocation {
  const SourceLocation(this.path, this.stepPath);

  final String path;
  final String stepPath;

  @override
  String toString() => '$path:$stepPath';
}

/// The only command representation between a compiled plan and its runtime.
final class TestOperation implements OperationInput {
  TestOperation({
    required this.id,
    required this.name,
    required this.kind,
    required this.handlerKey,
    required Map<String, Object?> input,
    required this.source,
  }) : input = freezeInput(input);

  final String id;
  final String name;
  final OperationKind kind;

  /// The registry route selected during compilation.
  final String handlerKey;
  final Map<String, Object?> input;
  final SourceLocation source;

  @override
  String get operationName => name;

  @override
  Map get arguments => input;
}

Map<String, Object?> freezeInput(Map<String, Object?> input) =>
    UnmodifiableMapView({
      for (final entry in input.entries) entry.key: _freeze(entry.value),
    });

Object? _freeze(Object? value) {
  if (value is Map) {
    final input = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        throw ArgumentError.value(
          key,
          'input map key',
          'Operation inputs must use string map keys.',
        );
      }
      input[key] = entry.value;
    }
    return freezeInput(input);
  }
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(_freeze));
  }
  return value;
}

bool sameInput(Object? left, Object? right) {
  if (identical(left, right)) return true;
  if (left is Map && right is Map) {
    if (left.length != right.length) return false;
    for (final entry in left.entries) {
      if (!right.containsKey(entry.key) ||
          !sameInput(entry.value, right[entry.key])) {
        return false;
      }
    }
    return true;
  }
  if (left is List && right is List) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (!sameInput(left[index], right[index])) return false;
    }
    return true;
  }
  return left == right;
}
