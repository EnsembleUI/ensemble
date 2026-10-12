import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/session/operation_target.dart';
import 'package:ensemble_test_runner/session/local/local_action_executor.dart';
import 'package:ensemble_test_runner/session/local/flutter_target_resolver.dart';
import 'support/session_operation.dart';
import 'package:ensemble_test_runner/session/local/observation_registry.dart';
import 'support/test_step_executor_handler_harness.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'scrollUntilVisible captures at the matched visible state',
    (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            key: const ValueKey('items'),
            itemCount: 40,
            itemBuilder: (_, index) => SizedBox(
              height: 48,
              child: Text('Item $index', key: ValueKey('item_$index')),
            ),
          ),
        ),
      ));

      final context = EnsembleTestContext.fromTestCase(
        const EnsembleTestCase(id: 'scroll_evidence', steps: []),
      );
      final executor = TestStepExecutor(
        tester: tester,
        context: context,
        assertions: AssertionEngine(tester: tester, context: context),
      );
      final captures = <String>[];
      executor.onEvidenceBoundary = (step) async {
        captures.add(step.type);
        expect(find.byKey(const ValueKey('item_25')).hitTestable(),
            findsOneWidget);
      };
      const step = TestStep(
        type: 'scrollUntilVisible',
        args: {
          'id': 'item_25',
          'scrollableId': 'items',
          'timeoutMs': 1000,
        },
      );
      await executor.execute(step);

      expect(captures, ['condition:scrollUntilVisible']);
    },
  );

  testWidgets(
    'structured scrollUntilVisible emits condition evidence after visibility',
    (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            key: const ValueKey('items'),
            child: Column(
              children: List.generate(
                40,
                (index) => SizedBox(
                  height: 48,
                  child: Text('Item $index', key: ValueKey('item_$index')),
                ),
              ),
            ),
          ),
        ),
      ));

      final element = find.byKey(const ValueKey('item_25')).evaluate().single;
      final registry = ObservationRegistry();
      registry.registerObservation(
        observationId: 'obs_scroll',
        handles: {
          'el_item_25': SnapshotElementHandle(
            observationId: 'obs_scroll',
            elementId: 'el_item_25',
            testId: 'item_25',
            element: element,
            observableFingerprint: 'item_25',
          ),
        },
      );
      final context = EnsembleTestContext.fromTestCase(
        const EnsembleTestCase(id: 'structured_scroll_evidence', steps: []),
      );
      final assertions = AssertionEngine(tester: tester, context: context);
      final executor = TestStepExecutor(
        tester: tester,
        context: context,
        assertions: assertions,
      );
      final actionExecutor = LocalActionExecutor(
        executor: executor,
        resolver: FlutterTargetResolver(
          tester: tester,
          assertions: assertions,
          registry: registry,
        ),
      );
      final captures = <String>[];
      executor.onOperationEvidenceBoundary = (operation, _) async {
        captures.add('condition:${operation.operationName}');
        expect(find.byKey(const ValueKey('item_25')).hitTestable(),
            findsOneWidget);
      };
      const target = ElementTarget(
        testId: 'item_25',
      );
      await actionExecutor.execute(
        actionOperation('scrollUntilVisible',
            target: target, input: const {'scrollableId': 'items'}),
      );

      expect(captures, ['condition:scrollUntilVisible']);
    },
  );
}
