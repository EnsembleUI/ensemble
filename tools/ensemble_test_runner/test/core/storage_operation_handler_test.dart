import '../support/test_step_executor_handler_harness.dart';
import 'package:ensemble_test_runner/application/application_test_types.dart';
import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:ensemble_test_runner/mocks/test_logger.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:ensemble_test_runner/session/session_capabilities.dart';
import 'package:ensemble_test_runner/src/core/operation.dart';
import 'package:ensemble_test_runner/src/runtime/operation_registry.dart'
    show operationRegistry;
import 'package:ensemble_test_runner/src/runtime/flutter_test_runtime.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('storage mutations use the direct session handler',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('Home')));
    final storage = _FakeStorage();
    final context = EnsembleTestContext(
      testCase: const EnsembleTestCase(id: 'storage-runtime-slice', steps: []),
      apiOverlay: TestApiProviderOverlay(mocks: const {}),
      logger: TestLogger(),
      setup: const EnsembleTestSetup(),
    );
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: context,
      permissions: SessionPermissions.testController,
      services: ApplicationTestServices(storage: storage),
    );
    final runtime = FlutterTestRuntime(session);

    final value = <String, Object?>{'token': 'abc'};
    final setOperation = _operation(
      id: 'set-storage',
      name: 'setStorage',
      input: {'key': 'token', 'value': value},
    );
    final setResult = await runtime.execute(setOperation);
    final removeResult = await runtime.execute(_operation(
      id: 'remove-storage',
      name: 'removeStorage',
      input: const {'key': 'token'},
    ));
    final clearResult = await runtime.execute(_operation(
      id: 'clear-storage',
      name: 'clearStorage',
    ));

    expect(setResult.succeeded, isTrue, reason: setResult.error);
    expect(removeResult.succeeded, isTrue, reason: removeResult.error);
    expect(clearResult.succeeded, isTrue, reason: clearResult.error);
    expect(storage.calls, ['write:token', 'remove:token', 'clear']);
    expect(
      identical(storage.lastWrittenValue, setOperation.input['value']),
      isTrue,
    );
    expect(setOperation.handlerKey, 'storage.set');
    await runtime.close();
  });

  testWidgets('storage mutations enforce privileged permission',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('Home')));
    final storage = _FakeStorage();
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase:
            const EnsembleTestCase(id: 'storage-permission-slice', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      permissions: SessionPermissions.restrictedUi,
      services: ApplicationTestServices(storage: storage),
    );
    final runtime = FlutterTestRuntime(session);

    for (final (name, input) in <(String, Map<String, Object?>)>[
      ('setStorage', const {'key': 'token', 'value': 'blocked'}),
      ('removeStorage', const {'key': 'token'}),
      ('clearStorage', const <String, Object?>{}),
    ]) {
      final result = await runtime.execute(_operation(
        id: 'storage-$name',
        name: name,
        input: input,
      ));
      expect(result.succeeded, isFalse, reason: name);
      expect(result.errorCode, 'permissionDenied', reason: name);
    }
    expect(storage.calls, isEmpty);
    await runtime.close();
  });

  testWidgets('step and session routes share storage capability handling',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('Home')));
    final storage = _FakeStorage();
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(id: 'storage-route-parity', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      permissions: SessionPermissions.testController,
      services: ApplicationTestServices(storage: storage),
    );
    final runtime = FlutterTestRuntime(session);

    final authoredValue = <String, Object?>{'origin': 'authored'};
    await session.executor.execute(TestStep(
      type: 'setStorage',
      args: {'key': 'token', 'value': authoredValue},
    ));
    expect(identical(storage.lastWrittenValue, authoredValue), isTrue);
    await session.executor.execute(const TestStep(
      type: 'removeStorage',
      args: {'key': 'token'},
    ));
    await session.executor.execute(
      const TestStep(type: 'clearStorage', args: {}),
    );
    final operation = _operation(
      id: 'set-storage-session',
      name: 'setStorage',
      input: const {
        'key': 'token',
        'value': {'origin': 'compiled'},
      },
    );
    await runtime.execute(operation);
    expect(
      identical(storage.lastWrittenValue, operation.input['value']),
      isTrue,
    );
    await runtime.execute(_operation(
      id: 'remove-storage-session',
      name: 'removeStorage',
      input: const {'key': 'token'},
    ));
    await runtime.execute(_operation(
      id: 'clear-storage-session',
      name: 'clearStorage',
    ));

    expect(
      storage.calls,
      [
        'write:token',
        'remove:token',
        'clear',
        'write:token',
        'remove:token',
        'clear'
      ],
    );
    await runtime.close();
  });
}

TestOperation _operation({
  required String id,
  required String name,
  Map<String, Object?> input = const {},
}) {
  return TestOperation(
    id: id,
    name: name,
    kind: OperationKind.environment,
    handlerKey: operationRegistry.lookup(name)!.handlerKey,
    input: input,
    source: const SourceLocation('storage-runtime-slice.yaml', 'steps/0'),
  );
}

final class _FakeStorage implements StorageTestService {
  final calls = <String>[];

  @override
  Future<void> apply(Map<String, dynamic> state) async {}

  @override
  Future<void> restore() async {}

  @override
  Object? read(String key) => null;

  @override
  Future<void> write(String key, Object? value) async {
    calls.add('write:$key');
    lastWrittenValue = value;
  }

  Object? lastWrittenValue;

  @override
  Future<void> remove(String key) async {
    calls.add('remove:$key');
  }

  @override
  Future<void> clear() async {
    calls.add('clear');
  }
}
