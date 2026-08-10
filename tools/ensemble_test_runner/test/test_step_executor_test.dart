import 'dart:convert';
import 'dart:io';

import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'package:ensemble_test_runner/actions/http_request_action.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:ensemble_test_runner/mocks/test_logger.dart';
import 'package:ensemble_test_runner/runner/app_performance_log.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/runner/test_runtime_state.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('httpRequest sends JSON and validates the response', () async {
    EnsembleTestHarness.ensureTestPlugins();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    late Map<String, dynamic> receivedBody;
    late ContentType receivedContentType;
    server.listen((request) async {
      receivedContentType = request.headers.contentType!;
      receivedBody = jsonDecode(await utf8.decoder.bind(request).join())
          as Map<String, dynamic>;
      request.response
        ..statusCode = HttpStatus.created
        ..write('{"ready":true}');
      await request.response.close();
    });

    try {
      await HttpRequestAction.execute({
        'method': 'POST',
        'url': 'http://127.0.0.1:${server.port}/control',
        'body': {'state': 'ready'},
        'expectStatus': 201,
        'expectBodyContains': 'ready',
      });
      expect(receivedBody, {'state': 'ready'});
      expect(receivedContentType.mimeType, ContentType.json.mimeType);
    } finally {
      await server.close(force: true);
    }
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

  testWidgets('onBeforeActionStep fires before a tap is performed',
      (tester) async {
    var tapped = false;
    TestStep? callbackStep;
    bool? tappedWhenCallbackRan;

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
    )..onBeforeActionStep = (step) {
        callbackStep = step;
        tappedWhenCallbackRan = tapped;
      };

    await executor.execute(
      const TestStep(type: 'tap', args: {'id': 'continue_button'}),
    );

    expect(callbackStep?.type, 'tap');
    expect(callbackStep?.args['id'], 'continue_button');
    expect(tappedWhenCallbackRan, isFalse);
    expect(tapped, isTrue);
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

    EnsembleTestFailure? failure;
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
    } on EnsembleTestFailure catch (error) {
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

  testWidgets('onAfterActionStep fires after text is entered', (tester) async {
    final controller = TextEditingController();
    TestStep? callbackStep;
    String? valueWhenCallbackRan;

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: TextField(
            key: const ValueKey('admin_password'),
            controller: controller,
          ),
        ),
      ),
    );

    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(
        id: 'enter_text_hook',
        startScreen: 'Home',
        steps: [],
      ),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
      harness: EnsembleTestHarness(appPath: 'unused', appHome: 'Home'),
    )..onAfterActionStep = (step) {
        callbackStep = step;
        valueWhenCallbackRan = controller.text;
      };

    await executor.execute(
      const TestStep(
        type: 'enterText',
        args: {'id': 'admin_password', 'value': 'secret'},
      ),
    );

    expect(callbackStep?.type, 'enterText');
    expect(valueWhenCallbackRan, 'secret');
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

  testWidgets('logApiCalls writes structured json', (tester) async {
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(
        id: 'api_log_test',
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

    await executor.execute(const TestStep(type: 'logApiCalls', args: {}));

    expect(context.logger.logs.single, startsWith('apiCalls: '));
    final path = context.logger.logs.single.substring('apiCalls: '.length);
    expect(path, endsWith('.json'));
    final content = File(path).readAsStringSync();
    expect(content, isNot(contains('API ')));
    expect(jsonDecode(content), {
      'total': 0,
      'calls': [],
      'events': [],
    });
  });

  test('performance log attributes frames and ranks jank context', () async {
    final logger = TestLogger();
    final start = DateTime.now();
    final apiTimestamp = start.add(const Duration(milliseconds: 20));
    final path = await writePerformanceLog(
      logger: logger,
      filePrefix: 'suite',
      name: 'app_performance',
      frames: const [
        AppFrameTimingEntry(
          frameNumber: 1,
          buildStartMicros: 1000,
          buildMs: 30,
          rasterMs: 0,
          vsyncOverheadMs: 1,
          totalSpanMs: 45,
        ),
        AppFrameTimingEntry(
          frameNumber: 2,
          buildStartMicros: 2000,
          buildMs: 5,
          rasterMs: 0,
          vsyncOverheadMs: 1,
          totalSpanMs: 10,
        ),
        AppFrameTimingEntry(
          frameNumber: 3,
          buildStartMicros: 3000,
          buildMs: 40,
          rasterMs: 0,
          vsyncOverheadMs: 1,
          totalSpanMs: 60,
        ),
      ],
      markers: [
        PerformanceMarker(
          testId: 'login_test',
          stepIndex: 1,
          label: 'login_test step 1 tap(login_button)',
          screen: 'Login',
          phase: 'step',
          startFrame: 1,
          endFrame: 3,
          startTime: start,
          endTime: start.add(const Duration(milliseconds: 100)),
        ),
      ],
      apiCalls: [
        APICallRecord(
          name: 'loginApi',
          apiDefinition: loadYaml('{}') as YamlMap,
          timestamp: apiTimestamp,
        ),
      ],
    );

    final json = jsonDecode(File(path).readAsStringSync()) as Map;
    expect(json['summary'], containsPair('worstScreen', 'Login'));
    expect(
      json['summary'],
      containsPair('worstStep', 'login_test step 1 tap(login_button)'),
    );
    expect((json['frames'] as List).first, containsPair('screen', 'Login'));
    expect((json['frames'] as List).first, containsPair('phase', 'step'));
    expect(
      ((json['worstSteps'] as List).first as Map)['step'],
      'login_test step 1 tap(login_button)',
    );
    expect(
      ((json['worstScreens'] as List).first as Map)['screen'],
      'Login',
    );
    expect((json['jankClusters'] as List), isNotEmpty);
    expect(
      (((json['apiCorrelation'] as List).first as Map)['apiCalls'] as List)
          .single,
      containsPair('name', 'loginApi'),
    );
    expect(
        (json['slowestFrames'] as List).first, containsPair('screen', 'Login'));
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
