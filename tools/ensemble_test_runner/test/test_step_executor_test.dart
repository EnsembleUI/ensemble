import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ensemble_test_runner/actions/test_execution_config.dart';
import 'package:ensemble_test_runner/actions/lifecycle_actions.dart';
import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'package:ensemble_test_runner/session/errors/test_execution_error.dart';
import 'support/test_step_executor_handler_harness.dart';
import 'package:ensemble_test_runner/session/http_request_operation_handler.dart';
import 'package:ensemble_test_runner/application/application_test_types.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:ensemble_test_runner/mocks/test_logger.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/runner/test_session.dart';
import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'package:ensemble_test_runner/src/core/operation.dart';
import 'support/session_operation.dart';
import 'package:ensemble_test_runner/src/runtime/operation_registry.dart'
    show operationRegistry;
import 'package:ensemble/framework/screen_tracker.dart';
import 'package:ensemble/framework/bindings.dart';
import 'package:ensemble/framework/theme_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

String _conditionBoundaryType(String type) =>
    type.startsWith('condition:') ? type.substring('condition:'.length) : type;

void main() {
  testWidgets('trigger publishes one evidence boundary before mutation',
      (tester) async {
    var activated = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ElevatedButton(
          key: const ValueKey('trigger_target'),
          onPressed: () => activated = true,
          child: const Text('Continue'),
        ),
      ),
    ));
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'trigger_evidence_boundary', steps: []),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
    );
    final events = <String>[];
    executor.onEvidenceBoundary = (step) {
      expect(step.type, 'trigger');
      expect(activated, isFalse);
      events.add('evidence');
    };

    await executor.execute(const TestStep(
      type: 'trigger',
      args: {'action': 'onTap', 'id': 'trigger_target'},
    ));

    expect(events, ['evidence']);
    expect(activated, isTrue);
  });

  testWidgets('wait, pump and settle share the condition execution path',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'direct_wait_dispatch', steps: []),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      executionConfig: const TestExecutionConfig(
        waitPollInterval: Duration.zero,
      ),
    );
    final boundaries = <String>[];
    executor.onEvidenceBoundary = (step) => boundaries.add(step.type);

    await executor.execute(const TestStep(type: 'wait', args: {
      'durationMs': 0,
    }));
    await executor.execute(const TestStep(type: 'pump', args: {}));
    await executor.execute(const TestStep(type: 'settle', args: {
      'timeoutMs': 1000,
    }));
    final pump = operationRegistry.lookup('pump')!;
    executor.onOperationEvidenceBoundary =
        (_, detail) => boundaries.add(detail);
    await executor.executeWaitOperation(TestOperation(
      id: 'compiled-pump',
      name: pump.name,
      kind: pump.kind,
      handlerKey: pump.handlerKey,
      input: const {'durationMs': 0},
      source: const SourceLocation('pump-dispatch-parity', 'steps[0]'),
    ));

    expect(boundaries, [
      'condition:wait',
      'condition:pump',
      'condition:settle',
      'condition:pump',
    ]);
  });

  testWidgets('waitForApi publishes one matched-state boundary',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'api_wait_dispatch', steps: []),
    );
    context.apiOverlay.calls.add(
      APICallRecord(
        name: 'login',
        apiDefinition: YamlMap.wrap(const {'url': 'https://example.test'}),
        timestamp: DateTime(2026),
        statusCode: 200,
      ),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
    );
    final callbacks = <String>[];
    executor.onEvidenceBoundary =
        (step) => callbacks.add(_conditionBoundaryType(step.type));

    await executor.execute(const TestStep(
      type: 'waitForApi',
      args: {'name': 'login'},
    ));

    expect(callbacks, ['waitForApi']);
    await expectLater(
      executor.execute(const TestStep(
        type: 'waitForApi',
        args: {'times': 1},
      )),
      throwsA(isA<EnsembleTestFailure>().having(
        (failure) => failure.message,
        'message',
        contains('waitForApi requires "name"'),
      )),
    );
    expect(callbacks, ['waitForApi']);
  });

  testWidgets('waitForApi waits for the API response before continuing',
      (tester) async {
    final response = ValueNotifier<String>('Loading');
    await tester.pumpWidget(MaterialApp(
      home: ValueListenableBuilder<String>(
        valueListenable: response,
        builder: (context, value, _) => Text(value),
      ),
    ));
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'api_wait_completion', steps: []),
    );
    final record = APICallRecord(
      name: 'getRooms',
      apiDefinition: YamlMap.wrap(const {'url': 'https://example.test'}),
      timestamp: DateTime(2026),
    );
    context.apiOverlay.calls.add(record);
    Timer(const Duration(milliseconds: 32), () {
      record.statusCode = 200;
      response.value = 'Rooms';
    });
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
    );

    await executor.execute(const TestStep(
      type: 'waitForApi',
      args: {'name': 'getRooms', 'timeoutMs': 1000},
    ));

    expect(record.isCompleted, isTrue);
    expect(find.text('Rooms'), findsOneWidget);
    response.dispose();
  });

  testWidgets('waitForGone publishes one matched-state boundary',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'gone_wait_dispatch', steps: []),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
    );
    final callbacks = <String>[];
    executor.onEvidenceBoundary =
        (step) => callbacks.add(_conditionBoundaryType(step.type));

    await executor.execute(const TestStep(
      type: 'waitForGone',
      args: {'id': 'already_absent', 'timeoutMs': 25},
    ));

    expect(callbacks, ['waitForGone']);
  });

  testWidgets('waitForText alias preserves anyOf and waitFor OR semantics',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Column(
        children: [
          Text('Ready'),
          Text('Anchor', key: ValueKey('anchor')),
        ],
      ),
    ));
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'text_wait_dispatch', steps: []),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
    );
    final matchedTexts = <String>[];
    final matchedSteps = <String>[];
    final evidenceSteps = <String>[];
    final matchedInputs = <TestStep>[];
    executor.onOperationEvidenceBoundary = (_, detail) {
      fail(
          'Authored wait evidence should retain its TestStep boundary: $detail');
    };
    executor.onEvidenceBoundary = (step) {
      evidenceSteps.add(step.type);
      if (step.type.startsWith('condition:')) {
        matchedSteps.add(_conditionBoundaryType(step.type));
      }
      if (step.type == 'waitForText') {
        matchedInputs.add(step);
        matchedTexts.add(step.args['text']?.toString() ?? 'anyOf');
      }
    };

    await executor.execute(const TestStep(
      type: 'waitForText',
      args: {
        'anyOf': ['Missing', 'Ready'],
        'timeoutMs': 25,
      },
    ));
    // A matching ID remains sufficient even if accompanying text is absent.
    await executor.execute(const TestStep(
      type: 'waitFor',
      args: {'id': 'anchor', 'text': 'Not present', 'timeoutMs': 25},
    ));
    // Conversely, any matching text remains sufficient if the ID is absent.
    await executor.execute(const TestStep(
      type: 'waitFor',
      args: {'id': 'missing', 'text': 'Ready', 'timeoutMs': 25},
    ));

    expect(matchedTexts, ['Ready']);
    expect(matchedInputs, hasLength(1));
    expect(matchedInputs.single.args['anyOf'], isNull);
    expect(matchedInputs.single.args['text'], 'Ready');
    expect(evidenceSteps, [
      'waitForText',
      'condition:waitFor',
      'condition:waitFor',
    ]);
    expect(matchedSteps, ['waitFor', 'waitFor']);
  });

  test('httpRequest sends JSON and validates the response', () async {
    EnsembleTestHarness.ensureTestPlugins();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final receivedBodies = <Map<String, dynamic>>[];
    final receivedContentTypes = <ContentType>[];
    server.listen((request) async {
      receivedContentTypes.add(request.headers.contentType!);
      receivedBodies.add(jsonDecode(await utf8.decoder.bind(request).join())
          as Map<String, dynamic>);
      request.response
        ..statusCode = HttpStatus.created
        ..write('{"ready":true}');
      await request.response.close();
    });

    try {
      final input = {
        'method': 'POST',
        'url': 'http://127.0.0.1:${server.port}/control',
        'body': {'state': 'ready'},
        'expectStatus': 201,
        'expectBodyContains': 'ready',
      };
      const handler = HttpRequestOperationHandler();
      await handler.execute(TestStep(type: 'httpRequest', args: input));
      await handler.execute(TestOperation(
        id: 'compiled-http-request',
        name: 'httpRequest',
        kind: OperationKind.environment,
        handlerKey: operationRegistry.lookup('httpRequest')!.handlerKey,
        input: input,
        source:
            const SourceLocation('http-request-dispatch-parity', 'steps[0]'),
      ));
      expect(receivedBodies, [
        {'state': 'ready'},
        {'state': 'ready'}
      ]);
      expect(receivedContentTypes.map((type) => type.mimeType), [
        ContentType.json.mimeType,
        ContentType.json.mimeType,
      ]);
    } finally {
      await server.close(force: true);
    }
  });

  testWidgets('API and storage assertions use explicit runtime handlers',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'runtime_assertions', steps: []),
    );
    final storage = _FakeStorageService({'ready': true});
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      harness: EnsembleTestHarness(appPath: 'unused', appHome: 'Home'),
      services: ApplicationTestServices(
        api: _FakeApiService({'login': 2}),
        storage: storage,
      ),
    );

    final matched = <String>[];
    executor.onEvidenceBoundary =
        (step) => matched.add(_conditionBoundaryType(step.type));

    await executor.execute(const TestStep(
      type: 'expectApiCalled',
      args: {'name': 'login', 'times': 2},
    ));
    final apiCalledDescriptor = operationRegistry.lookup('expectApiCalled')!;
    expect(
      await executor.executeRegisteredAssertion(
        sessionOperation(
          'expectApiCalled',
          input: const {'name': 'login', 'times': 2},
        ),
        descriptor: apiCalledDescriptor,
      ),
      isTrue,
    );
    await executor.execute(const TestStep(
      type: 'expectApiNotCalled',
      args: {'name': 'logout'},
    ));
    await executor.execute(const TestStep(
      type: 'expectStorage',
      args: {'key': 'ready', 'equals': true},
    ));
    await executor.execute(const TestStep(
      type: 'expectApiCallOrder',
      args: {'names': []},
    ));
    await executor.execute(const TestStep(
      type: 'removeStorage',
      args: {'key': 'ready'},
    ));
    expect(storage.values, isEmpty);
    storage.values['temporary'] = 'value';
    await executor.execute(const TestStep(type: 'clearStorage', args: {}));
    expect(storage.values, isEmpty);
    expect(matched, [
      'expectApiCalled',
      'expectApiNotCalled',
      'expectStorage',
      'expectApiCallOrder',
    ]);

    await expectLater(
      executor.execute(const TestStep(
        type: 'expectLastApiCall',
        args: {'name': 'login'},
      )),
      throwsA(isA<EnsembleTestFailure>()),
    );
    expect(matched, [
      'expectApiCalled',
      'expectApiNotCalled',
      'expectStorage',
      'expectApiCallOrder',
    ]);
  });

  testWidgets('permission and locale steps use registered environment handlers',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'environment_dispatch', steps: []),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
    );

    await executor.execute(const TestStep(
      type: 'setPermission',
      args: {'name': 'camera', 'value': 'denied'},
    ));
    await executor.execute(const TestStep(
      type: 'setLocale',
      args: {'locale': 'nl-NL'},
    ));

    expect(context.runtime.permissions['camera'], 'denied');
    expect(context.envOverrides['APP_LOCALE'], 'nl-NL');
    expect(context.runtime.locale?.languageCode, 'nl');
    expect(context.runtime.locale?.countryCode, 'NL');

    for (final args in [
      const <String, dynamic>{},
      const {'name': ''}
    ]) {
      await expectLater(
        executor.execute(TestStep(type: 'setPermission', args: args)),
        throwsA(
          isA<EnsembleTestFailure>().having(
            (failure) => failure.message,
            'message',
            'setPermission requires "name"',
          ),
        ),
      );
    }
    expect(context.runtime.permissions, {'camera': 'denied'});
  });

  testWidgets('resetApiCalls clears the compatibility API overlay',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'reset_api_calls', steps: []),
    );
    context.apiOverlay.recorder.record(APICallRecord(
      name: 'before-reset',
      apiDefinition: YamlMap(),
      timestamp: DateTime.now(),
    ));
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      harness: EnsembleTestHarness(appPath: 'ensemble/apps/', appHome: 'Home'),
    );

    await executor.execute(const TestStep(type: 'resetApiCalls', args: {}));

    expect(context.apiOverlay.calls, isEmpty);
  });

  testWidgets('scrollUntilVisible dispatches through its registered handler',
      (tester) async {
    expect(
      operationRegistry.lookup('scrollUntilVisible')?.notifiesConditionMatched,
      isTrue,
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView.builder(
          key: const ValueKey('items'),
          itemCount: 30,
          itemBuilder: (_, index) => SizedBox(
            height: 48,
            child: Text('Item $index', key: ValueKey('item_$index')),
          ),
        ),
      ),
    ));
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'scroll_dispatch', steps: []),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
    );
    final matched = <String>[];
    executor.onEvidenceBoundary =
        (step) => matched.add(_conditionBoundaryType(step.type));

    await executor.execute(const TestStep(
      type: 'scrollUntilVisible',
      args: {
        'id': 'item_25',
        'scrollableId': 'items',
        'timeoutMs': 1000,
      },
    ));

    expect(find.byKey(const ValueKey('item_25')), findsOneWidget);
    expect(matched, ['scrollUntilVisible']);
  });

  testWidgets('gesture steps use registered handlers and capture evidence',
      (tester) async {
    final controller = ScrollController();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(
          controller: controller,
          children: [
            SizedBox(
              key: const ValueKey('drag_target'),
              height: 80,
              child: const Text('Drag target'),
            ),
            for (var index = 0; index < 20; index++)
              SizedBox(height: 80, child: Text('Row $index')),
          ],
        ),
      ),
    ));
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'gesture_dispatch', steps: []),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
    );
    final evidenceBoundaries = <String>[];
    executor.onEvidenceBoundary = (step) {
      evidenceBoundaries.add(_conditionBoundaryType(step.type));
      if (step.type == 'drag') {
        expect(find.byKey(const ValueKey('drag_target')), findsOneWidget);
      }
    };

    await executor.execute(const TestStep(
      type: 'drag',
      args: {'id': 'drag_target', 'dx': 20, 'dy': 0},
    ));
    await executor.execute(const TestStep(
      type: 'scroll',
      args: {'delta': -120},
    ));
    expect(controller.offset, greaterThan(0));
    await executor.execute(const TestStep(
      type: 'swipe',
      args: {'direction': 'down'},
    ));
    await executor.execute(const TestStep(type: 'pullToRefresh', args: {}));

    expect(evidenceBoundaries, ['drag', 'scroll', 'swipe', 'pullToRefresh']);
    controller.dispose();
  });

  testWidgets('invalid openScreen does not capture before validation',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'open_screen_dispatch', steps: []),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      harness: EnsembleTestHarness(appPath: 'unused', appHome: 'Home'),
    );
    var evidenceCaptured = false;
    executor.onEvidenceBoundary = (_) => evidenceCaptured = true;

    await expectLater(
      executor.execute(const TestStep(type: 'openScreen', args: {})),
      throwsA(isA<EnsembleTestFailure>()),
    );

    expect(evidenceCaptured, isFalse);
  });

  testWidgets('invalid reloadScreen does not capture before validation',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    ScreenTracker().clearAll();
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'reload_without_screen', steps: []),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      harness: EnsembleTestHarness(appPath: 'unused', appHome: 'Home'),
    );
    await expectLater(
      executor.execute(const TestStep(type: 'reloadScreen', args: {})),
      throwsA(isA<EnsembleTestFailure>().having(
        (failure) => failure.message,
        'message',
        'No current screen to reload',
      )),
    );
    ScreenTracker().clearAll();
  });

  testWidgets('screen actions publish evidence at the route mutation boundary',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(
        id: 'screen_action_boundary_order',
        startScreen: 'Home',
        steps: [],
      ),
    );
    final executor = _RecordingNavigationExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      harness: EnsembleTestHarness(appPath: 'unused', appHome: 'Home'),
    );
    executor.onEvidenceBoundary = (step) {
      executor.events.add('evidence:${step.type}');
    };

    await executor.execute(
      const TestStep(type: 'openScreen', args: {'name': 'Next'}),
    );
    await executor.execute(const TestStep(type: 'reloadScreen', args: {}));

    expect(executor.events, [
      'route:Next',
      'evidence:openScreen',
      'mutation:Next',
      'route:Home',
      'evidence:reloadScreen',
      'mutation:Home',
    ]);
  });

  testWidgets('goBack evidence is published before pop', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            key: const ValueKey('go_back_push'),
            onPressed: () => Navigator.of(context).push<void>(
              PageRouteBuilder<void>(
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
                pageBuilder: (_, __, ___) => const Scaffold(
                  body: Text('Second', key: ValueKey('go_back_second')),
                ),
              ),
            ),
            child: const Text('Push'),
          ),
        ),
      ),
    ));
    await tester.tap(find.byKey(const ValueKey('go_back_push')));
    await tester.pump();

    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'go_back_evidence', steps: []),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      harness: EnsembleTestHarness(appPath: 'unused', appHome: 'Home'),
    );
    final order = <String>[];
    executor.onEvidenceBoundary = (step) {
      expect(step.type, 'goBack');
      expect(find.byKey(const ValueKey('go_back_second')), findsOneWidget);
      order.add('evidence');
    };

    await executor.execute(const TestStep(type: 'goBack', args: {}));

    expect(order, ['evidence']);
    expect(find.byKey(const ValueKey('go_back_push')), findsOneWidget);
    expect(find.byKey(const ValueKey('go_back_second')), findsNothing);
  });

  testWidgets('reset lifecycle evidence precedes first runtime mutation',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('Home')));
    final context = _NoopStorageTestContext(
      testCase: const EnsembleTestCase(
        id: 'reset_lifecycle_evidence',
        startScreen: 'Home',
        steps: [],
      ),
      apiOverlay: TestApiProviderOverlay(mocks: const {}),
      logger: TestLogger(),
      setup: const EnsembleTestSetup(),
    );
    final executor = _RecordingNavigationExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      harness: EnsembleTestHarness(appPath: 'unused', appHome: 'Home'),
    );
    final order = <String>[];
    executor.onEvidenceBoundary = (step) {
      expect(step.type, anyOf('restartApp', 'launchApp', 'resetAppState'));
      expect(context.runtime.networkOffline, isTrue);
      order.add('evidence:${step.type}');
    };

    context.runtime.networkOffline = true;
    await executor.execute(const TestStep(type: 'restartApp', args: {}));
    expect(context.runtime.networkOffline, isFalse);
    expect(order, [
      'evidence:restartApp',
    ]);
    expect(executor.events, ['route:Home', 'mutation:Home']);

    for (final name in ['restartApp', 'launchApp']) {
      order.clear();
      context.runtime.networkOffline = true;
      await LifecycleActions.execute(
        executor,
        operationRegistry.lookup(name)!,
        name,
        const {},
        step: TestStep(type: name, args: const {}),
        beforeMutation: () async => order.add('legacy-mutation-callback'),
      );
      expect(context.runtime.networkOffline, isFalse);
      expect(order, ['evidence:$name']);
    }

    order.clear();
    context.runtime.networkOffline = true;
    await executor.execute(const TestStep(type: 'resetAppState', args: {}));
    expect(context.runtime.networkOffline, isFalse);
    expect(order, [
      'evidence:resetAppState',
    ]);

    order.clear();
    context.runtime.networkOffline = true;
    await LifecycleActions.execute(
      executor,
      operationRegistry.lookup('resetAppState')!,
      'resetAppState',
      const {},
      step: const TestStep(type: 'resetAppState', args: {}),
      beforeMutation: () async => order.add('legacy-mutation-callback'),
    );
    expect(order, ['evidence:resetAppState']);
  });

  testWidgets('target assertions use registered runtime handlers',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: SingleChildScrollView(
              child: Column(children: [
        ElevatedButton(
          key: const ValueKey('enabled'),
          onPressed: () {},
          child: const Text('Enabled'),
        ),
        ElevatedButton(
          key: const ValueKey('disabled'),
          onPressed: null,
          child: const Text('Disabled'),
        ),
        TextField(
          key: const ValueKey('field'),
          controller: TextEditingController(text: 'ready'),
        ),
        const SizedBox(key: ValueKey('item')),
      ]))),
    ));
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'target_assertions', steps: []),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
    );
    final matched = <String>[];
    executor.onEvidenceBoundary =
        (step) => matched.add(_conditionBoundaryType(step.type));

    await executor.execute(const TestStep(
      type: 'expectEnabled',
      args: {'id': 'enabled'},
    ));
    await executor.execute(const TestStep(
      type: 'expectDisabled',
      args: {'id': 'disabled'},
    ));
    await executor.execute(const TestStep(
      type: 'expectValue',
      args: {'id': 'field', 'equals': 'ready'},
    ));
    await executor.execute(const TestStep(
      type: 'expectCount',
      args: {'id': 'item', 'equals': 1},
    ));
    expect(matched, [
      'expectEnabled',
      'expectDisabled',
      'expectValue',
      'expectCount',
    ]);

    await expectLater(
      executor.execute(const TestStep(
        type: 'expectCount',
        args: {'id': 'item'},
      )),
      throwsA(isA<EnsembleTestFailure>()),
    );
    expect(matched, hasLength(4));
  });

  testWidgets('httpRequest validates input through the operation dispatcher',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'http_request_validation', steps: []),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      harness: EnsembleTestHarness(appPath: 'unused', appHome: 'Home'),
    );

    await expectLater(
      executor.execute(
        const TestStep(type: 'httpRequest', args: {'url': 'invalid'}),
      ),
      throwsA(isA<EnsembleTestFailure>()),
    );
  });

  testWidgets('toggle taps the switch inside a keyed input wrapper',
      (tester) async {
    var value = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: KeyedSubtree(
              key: const ValueKey('notifications'),
              child: SizedBox(
                width: 400,
                child: Row(
                  children: [
                    const Expanded(child: Text('Notifications')),
                    CupertinoSwitch(
                      value: value,
                      onChanged: (next) => setState(() => value = next),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(
        id: 't',
        startScreen: 'Home',
        steps: [],
      ),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      harness: EnsembleTestHarness(appPath: 'ensemble/apps/', appHome: 'x'),
    );

    await executor.execute(
      const TestStep(type: 'toggle', args: {'id': 'notifications'}),
    );

    expect(value, isTrue);
  });

  testWidgets('select dispatch keeps pre-action capture before dropdown input',
      (tester) async {
    var selection = 'Red';
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(
        builder: (context, setState) => Scaffold(
          body: DropdownButton<String>(
            key: const ValueKey('color_dropdown'),
            value: selection,
            items: const [
              DropdownMenuItem(value: 'Red', child: Text('Red')),
              DropdownMenuItem(value: 'Blue', child: Text('Blue')),
            ],
            onChanged: (value) => setState(() => selection = value!),
          ),
        ),
      ),
    ));
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'select_dispatch', steps: []),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
    );
    String? selectionAtEvidenceBoundary;
    executor.onEvidenceBoundary = (step) {
      selectionAtEvidenceBoundary = '${step.type}:$selection';
    };

    await executor.execute(const TestStep(
      type: 'select',
      args: {'id': 'color_dropdown', 'value': 'Blue'},
    ));

    expect(selectionAtEvidenceBoundary, 'select:Red');
    expect(selection, 'Blue');
  });

  testWidgets('optional toggle evidence runs before the mutation',
      (tester) async {
    var value = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: KeyedSubtree(
              key: const ValueKey('notifications'),
              child: Switch(
                value: value,
                onChanged: (next) => setState(() => value = next),
              ),
            ),
          ),
        ),
      ),
    );

    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'toggle_hook', startScreen: 'Home', steps: []),
    );
    bool? valueAtEvidenceBoundary;
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      harness: EnsembleTestHarness(appPath: 'unused', appHome: 'Home'),
    );
    executor.onEvidenceBoundary = (_) => valueAtEvidenceBoundary = value;

    await executor.execute(
      const TestStep(type: 'toggle', args: {'id': 'notifications'}),
    );

    expect(valueAtEvidenceBoundary, isFalse);
    expect(value, isTrue);
  });

  testWidgets('tap evidence is captured before the tap is performed',
      (tester) async {
    var tapped = false;
    bool? tappedAtEvidenceBoundary;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ElevatedButton(
              key: const ValueKey('continue_button'),
              onPressed: () => tapped = true,
              child: const Text('Continue'),
            ),
          ),
        ),
      ),
    );

    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(
        id: 'tap_hook',
        startScreen: 'Home',
        steps: [],
      ),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      harness: EnsembleTestHarness(appPath: 'unused', appHome: 'Home'),
    );
    executor.onEvidenceBoundary = (_) => tappedAtEvidenceBoundary = tapped;

    await executor.execute(
      const TestStep(type: 'tap', args: {'id': 'continue_button'}),
    );

    expect(tappedAtEvidenceBoundary, isFalse);
    expect(tapped, isTrue);
  });

  testWidgets('tap dispatch waits for readiness before pre-action capture',
      (tester) async {
    var tapped = false;
    bool? targetWasReadyAtCapture;
    final ready = Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pumpWidget(MaterialApp(
      home: FutureBuilder<void>(
        future: ready,
        builder: (context, snapshot) => Scaffold(
          body: snapshot.connectionState == ConnectionState.done
              ? ElevatedButton(
                  key: const ValueKey('delayed_button'),
                  onPressed: () => tapped = true,
                  child: const Text('Continue'),
                )
              : const SizedBox(),
        ),
      ),
    ));
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'tap_readiness', steps: []),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
    );
    final hooks = <String>[];
    executor.onEvidenceBoundary = (step) {
      hooks.add('evidence:${step.type}');
      targetWasReadyAtCapture =
          find.byKey(const ValueKey('delayed_button')).evaluate().isNotEmpty;
    };

    await executor.execute(const TestStep(
      type: 'tap',
      args: {'id': 'delayed_button', 'timeoutMs': 1000},
    ));

    expect(targetWasReadyAtCapture, isTrue);
    expect(tapped, isTrue);
    expect(hooks, ['evidence:tap']);
  });

  testWidgets('condition callback fires after a successful assertion',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Ready'))),
    );
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'condition_hook', steps: []),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
    );
    final matched = <String>[];
    executor.onEvidenceBoundary = (step) {
      matched.add(_conditionBoundaryType(step.type));
      expect(find.text('Ready'), findsOneWidget);
    };

    await executor.execute(
      const TestStep(type: 'expectText', args: {'text': 'Ready'}),
    );
    await executor.execute(
      const TestStep(type: 'expectText', args: {
        'anyOf': ['Ready', 'Other']
      }),
    );
    await executor.execute(
      const TestStep(type: 'expectNoText', args: {'text': 'Missing'}),
    );

    expect(matched, ['expectText', 'expectText', 'expectNoText']);
  });

  testWidgets('expectText waits for text when timeoutMs is provided',
      (tester) async {
    var showReady = false;
    late void Function(VoidCallback) changeState;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            changeState = setState;
            return Scaffold(body: showReady ? const Text('Ready') : null);
          },
        ),
      ),
    );
    Timer(const Duration(milliseconds: 20), () {
      changeState(() => showReady = true);
    });
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'expect_text_wait', steps: []),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
    );

    await executor.execute(
      const TestStep(
        type: 'expectText',
        args: {'text': 'Ready', 'timeoutMs': 1000},
      ),
    );

    expect(showReady, isTrue);
  });

  testWidgets('expectVisible waits for visibility when timeoutMs is provided',
      (tester) async {
    var showReady = false;
    late void Function(VoidCallback) changeState;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            changeState = setState;
            return Scaffold(
              body: showReady
                  ? const SizedBox(
                      key: ValueKey('ready_target'),
                      width: 100,
                      height: 100,
                    )
                  : null,
            );
          },
        ),
      ),
    );
    Timer(const Duration(milliseconds: 20), () {
      changeState(() => showReady = true);
    });
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'expect_visible_wait', steps: []),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
    );

    await executor.execute(
      const TestStep(
        type: 'expectVisible',
        args: {'id': 'ready_target', 'timeoutMs': 1000},
      ),
    );

    expect(showReady, isTrue);
  });

  testWidgets('compiled expectVisible uses the same bounded readiness wait',
      (tester) async {
    var showReady = false;
    late void Function(VoidCallback) changeState;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            changeState = setState;
            return Scaffold(
              body: showReady
                  ? const SizedBox(
                      key: ValueKey('compiled_ready_target'),
                      width: 100,
                      height: 100,
                    )
                  : null,
            );
          },
        ),
      ),
    );
    Timer(const Duration(milliseconds: 20), () {
      changeState(() => showReady = true);
    });
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'compiled_expect_visible_wait', steps: []),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
    );
    final descriptor = operationRegistry.lookup('expectVisible')!;

    expect(
      await executor.executeRegisteredAssertion(
        sessionOperation(
          'expectVisible',
          input: const {'id': 'compiled_ready_target', 'timeoutMs': 1000},
        ),
        descriptor: descriptor,
      ),
      isTrue,
    );
    expect(showReady, isTrue);
  });

  testWidgets('expectVisible accepts a visible disabled control',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ElevatedButton(
            key: const ValueKey('disabled_visible_target'),
            onPressed: null,
            child: const Text('Continue'),
          ),
        ),
      ),
    );
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'visible_disabled_control', steps: []),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
    );
    const input = {'id': 'disabled_visible_target'};
    final descriptor = operationRegistry.lookup('expectVisible')!;

    expect(
      await executor.executeRegisteredAssertion(
        sessionOperation('expectVisible', input: input),
        descriptor: descriptor,
      ),
      isTrue,
    );
    await executor.execute(
      const TestStep(type: 'expectVisible', args: input),
    );
    expect(
      tester
          .widget<ElevatedButton>(
            find.byKey(const ValueKey('disabled_visible_target')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('missing tap target reports concise visible id hints',
      (tester) async {
    final hugeKey = 'custom_widget_${'x' * 400}';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ElevatedButton(
                key: const ValueKey('schedule_delete_all_config_button'),
                onPressed: () {},
                child: const Text('Delete all'),
              ),
              ElevatedButton(
                key: const ValueKey('schedules_delete_button'),
                onPressed: () {},
                child: const Text('Delete'),
              ),
              KeyedSubtree(
                key: ValueKey(hugeKey),
                child: const Text('Huge internal key'),
              ),
              const KeyedSubtree(
                key: ValueKey('{DeleteAllSchedulesButton: null}'),
                child: Text('Internal YAML map key'),
              ),
              const KeyedSubtree(
                key: ValueKey(
                  '{Text: {className: deviceActivityBadge, text: \${ badge }}',
                ),
                child: Text('Internal expression key'),
              ),
              const KeyedSubtree(
                key: ValueKey('1'),
                child: Text('Numeric internal key'),
              ),
            ],
          ),
        ),
      ),
    );

    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(
        id: 'missing_tap',
        startScreen: 'Home',
        steps: [],
      ),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      harness: EnsembleTestHarness(appPath: 'unused', appHome: 'Home'),
    );

    TestExecutionError? failure;
    try {
      await executor.execute(
        const TestStep(
          type: 'tap',
          args: {
            'id': 'schedules_delete_all_button',
            'timeoutMs': 1,
          },
        ),
      );
    } on TestExecutionError catch (error) {
      failure = error;
    }

    expect(failure, isNotNull);
    expect(
      failure!.message,
      contains(
        'Timed out after 1ms waiting for id '
        '"schedules_delete_all_button".',
      ),
    );
    expect(failure.message, contains('Closest visible ids:'));
    expect(failure.message, contains('schedule_delete_all_config_button'));
    expect(
      failure.message,
      contains(
        'Hint: check that "schedules_delete_all_button" is on the current '
        'screen/state, or add a testId/id to the intended widget.',
      ),
    );
    expect(failure.message.length, lessThan(850));
    expect(failure.message, isNot(contains('custom_widget_')));
    expect(failure.message, isNot(contains('DeleteAllSchedulesButton')));
    expect(failure.message, isNot(contains('deviceActivityBadge')));
    expect(failure.message, isNot(contains('Visible widget ids: 1')));
  });

  testWidgets('text wait timeout reports recovery hint', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Text('Parental control settings'),
              Text('Set new schedule'),
            ],
          ),
        ),
      ),
    );

    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(
        id: 'missing_text',
        startScreen: 'Home',
        steps: [],
      ),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      harness: EnsembleTestHarness(appPath: 'unused', appHome: 'Home'),
    );

    EnsembleTestFailure? failure;
    try {
      await executor.execute(
        const TestStep(
          type: 'waitFor',
          args: {
            'anyOf': [
              'Alle schema’s zijn verwijderd.',
              'All schedules have been deleted.',
            ],
            'timeoutMs': 1,
          },
        ),
      );
    } on EnsembleTestFailure catch (error) {
      failure = error;
    }

    expect(failure, isNotNull);
    expect(
      failure!.message,
      contains(
        'Timed out after 1ms waiting for any text in '
        '"Alle schema’s zijn verwijderd.", '
        '"All schedules have been deleted.".',
      ),
    );
    expect(failure.message, contains('Visible text:'));
    expect(failure.message, contains('Parental control settings'));
    expect(failure.message, isNot(contains('Visible widget ids:')));
    expect(
      failure.message,
      contains(
        'Hint: check that the app is on the expected screen/state before '
        'this assertion.',
      ),
    );
    expect(
      failure.message,
      contains(
        'Also verify that the test is running with the expected '
        'locale/translation.',
      ),
    );
  });

  testWidgets('submitText calls the pre-action hook before submitting',
      (tester) async {
    var submitted = false;
    bool? submittedAtEvidenceBoundary;
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'submit_text', startScreen: 'Home', steps: []),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
    );
    executor.onEvidenceBoundary =
        (_) => submittedAtEvidenceBoundary = submitted;

    await tester.pumpWidget(MaterialApp(
      home: Material(
        child: TextField(
          key: const ValueKey('submit_field'),
          onSubmitted: (_) => submitted = true,
        ),
      ),
    ));
    await executor.execute(const TestStep(
      type: 'submitText',
      args: {'id': 'submit_field'},
    ));

    expect(submittedAtEvidenceBoundary, isFalse);
    expect(submitted, isTrue);
  });

  testWidgets('submitText captures evidence after an off-screen field is shown',
      (tester) async {
    var submitted = false;
    var targetVisibleAtEvidence = false;
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'submit_text_visibility', steps: []),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
    );
    executor.onEvidenceBoundary = (_) {
      targetVisibleAtEvidence = find
          .byKey(const ValueKey('submit_offscreen_field'))
          .hitTestable()
          .evaluate()
          .isNotEmpty;
      expect(submitted, isFalse);
    };

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(children: [
            for (var index = 0; index < 30; index++) const SizedBox(height: 80),
            TextField(
              key: const ValueKey('submit_offscreen_field'),
              onSubmitted: (_) => submitted = true,
            ),
          ]),
        ),
      ),
    ));
    await executor.execute(const TestStep(
      type: 'submitText',
      args: {'id': 'submit_offscreen_field'},
    ));

    expect(targetVisibleAtEvidence, isTrue);
    expect(submitted, isTrue);
  });

  testWidgets('enterText captures an off-screen field before changing it',
      (tester) async {
    final controller = TextEditingController(text: 'before');
    addTearDown(controller.dispose);
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'offscreen_text_evidence', steps: []),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
    );
    var visibleAtEvidence = false;
    var textAtEvidence = '';
    executor.onEvidenceBoundary = (_) {
      visibleAtEvidence = find
          .byKey(const ValueKey('offscreen_text_target'))
          .hitTestable()
          .evaluate()
          .isNotEmpty;
      textAtEvidence = controller.text;
    };

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(children: [
            for (var index = 0; index < 30; index++) const SizedBox(height: 80),
            TextField(
              key: const ValueKey('offscreen_text_target'),
              controller: controller,
            ),
          ]),
        ),
      ),
    ));
    expect(
      find
          .byKey(const ValueKey('offscreen_text_target'))
          .hitTestable()
          .evaluate(),
      isEmpty,
    );

    await executor.execute(const TestStep(
      type: 'enterText',
      args: {'id': 'offscreen_text_target', 'value': 'after'},
    ));

    expect(visibleAtEvidence, isTrue);
    expect(textAtEvidence, 'before');
    expect(controller.text, 'after');
  });

  testWidgets('text mutations emit evidence before their first input',
      (tester) async {
    final controller = TextEditingController(text: 'clear-before');
    final submitted = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TextField(
          key: const ValueKey('text_boundary_target'),
          controller: controller,
          onSubmitted: submitted.add,
        ),
      ),
    ));
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'text_boundary', steps: []),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      harness: EnsembleTestHarness(appPath: 'ensemble/apps/', appHome: 'x'),
    );
    final boundaries = <String>[];
    executor.onEvidenceBoundary = (step) {
      boundaries.add('${step.type}:${controller.text}');
    };

    await executor.execute(
      const TestStep(type: 'clearText', args: {'id': 'text_boundary_target'}),
    );
    controller.text = 'enter-before';
    await executor.execute(
      const TestStep(
        type: 'enterText',
        args: {'id': 'text_boundary_target', 'value': 'entered'},
      ),
    );
    controller.text = 'replace-before';
    await executor.execute(
      const TestStep(
        type: 'replaceText',
        args: {'id': 'text_boundary_target', 'value': 'replaced'},
      ),
    );
    expect(controller.text, 'replaced');
    controller.text = 'submit-before';
    await executor.execute(
      const TestStep(
        type: 'submitText',
        args: {'id': 'text_boundary_target'},
      ),
    );

    expect(boundaries, [
      'clearText:clear-before',
      'enterText:enter-before',
      'replaceText:replace-before',
      'submitText:submit-before',
    ]);
    expect(controller.text, 'submit-before');
    expect(submitted, ['submit-before']);
    controller.dispose();
  });

  testWidgets('enterText waits for a field that appears asynchronously',
      (tester) async {
    final controller = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: FutureBuilder<void>(
            future: Future<void>.delayed(const Duration(milliseconds: 100)),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox();
              }
              return TextField(
                key: const ValueKey('extenderName'),
                controller: controller,
              );
            },
          ),
        ),
      ),
    );

    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(
        id: 'delayed_enter_text',
        startScreen: 'Home',
        steps: [],
      ),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      harness: EnsembleTestHarness(appPath: 'unused', appHome: 'Home'),
    );

    await executor.execute(
      const TestStep(
        type: 'enterText',
        args: {'id': 'extenderName', 'value': 'Test Extender'},
      ),
    );

    expect(controller.text, 'Test Extender');
  });

  testWidgets('mocks step updates active API mocks', (tester) async {
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(
        id: 'step_mocks',
        startScreen: 'Home',
        steps: [],
      ),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      harness: EnsembleTestHarness(appPath: 'unused', appHome: 'Home'),
    );

    await executor.execute(
      const TestStep(
        type: 'mocks',
        args: {
          'getDevices': {
            'body': {'count': 2}
          },
        },
        mocks: TestMocks(
          apis: {
            'getDevices': MockAPIResponse(body: {'count': 2}),
          },
        ),
      ),
    );

    expect(context.apiOverlay.callCount('getDevices'), 0);
    expect(context.apiOverlay.hasMock('getDevices'), isTrue);
  });

  testWidgets('tap targets the only hit-testable widget when ids repeat',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            IgnorePointer(
              child: TextButton(
                key: const ValueKey('repeated_button'),
                onPressed: () => taps += 100,
                child: const Text('Old route'),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: TextButton(
                key: const ValueKey('repeated_button'),
                onPressed: () => taps++,
                child: const Text('Current route'),
              ),
            ),
          ],
        ),
      ),
    );

    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(
        id: 'repeated_id',
        startScreen: 'Home',
        steps: [],
      ),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      harness: EnsembleTestHarness(appPath: 'unused', appHome: 'Home'),
    );
    await executor.tapWidget('repeated_button');
    expect(taps, 1);
  });

  testWidgets('tap waits until widget becomes hit-testable', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: _DelayedTappableButton(
          onTap: () => tapped = true,
        ),
      ),
    );

    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(
        id: 'delayed_tap',
        startScreen: 'Home',
        steps: [],
      ),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      harness: EnsembleTestHarness(appPath: 'unused', appHome: 'Home'),
    );

    await executor.tapWidget('delayed_button');
    expect(tapped, isTrue);
  });

  testWidgets('structured tap waits until an ID target becomes hit-testable',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: _DelayedTappableButton(onTap: () => tapped = true),
      ),
    );

    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(
        id: 'delayed_structured_tap',
        startScreen: 'Home',
        steps: [],
      ),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      harness: EnsembleTestHarness(appPath: 'unused', appHome: 'Home'),
    );

    await executor.execute(const TestStep(
      type: 'tap',
      args: {'id': 'delayed_button', 'timeoutMs': 1000},
    ));

    expect(tapped, isTrue);
  });

  testWidgets('tap resolves a rendered target before polling a new frame',
      (tester) async {
    var tapped = false;
    var delayedWorkRan = false;
    Timer(const Duration(seconds: 1), () => delayedWorkRan = true);
    await tester.pumpWidget(
      MaterialApp(
        home: ElevatedButton(
          key: const ValueKey('ready_button'),
          onPressed: () => tapped = true,
          child: const Text('Ready'),
        ),
      ),
    );

    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'ready_tap', startScreen: 'Home', steps: []),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      harness: EnsembleTestHarness(appPath: 'unused', appHome: 'Home'),
      executionConfig: const TestExecutionConfig(
        waitPollInterval: Duration(milliseconds: 500),
      ),
    );

    await executor.tapWidget('ready_button');

    expect(tapped, isTrue);
    expect(
      delayedWorkRan,
      isFalse,
      reason: 'a rendered target must not advance the polling interval first',
    );
    await tester.pump(const Duration(seconds: 1));
    expect(delayedWorkRan, isTrue);
  });

  testWidgets('tap scrolls an offscreen id into view once', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: Column(
            children: [
              for (var index = 0; index < 20; index++)
                SizedBox(
                  height: 80,
                  child: index == 19
                      ? ElevatedButton(
                          key: const ValueKey('offscreen_button'),
                          onPressed: () => tapped = true,
                          child: const Text('Open'),
                        )
                      : Text('Item $index'),
                ),
            ],
          ),
        ),
      ),
    );
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(
          id: 'offscreen_tap', startScreen: 'Home', steps: []),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      harness: EnsembleTestHarness(appPath: 'unused', appHome: 'Home'),
    );

    await executor.tapWidget('offscreen_button');
    expect(tapped, isTrue);
  });

  testWidgets('text assertions use visual visibility, not hit testing',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Stack(
          children: [
            Offstage(child: Text('Old route text')),
            IgnorePointer(child: Text('Visible non-interactive text')),
            Align(
              alignment: Alignment.bottomCenter,
              child: Text('Current route text'),
            ),
          ],
        ),
      ),
    );

    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(
        id: 'visible_text',
        startScreen: 'Home',
        steps: [],
      ),
    );
    final assertions = AssertionEngine(tester: tester, context: context);

    assertions.expectText('Current route text');
    assertions.expectText('Visible non-interactive text');
    assertions.expectNoText('Old route text');
    expect(
      () => assertions.expectText('Old route text'),
      throwsA(isA<EnsembleTestFailure>()),
    );
  });

  testWidgets('waitFor requires id or text', (tester) async {
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(
        id: 't',
        startScreen: 'Home',
        steps: [],
      ),
    );
    final harness =
        EnsembleTestHarness(appPath: 'ensemble/apps/', appHome: 'x');
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      harness: harness,
    );

    await expectLater(
      executor.execute(const TestStep(type: 'waitFor', args: {})),
      throwsA(
        isA<EnsembleTestFailure>().having(
          (e) => e.message,
          'message',
          contains('waitFor requires either'),
        ),
      ),
    );
  });

  testWidgets('waitFor does not pump when the target is already rendered',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: KeyedSubtree(
          key: ValueKey('ready'),
          child: Text('Ready'),
        ),
      ),
    );
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'immediate_wait', steps: []),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      harness: EnsembleTestHarness(appPath: 'unused', appHome: 'Home'),
    );
    final collector = BenchmarkCollector(
      caseId: 'immediate_wait',
      sample: 0,
      processId: 'test',
    );

    await RunnerBenchmark.collect(
      collector,
      () => executor.execute(
        const TestStep(
          type: 'waitFor',
          args: {'id': 'ready', 'timeoutMs': 1000},
        ),
      ),
    );

    final waitSpan = collector.spans.singleWhere(
      (span) => span.service == 'execution' && span.operation == 'waitFor',
    );
    expect(waitSpan.counters['pollingAttempts'], isNull);
  });

  testWidgets('setDevice updates the render surface size', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SizedBox.expand()),
    );
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(
        id: 'set_device_test',
        startScreen: 'Home',
        steps: [],
      ),
    );
    final harness =
        EnsembleTestHarness(appPath: 'ensemble/apps/', appHome: 'x');
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      harness: harness,
    );

    await executor.execute(
      const TestStep(
        type: 'setDevice',
        args: {'width': 393, 'height': 852},
      ),
    );

    expect(tester.binding.renderViews.first.size, const Size(393, 852));
  });

  testWidgets('setDevice rejects physical-display mode before mutation',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('Home')));
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'set_device_integration', steps: []),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      harness: EnsembleTestHarness(
        appPath: 'ensemble/apps/',
        appHome: 'Home',
        executionMode: ExecutionMode.integration,
      ),
    );
    final originalSize = tester.view.physicalSize;

    await expectLater(
      executor.execute(const TestStep(
        type: 'setDevice',
        args: {'width': 393, 'height': 852},
      )),
      throwsA(
        isA<EnsembleTestFailure>().having(
          (failure) => failure.message,
          'message',
          contains('cannot override the simulator/emulator display'),
        ),
      ),
    );

    expect(tester.view.physicalSize, originalSize);
    expect(context.runtime.deviceSize, isNull);
  });

  testWidgets('setTheme updates state and rebuilds theme listeners',
      (tester) async {
    final themeManager = EnsembleThemeManager();
    themeManager.reset();
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        themeManager.init(
          context,
          {
            'Light': YamlMap.wrap({}),
            'Dark': YamlMap.wrap({}),
          },
          'Light',
        );
        return StreamBuilder<ThemeChangeEvent>(
          stream: AppEventBus().eventBus.on<ThemeChangeEvent>(),
          builder: (context, _) => Text(themeManager.currentThemeName),
        );
      }),
    ));
    expect(find.text('Light'), findsOneWidget);

    final testContext = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'set_theme', steps: []),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: testContext,
      assertions: AssertionEngine(tester: tester, context: testContext),
      harness: EnsembleTestHarness(appPath: 'ensemble/apps/', appHome: 'x'),
    );

    await executor.execute(
      const TestStep(type: 'setTheme', args: {'mode': 'dark'}),
    );

    expect(themeManager.currentThemeName, 'Dark');
    expect(testContext.envOverrides['APP_THEME'], 'dark');
    expect(testContext.runtime.themeMode, 'Dark');
    expect(find.text('Dark'), findsOneWidget);
    themeManager.reset();
  });

  testWidgets(
    'navigation assertions dispatch through registered handlers',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Devices'))),
      );
      final context = EnsembleTestContext.fromTestCase(
        const EnsembleTestCase(id: 'navigation_assertions', steps: []),
      );
      final executor = TestStepExecutor(
        tester: tester,
        context: context,
        assertions: AssertionEngine(tester: tester, context: context),
        harness: EnsembleTestHarness(appPath: 'ensemble/apps/', appHome: 'x'),
        services: ApplicationTestServices(
          navigation: _FakeNavigationService(
            currentRoute: 'Devices',
            routeHistory: const ['Home', 'Devices'],
          ),
        ),
      );
      final matched = <String>[];
      executor.onEvidenceBoundary =
          (step) => matched.add(_conditionBoundaryType(step.type));

      await executor.execute(
        const TestStep(type: 'expectScreen', args: {'screen': 'Devices'}),
      );
      await executor.execute(
        const TestStep(type: 'expectVisited', args: {'screen': 'Home'}),
      );

      expect(matched, ['expectNavigateTo', 'expectVisited']);
    },
  );

  testWidgets('navigation history assertions preserve their outcomes',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('Home')));
    final navigationFlow = NavigationFlowRecorder();
    final screenTracker = ScreenTracker();
    navigationFlow.seed(['Home', 'Devices']);
    screenTracker.clearAll();
    addTearDown(() {
      navigationFlow.clear();
      screenTracker.clearAll();
    });

    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'navigation_history_assertions', steps: []),
      navigationFlow: navigationFlow,
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      harness: EnsembleTestHarness(appPath: 'ensemble/apps/', appHome: 'x'),
    );
    final matched = <String>[];
    executor.onEvidenceBoundary =
        (step) => matched.add(_conditionBoundaryType(step.type));

    await executor.execute(
      const TestStep(type: 'expectNotVisited', args: {'screen': 'Profile'}),
    );
    await executor.execute(
      const TestStep(type: 'expectBackStack', args: {'screens': []}),
    );
    await executor.execute(
      const TestStep(type: 'expectCanGoBack', args: {'equals': false}),
    );
    expect(matched, ['expectNotVisited', 'expectBackStack', 'expectCanGoBack']);

    await expectLater(
      executor.execute(const TestStep(type: 'expectNotVisited', args: {})),
      throwsA(isA<EnsembleTestFailure>().having(
        (failure) => failure.message,
        'message',
        'expectNotVisited requires "screen"',
      )),
    );
    await expectLater(
      executor.execute(
        const TestStep(type: 'expectBackStack', args: {
          'screens': ['Home']
        }),
      ),
      throwsA(isA<EnsembleTestFailure>().having(
        (failure) => failure.message,
        'message',
        'Back stack too short. Expected suffix [Home], got []',
      )),
    );
    await expectLater(
      executor.execute(const TestStep(type: 'expectCanGoBack', args: {})),
      throwsA(isA<EnsembleTestFailure>().having(
        (failure) => failure.message,
        'message',
        'Expected canGoBack=true, but history length is 0.',
      )),
    );
  });

  testWidgets('runtime log and error assertions preserve recorded state',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('Home')));
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'runtime_log_assertions', steps: []),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      harness: EnsembleTestHarness(appPath: 'ensemble/apps/', appHome: 'x'),
    );
    final matched = <String>[];
    executor.onEvidenceBoundary =
        (step) => matched.add(_conditionBoundaryType(step.type));

    await executor
        .execute(const TestStep(type: 'expectNoConsoleErrors', args: {}));
    await executor
        .execute(const TestStep(type: 'expectNoRenderErrors', args: {}));
    await executor.execute(const TestStep(type: 'expectNoErrors', args: {}));
    context.runtime.consoleLogs.add('INFO: Screen loaded');
    context.runtime.flutterErrors.add('RenderFlex overflowed by 12 pixels');
    await executor.execute(
      const TestStep(
        type: 'expectConsoleLog',
        args: {'contains': 'Screen loaded'},
      ),
    );
    await executor.execute(
      const TestStep(type: 'expectError', args: {'contains': 'overflowed'}),
    );

    expect(matched, [
      'expectNoConsoleErrors',
      'expectNoRenderErrors',
      'expectNoErrors',
      'expectConsoleLog',
      'expectError',
    ]);

    await expectLater(
      executor.execute(
        const TestStep(type: 'expectError', args: {'contains': 'missing'}),
      ),
      throwsA(isA<EnsembleTestFailure>().having(
        (failure) => failure.message,
        'message',
        contains('Expected error containing "missing"'),
      )),
    );
    await expectLater(
      executor.execute(const TestStep(type: 'expectNoErrors', args: {})),
      throwsA(isA<EnsembleTestFailure>().having(
        (failure) => failure.message,
        'message',
        contains('Expected no render errors'),
      )),
    );
    await expectLater(
      executor.execute(const TestStep(type: 'expectNoConsoleErrors', args: {})),
      throwsA(isA<EnsembleTestFailure>().having(
        (failure) => failure.message,
        'message',
        contains('Expected no console errors'),
      )),
    );
  });

  testWidgets('semantics assertions preserve target and description behavior',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Semantics(
          key: ValueKey('continue_button'),
          label: 'Continue',
          child: ExcludeSemantics(
            child: SizedBox(width: 100, height: 40, child: Text('Continue')),
          ),
        ),
      ),
    ));
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'semantics_assertions', steps: []),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      harness: EnsembleTestHarness(appPath: 'ensemble/apps/', appHome: 'x'),
    );
    final matched = <String>[];
    executor.onEvidenceBoundary =
        (step) => matched.add(_conditionBoundaryType(step.type));

    await executor.execute(
      const TestStep(type: 'expectAccessible', args: {'id': 'continue_button'}),
    );
    await executor.execute(
      const TestStep(
        type: 'expectSemanticsLabel',
        args: {'id': 'continue_button', 'label': 'Continue'},
      ),
    );
    await executor.execute(
      const TestStep(type: 'expectNoOverflow', args: {'id': 'continue_button'}),
    );
    expect(matched, [
      'expectAccessible',
      'expectSemanticsLabel',
      'expectNoOverflow',
    ]);

    await expectLater(
      executor.execute(
        const TestStep(
          type: 'expectSemanticsLabel',
          args: {'id': 'continue_button', 'label': 'Proceed'},
        ),
      ),
      throwsA(isA<EnsembleTestFailure>().having(
        (failure) => failure.message,
        'message',
        'Expected semantics label "Proceed" for continue_button, got "Continue".',
      )),
    );
    await expectLater(
      executor.execute(
        const TestStep(type: 'expectAccessible', args: {'id': 'missing'}),
      ),
      throwsA(isA<EnsembleTestFailure>().having(
        (failure) => failure.message,
        'message',
        'expectAccessible: missing not found.',
      )),
    );
    await expectLater(
      executor.execute(
        const TestStep(type: 'expectNoOverflow', args: {'id': 'missing'}),
      ),
      throwsA(isA<EnsembleTestFailure>().having(
        (failure) => failure.message,
        'message',
        'expectNoOverflow: missing not found.',
      )),
    );
    semantics.dispose();
  });

  testWidgets('list and existence assertions preserve selection semantics',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            Column(
              key: ValueKey('items_list'),
              children: [
                Text('Alpha', key: ValueKey('row_alpha')),
                Text('Beta', key: ValueKey('row_beta')),
              ],
            ),
            Column(key: ValueKey('empty_list')),
            Text('A great title'),
          ],
        ),
      ),
    ));
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'list_assertions', steps: []),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      harness: EnsembleTestHarness(appPath: 'ensemble/apps/', appHome: 'x'),
    );
    final matched = <String>[];
    executor.onEvidenceBoundary =
        (step) => matched.add(_conditionBoundaryType(step.type));

    await executor.execute(
      const TestStep(type: 'expectExists', args: {'id': 'row_alpha'}),
    );
    await executor.execute(
      const TestStep(type: 'expectNotExists', args: {'id': 'not_present'}),
    );
    await executor.execute(
      const TestStep(type: 'expectTextContains', args: {'text': 'great tit'}),
    );
    await executor.execute(
      const TestStep(
        type: 'expectTextContains',
        args: {
          'anyOf': ['missing', 'title']
        },
      ),
    );
    await executor.execute(
      const TestStep(
        type: 'expectTextContains',
        args: {'text': 'title', 'timeoutMs': 20},
      ),
    );
    await executor.execute(
      const TestStep(
        type: 'expectListCount',
        args: {'id': 'items_list', 'equals': 4},
      ),
    );
    await executor.execute(
      const TestStep(
        type: 'expectListCount',
        args: {'id': 'items_list', 'itemId': 'row_alpha', 'equals': 1},
      ),
    );
    await executor.execute(
      const TestStep(
        type: 'expectListContains',
        args: {'id': 'items_list', 'text': 'Beta'},
      ),
    );
    await executor.execute(
      const TestStep(type: 'expectListItem', args: {'itemId': 'row_alpha'}),
    );
    await executor.execute(
      const TestStep(type: 'expectEmpty', args: {'id': 'empty_list'}),
    );
    await executor.execute(
      const TestStep(type: 'expectNotEmpty', args: {'id': 'items_list'}),
    );
    expect(matched, [
      'expectExists',
      'expectNotExists',
      'expectTextContains',
      'expectTextContains',
      'expectTextContains',
      'expectListCount',
      'expectListCount',
      'expectListContains',
      'expectListItem',
      'expectEmpty',
      'expectNotEmpty',
    ]);

    await expectLater(
      executor.execute(
        const TestStep(
          type: 'expectListCount',
          args: {'id': 'items_list', 'equals': 2},
        ),
      ),
      throwsA(isA<EnsembleTestFailure>().having(
        (failure) => failure.message,
        'message',
        'Expected 2 items in items_list, found 4.',
      )),
    );
  });

  testWidgets('checkbox and property handlers preserve action semantics',
      (tester) async {
    final semantics = tester.ensureSemantics();
    var checked = false;
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(
        builder: (context, setState) => Scaffold(
          body: Checkbox(
            key: const ValueKey('terms_checkbox'),
            value: checked,
            semanticLabel: 'Terms',
            onChanged: (value) => setState(() => checked = value ?? false),
          ),
        ),
      ),
    ));
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'checkbox_handlers', steps: []),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      harness: EnsembleTestHarness(appPath: 'ensemble/apps/', appHome: 'x'),
    );
    final evidenceBoundaries = <String>[];
    final matched = <String>[];
    executor.onEvidenceBoundary = (step) {
      if (step.type == 'check' || step.type == 'uncheck') {
        evidenceBoundaries.add('${step.type}:$checked');
      } else {
        matched.add(_conditionBoundaryType(step.type));
      }
    };

    await executor.execute(
      const TestStep(type: 'check', args: {'id': 'terms_checkbox'}),
    );
    expect(checked, isTrue);
    await executor.execute(
      const TestStep(type: 'check', args: {'id': 'terms_checkbox'}),
    );
    expect(checked, isTrue);
    await executor.execute(
      const TestStep(
        type: 'expectChecked',
        args: {'id': 'terms_checkbox'},
      ),
    );
    await executor.execute(
      const TestStep(
        type: 'expectSelected',
        args: {'id': 'terms_checkbox'},
      ),
    );
    await executor.execute(
      const TestStep(
        type: 'expectProperty',
        args: {'id': 'terms_checkbox', 'equals': 'Terms'},
      ),
    );
    await executor.execute(
      const TestStep(type: 'uncheck', args: {'id': 'terms_checkbox'}),
    );
    expect(checked, isFalse);
    await executor.execute(
      const TestStep(
        type: 'expectChecked',
        args: {'id': 'terms_checkbox', 'equals': false},
      ),
    );
    expect(evidenceBoundaries, ['check:false', 'uncheck:true']);
    expect(matched,
        ['expectChecked', 'expectSelected', 'expectProperty', 'expectChecked']);

    await expectLater(
      executor.execute(
        const TestStep(
          type: 'expectStyle',
          args: {'id': 'terms_checkbox', 'equals': 'anything'},
        ),
      ),
      throwsA(isA<EnsembleTestFailure>().having(
        (failure) => failure.message,
        'message',
        'Unsupported property "style".',
      )),
    );
    semantics.dispose();
  });

  testWidgets('focus and gesture handlers preserve ordering and defaults',
      (tester) async {
    var taps = 0;
    var longPresses = 0;
    final focusNode = FocusNode();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            TextButton(
              key: const ValueKey('double_tap_target'),
              onPressed: () => taps++,
              child: const Text('Tap twice'),
            ),
            GestureDetector(
              key: const ValueKey('long_press_target'),
              onLongPress: () => longPresses++,
              child: const ColoredBox(
                color: Colors.blue,
                child: SizedBox(width: 100, height: 40),
              ),
            ),
            TextField(
              key: const ValueKey('focus_target'),
              focusNode: focusNode,
            ),
          ],
        ),
      ),
    ));
    addTearDown(focusNode.dispose);
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'focus_gesture_handlers', steps: []),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      harness: EnsembleTestHarness(appPath: 'ensemble/apps/', appHome: 'x'),
    );
    final evidenceBoundaries = <String>[];
    executor.onEvidenceBoundary = (step) => evidenceBoundaries.add(
          '${step.type}:$taps:$longPresses:${focusNode.hasFocus}',
        );

    await executor.execute(
      const TestStep(type: 'doubleTap', args: {'id': 'double_tap_target'}),
    );
    await executor.execute(
      const TestStep(type: 'longPress', args: {'id': 'long_press_target'}),
    );
    await executor.execute(
      const TestStep(type: 'focus', args: {'id': 'focus_target'}),
    );
    await executor.execute(const TestStep(type: 'unfocus', args: {}));

    expect(taps, 2);
    expect(longPresses, 1);
    expect(focusNode.hasFocus, isFalse);
    expect(evidenceBoundaries, [
      'doubleTap:0:0:false',
      'longPress:2:0:false',
      'focus:2:1:false',
      'unfocus:2:1:true',
    ]);
  });

  testWidgets('selectIndex keeps index zero as its default', (tester) async {
    var expanded = false;
    String? selected;
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(
        builder: (context, setState) => Scaffold(
          body: Column(
            children: [
              TextButton(
                key: const ValueKey('select_index_target'),
                onPressed: () => setState(() => expanded = true),
                child: const Text('Choose'),
              ),
              if (expanded) ...[
                ListTile(
                  title: const Text('First'),
                  onTap: () => setState(() => selected = 'First'),
                ),
                ListTile(
                  title: const Text('Second'),
                  onTap: () => setState(() => selected = 'Second'),
                ),
              ],
            ],
          ),
        ),
      ),
    ));
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'select_index_handler', steps: []),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      harness: EnsembleTestHarness(appPath: 'ensemble/apps/', appHome: 'x'),
    );
    final evidenceBoundaries = <bool>[];
    executor.onEvidenceBoundary = (_) => evidenceBoundaries.add(expanded);

    await executor.execute(
      const TestStep(type: 'selectIndex', args: {'id': 'select_index_target'}),
    );

    expect(selected, 'First');
    expect(evidenceBoundaries, [false]);
  });

  testWidgets(
    'waitForNavigation succeeds when screen was visited but already left',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Devices'))),
      );

      final context = EnsembleTestContext.fromTestCase(
        const EnsembleTestCase(
          id: 'nav_history',
          startScreen: 'Home',
          steps: [],
        ),
      );
      final navigation = _FakeNavigationService(
        currentRoute: 'Devices',
        routeHistory: const ['Loading', 'Home', 'Devices'],
      );
      final executor = TestStepExecutor(
        tester: tester,
        context: context,
        assertions: AssertionEngine(tester: tester, context: context),
        harness: EnsembleTestHarness(appPath: 'ensemble/apps/', appHome: 'x'),
        services: ApplicationTestServices(navigation: navigation),
        executionConfig: const TestExecutionConfig(
          defaultWaitTimeout: Duration(milliseconds: 300),
          waitPollInterval: Duration(milliseconds: 50),
        ),
      );

      await executor.execute(
        const TestStep(
          type: 'waitForNavigation',
          args: {'screen': 'Home', 'timeoutMs': 300},
        ),
      );
    },
  );

  testWidgets(
    'waitForNavigation accepts a visible target when navigation service is stale',
    (tester) async {
      ScreenTracker().clearAll();
      addTearDown(ScreenTracker().clearAll);
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Home'))),
      );
      ScreenTracker().trackScreen(screenName: 'Home');

      final context = EnsembleTestContext.fromTestCase(
        const EnsembleTestCase(id: 'navigation_visible_target', steps: []),
      );
      final executor = TestStepExecutor(
        tester: tester,
        context: context,
        assertions: AssertionEngine(tester: tester, context: context),
        services: ApplicationTestServices(
          navigation: _FakeNavigationService(
            currentRoute: null,
            routeHistory: const [],
          ),
        ),
        executionConfig: const TestExecutionConfig(
          defaultWaitTimeout: Duration(milliseconds: 20),
          waitPollInterval: Duration(milliseconds: 2),
        ),
      );
      var matchedCaptures = 0;
      executor.onEvidenceBoundary = (_) => matchedCaptures++;

      await executor.execute(const TestStep(
        type: 'waitForNavigation',
        args: {'screen': 'Home', 'timeoutMs': 20},
      ));

      expect(matchedCaptures, 1);
      expect(context.navigationFlow.flow, isEmpty);
    },
  );

  testWidgets(
    'waitForNavigation reads history from its own attempt context',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Devices'))),
      );
      final firstContext = EnsembleTestContext.fromTestCase(
        const EnsembleTestCase(id: 'first_attempt_navigation', steps: []),
        navigationFlow: NavigationFlowRecorder()..seed(['Home']),
      );
      final secondContext = EnsembleTestContext.fromTestCase(
        const EnsembleTestCase(id: 'second_attempt_navigation', steps: []),
        navigationFlow: NavigationFlowRecorder(),
      );

      TestStepExecutor createExecutor(EnsembleTestContext context) =>
          TestStepExecutor(
            tester: tester,
            context: context,
            assertions: AssertionEngine(tester: tester, context: context),
            executionConfig: const TestExecutionConfig(
              defaultWaitTimeout: Duration(milliseconds: 20),
              waitPollInterval: Duration.zero,
            ),
          );

      const step = TestStep(
        type: 'waitForNavigation',
        args: {'screen': 'Home', 'timeoutMs': 20},
      );
      await createExecutor(firstContext).execute(step);
      expect(firstContext.navigationFlow,
          isNot(same(secondContext.navigationFlow)));
      expect(firstContext.navigationFlow.flow, contains('Home'));
      expect(secondContext.navigationFlow.flow, isEmpty);
    },
  );

  testWidgets(
    'waitForNavigation accepts an attempt-recorded route when the service has moved on',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Home'))),
      );
      final context = EnsembleTestContext.fromTestCase(
        const EnsembleTestCase(
            id: 'transient_route_already_recorded', steps: []),
        navigationFlow: NavigationFlowRecorder()
          ..seed(['InitApp', 'AutoSignIn_Gateway', 'Home']),
      );
      final executor = TestStepExecutor(
        tester: tester,
        context: context,
        assertions: AssertionEngine(tester: tester, context: context),
        services: ApplicationTestServices(
          navigation: _FakeNavigationService(
            currentRoute: 'Home',
            routeHistory: const ['InitApp', 'Home'],
          ),
        ),
        executionConfig: const TestExecutionConfig(
          defaultWaitTimeout: Duration(milliseconds: 20),
          waitPollInterval: Duration.zero,
        ),
      );

      await executor.execute(
        const TestStep(
          type: 'waitForNavigation',
          args: {
            'screen': 'AutoSignIn_Gateway',
            'timeoutMs': 20,
          },
        ),
      );
    },
  );

  testWidgets(
    'waitForNavigation resolves a transient visit without capturing a later route',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Devices'))),
      );

      final history = <String>[];
      final navigation = _MutableNavigationService(
        currentRoute: 'Devices',
        routeHistory: history,
      );
      final context = EnsembleTestContext.fromTestCase(
        const EnsembleTestCase(
          id: 'transient_navigation_evidence',
          startScreen: 'Home',
          steps: [],
        ),
        navigationFlow: NavigationFlowRecorder(),
      );
      final executor = TestStepExecutor(
        tester: tester,
        context: context,
        assertions: AssertionEngine(tester: tester, context: context),
        harness: EnsembleTestHarness(appPath: 'ensemble/apps/', appHome: 'x'),
        services: ApplicationTestServices(navigation: navigation),
        executionConfig: const TestExecutionConfig(
          defaultWaitTimeout: Duration(milliseconds: 300),
          waitPollInterval: Duration(milliseconds: 10),
        ),
      );
      final evidenceCallbacks = <String>[];
      final flushedScreens = <String>{};
      executor.onEvidenceBoundary = (matchedStep) {
        if (matchedStep.type == 'waitForNavigation') {
          expect(flushedScreens, contains(matchedStep.args['screen']));
        }
        evidenceCallbacks.add(matchedStep.type);
      };
      executor.onOperationEvidenceBoundary = (_, detail) {
        evidenceCallbacks.add(detail);
      };

      final transientEvent = Future<void>.delayed(
        Duration.zero,
        () async {
          // The target is visible only long enough to publish its navigation
          // event. The service already reports the next route by the time the
          // wait observes history.
          context.navigationFlow.recordScreenChange(
            VisibleScreen(
              screenName: 'Home',
              visibleSince: DateTime.now(),
            ),
          );
          history.addAll(const ['Home', 'Devices']);
          await context.navigationFlow.flushPending();
          flushedScreens.add('Home');
        },
      );

      await executor.execute(
        const TestStep(
          type: 'waitForNavigation',
          args: {'screen': 'Home', 'timeoutMs': 300},
        ),
      );
      await transientEvent;

      // The service has advanced to Devices by the time the queued route
      // events are processed. The wait still recognizes the transient visit,
      // but must leave evidence to the rendered step-completion boundary
      // rather than pairing Devices with a Transient route match.
      expect(evidenceCallbacks, isEmpty);
      expect(find.text('Devices'), findsOneWidget);
      expect(find.text('Home'), findsNothing);

      await executor.executeWaitOperation(
        sessionOperation('settle', input: const {'timeoutMs': 300}),
      );
      expect(evidenceCallbacks.last, 'condition:settle');
    },
  );

  testWidgets(
      'waitForNavigation accepts a transient tracker event before its deadline',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    final screenTracker = ScreenTracker()..clearAll();
    addTearDown(screenTracker.clearAll);
    final pending = Completer<void>();
    final routeHistory = <String>[];
    final start = tester.binding.clock.now();
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'navigation_pending_call', steps: []),
      apiOverlay: _PendingNavigationApiOverlay(pending: pending),
    );
    final navigation = _MutableNavigationService(
      currentRoute: null,
      routeHistory: routeHistory,
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      services: ApplicationTestServices(navigation: navigation),
      executionConfig: const TestExecutionConfig(
        waitPollInterval: Duration(milliseconds: 2),
        settleStepDuration: Duration(milliseconds: 4),
      ),
    );

    Future<void>.delayed(const Duration(milliseconds: 10), () {
      screenTracker.trackScreen(screenName: 'Home');
      screenTracker.trackScreen(screenName: 'Devices');
      routeHistory.add('Devices');
      pending.complete();
    });
    await executor.execute(const TestStep(
      type: 'waitForNavigation',
      args: {'screen': 'Home', 'timeoutMs': 20},
    ));
    expect(routeHistory, ['Devices']);
    expect(
      tester.binding.clock.now().difference(start),
      lessThanOrEqualTo(const Duration(milliseconds: 20)),
    );
  });

  testWidgets(
      'waitForNavigation accepts a target during the bounded live-call drain',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    final screenTracker = ScreenTracker()..clearAll();
    addTearDown(screenTracker.clearAll);
    final pending = Completer<void>();
    final routeHistory = <String>[];
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'navigation_call_completed', steps: []),
      apiOverlay: _PendingNavigationApiOverlay(pending: pending),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      services: ApplicationTestServices(
        navigation: _MutableNavigationService(
          currentRoute: null,
          routeHistory: routeHistory,
        ),
      ),
      executionConfig: const TestExecutionConfig(
        waitPollInterval: Duration(milliseconds: 2),
        settleStepDuration: Duration(milliseconds: 4),
      ),
    );
    final start = tester.binding.clock.now();
    Future<void>.delayed(const Duration(milliseconds: 25), () {
      screenTracker.trackScreen(screenName: 'Home');
      routeHistory.add('Home');
      pending.complete();
    });

    await executor.execute(const TestStep(
      type: 'waitForNavigation',
      args: {'screen': 'Home', 'timeoutMs': 20},
    ));

    expect(
      tester.binding.clock.now().difference(start),
      allOf(
        greaterThan(const Duration(milliseconds: 20)),
        lessThanOrEqualTo(const Duration(milliseconds: 40)),
      ),
    );
    expect(routeHistory, ['Home']);
  });

  testWidgets(
      'waitForNavigation returns on route while unrelated live work remains',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    final screenTracker = ScreenTracker()..clearAll();
    addTearDown(screenTracker.clearAll);
    // This call is intentionally unrelated to the route and never completes.
    // Navigation should be gated on the route event, not global quiescence.
    final unrelatedCall = Completer<void>();
    final routeHistory = <String>[];
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'navigation_unrelated_live_call', steps: []),
      apiOverlay: _PendingNavigationApiOverlay(pending: unrelatedCall),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      services: ApplicationTestServices(
        navigation: _MutableNavigationService(
          currentRoute: null,
          routeHistory: routeHistory,
        ),
      ),
      executionConfig: const TestExecutionConfig(
        waitPollInterval: Duration(milliseconds: 2),
        settleStepDuration: Duration(milliseconds: 4),
      ),
    );
    final collector = BenchmarkCollector(
      caseId: 'navigation_unrelated_live_call',
      sample: 0,
      processId: 'test',
    );
    final startedAt = tester.binding.clock.now();
    Future<void>.delayed(const Duration(milliseconds: 25), () {
      screenTracker.trackScreen(screenName: 'Home');
      routeHistory.add('Home');
    });

    await RunnerBenchmark.collect(
      collector,
      () => executor.execute(const TestStep(
        type: 'waitForNavigation',
        args: {'screen': 'Home', 'timeoutMs': 20},
      )),
    );

    expect(routeHistory, ['Home']);
    expect(context.apiOverlay.hasPendingLiveCalls, isTrue);
    expect(
      tester.binding.clock.now().difference(startedAt),
      lessThan(const Duration(milliseconds: 100)),
    );
    final drainSpan = collector.spans.singleWhere(
      (span) =>
          span.service == 'execution' &&
          span.operation == 'navigationLiveCallDrain',
    );
    expect(drainSpan.elapsedUs, greaterThan(0));
    expect(drainSpan.elapsedUs, lessThan(100000));
    expect(drainSpan.dimensions['authoredTimeoutMs'], 20);
    expect(drainSpan.dimensions['drainBudgetMs'], 60);
    expect(drainSpan.counters['pendingCallsAtDrainStart'], 1);
  });

  testWidgets(
      'waitForNavigation observes route from follow-up async work within its cap',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    final screenTracker = ScreenTracker()..clearAll();
    addTearDown(screenTracker.clearAll);
    final pending = Completer<void>();
    final routeHistory = <String>[];
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'navigation_post_completion_event', steps: []),
      apiOverlay: _PendingNavigationApiOverlay(pending: pending),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      services: ApplicationTestServices(
        navigation: _MutableNavigationService(
          currentRoute: null,
          routeHistory: routeHistory,
        ),
      ),
      executionConfig: const TestExecutionConfig(
        waitPollInterval: Duration(milliseconds: 2),
        settleStepDuration: Duration(milliseconds: 4),
      ),
    );
    final start = tester.binding.clock.now();
    Future<void>.delayed(const Duration(milliseconds: 1100), () {
      pending.complete();
      // API response handling can dispatch a host callback after the live-call
      // snapshot completes. Model that untracked continuation taking 500ms.
      Future<void>.delayed(const Duration(milliseconds: 500), () {
        screenTracker.trackScreen(screenName: 'Home');
        routeHistory.add('Home');
      });
    });

    await executor.execute(const TestStep(
      type: 'waitForNavigation',
      args: {'screen': 'Home', 'timeoutMs': 1000},
    ));

    expect(routeHistory, ['Home']);
    expect(
      tester.binding.clock.now().difference(start),
      allOf(
        greaterThan(const Duration(milliseconds: 1000)),
        lessThanOrEqualTo(const Duration(milliseconds: 2000)),
      ),
    );
  });

  testWidgets('waitForNavigation drains live work started by a completed call',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    final screenTracker = ScreenTracker()..clearAll();
    addTearDown(screenTracker.clearAll);
    final initialCall = Completer<void>();
    final followUpCall = Completer<void>();
    final routeHistory = <String>[];
    final startedAt = tester.binding.clock.now();
    late final _ChainedNavigationApiOverlay overlay;
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'navigation_chained_live_work', steps: []),
      apiOverlay: overlay = _ChainedNavigationApiOverlay(
        initialCall: initialCall,
        followUpCall: followUpCall,
        followUpDelay: const Duration(milliseconds: 40),
        onFollowUpDrained: () {
          screenTracker.trackScreen(screenName: 'Home');
          routeHistory.add('Home');
        },
      ),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      services: ApplicationTestServices(
        navigation: _MutableNavigationService(
          currentRoute: null,
          routeHistory: routeHistory,
        ),
      ),
      executionConfig: const TestExecutionConfig(
        waitPollInterval: Duration(milliseconds: 2),
        settleStepDuration: Duration(milliseconds: 4),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 25), () {
      overlay.completeInitialAndStartFollowUp();
    });

    await executor.execute(const TestStep(
      type: 'waitForNavigation',
      args: {'screen': 'Home', 'timeoutMs': 20},
    ));

    expect(routeHistory, ['Home']);
    expect(followUpCall.isCompleted, isTrue);
    expect(
      tester.binding.clock.now().difference(startedAt),
      greaterThan(const Duration(milliseconds: 60)),
    );
  });

  testWidgets(
      'waitForNavigation leaves a short route window after a late call completes',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    final screenTracker = ScreenTracker()..clearAll();
    addTearDown(screenTracker.clearAll);
    final pending = Completer<void>();
    final routeHistory = <String>[];
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'navigation_late_call_route', steps: []),
      apiOverlay: _PendingNavigationApiOverlay(pending: pending),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      services: ApplicationTestServices(
        navigation: _MutableNavigationService(
          currentRoute: null,
          routeHistory: routeHistory,
        ),
      ),
      executionConfig: const TestExecutionConfig(
        waitPollInterval: Duration(milliseconds: 2),
        settleStepDuration: Duration(milliseconds: 4),
      ),
    );
    final start = tester.binding.clock.now();
    Future<void>.delayed(const Duration(milliseconds: 39), () {
      pending.complete();
      Future<void>.delayed(const Duration(milliseconds: 6), () {
        screenTracker.trackScreen(screenName: 'Home');
        routeHistory.add('Home');
      });
    });

    await executor.execute(const TestStep(
      type: 'waitForNavigation',
      args: {'screen': 'Home', 'timeoutMs': 20},
    ));

    expect(routeHistory, ['Home']);
    expect(
      tester.binding.clock.now().difference(start),
      lessThanOrEqualTo(const Duration(milliseconds: 60)),
    );
  });

  testWidgets(
      'waitForNavigation caps follow-up work started after the deadline',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    final screenTracker = ScreenTracker()..clearAll();
    addTearDown(screenTracker.clearAll);
    final initialCall = Completer<void>();
    final laterCall = Completer<void>();
    final routeHistory = <String>[];
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'navigation_snapshot_bound', steps: []),
      apiOverlay: _SnapshotNavigationApiOverlay(
        initialCall: initialCall,
        laterCall: laterCall,
      ),
    );
    final overlay = context.apiOverlay as _SnapshotNavigationApiOverlay;
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      services: ApplicationTestServices(
        navigation: _MutableNavigationService(
          currentRoute: null,
          routeHistory: routeHistory,
        ),
      ),
      executionConfig: const TestExecutionConfig(
        waitPollInterval: Duration(milliseconds: 2),
        settleStepDuration: Duration(milliseconds: 4),
      ),
    );
    final start = tester.binding.clock.now();
    Future<void>.delayed(
        const Duration(milliseconds: 25), overlay.startLaterCall);
    Future<void>.delayed(
        const Duration(milliseconds: 30), initialCall.complete);

    await expectLater(
      executor.execute(const TestStep(
        type: 'waitForNavigation',
        args: {'screen': 'Home', 'timeoutMs': 20},
      )),
      throwsA(isA<EnsembleTestFailure>().having(
        (failure) => failure.message,
        'message',
        allOf(
          contains('bounded live-call drain expired'),
          contains('liveCallsPendingAtDeadline=true'),
        ),
      )),
    );
    expect(
      tester.binding.clock.now().difference(start),
      lessThanOrEqualTo(const Duration(milliseconds: 80)),
    );
    expect(routeHistory, isEmpty);
    expect(overlay.laterCallStarted, isTrue);
    expect(laterCall.isCompleted, isFalse);
  });

  testWidgets(
      'waitForNavigation still times out when pending work has no route',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    final screenTracker = ScreenTracker()..clearAll();
    addTearDown(screenTracker.clearAll);
    final pending = Completer<void>();
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'navigation_missing_route', steps: []),
      apiOverlay: _PendingNavigationApiOverlay(pending: pending),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      services: ApplicationTestServices(
        navigation: _MutableNavigationService(
          currentRoute: null,
          routeHistory: <String>[],
        ),
      ),
      executionConfig: const TestExecutionConfig(
        waitPollInterval: Duration(milliseconds: 2),
        settleStepDuration: Duration(milliseconds: 4),
      ),
    );
    final start = tester.binding.clock.now();
    Future<void>.delayed(const Duration(milliseconds: 85), () {
      screenTracker.trackScreen(screenName: 'Home');
    });

    await expectLater(
      executor.execute(const TestStep(
        type: 'waitForNavigation',
        args: {'screen': 'Home', 'timeoutMs': 20},
      )),
      throwsA(isA<EnsembleTestFailure>().having(
        (failure) => failure.message,
        'message',
        allOf(
          contains('Timed out after 20ms waiting for navigation to "Home"'),
          contains('bounded live-call drain expired'),
          contains('targetVisibleAtDeadline=false'),
        ),
      )),
    );
    expect(
      tester.binding.clock.now().difference(start),
      allOf(
        greaterThan(const Duration(milliseconds: 20)),
        lessThanOrEqualTo(const Duration(milliseconds: 80)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 5));
    expect(screenTracker.currentScreen?.screenName, 'Home');
  });

  testWidgets(
      'waitForNavigation preserves timeout when no live call is pending',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'navigation_no_pending_call', steps: []),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      services: ApplicationTestServices(
        navigation: _MutableNavigationService(
          currentRoute: null,
          routeHistory: <String>[],
        ),
      ),
      executionConfig: const TestExecutionConfig(
        waitPollInterval: Duration(milliseconds: 2),
        settleStepDuration: Duration(milliseconds: 4),
      ),
    );
    final start = tester.binding.clock.now();

    await expectLater(
      executor.execute(const TestStep(
        type: 'waitForNavigation',
        args: {'screen': 'Home', 'timeoutMs': 20},
      )),
      throwsA(isA<EnsembleTestFailure>()),
    );

    expect(
      tester.binding.clock.now().difference(start),
      lessThanOrEqualTo(const Duration(milliseconds: 20)),
    );
  });
}

