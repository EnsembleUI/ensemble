import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'support/test_step_executor_handler_harness.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble/framework/screen_tracker.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/src/runtime/operation_registry.dart'
    show operationRegistry;
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('form controls dispatch through the runtime handler registry',
      (tester) async {
    final dateController = TextEditingController();
    final timeController = TextEditingController();
    var sliderValue = 0.25;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            KeyedSubtree(
              key: const ValueKey('slider'),
              child: Slider(
                value: sliderValue,
                onChanged: (value) => sliderValue = value,
              ),
            ),
            TextField(key: const ValueKey('date'), controller: dateController),
            TextField(key: const ValueKey('time'), controller: timeController),
          ],
        ),
      ),
    ));
    final executor = _executor(tester);
    final evidenceBoundaries = <String>[];
    final eventOrder = <String>[];
    executor.onEvidenceBoundary = (step) {
      final text =
          step.args['id'] == 'date' ? dateController.text : timeController.text;
      evidenceBoundaries.add('${step.type}:$text');
      eventOrder.add('boundary:${step.type}:$text');
    };

    await executor.execute(
      const TestStep(type: 'setSlider', args: {'id': 'slider', 'value': 0.8}),
    );
    await executor.execute(
      const TestStep(
        type: 'chooseDate',
        args: {'id': 'date', 'value': '2026-10-03'},
      ),
    );
    await executor.execute(
      const TestStep(
        type: 'chooseTime',
        args: {'id': 'time', 'value': '09:30'},
      ),
    );

    expect(sliderValue, greaterThan(0.25));
    expect(dateController.text, '2026-10-03');
    expect(timeController.text, '09:30');
    expect(evidenceBoundaries, ['setSlider:', 'chooseDate:', 'chooseTime:']);
    expect(eventOrder, [
      'boundary:setSlider:',
      'boundary:chooseDate:',
      'boundary:chooseTime:',
    ]);
    dateController.dispose();
    timeController.dispose();
  });

  testWidgets('restart and launch aliases publish lifecycle evidence once',
      (tester) async {
    final lifecycle = operationRegistry.lookup('restartApp')!;
    expect(lifecycle.aliases, contains('launchApp'));
    expect(operationRegistry.lookup('launchApp'), same(lifecycle));

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final results = <(String, String, List<String>)>[];

    for (final name in ['restartApp', 'launchApp']) {
      ScreenTracker().clearAll();
      final executor = _executor(tester);
      final callbacks = <String>[];
      executor.onEvidenceBoundary = (step) {
        callbacks.add('boundary:${step.type}');
      };

      try {
        await executor.executeRegisteredLifecycleOperation(
          operationRegistry.lookup(name)!,
          const {},
          operationName: name,
          step: TestStep(type: name, args: const {}),
        );
        fail('Expected $name without a tracked screen to fail');
      } on EnsembleTestFailure catch (error) {
        results.add((name, error.message, callbacks));
      }
    }

    expect(results.map((result) => result.$2).toSet(), hasLength(1));
    for (final result in results) {
      expect(result.$2, contains('restartApp requires startScreen'));
      expect(result.$3, [
        'boundary:${result.$1}',
      ]);
    }

    final aliasExecutor = _executor(tester);
    final aliasCallbacks = <String>[];
    aliasExecutor.onEvidenceBoundary =
        (step) => aliasCallbacks.add('boundary:${step.type}');
    await expectLater(
      aliasExecutor.execute(const TestStep(type: 'launchApp', args: {})),
      throwsA(isA<EnsembleTestFailure>()),
    );
    expect(aliasCallbacks, [
      'boundary:restartApp',
    ]);
  });

  testWidgets('goBack uses the registered lifecycle handler', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('First')),
    ));
    navigatorKey.currentState!.push<void>(PageRouteBuilder<void>(
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (_, __, ___) => const Scaffold(body: Text('Second')),
    ));
    await tester.pump();
    final executor = _executor(tester);
    final callbacks = <String>[];
    executor.onEvidenceBoundary =
        (step) => callbacks.add('boundary:${step.type}');

    await executor.execute(const TestStep(type: 'goBack', args: {}));

    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsNothing);
    expect(callbacks, ['boundary:goBack']);
  });
}

TestStepExecutor _executor(WidgetTester tester) {
  final context = EnsembleTestContext.fromTestCase(
    const EnsembleTestCase(id: 'runtime-handler-migration', steps: []),
  );
  return TestStepExecutor(
    tester: tester,
    context: context,
    assertions: AssertionEngine(tester: tester, context: context),
    harness: EnsembleTestHarness(appPath: 'unused', appHome: 'Home'),
  );
}
