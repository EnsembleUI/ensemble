import 'package:ensemble_test_runner/actions/test_step_target_resolver.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('resolves id and itemId targets through the assertion engine',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Welcome'))),
    );
    final resolver = TestStepTargetResolver(
      assertions: AssertionEngine(tester: tester),
      resolveTargetFinder: () => null,
    );

    final idStep = const TestStep(type: 'tap', args: {'id': 'welcome'});
    expect(resolver.targetForStep(idStep).testId, 'welcome');
    expect(resolver.finderForStep(idStep).evaluate(), isEmpty);

    const itemStep = TestStep(type: 'expectVisible', args: {'itemId': 'row'});
    expect(resolver.targetForStep(itemStep).testId, 'row');
    expect(resolver.descriptionFor(itemStep), 'row');
  });

  testWidgets('delegates locator targets to the session resolver',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Welcome'))),
    );
    final expected = find.text('Welcome');
    final resolver = TestStepTargetResolver(
      assertions: AssertionEngine(tester: tester),
      resolveTargetFinder: () => (
        target, {
        requireInteractive = true,
        allowEmpty = false,
        allowOffscreen = false,
      }) {
        expect(target.locator?.text, 'Welcome');
        expect(requireInteractive, isFalse);
        expect(allowEmpty, isFalse);
        expect(allowOffscreen, isFalse);
        return expected;
      },
    );

    const step = TestStep(
      type: 'expectVisible',
      args: {
        'target': {'text': 'Welcome'},
      },
    );
    expect(
      resolver.finderForStep(step, requireInteractive: false),
      same(expected),
    );
  });

  testWidgets('reports missing ids consistently', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final resolver = TestStepTargetResolver(
      assertions: AssertionEngine(tester: tester),
      resolveTargetFinder: () => null,
    );
    const step = TestStep(type: 'tap', args: {});

    expect(
      () => resolver.requireId(step),
      throwsA(isA<EnsembleTestFailure>()),
    );
    expect(
      () => resolver.finderForStep(step),
      throwsA(isA<EnsembleTestFailure>()),
    );
  });
}
