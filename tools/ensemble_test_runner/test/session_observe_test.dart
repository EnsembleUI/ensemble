import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:ensemble_test_runner/mocks/test_logger.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/session/actions/test_action.dart';
import 'package:ensemble_test_runner/session/errors/test_execution_error.dart';
import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:ensemble_test_runner/session/observation/observation_options.dart';
import 'package:ensemble_test_runner/session/session_capabilities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

EnsembleTestContext _ctx(String id) => EnsembleTestContext(
      testCase: EnsembleTestCase(id: id, steps: const []),
      apiOverlay: TestApiProviderOverlay(mocks: const {}),
      logger: TestLogger(),
      setup: const EnsembleTestSetup(),
    );

EnsembleTestHarness _harness() => EnsembleTestHarness(
      appPath: 'unused/',
      appHome: 'Home',
    );

void main() {
  testWidgets('session observe redacts password fields', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const Text('Login', key: ValueKey('login_title')),
              TextField(
                key: const ValueKey('password_field'),
                obscureText: true,
                controller: TextEditingController(text: 'secret'),
              ),
            ],
          ),
        ),
      ),
    );

    final session = LocalTestExecutionSession.attach(
      tester: tester,
      harness: _harness(),
      context: _ctx('obs'),
      permissions: SessionPermissions.restrictedUi,
    );

    final obs = await session.observe(
      options: const ObservationOptions(
        synchronization: ObservationSynchronization.immediate,
      ),
    );
    expect(obs.revision, greaterThan(0));
    expect(obs.elements.map((e) => e.testId), contains('password_field'));
    final password =
        obs.elements.firstWhere((e) => e.testId == 'password_field');
    expect(password.state.secure, isTrue);
    expect(password.text, isNull);

    final caps = await session.getCapabilities();
    expect(caps.secureFieldRedaction, isTrue);

    await session.close();
    expect(() => session.observe(), throwsA(isA<TestExecutionError>()));
  });

  testWidgets('ambiguous duplicate testIds', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(
          children: [
            Center(child: Text('A', key: ValueKey('dup'))),
            Center(child: Text('B', key: ValueKey('dup'))),
          ],
        ),
      ),
    );

    final session = LocalTestExecutionSession.attach(
      tester: tester,
      harness: _harness(),
      context: _ctx('dup'),
      permissions: SessionPermissions.restrictedUi,
    );

    final obs = await session.observe(
      options: const ObservationOptions(
        synchronization: ObservationSynchronization.immediate,
      ),
    );
    final dups = obs.elements.where((e) => e.testId == 'dup').toList();
    expect(dups.length, greaterThanOrEqualTo(2));

    final ambiguous = await session.act(
      const TapAction(ElementTarget(testId: 'dup')),
    );
    expect(ambiguous.error?.code.name, 'ambiguousTarget');
    await session.close();
  });

  testWidgets('snapshot elementId taps exact duplicate testId', (tester) async {
    final taps = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            GestureDetector(
              onTap: () => taps.add('first'),
              child: const SizedBox(
                width: 80,
                height: 40,
                child: Text('first', key: ValueKey('dup')),
              ),
            ),
            GestureDetector(
              onTap: () => taps.add('second'),
              child: const SizedBox(
                width: 80,
                height: 40,
                child: Text('second', key: ValueKey('dup')),
              ),
            ),
          ],
        ),
      ),
    );

    final session = LocalTestExecutionSession.attach(
      tester: tester,
      harness: _harness(),
      context: _ctx('snap'),
      permissions: SessionPermissions.restrictedUi,
    );

    final obs = await session.observe(
      options: const ObservationOptions(
        synchronization: ObservationSynchronization.immediate,
      ),
    );
    final dups = obs.elements.where((e) => e.testId == 'dup').toList();
    expect(dups.length, greaterThanOrEqualTo(2));
    final second = dups.last;

    final result = await session.act(
      TapAction(
        ElementTarget(
          elementId: second.elementId,
          observationId: obs.observationId,
        ),
      ),
    );
    expect(result.succeeded, isTrue, reason: '${result.error?.message}');
    expect(taps, ['second']);

    // Stale observation id must fail without falling back to testId.
    final stale = await session.act(
      TapAction(
        ElementTarget(
          elementId: second.elementId,
          observationId: 'obs_missing',
        ),
      ),
    );
    expect(stale.error?.code, TestExecutionErrorCode.staleObservation);
    expect(taps, ['second']);

    await session.close();
  });

  testWidgets('permission denial blocks actions', (tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      harness: _harness(),
      context: _ctx('p'),
      permissions: const SessionPermissions(
        actions: {},
        assertionDomains: {'ui'},
        waits: {'pump'},
      ),
    );
    final result = await session.act(
      const TapAction(ElementTarget(testId: 'btn')),
    );
    expect(result.error?.code.name, 'permissionDenied');
    await session.close();
  });
}
