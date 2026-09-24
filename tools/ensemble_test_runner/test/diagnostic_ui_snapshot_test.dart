import 'dart:typed_data';
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
    'diagnostic snapshot suggests label+role for unkeyed caption buttons',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: InkWell(
                onTap: () {},
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Netwerk'),
                ),
              ),
            ),
          ),
        ),
      );

      final snap = captureDiagnosticUiSnapshot(
        tester: tester,
        assertions: AssertionEngine(tester: tester),
      );
      final button = _flatten(snap.observation.elements)
          .firstWhere((e) => e.type == 'button');
      expect(button.state.interactable, isTrue);
      expect(button.supportedActions, contains('tap'));
      expect(button.suggestedLocator?.id, isNull);
      expect(button.suggestedLocator?.label, 'Netwerk');
      expect(button.suggestedLocator?.role, 'button');

      final tree = observationElementsTreeForReport(snap.observation);
      final node = tree.firstWhere((e) => e['type'] == 'button');
      expect(node['locator'], {'label': 'Netwerk', 'role': 'button'});
      expect(node.containsKey('selector'), isFalse);
      expect(node['interactable'], isTrue);
    },
  );

  testWidgets(
    'diagnostic snapshot omits selector for unkeyed decorative images',
    (tester) async {
      // 1x1 PNG
      final png = Uint8List.fromList(<int>[
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
        0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
        0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Image.memory(png, width: 80, height: 80),
            ),
          ),
        ),
      );

      final snap = captureDiagnosticUiSnapshot(
        tester: tester,
        assertions: AssertionEngine(tester: tester),
      );
      final media = _flatten(snap.observation.elements)
          .where((e) => e.type == 'image')
          .toList();
      expect(media, isNotEmpty, reason: 'Image.memory should observe as image');
      for (final el in media) {
        expect(
          el.suggestedLocator,
          isNull,
          reason: 'no image steps without id — do not invent label+role=image',
        );
        expect(el.supportedActions, isEmpty);
      }
    },
  );

  testWidgets(
    'diagnostic snapshot keeps CloseAppButton a11y label as label+role=icon',
    (tester) async {
      // Mirrors inhome CloseAppButton: Column(semantics.label, onTap) → SVG
      // AppIcon, with an empty intermediate Semantics (Material/InkWell pattern).
      final png = Uint8List.fromList(<int>[
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
        0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
        0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: Semantics(
                label: 'back button',
                button: true,
                child: Semantics(
                  // Empty intermediate node — must not block the a11y label.
                  child: Material(
                    color: const Color(0xFFFFCC00),
                    child: InkWell(
                      onTap: () {},
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Center(
                          child: Image.memory(png, width: 28, height: 28),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final snap = captureDiagnosticUiSnapshot(
        tester: tester,
        assertions: AssertionEngine(tester: tester),
      );
      final icon = _flatten(snap.observation.elements).firstWhere(
        (e) => e.type == 'icon',
      );
      expect(icon.label, 'back button');
      expect(icon.state.interactable, isTrue);
      expect(icon.suggestedLocator, isNotNull);
      expect(icon.suggestedLocator!.label, 'back button');
      expect(icon.suggestedLocator!.role, 'icon');
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

  testWidgets(
    'diagnostic snapshot suggests caption+role only for tappable cards',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Column(
                  children: [
                    SizedBox(
                      width: 360,
                      height: 100,
                      child: InkWell(
                        onTap: () {},
                        child: const Column(
                          children: [
                            Text('KPN Box 12'),
                            Text('Modem'),
                            Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 320,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFD3D3D3)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Column(
                        children: [
                          Text('Wifi naam'),
                          Text('KPN'),
                        ],
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: 220,
                  left: 24,
                  right: 24,
                  child: GestureDetector(
                    onTap: null,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade900,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'No token found, please open the app again.',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final snap = captureDiagnosticUiSnapshot(
        tester: tester,
        assertions: AssertionEngine(tester: tester),
      );
      final flat = _flatten(snap.observation.elements);

      final tappableCard = flat.firstWhere(
        (e) => e.type == 'card' && (e.text ?? '').contains('KPN Box 12'),
      );
      expect(tappableCard.state.interactable, isTrue);
      expect(tappableCard.suggestedLocator?.label, 'KPN Box 12');
      expect(tappableCard.suggestedLocator?.role, 'card');
      expect(tappableCard.supportedActions, contains('tap'));

      final inertCards = flat.where(
        (e) =>
            e.type == 'card' &&
            (e.text ?? '').contains('Wifi naam') &&
            e.state.interactable != true,
      );
      for (final card in inertCards) {
        expect(
          card.suggestedLocator,
          isNull,
          reason: 'non-tappable cards must not get label+role selectors',
        );
      }

      final modem = flat.firstWhere(
        (e) => e.type == 'text' && (e.text ?? '') == 'Modem',
      );
      expect(modem.suggestedLocator?.text, 'Modem');

      // Decorative chevron under the card is not interactable — no sel.
      final chevrons = flat.where(
        (e) =>
            e.type == 'icon' &&
            e.suggestedLocator?.within?.label == 'KPN Box 12',
      );
      expect(
        chevrons,
        isEmpty,
        reason: 'non-tappable nested icons must not get within selectors',
      );

      final toast = flat.firstWhere((e) => e.type == 'toast');
      expect(
        toast.suggestedLocator,
        isNull,
        reason: 'non-tappable toast host; message text keeps text=',
      );
      expect(
        flat.any(
          (e) =>
              e.type == 'text' &&
              (e.text ?? '').contains('No token found') &&
              e.suggestedLocator?.text != null,
        ),
        isTrue,
      );
    },
  );

  testWidgets(
    'diagnostic snapshot gives within+role sel for icons under inert card',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Container(
                width: 320,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFD3D3D3)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('What do you think of this page?'),
                    const Text("We'd love to hear your opinion!"),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var i = 0; i < 5; i++)
                          InkWell(
                            onTap: () {},
                            child: const SizedBox(
                              width: 40,
                              height: 40,
                              child: Icon(Icons.sentiment_satisfied),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      final snap = captureDiagnosticUiSnapshot(
        tester: tester,
        assertions: AssertionEngine(tester: tester),
      );
      final card = snap.observation.elements
          .where((e) => e.type == 'card')
          .first;
      expect(card.suggestedLocator, isNull);
      expect(card.state.interactable, isFalse);

      final icons = _flatten(card.children)
          .where((e) => e.type == 'icon')
          .toList();
      expect(icons, hasLength(5));
      for (var i = 0; i < icons.length; i++) {
        final icon = icons[i];
        expect(icon.state.interactable, isTrue);
        expect(icon.supportedActions, contains('tap'));
        expect(icon.suggestedLocator?.role, 'icon');
        expect(icon.suggestedLocator?.within?.role, 'card');
        expect(
          icon.suggestedLocator?.within?.label,
          'What do you think of this page?',
        );
        expect(icon.suggestedLocator?.occurrence, i);
      }
    },
  );

  testWidgets(
    'diagnostic snapshot gives unkeyed switch label+role and toggle actions',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 56,
              child: Row(
                children: [
                  const Expanded(child: Text('Kinder-Phone')),
                  Switch(value: true, onChanged: (_) {}),
                ],
              ),
            ),
          ),
        ),
      );

      final snap = captureDiagnosticUiSnapshot(
        tester: tester,
        assertions: AssertionEngine(tester: tester),
      );
      final sw = _flatten(snap.observation.elements)
          .firstWhere((e) => e.type == 'switch');
      expect(sw.state.enabled, isTrue);
      expect(sw.state.interactable, isTrue);
      expect(sw.supportedActions, contains('toggle'));
      expect(sw.suggestedLocator?.label, 'Kinder-Phone');
      expect(sw.suggestedLocator?.role, 'switch');
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
