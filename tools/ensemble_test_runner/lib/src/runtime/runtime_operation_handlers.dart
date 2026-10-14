import '../core/operation.dart';
import '../core/operation_registry.dart';

typedef RuntimeOperationHandler = Future<void> Function(
    TestOperation operation);

/// Validated dispatch table keyed by the operation registry's handler keys.
///
/// Kind handlers provide shared behavior, while a handler-key override can
/// route a single registered operation through a specialized runtime path.
final class RuntimeOperationHandlers {
  RuntimeOperationHandlers({
    required OperationRegistry registry,
    Map<OperationKind, RuntimeOperationHandler> kindHandlers = const {},
    Map<String, RuntimeOperationHandler> handlerOverrides = const {},
  })  : _registry = registry,
        _handlers = _validate(
          registry,
          kindHandlers,
          handlerOverrides,
        );

  final OperationRegistry _registry;
  final Map<String, RuntimeOperationHandler> _handlers;

  Future<void> execute(TestOperation operation) {
    final descriptor = _registry.lookup(operation.name);
    if (descriptor == null) {
      throw ArgumentError.value(
        operation.name,
        'operation.name',
        'Operation is not registered.',
      );
    }
    if (descriptor.kind != operation.kind) {
      throw ArgumentError(
        'Operation ${operation.name} is registered as '
        '${descriptor.kind.name}, not ${operation.kind.name}.',
      );
    }
    final handlerKey = operation.handlerKey;
    if (handlerKey != descriptor.handlerKey) {
      throw ArgumentError(
        'Operation ${operation.name} carries handler "$handlerKey", '
        'but the registry selects "${descriptor.handlerKey}".',
      );
    }
    return _handlers[handlerKey]!(operation);
  }

  static Map<String, RuntimeOperationHandler> _validate(
    OperationRegistry registry,
    Map<OperationKind, RuntimeOperationHandler> kindHandlers,
    Map<String, RuntimeOperationHandler> handlerOverrides,
  ) {
    final knownHandlerKeys = <String>{
      for (final descriptor in registry.descriptors) descriptor.handlerKey,
    };
    final unknownOverrides =
        handlerOverrides.keys.toSet().difference(knownHandlerKeys);
    if (unknownOverrides.isNotEmpty) {
      throw ArgumentError('Unknown operation handler keys: $unknownOverrides');
    }

    final handlers = <String, RuntimeOperationHandler>{};
    for (final descriptor in registry.descriptors) {
      final handler = handlerOverrides[descriptor.handlerKey] ??
          kindHandlers[descriptor.kind];
      if (handler == null) {
        throw ArgumentError(
          'Missing handler for ${descriptor.name} '
          '(${descriptor.handlerKey}).',
        );
      }
      handlers[descriptor.handlerKey] = handler;
    }
    return Map.unmodifiable(handlers);
  }
}
