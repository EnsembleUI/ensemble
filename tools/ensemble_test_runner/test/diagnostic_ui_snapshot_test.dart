import 'dart:ui' as ui;

import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:ensemble_test_runner/mocks/test_logger.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/reporters/step_log_grouping.dart';
import 'package:ensemble_test_runner/runner/diagnostic_ui_snapshot.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/runner/failure_observer_capture.dart';
import 'package:ensemble_test_runner/runner/test_runtime_state.dart';
import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:ensemble_test_runner/session/local/observable_fingerprint.dart';
import 'package:ensemble_test_runner/session/observation/ui_element.dart';
import 'package:ensemble_test_runner/session/session_capabilities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'diagnostic snapshot does not register ModalRoute dependents',
    (tester) async {
      var buttonBuilds = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElevatedButton(
              key: const ValueKey('go_button'),
              onPressed: () {
                Navigator.of(tester.element(find.byType(ElevatedButton))).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(
                      body: Text('Next', key: ValueKey('next_text')),
                    ),
                  ),
                );
              },
              child: Builder(
                builder: (context) {
                  buttonBuilds++;
                  return const Text('Go');
                },
              ),
            ),
          ),
        ),
      );

      final before = buttonBuilds;
      captureDiagnosticUiSnapshot(
        tester: tester,
        assertions: AssertionEngine(tester: tester),
      );
      expect(buttonBuilds, before);

      await tester.tap(find.byKey(const ValueKey('go_button')));
      await tester.pumpAndSettle();
      // If ModalRoute.of subscribed the button subtree, isCurrent flipping
      // would rebuild it during the push. Diagnostic must not do that.
      expect(
        buttonBuilds,
        before,
        reason: 'diagnostic must not ModalRoute.of-subscribe kept elements',
      );
      expect(find.byKey(const ValueKey('next_text')), findsOneWidget);
    },
  );

  testWidgets(
    'diagnostic snapshot does not enable SemanticsHandle',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const Text('Hello', key: ValueKey('greeting_text')),
                ElevatedButton(
                  key: const ValueKey('go_button'),
                  onPressed: () {},
                  child: const Text('Go'),
                ),
              ],
            ),
          ),
        ),
      );

      final handlesBefore =
          tester.binding.debugOutstandingSemanticsHandles;

      final snap = captureDiagnosticUiSnapshot(
        tester: tester,
        assertions: AssertionEngine(tester: tester),
      );

      expect(
        tester.binding.debugOutstandingSemanticsHandles,
        handlesBefore,
        reason: 'diagnostic path must not call ensureSemantics',
      );
      final flat = _flatten(snap.observation.elements);
      expect(
        flat.map((e) => e.testId),
        containsAll(['greeting_text', 'go_button']),
      );
      expect(
        flat.any((e) => e.suggestedLocator?.id == 'go_button'),
        isTrue,
        reason: 'cheap id= locator without live finder enrich',
      );
    },
  );

  testWidgets(
    'diagnostic capture skips while leaf queue is busy then succeeds after',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Text('Queued', key: ValueKey('queued_text')),
          ),
        ),
      );

      final ctx = EnsembleTestContext(
        testCase: const EnsembleTestCase(
          id: 'queue-observe',
          steps: [],
        ),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
        config: const EnsembleTestConfig(
          screenshots: ScreenshotConfig(enabled: true),
        ),
      );
      ctx.runtime.addScreenshotSheetFrame(
        ScreenshotSheetFrame(
          stepIndex: 0,
          label: '1. synthetic',
          image: await _solidImage(),
        ),
      );

      final session = LocalTestExecutionSession.attach(
        tester: tester,
        harness: EnsembleTestHarness(appPath: 'unused/', appHome: 'Home'),
        context: ctx,
        permissions: SessionPermissions.restrictedUi,
      );
      addTearDown(session.close);

      var midWaitCaptured = false;
      await session.queue.run(() async {
        // Mid-wait style: queue held — default skips so live observe never
        // nests under the leaf queue.
        await captureStepObserverBestEffort(
          session: session,
          executor: session.executor,
          stepIndex: 0,
        );
        midWaitCaptured = hasStepObserver(ctx, 0);
      });
      expect(midWaitCaptured, isFalse);

      await session.queue.run(() async {
        // Report mid-wait pair: diagnostic snapshot is queue-free, so allow
        // overlays to match the mid-wait PNG before navigation advances.
        await captureStepObserverBestEffort(
          session: session,
          executor: session.executor,
          stepIndex: 0,
          allowWhileQueueBusy: true,
        );
      });
      expect(hasStepObserver(ctx, 0), isTrue);
      expect(ctx.runtime.stepObservers.single.elements, isNotEmpty);

      // Idempotent when already present (post-step fill must not replace).
      final elementCount = ctx.runtime.stepObservers.single.elements.length;
      await captureStepObserverBestEffort(
        session: session,
        executor: session.executor,
        stepIndex: 0,
      );
      expect(ctx.runtime.stepObservers.single.elements.length, elementCount);
    },
  );

  testWidgets(
    'lightweight mutation fingerprint does not enable semantics',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              key: const ValueKey('name_input'),
              controller: TextEditingController(text: 'Ada'),
            ),
          ),
        ),
      );
      final handlesBefore =
          tester.binding.debugOutstandingSemanticsHandles;
      final a =
          lightweightMutationFingerprint(tester: tester, routeName: 'Home');
      expect(tester.binding.debugOutstandingSemanticsHandles, handlesBefore);
      await tester.enterText(find.byType(TextField), 'Bob');
      final b =
          lightweightMutationFingerprint(tester: tester, routeName: 'Home');
      expect(a, isNot(b));
      expect(tester.binding.debugOutstandingSemanticsHandles, handlesBefore);
    },
  );

  test(
    'groupLogsByStep attaches multiple role:observer entries per step',
    () {
      final steps = groupLogsByStep(
        stepsOutline: const [
          'tap(login)',
          'waitForNavigation(Home)',
          'tap(continue)',
        ],
        stepDurationsMs: const [100, 200, 150],
        stepStartTimes: const [
          '2026-01-01T00:00:00.000Z',
          '2026-01-01T00:00:01.000Z',
          '2026-01-01T00:00:02.000Z',
        ],
        apiEvents: const [],
        rawConsoleLines: const [],
        screenshotFrames: [
          {
            'stepIndex': 0,
            'label': '1. tap(login)',
            'file': 'tap.webp',
            'href': 'screenshots/tap.webp',
          },
          {
            'stepIndex': 0,
            'role': 'observer',
            'screen': 'Login',
            'elements': [
              {'index': 1, 'type': 'button', 'title': 'Login', 'id': 'login'},
            ],
            'overlays': [
              {
                'left': 5.0,
                'top': 10.0,
                'width': 20.0,
                'height': 8.0,
                'id': 'login',
                'type': 'button',
              },
            ],
          },
          {
            'stepIndex': 1,
            'label': '2. waitForNavigation(Home)',
            'file': 'nav.webp',
            'href': 'screenshots/nav.webp',
          },
          {
            'stepIndex': 1,
            'role': 'observer',
            'screen': 'Home',
            'elements': [
              {'index': 1, 'type': 'text', 'title': 'Welcome'},
            ],
            'overlays': const [],
          },
          {
            'stepIndex': 2,
            'label': '3. tap(continue)',
            'file': 'cont.webp',
            'href': 'screenshots/cont.webp',
          },
          {
            'stepIndex': 2,
            'role': 'observer',
            'screen': 'Home',
            'elements': [
              {'index': 1, 'type': 'button', 'title': 'Continue', 'id': 'go'},
            ],
            'overlays': [
              {
                'left': 10.0,
                'top': 20.0,
                'width': 15.0,
                'height': 5.0,
                'id': 'go',
                'type': 'button',
              },
            ],
          },
        ],
      );

      expect(steps, hasLength(3));
      expect(steps[0]['observer']['screen'], 'Login');
      expect(steps[1]['observer']['screen'], 'Home');
      expect(steps[2]['observer']['elements'].single['id'], 'go');
      for (final step in steps) {
        expect(step['screenshots'], hasLength(1));
        expect((step['observer'] as Map).containsKey('file'), isFalse);
      }
    },
  );
}

List<UiElement> _flatten(List<UiElement> roots) {
  final out = <UiElement>[];
  void walk(UiElement e) {
    out.add(e);
    for (final child in e.children) {
      walk(child);
    }
  }

  for (final root in roots) {
    walk(root);
  }
  return out;
}

Future<ui.Image> _solidImage() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 100, 100),
    Paint()..color = const Color(0xFFCCCCCC),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(100, 100);
  picture.dispose();
  return image;
}
