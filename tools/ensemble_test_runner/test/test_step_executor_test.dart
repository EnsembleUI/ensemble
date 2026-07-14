import 'dart:convert';
import 'dart:io';

import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:ensemble_test_runner/mocks/test_logger.dart';
import 'package:ensemble_test_runner/runner/app_performance_log.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/runner/test_runtime_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
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
