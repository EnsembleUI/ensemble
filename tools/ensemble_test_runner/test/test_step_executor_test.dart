import 'dart:convert';
import 'dart:io';

import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/test_runtime_state.dart';
import 'package:ensemble/framework/storage_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

  testWidgets('logStorage logs all public storage when key is omitted',
      (tester) async {
    EnsembleTestHarness.ensureTestPlugins();
    await tester.runAsync(() async {
      await StorageManager().init();
      await StorageManager().clearPublicStorage();
      await StorageManager().write('first', 'one');
      await StorageManager().write('second', {'nested': true});
    });

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

    await executor.execute(const TestStep(type: 'logStorage', args: {}));

    expect(context.logger.logs, hasLength(1));
    expect(context.logger.logs.single, startsWith('storage: '));
    final path = context.logger.logs.single.substring('storage: '.length);
    expect(path, endsWith('.json'));
    final file = File(path);
    expect(file.existsSync(), isTrue);
    final content = file.readAsStringSync();
    expect(content, contains('\n  "first": "one"'));
    final json = jsonDecode(content) as Map<String, dynamic>;
    expect(json['first'], 'one');
    expect(json['second'], {'nested': true});
  });

  testWidgets('dumpTree writes the widget tree to test logs', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Text('debug target')),
    );
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(
        id: 'debug_test',
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

    await executor.execute(const TestStep(type: 'dumpTree', args: {}));

    expect(context.logger.logs.single, startsWith('dumpTree: '));
    final path = context.logger.logs.single.substring('dumpTree: '.length);
    expect(path, endsWith('.txt'));
    final file = File(path);
    expect(file.existsSync(), isTrue);
    final content = file.readAsStringSync();
    expect(content, isNot(startsWith('dumpTree:')));
    expect(content, contains('debug target'));
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

  testWidgets('logPerformance writes app frame timing json', (tester) async {
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(
        id: 'performance_log_test',
        startScreen: 'Home',
        steps: [],
      ),
    );
    context.runtime.appFrameTimings.add(
      const AppFrameTimingEntry(
        frameNumber: 1,
        buildStartMicros: 1000,
        buildMs: 5,
        rasterMs: 7,
        vsyncOverheadMs: 1,
        totalSpanMs: 12,
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

    await executor.execute(const TestStep(type: 'logPerformance', args: {}));

    expect(context.logger.logs.single, startsWith('appPerformance: '));
    final path =
        context.logger.logs.single.substring('appPerformance: '.length);
    expect(path, endsWith('.json'));
    final content = File(path).readAsStringSync();
    final json = jsonDecode(content) as Map<String, dynamic>;
    expect(json['testId'], 'performance_log_test');
    expect(json['frameBudgetMs'], 16.67);
    expect(json['totalFrames'], 1);
    expect(json['jankyFrames'], 0);
    expect(json['averageBuildMs'], 5);
    expect(json['averageRasterMs'], 7);
    expect((json['frames'] as List).single, containsPair('totalSpanMs', 12));
  });

  testWidgets('screenshot writes a framed png by default', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Text('screenshot target')),
    );
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(
        id: 'debug_test',
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
      const TestStep(type: 'screenshot', args: {'name': 'home'}),
    );

    expect(context.logger.logs.single, startsWith('screenshot: '));
    final path = context.logger.logs.single.substring('screenshot: '.length);
    final file = File(path);
    expect(file.existsSync(), isTrue);
    expect(file.readAsBytesSync().take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    final dimensions = _pngDimensions(file.readAsBytesSync());

    expect(
      dimensions.$1,
      greaterThan(tester.binding.renderViews.first.size.width),
    );
    expect(
      dimensions.$2,
      greaterThan(tester.binding.renderViews.first.size.height),
    );
  });

  testWidgets('screenshot can use a custom device model', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ColoredBox(
          color: Colors.green,
          child: Center(child: Text('framed screenshot target')),
        ),
      ),
    );
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(
        id: 'framed_debug_test',
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
        type: 'screenshot',
        args: {
          'name': 'home',
          'platform': 'android',
          'model': 'Samsung Galaxy S20',
        },
      ),
    );

    final path = context.logger.logs.single.substring('screenshot: '.length);
    final dimensions = _pngDimensions(File(path).readAsBytesSync());

    expect(
      dimensions.$1,
      greaterThan(tester.binding.renderViews.first.size.width),
    );
    expect(
      dimensions.$2,
      greaterThan(tester.binding.renderViews.first.size.height),
    );
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

(int, int) _pngDimensions(List<int> bytes) {
  int readInt32(int offset) =>
      bytes[offset] << 24 |
      bytes[offset + 1] << 16 |
      bytes[offset + 2] << 8 |
      bytes[offset + 3];

  return (readInt32(16), readInt32(20));
}
