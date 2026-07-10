import 'dart:io';

import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
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
    final file = File(path);
    expect(file.existsSync(), isTrue);
    final content = file.readAsStringSync();
    expect(content, contains('"first":"one"'));
    expect(content, contains('"second":{"nested":true}'));
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
    final file = File(path);
    expect(file.existsSync(), isTrue);
    expect(file.readAsStringSync(), contains('debug target'));
  });

  testWidgets('screenshot writes a png and logs the path', (tester) async {
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
  });
}
