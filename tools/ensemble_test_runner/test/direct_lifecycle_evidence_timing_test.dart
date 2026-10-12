import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/src/runtime/operation_registry.dart'
    show operationRegistry;
import 'package:ensemble/framework/screen_tracker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'direct screen lifecycle operations capture before route mutation',
    (tester) async {
      ScreenTracker().clearAll();
      final context = EnsembleTestContext.fromTestCase(
        const EnsembleTestCase(
          id: 'direct_screen_evidence',
          startScreen: 'Home',
          steps: [],
        ),
      );
      final executor = _RecordingLifecycleExecutor(
        tester: tester,
        context: context,
        assertions: AssertionEngine(tester: tester, context: context),
      );
      final legacyBoundaries = <String>[];
      executor.onEvidenceBoundary = (step) {
        legacyBoundaries.add(step.type);
      };
      executor.onNamedOperationEvidenceBoundary = (name) {
        executor.events.add('evidence:$name');
      };

      await _executeLifecycleOperation(
        executor,
        'openScreen',
        const {'name': 'Next'},
      );
      await _executeLifecycleOperation(executor, 'reloadScreen', const {});

      expect(executor.events, [
        'resolved:Next',
        'evidence:openScreen',
        'mutated:Next',
        'resolved:Home',
        'evidence:reloadScreen',
        'mutated:Home',
      ]);
      expect(legacyBoundaries, isEmpty);
    },
  );

  testWidgets('goBack publishes ordered evidence immediately before pop',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('Home')));
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    final routeResult = navigator.push<void>(
      MaterialPageRoute<void>(builder: (_) => const Text('Target')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'go_back_evidence', steps: []),
    );
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
    );
    final evidence = <String>[];
    final legacyBoundaries = <String>[];
    executor.onEvidenceBoundary = (step) {
      legacyBoundaries.add(step.type);
    };
    executor.onNamedOperationEvidenceBoundary = (name) {
      evidence.add('$name:${find.text('Target').evaluate().isNotEmpty}');
    };

    await _executeLifecycleOperation(executor, 'goBack', const {});

    expect(evidence, ['goBack:true']);
    expect(legacyBoundaries, isEmpty);
    expect(find.text('Home'), findsOneWidget);
    await routeResult;
  });
}

Future<void> _executeLifecycleOperation(
  TestStepExecutor executor,
  String name,
  Map<String, dynamic> input,
) =>
    executor.executeRegisteredLifecycleOperation(
      operationRegistry.lookup(name)!,
      input,
      operationName: name,
    );

class _RecordingLifecycleExecutor extends TestStepExecutor {
  _RecordingLifecycleExecutor({
    required super.tester,
    required super.context,
    required super.assertions,
  });

  final events = <String>[];

  @override
  Future<void> openScreenByName(
    String screen, {
    Future<void> Function()? beforeMutation,
  }) async {
    events.add('resolved:$screen');
    await beforeMutation?.call();
    events.add('mutated:$screen');
  }
}
