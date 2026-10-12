import 'package:ensemble_test_runner/src/core/operation.dart';
import 'package:ensemble_test_runner/src/core/operation_registry.dart';
import 'package:ensemble_test_runner/src/runtime/runtime_operation_handlers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('requires a handler for every registered operation', () {
    final registry = _registry();

    expect(
      () => RuntimeOperationHandlers(
        registry: registry,
        kindHandlers: {OperationKind.interaction: _ignore},
      ),
      throwsArgumentError,
    );
  });

  test('rejects overrides for unknown handler keys', () {
    expect(
      () => RuntimeOperationHandlers(
        registry: _registry(),
        kindHandlers: _kindHandlers,
        handlerOverrides: {'unknown': _ignore},
      ),
      throwsArgumentError,
    );
  });

  test('dispatches aliases and canonical names through registry descriptors',
      () async {
    final seen = <String>[];
    final handlers = RuntimeOperationHandlers(
      registry: _registry(),
      kindHandlers: {
        OperationKind.interaction: (_) async => seen.add('interaction'),
        OperationKind.lifecycle: (_) async => seen.add('lifecycle'),
      },
    );

    await handlers.execute(_operation('tap'));
    await handlers.execute(_operation('press'));

    expect(seen, ['interaction', 'interaction']);
  });

  test('handler-key override takes precedence over operation-kind handler',
      () async {
    final seen = <String>[];
    final handlers = RuntimeOperationHandlers(
      registry: _registry(),
      kindHandlers: _kindHandlersWith((_) async => seen.add('kind')),
      handlerOverrides: {'navigation.back': (_) async => seen.add('override')},
    );

    await handlers.execute(_operation('goBack'));

    expect(seen, ['override']);
  });

  test('unregistered runtime operations fail before handler execution', () {
    final handlers = RuntimeOperationHandlers(
      registry: _registry(),
      kindHandlers: _kindHandlers,
    );

    expect(() => handlers.execute(_operation('unknown')), throwsArgumentError);
  });

  test('registered operation cannot claim a different kind', () {
    final handlers = RuntimeOperationHandlers(
      registry: _registry(),
      kindHandlers: _kindHandlers,
    );

    expect(
      () => handlers.execute(
        _operation('goBack', kind: OperationKind.interaction),
      ),
      throwsArgumentError,
    );
  });

  test('rejects a compiled operation with a stale handler key', () {
    final handlers = RuntimeOperationHandlers(
      registry: _registry(),
      kindHandlers: _kindHandlers,
    );

    expect(
      () => handlers.execute(
        _operation('goBack', handlerKey: 'lifecycle.goBack'),
      ),
      throwsArgumentError,
    );
  });
}

final Map<OperationKind, RuntimeOperationHandler> _kindHandlers =
    _kindHandlersWith(_ignore);

Map<OperationKind, RuntimeOperationHandler> _kindHandlersWith(
  RuntimeOperationHandler handler,
) =>
    {
      OperationKind.interaction: handler,
      OperationKind.lifecycle: handler,
    };

OperationRegistry _registry() => OperationRegistry([
      OperationDescriptor(
        name: 'tap',
        kind: OperationKind.interaction,
        argumentSchema: const {},
        aliases: const ['press'],
      ),
      OperationDescriptor(
        name: 'goBack',
        kind: OperationKind.lifecycle,
        argumentSchema: const {},
        handlerKey: 'navigation.back',
      ),
    ]);

Future<void> _ignore(TestOperation _) async {}

TestOperation _operation(
  String name, {
  OperationKind? kind,
  String? handlerKey,
}) =>
    TestOperation(
      id: 'test-operation',
      name: name,
      kind: kind ??
          (name == 'goBack'
              ? OperationKind.lifecycle
              : OperationKind.interaction),
      handlerKey: handlerKey ?? _registry().lookup(name)?.handlerKey ?? name,
      input: const {},
      source: const SourceLocation('test.yaml', 'steps/0'),
    );
