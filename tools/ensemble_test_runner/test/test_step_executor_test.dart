import 'dart:convert';
import 'dart:io';

import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'package:ensemble_test_runner/actions/http_request_action.dart';
import 'package:ensemble_test_runner/actions/run_command_action.dart';
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
  test('runCommand executes a finite process', () async {
    await RunCommandAction.execute({
      'command':
          '${Platform.environment['FLUTTER_ROOT']}/bin/cache/dart-sdk/bin/dart',
      'arguments': ['--version'],
      'expectExitCode': 0,
    });
  });

  test('runCommand stops a process when it times out', () async {
    final temp = await Directory.systemTemp.createTemp('run_command_timeout');
    final script = File('${temp.path}/wait.dart');
    await script.writeAsString('''
Future<void> main() async {
  await Future<void>.delayed(const Duration(seconds: 30));
}
''');

    try {
      await expectLater(
        RunCommandAction.execute({
          'command':
              '${Platform.environment['FLUTTER_ROOT']}/bin/cache/dart-sdk/bin/dart',
          'arguments': [script.path],
          'timeoutMs': 100,
        }),
        throwsA(isA<EnsembleTestFailure>()),
      );
    } finally {
      await temp.delete(recursive: true);
    }
  });

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
          contains('either "id" or "text"'),
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
