import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:ensemble_test_runner/mocks/test_logger.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/session/actions/artifact_request.dart';
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

LocalTestExecutionSession _session(WidgetTester tester, String id) =>
    LocalTestExecutionSession.attach(
      tester: tester,
      harness: _harness(),
      context: _ctx(id),
      permissions: SessionPermissions.restrictedUi,
    );

void main() {
  testWidgets('observer extracts type, text, enabled, bounds, actions',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const Text('Welcome', key: ValueKey('title')),
              ElevatedButton(
                key: const ValueKey('login_button'),
                onPressed: () {},
                child: const Text('Login'),
              ),
              ElevatedButton(
                key: const ValueKey('disabled_button'),
                onPressed: null,
                child: const Text('Disabled'),
              ),
              TextField(
                key: const ValueKey('email_field'),
                controller: TextEditingController(text: 'a@b.com'),
              ),
              TextField(
                key: const ValueKey('token_field'),
                obscureText: true,
                controller: TextEditingController(text: 'secret'),
              ),
            ],
          ),
        ),
      ),
    );

    final session = _session(tester, 'sem');
    final obs = await session.observe(
      options: const ObservationOptions(
        synchronization: ObservationSynchronization.immediate,
        includeBounds: true,
      ),
    );

    final title = obs.elements.firstWhere((e) => e.testId == 'title');
    expect(title.type, 'text');
    expect(title.text, 'Welcome');
    expect(title.supportedActions, contains('tap'));
    expect(title.bounds, isNotNull);

    final login =
        obs.elements.firstWhere((e) => e.testId == 'login_button');
    expect(login.type, 'button');
    expect(login.state.enabled, isTrue);
    expect(login.supportedActions, containsAll(['tap', 'doubleTap']));
    expect(login.supportedActions, isNot(contains('enterText')));

    final disabled =
        obs.elements.firstWhere((e) => e.testId == 'disabled_button');
    expect(disabled.state.enabled, isFalse);
    expect(disabled.state.interactable, isFalse);

    final email = obs.elements.firstWhere((e) => e.testId == 'email_field');
    expect(email.type, 'textInput');
    expect(email.text, 'a@b.com');
    expect(email.supportedActions, contains('enterText'));

    final token = obs.elements.firstWhere((e) => e.testId == 'token_field');
    expect(token.state.secure, isTrue);
    expect(token.text, isNull);
    expect(token.supportedActions, isNot(contains('replaceText')));

    await session.close();
  });

  testWidgets('live fingerprint rejects stale enabled state before tap',
      (tester) async {
    final enabled = ValueNotifier<bool>(true);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: enabled,
          builder: (_, isEnabled, __) {
            return Scaffold(
              body: ElevatedButton(
                key: const ValueKey('toggle_btn'),
                onPressed: isEnabled ? () {} : null,
                child: Text(isEnabled ? 'On' : 'Off'),
              ),
            );
          },
        ),
      ),
    );

    final session = _session(tester, 'stale');
    final obs = await session.observe(
      options: const ObservationOptions(
        synchronization: ObservationSynchronization.immediate,
      ),
    );
    final btn = obs.elements.firstWhere((e) => e.testId == 'toggle_btn');
    expect(btn.state.enabled, isTrue);

    // Same Element stays mounted; only observable enabled state changes.
    enabled.value = false;
    await tester.pump();

    final result = await session.act(
      TapAction(
        ElementTarget(
          elementId: btn.elementId,
          observationId: obs.observationId,
        ),
      ),
    );
    expect(result.error?.code, TestExecutionErrorCode.staleObservation);
    await session.close();
    enabled.dispose();
  });

  testWidgets('occurrence targeting taps the selected duplicate', (tester) async {
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

    final session = _session(tester, 'occ');
    final result = await session.act(
      const TapAction(ElementTarget(testId: 'dup', occurrence: 1)),
    );
    expect(result.succeeded, isTrue, reason: '${result.error?.message}');
    expect(taps, ['second']);
    await session.close();
  });

  testWidgets('check/uncheck snapshot and testId are idempotent',
      (tester) async {
    var checked = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: Checkbox(
                key: const ValueKey('agree'),
                value: checked,
                onChanged: (v) => setState(() => checked = v ?? false),
              ),
            );
          },
        ),
      ),
    );

    final session = _session(tester, 'check');
    final obs = await session.observe(
      options: const ObservationOptions(
        synchronization: ObservationSynchronization.immediate,
      ),
    );
    final el = obs.elements.firstWhere((e) => e.testId == 'agree');
    expect(el.type, 'toggle');
    expect(el.state.checked, isFalse);

    final viaSnapshot = await session.act(
      CheckAction(
        ElementTarget(
          elementId: el.elementId,
          observationId: obs.observationId,
        ),
      ),
    );
    expect(viaSnapshot.succeeded, isTrue, reason: '${viaSnapshot.error}');
    expect(checked, isTrue);

    // Re-observe after state change (fingerprint would otherwise stale).
    final obs2 = await session.observe(
      options: const ObservationOptions(
        synchronization: ObservationSynchronization.immediate,
      ),
    );
    final el2 = obs2.elements.firstWhere((e) => e.testId == 'agree');

    // Already checked — second check must not toggle off.
    final again = await session.act(
      CheckAction(
        ElementTarget(
          elementId: el2.elementId,
          observationId: obs2.observationId,
        ),
      ),
    );
    expect(again.succeeded, isTrue, reason: '${again.error}');
    expect(checked, isTrue);

    final viaTestId = await session.act(
      const UncheckAction(ElementTarget(testId: 'agree')),
    );
    expect(viaTestId.succeeded, isTrue, reason: '${viaTestId.error}');
    expect(checked, isFalse);

    final uncheckAgain = await session.act(
      const UncheckAction(ElementTarget(testId: 'agree')),
    );
    expect(uncheckAgain.succeeded, isTrue);
    expect(checked, isFalse);

    await session.close();
  });

  testWidgets('captureArtifact stores retrievable PNG bytes', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Text('shot', key: ValueKey('shot'))),
      ),
    );
    // Paint a frame so the layer tree is screenshotable.
    await tester.pumpAndSettle();

    final session = _session(tester, 'art');
    final artifact = await session.captureArtifact(
      const ArtifactRequest(kind: 'screenshot'),
    );
    expect(artifact.mimeType, 'image/png');
    expect(artifact.path, startsWith('memory:'));
    expect(artifact.byteLength, greaterThan(100));
    final bytes = session.artifactBytes(artifact.artifactId);
    expect(bytes, isNotNull);
    expect(bytes!.length, artifact.byteLength);
    // PNG magic
    expect(bytes.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);

    await session.close();
    expect(session.artifactBytes(artifact.artifactId), isNull);
  });

  testWidgets('standalone close clears bootstrap runtime', (tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    final context = _ctx('boot');
    context.runtime.networkOffline = true;
    context.runtime.consoleLogs.add('noise');

    final assertions = AssertionEngine(tester: tester, context: context);
    final harness = _harness();
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: assertions,
      harness: harness,
    );
    final session = LocalTestExecutionSession.standalone(
      tester: tester,
      harness: harness,
      context: context,
      assertions: assertions,
      executor: executor,
    );
    expect(session.ownsBootstrap, isTrue);
    await session.close();
    expect(context.runtime.networkOffline, isFalse);
    expect(context.runtime.consoleLogs, isEmpty);
  });
}
