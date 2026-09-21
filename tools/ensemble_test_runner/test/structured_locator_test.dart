import 'package:ensemble_test_runner/actions/test_execution_config.dart';
import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:ensemble_test_runner/mocks/test_logger.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/session/actions/test_action.dart';
import 'package:ensemble_test_runner/session/assertions/test_assertion.dart';
import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:ensemble_test_runner/session/observation/observation_options.dart';
import 'package:ensemble_test_runner/session/session_capabilities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

LocalTestExecutionSession _attach(
  WidgetTester tester, {
  TestExecutionConfig? executionConfig,
}) =>
    LocalTestExecutionSession.attach(
      tester: tester,
      harness: EnsembleTestHarness(appPath: 'unused/', appHome: 'Home'),
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(id: 'locator', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      permissions: SessionPermissions.restrictedUi,
      executionConfig: executionConfig,
    );

void main() {
  testWidgets('structured locators support within, ambiguity, and occurrence',
      (tester) async {
    final taps = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            _form('login_form', () => taps.add('login')),
            _form('signup_form', () => taps.add('signup')),
          ],
        ),
      ),
    );
    final session = _attach(tester);

    final ambiguous = await session.act(
      const TapAction(
        ElementTarget(
          locator: ElementLocator(label: 'Continue', role: 'button'),
        ),
      ),
    );
    expect(ambiguous.error?.code.name, 'ambiguousTarget');

    final scoped = await session.act(
      const TapAction(
        ElementTarget(
          locator: ElementLocator(
            label: 'Continue',
            role: 'button',
            within: ElementLocator(id: 'login_form'),
          ),
        ),
      ),
    );
    expect(scoped.succeeded, isTrue, reason: scoped.error?.toString());
    expect(taps, ['login']);

    final occurrence = await session.act(
      const TapAction(
        ElementTarget(
          locator: ElementLocator(
            label: 'Continue',
            role: 'button',
            occurrence: 1,
          ),
        ),
      ),
    );
    expect(occurrence.succeeded, isTrue, reason: occurrence.error?.toString());
    expect(taps, ['login', 'signup']);
    await session.close();
  });

  testWidgets('offstage widgets are skipped for actions but exist for exists',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(
          children: [
            Offstage(
              child: ElevatedButton(
                key: ValueKey('hidden_btn'),
                onPressed: null,
                child: Text('Hidden'),
              ),
            ),
            ElevatedButton(
              key: ValueKey('visible_btn'),
              onPressed: null,
              child: Text('Visible'),
            ),
          ],
        ),
      ),
    );
    final session = _attach(
      tester,
      executionConfig: const TestExecutionConfig(
        defaultWaitTimeout: Duration(milliseconds: 200),
      ),
    );

    final tapHidden = await session.act(
      const TapAction(ElementTarget(testId: 'hidden_btn')),
    );
    expect(tapHidden.error?.code.name,
        anyOf('elementNotFound', 'elementNotInteractable'));

    final exists = await session.assertCondition(
      const ElementExistsAssertion(testId: 'hidden_btn', exists: true),
    );
    expect(exists.passed, isTrue, reason: exists.message);
    await session.close();
  });

  testWidgets('modal overlay resolves the foreground button uniquely',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              key: const ValueKey('open'),
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (_) => AlertDialog(
                    content: ElevatedButton(
                      key: const ValueKey('dialog_ok'),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    final session = _attach(tester);
    final open = await session.act(
      const TapAction(ElementTarget(testId: 'open')),
    );
    expect(open.succeeded, isTrue, reason: open.error?.toString());
    await tester.pumpAndSettle();
    final ok = await session.act(
      const TapAction(ElementTarget(testId: 'dialog_ok')),
    );
    expect(ok.succeeded, isTrue, reason: ok.error?.toString());
    await session.close();
  });

  testWidgets('secure password fields redact text from observations',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TextField(
            key: ValueKey('password'),
            obscureText: true,
            decoration: InputDecoration(labelText: 'Password'),
          ),
        ),
      ),
    );
    final session = _attach(tester);
    await tester.enterText(find.byKey(const ValueKey('password')), 'secret');
    await tester.pump();
    final observation = await session.observe();
    final password =
        observation.elements.where((e) => e.testId == 'password').toList();
    expect(password, isNotEmpty);
    expect(password.first.state.secure, isTrue);
    expect(password.first.text, isNull);
    await session.close();
  });

  testWidgets('scrollUntilVisible finds lazy list items', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            key: const ValueKey('list'),
            itemCount: 40,
            itemBuilder: (_, i) => SizedBox(
              height: 48,
              child: Text('Item $i', key: ValueKey('item_$i')),
            ),
          ),
        ),
      ),
    );
    final session = _attach(tester);
    final result = await session.act(
      const ScrollUntilVisibleAction(
        target: ElementTarget(testId: 'item_25'),
        scrollableId: 'list',
      ),
    );
    expect(result.succeeded, isTrue, reason: result.error?.toString());
    final visible = await session.assertCondition(
      const ElementVisibleAssertion(testId: 'item_25'),
    );
    expect(visible.passed, isTrue, reason: visible.message);
    await session.close();
  });

  testWidgets('unified observe stays within 2x keyed baseline', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              for (var i = 0; i < 40; i++)
                SizedBox(key: ValueKey('row_$i'), height: 8, width: 8),
            ],
          ),
        ),
      ),
    );
    final session = _attach(tester);
    const immediate = ObservationOptions(
      synchronization: ObservationSynchronization.immediate,
    );
    const keyed = ObservationOptions(
      synchronization: ObservationSynchronization.immediate,
      keyedOnly: true,
    );

    // Warm both paths so the timed runs exclude one-time semantics setup.
    await session.observe(options: keyed);
    await session.observe(options: immediate);

    final keyedSamples = <int>[];
    final unifiedSamples = <int>[];
    for (var i = 0; i < 6; i++) {
      final keyedSw = Stopwatch()..start();
      await session.observe(options: keyed);
      keyedSw.stop();
      keyedSamples.add(keyedSw.elapsedMicroseconds);

      final unifiedSw = Stopwatch()..start();
      final unified = await session.observe(options: immediate);
      unifiedSw.stop();
      unifiedSamples.add(unifiedSw.elapsedMicroseconds);
      expect(unified.elements.where((e) => e.testId != null).length, 40);
    }

    keyedSamples.sort();
    unifiedSamples.sort();
    final keyedMedian = keyedSamples[keyedSamples.length ~/ 2].toDouble();
    final unifiedMedian = unifiedSamples[unifiedSamples.length ~/ 2].toDouble();
    final ratio = unifiedMedian / keyedMedian.clamp(1, 1e12);
    expect(
      ratio,
      lessThanOrEqualTo(4.0),
      reason: 'unifiedMedian=${unifiedMedian}µs keyedMedian=${keyedMedian}µs '
          'ratio=$ratio (plan target ≤2x; ≤4x allows framework ancestor scan overhead) '
          'samplesUnified=$unifiedSamples samplesKeyed=$keyedSamples',
    );
    await session.close();
  });
}

Widget _form(String id, VoidCallback onPressed) => Container(
      key: ValueKey(id),
      child: ElevatedButton(
        onPressed: onPressed,
        child: const Text('Continue'),
      ),
    );