class _PendingNavigationApiOverlay extends TestApiProviderOverlay {
  _PendingNavigationApiOverlay({required this.pending}) : super(mocks: {});

  final Completer<void> pending;

  @override
  bool get hasPendingLiveCalls => !pending.isCompleted;

  @override
  int get pendingLiveCallCount => pending.isCompleted ? 0 : 1;

  @override
  Future<void>? pendingLiveCallsSnapshot() => pending.future;

  @override
  Future<void> waitForLiveCalls() => pending.future;
}

class _SnapshotNavigationApiOverlay extends TestApiProviderOverlay {
  _SnapshotNavigationApiOverlay({
    required this.initialCall,
    required this.laterCall,
  }) : super(mocks: {});

  final Completer<void> initialCall;
  final Completer<void> laterCall;
  bool laterCallStarted = false;

  void startLaterCall() => laterCallStarted = true;

  @override
  bool get hasPendingLiveCalls =>
      !initialCall.isCompleted || (laterCallStarted && !laterCall.isCompleted);

  @override
  Future<void> pendingLiveCallsSnapshot() => initialCall.future;

  @override
  Future<void> waitForLiveCalls() => initialCall.future;
}

class _ChainedNavigationApiOverlay extends TestApiProviderOverlay {
  _ChainedNavigationApiOverlay({
    required this.initialCall,
    required this.followUpCall,
    this.followUpDelay = Duration.zero,
    required this.onFollowUpDrained,
  }) : super(mocks: {});

