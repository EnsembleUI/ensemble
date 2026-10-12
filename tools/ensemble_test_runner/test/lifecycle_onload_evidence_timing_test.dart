import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'support/test_step_executor_handler_harness.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble/framework/screen_tracker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('trigger onLoad captures after route selection and before load',
      (tester) async {
    ScreenTracker().clearAll();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(
        id: 'trigger_onload_evidence',
        startScreen: 'Home',
        steps: [],
      ),
    );
    final executor = _RecordingScreenExecutor(
      tester: tester,
      context: context,
      assertions: AssertionEngine(tester: tester, context: context),
    );
    executor.onEvidenceBoundary = (step) {
      executor.events.add('evidence:${step.type}');
    };

    await executor.execute(const TestStep(
      type: 'trigger',
      args: {'action': 'onLoad'},
    ));

    expect(executor.events, [
      'resolved:Home',
      'evidence:trigger',
      'loaded:Home',
    ]);
    ScreenTracker().clearAll();
  });
}

class _RecordingScreenExecutor extends TestStepExecutor {
  _RecordingScreenExecutor({
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
    events.add('loaded:$screen');
  }
}
