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
  testWidgets('compiled mocks use the direct API handler', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('Home')));
    final api = _FakeApiService();
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(id: 'mocks', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      permissions: SessionPermissions.testController,
      services: ApplicationTestServices(api: api),
    );
    final runtime = FlutterTestRuntime(session);
    final result = await runtime.execute(TestOperation(
      id: 'mocks',
      name: 'mocks',
      kind: OperationKind.environment,
      handlerKey: operationRegistry.lookup('mocks')!.handlerKey,
      input: {
        '__ensembleRunnerResolvedMocks': {
          'profile': {
            'statusCode': 200,
            'body': {'name': 'Ada'},
          },
        },
      },
      source: SourceLocation('mocks.yaml', 'steps/0'),
    ));

    expect(result.succeeded, isTrue, reason: result.error);
    expect(api.applied.single.apis['profile']?.body, {'name': 'Ada'});
    await runtime.close();
  });

  testWidgets('authored and compiled mocks preserve shared response data',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('Home')));
    final authoredApi = _FakeApiService();
    final compiledApi = _FakeApiService();
    LocalTestExecutionSession createSession(String id, _FakeApiService api) =>
        LocalTestExecutionSession.attach(
          tester: tester,
          context: EnsembleTestContext(
            testCase: EnsembleTestCase(id: id, steps: const []),
            apiOverlay: TestApiProviderOverlay(mocks: const {}),
            logger: TestLogger(),
            setup: const EnsembleTestSetup(),
          ),
          permissions: SessionPermissions.testController,
          services: ApplicationTestServices(api: api),
        );

    final authoredSession = createSession('mocks-authored', authoredApi);
    final compiledSession = createSession('mocks-compiled', compiledApi);
    final runtime = FlutterTestRuntime(compiledSession);
    const responseBody = {
      'name': 'Ada',
      'features': ['profile', 'search']
    };
    const response = MockAPIResponse(
      statusCode: 201,
      body: responseBody,
      responses: [
        MockAPIResponse(statusCode: 202, body: {'name': 'Grace'})
      ],
    );

    await authoredSession.executor.execute(const TestStep(
      type: 'mocks',
      args: {},
      mocks: TestMocks(apis: {'profile': response}),
    ));
    final result = await runtime.execute(TestOperation(
      id: 'mocks-compiled',
      name: 'mocks',
      kind: OperationKind.environment,
      handlerKey: operationRegistry.lookup('mocks')!.handlerKey,
      input: const {
        '__ensembleRunnerResolvedMocks': {
          'profile': {
            'statusCode': 201,
            'body': responseBody,
            'responses': [
              {
                'statusCode': 202,
                'body': {'name': 'Grace'}
              },
            ],
          },
        },
      },
      source: const SourceLocation('mocks-compiled', 'steps/0'),
    ));

    expect(result.succeeded, isTrue, reason: result.error);
    expect(authoredApi.applied.single.apis['profile']?.statusCode, 201);
    expect(compiledApi.applied.single.apis['profile']?.statusCode, 201);
    expect(authoredApi.applied.single.apis['profile']?.body, responseBody);
    expect(compiledApi.applied.single.apis['profile']?.body, responseBody);
    expect(
      authoredApi.applied.single.apis['profile']?.responses.single.statusCode,
      202,
    );
    expect(
      compiledApi.applied.single.apis['profile']?.responses.single.statusCode,
      202,
    );
    await authoredSession.close();
    await runtime.close();
  });

  testWidgets('resetApiCalls uses the direct environment handler',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('Home')));
    final api = _FakeApiService();
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(id: 'reset-api-calls', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      permissions: SessionPermissions.testController,
      services: ApplicationTestServices(api: api),
    );
    final runtime = FlutterTestRuntime(session);

    final result = await runtime.execute(_environmentOperation(
      id: 'reset-api-calls',
      name: 'resetApiCalls',
      source: const SourceLocation('reset-api-calls', 'steps/0'),
    ));

    expect(result.succeeded, isTrue, reason: result.error);
    expect(api.resetCount, 1);
    await runtime.close();
  });

  testWidgets('permission and locale mutations use direct handlers',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('Home')));
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(id: 'environment', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      permissions: SessionPermissions.testController,
    );
    final runtime = FlutterTestRuntime(session);

    final permission = await runtime.execute(_environmentOperation(
      id: 'permission',
      name: 'setPermission',
      input: const {'name': 'camera', 'value': 'granted'},
      source: const SourceLocation('environment', 'steps/0'),
    ));
    final locale = await runtime.execute(_environmentOperation(
      id: 'locale',
      name: 'setLocale',
      input: const {'locale': 'nl-NL'},
      source: const SourceLocation('environment', 'steps/1'),
    ));

    expect(permission.succeeded, isTrue, reason: permission.error);
    expect(locale.succeeded, isTrue, reason: locale.error);
    expect(session.context.runtime.permissions['camera'], 'granted');
    expect(session.context.runtime.locale?.languageCode, 'nl');
    expect(session.context.runtime.locale?.countryCode, 'NL');
    expect(session.context.envOverrides['APP_LOCALE'], 'nl-NL');
    await runtime.close();
  });

  testWidgets('compiled permission mutation shares raw validation',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('Home')));

    LocalTestExecutionSession createSession(String id) =>
        LocalTestExecutionSession.attach(
          tester: tester,
          context: EnsembleTestContext(
            testCase: EnsembleTestCase(id: id, steps: const []),
            apiOverlay: TestApiProviderOverlay(mocks: const {}),
            logger: TestLogger(),
            setup: const EnsembleTestSetup(),
          ),
          permissions: SessionPermissions.testController,
        );

    final rawSession = createSession('permission-raw');
    final compiledSession = createSession('permission-compiled');
    final runtime = FlutterTestRuntime(compiledSession);
    const validInput = {'name': 'camera', 'value': 'granted'};
    await rawSession.executor.execute(const TestStep(
      type: 'setPermission',
      args: validInput,
    ));
    final validResult = await runtime.execute(_environmentOperation(
      id: 'permission',
      name: 'setPermission',
      input: validInput,
      source: const SourceLocation('environment', 'steps/0'),
    ));

    expect(validResult.succeeded, isTrue, reason: validResult.error);
    expect(
      rawSession.context.runtime.permissions,
      compiledSession.context.runtime.permissions,
    );

    for (final input in [
      const <String, Object?>{},
      const <String, Object?>{'name': ''},
    ]) {
      await expectLater(
        rawSession.executor.execute(TestStep(
          type: 'setPermission',
          args: Map<String, dynamic>.from(input),
        )),
        throwsA(isA<EnsembleTestFailure>().having(
          (failure) => failure.message,
          'message',
          contains('setPermission requires "name"'),
        )),
      );
      final result = await runtime.execute(_environmentOperation(
        id: 'invalid-permission',
        name: 'setPermission',
        input: input,
        source: const SourceLocation('permission-validation', 'steps/0'),
      ));
      expect(result.succeeded, isFalse);
      expect(
        result.error.toString(),
        contains('setPermission requires "name"'),
      );
    }

    expect(
      rawSession.context.runtime.permissions,
      compiledSession.context.runtime.permissions,
    );
    expect(rawSession.context.runtime.permissions, {'camera': 'granted'});
    await rawSession.close();
    await runtime.close();
  });

  testWidgets('authored and compiled environment mutations keep the input',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('Home')));
    LocalTestExecutionSession createSession(String id) =>
        LocalTestExecutionSession.attach(
          tester: tester,
          context: EnsembleTestContext(
            testCase: EnsembleTestCase(id: id, steps: const []),
            apiOverlay: TestApiProviderOverlay(mocks: const {}),
            logger: TestLogger(),
            setup: const EnsembleTestSetup(),
          ),
          permissions: SessionPermissions.testController,
        );

    final authoredSession = createSession('environment-authored');
    final compiledSession = createSession('environment-compiled');
    final runtime = FlutterTestRuntime(compiledSession);
    final value = <String, Object?>{'enabled': true};
    const key = 'FEATURE_FLAG';

    await authoredSession.executor.execute(TestStep(
      type: 'setEnv',
      args: {'key': key, 'value': value},
    ));
    final operation = _environmentOperation(
      id: 'set-env',
      name: 'setEnv',
      input: {'key': key, 'value': value},
      source: const SourceLocation('environment', 'steps/0'),
    );
    final result = await runtime.execute(operation);

    expect(result.succeeded, isTrue, reason: result.error);
    expect(identical(authoredSession.context.envOverrides[key], value), isTrue);
    expect(
      identical(
        compiledSession.context.envOverrides[key],
        operation.input['value'],
      ),
      isTrue,
    );
    expect(
      authoredSession.context.envOverrides,
      compiledSession.context.envOverrides,
    );
    await authoredSession.close();
    await runtime.close();
  });
}

TestOperation _environmentOperation({
  required String id,
  required String name,
  required SourceLocation source,
  Map<String, Object?> input = const {},
}) =>
    TestOperation(
      id: id,
      name: name,
      kind: OperationKind.environment,
      handlerKey: operationRegistry.lookup(name)!.handlerKey,
      input: input,
      source: source,
    );

final class _FakeApiService implements ApiMockingTestService {
  int resetCount = 0;
  final applied = <TestMocks>[];

  @override
  void applyMocks(TestMocks mocks) => applied.add(mocks);

  @override
  int callCount(String name) => 0;

  @override
  void resetCalls() => resetCount++;
}