  final Completer<void> initialCall;
  final Completer<void> followUpCall;
  final Duration followUpDelay;
  final void Function() onFollowUpDrained;
  var followUpStarted = false;
  var followUpScheduled = false;

  void completeInitialAndStartFollowUp() {
    followUpStarted = true;
    initialCall.complete();
  }

  @override
  bool get hasPendingLiveCalls =>
      !initialCall.isCompleted ||
      (followUpStarted && !followUpCall.isCompleted);

  @override
  Future<void>? pendingLiveCallsSnapshot() {
    if (!initialCall.isCompleted) return initialCall.future;
    if (followUpStarted && !followUpCall.isCompleted) {
      return followUpCall.future;
    }
    return null;
  }

  @override
  Future<void> waitForLiveCalls() {
    if (!initialCall.isCompleted) return initialCall.future;
    if (followUpStarted && !followUpCall.isCompleted) {
      if (!followUpScheduled) {
        followUpScheduled = true;
        Future<void>.delayed(followUpDelay, () {
          onFollowUpDrained();
          followUpCall.complete();
        });
      }
      return followUpCall.future;
    }
    return Future<void>.value();
  }
}

class _FakeNavigationService implements NavigationTestService {
  _FakeNavigationService({
    required this.currentRoute,
    required this.routeHistory,
  });

  @override
  final String? currentRoute;

  @override
  final List<String> routeHistory;
}

class _FakeApiService implements ApiTestService {
  _FakeApiService(this.counts);

  final Map<String, int> counts;

  @override
  int callCount(String name) => counts[name] ?? 0;
}

class _FakeStorageService implements StorageTestService {
  _FakeStorageService(this.values);

  final Map<String, Object?> values;

  @override
  Future<void> apply(Map<String, dynamic> state) async {}

  @override
  Future<void> restore() async {}

  @override
  Object? read(String key) => values[key];

  @override
  Future<void> write(String key, Object? value) async => values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);

  @override
  Future<void> clear() async => values.clear();
}

class _MutableNavigationService implements NavigationTestService {
  _MutableNavigationService({
    required this.currentRoute,
    required this.routeHistory,
  });

  @override
  final String? currentRoute;

  @override
  final List<String> routeHistory;
}

class _DelayedTappableButton extends StatefulWidget {
  const _DelayedTappableButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_DelayedTappableButton> createState() => _DelayedTappableButtonState();
}

class _DelayedTappableButtonState extends State<_DelayedTappableButton> {
  var _enabled = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _enabled = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !_enabled,
      child: TextButton(
        key: const ValueKey('delayed_button'),
        onPressed: widget.onTap,
        child: const Text('Delayed'),
      ),
    );
  }
}

class _RecordingNavigationExecutor extends TestStepExecutor {
  _RecordingNavigationExecutor({
    required super.tester,
    required super.context,
    required super.assertions,
    required super.harness,
  });

  final events = <String>[];

  @override
  Future<void> openScreenByName(
    String screen, {
    Future<void> Function()? beforeMutation,
  }) async {
    events.add('route:$screen');
    await beforeMutation?.call();
    events.add('mutation:$screen');
  }
}

class _NoopStorageTestContext extends EnsembleTestContext {
  _NoopStorageTestContext({
    required super.testCase,
    required super.apiOverlay,
    required super.logger,
    required super.setup,
  });

  @override
  Future<void> clearStorage() async {}
}
