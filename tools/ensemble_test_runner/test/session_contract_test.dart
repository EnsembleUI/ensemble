import 'dart:convert';

import 'package:ensemble_test_runner/session/session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('session contract JSON round-trips', () {
    test('SessionCapabilities', () {
      const original = SessionCapabilities(
        actions: {'tap', 'enterText'},
        assertionDomains: {'ui', 'navigation'},
        waits: {'settle', 'text'},
        semanticTree: true,
        runtimeMetadata: true,
        navigationState: true,
        screenshots: true,
        secureFieldRedaction: true,
        observationRevisions: true,
        snapshotElementTargets: true,
      );
      final roundTrip = SessionCapabilities.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );
      expect(roundTrip.toJson(), original.toJson());
    });

    test('SessionPermissions', () {
      final original = SessionPermissions.yamlController;
      final roundTrip = SessionPermissions.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );
      expect(roundTrip.toJson(), original.toJson());
    });

    test('UiObservation with nested elements', () {
      final original = UiObservation(
        observationId: 'obs_1',
        revision: 3,
        timestamp: DateTime.utc(2026, 3, 17, 12),
        screen: const ScreenObservation(
          name: 'Login',
          navigationStack: ['Home', 'Login'],
          hasModal: false,
        ),
        elements: const [
          UiElement(
            elementId: 'el_1',
            testId: 'email_field',
            type: 'textInput',
            label: 'Email',
            state: UiElementState(
              visible: true,
              enabled: true,
              interactable: true,
              secure: false,
            ),
            bounds: UiBounds(left: 0, top: 10, width: 100, height: 40),
            supportedActions: ['tap', 'enterText'],
          ),
          UiElement(
            elementId: 'el_2',
            testId: 'password_field',
            type: 'textInput',
            state: UiElementState(secure: true, visible: true),
            supportedActions: ['tap', 'enterText'],
          ),
        ],
        viewport: const UiViewport(width: 390, height: 844, devicePixelRatio: 2),
        observableFingerprint: 'fp_abc',
        completeness: const ObservationCompleteness(
          semanticTree: true,
          runtimeMetadata: true,
          navigationState: true,
        ),
      );
      final roundTrip = UiObservation.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );
      expect(roundTrip.toJson(), original.toJson());
      expect(roundTrip.elements[1].text, isNull);
      expect(roundTrip.elements[1].state.secure, isTrue);
    });

    test('ObservationOptions', () {
      const original = ObservationOptions(
        synchronization: ObservationSynchronization.nextFrame,
        stableTimeout: Duration(seconds: 2),
        includeScreenshot: true,
        allowPartial: true,
      );
      final roundTrip = ObservationOptions.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );
      expect(roundTrip.toJson(), original.toJson());
    });

    test('TestAction variants', () {
      final actions = <TestAction>[
        const TapAction(ElementTarget(testId: 'login_button')),
        const EnterTextAction(
          target: ElementTarget(
            elementId: 'el_1',
            observationId: 'obs_1',
          ),
          value: 'user@test.com',
        ),
        const ScrollUntilVisibleAction(
          target: ElementTarget(testId: 'footer'),
          scrollableId: 'list',
        ),
        const SwipeAction(direction: SwipeDirection.left),
        const DragAction(
          target: ElementTarget(testId: 'knob'),
          dx: 10,
          dy: -5,
        ),
        const SelectIndexAction(
          target: ElementTarget(testId: 'picker'),
          index: 2,
        ),
        const SetSliderAction(
          target: ElementTarget(testId: 'volume'),
          value: 0.5,
        ),
      ];
      for (final action in actions) {
        final roundTrip = TestAction.fromJson(
          jsonDecode(jsonEncode(action.toJson())) as Map<String, dynamic>,
        );
        expect(roundTrip.toJson(), action.toJson(), reason: action.type);
      }
    });

    test('ActionResult with error', () {
      const original = ActionResult(
        actionId: 'a1',
        status: ActionStatus.failed,
        beforeRevision: 1,
        afterRevision: 1,
        duration: Duration(milliseconds: 12),
        error: TestExecutionError(
          code: TestExecutionErrorCode.staleObservation,
          message: 'observation expired',
          details: {'observationId': 'obs_old'},
        ),
      );
      final roundTrip = ActionResult.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );
      expect(roundTrip.toJson(), original.toJson());
    });

    test('TestAssertion and WaitCondition variants', () {
      final assertions = <TestAssertion>[
        const ElementVisibleAssertion(testId: 'title'),
        const ElementTextAssertion(testId: 'title', text: 'Hello', contains: true),
        const ScreenAssertion(screen: 'Home'),
        const ElementEnabledAssertion(testId: 'submit', enabled: false),
        const GenericAssertion(
          domain: 'api',
          name: 'expectApiCalled',
          args: {'name': 'login'},
        ),
      ];
      for (final a in assertions) {
        final roundTrip = TestAssertion.fromJson(
          jsonDecode(jsonEncode(a.toJson())) as Map<String, dynamic>,
        );
        expect(roundTrip.toJson(), a.toJson(), reason: a.type);
      }

      final waits = <WaitCondition>[
        const PumpWait(duration: Duration(milliseconds: 100)),
        const SettleWait(timeout: Duration(seconds: 1)),
        const ElementWait(testId: 'spinner', gone: true),
        const TextWait(anyOf: ['Done', 'Complete']),
        const ScreenWait(screen: 'Home'),
        const ApiWait(name: 'getProfile', args: {'timeoutMs': 5000}),
      ];
      for (final w in waits) {
        final roundTrip = WaitCondition.fromJson(
          jsonDecode(jsonEncode(w.toJson())) as Map<String, dynamic>,
        );
        expect(roundTrip.toJson(), w.toJson(), reason: w.type);
      }
    });

    test('AssertionResult WaitResult ArtifactRequest TestArtifact', () {
      const assertion = AssertionResult(
        assertionId: 'as1',
        status: AssertionStatus.passed,
        message: 'ok',
      );
      expect(
        AssertionResult.fromJson(
          jsonDecode(jsonEncode(assertion.toJson())) as Map<String, dynamic>,
        ).toJson(),
        assertion.toJson(),
      );

      const wait = WaitResult(
        waitId: 'w1',
        status: WaitStatus.satisfied,
        duration: Duration(milliseconds: 50),
      );
      expect(
        WaitResult.fromJson(
          jsonDecode(jsonEncode(wait.toJson())) as Map<String, dynamic>,
        ).toJson(),
        wait.toJson(),
      );

      const req = ArtifactRequest(
        kind: 'screenshot',
        options: {'fullPage': true},
      );
      expect(
        ArtifactRequest.fromJson(
          jsonDecode(jsonEncode(req.toJson())) as Map<String, dynamic>,
        ).toJson(),
        req.toJson(),
      );

      const art = TestArtifact(
        artifactId: 'art_1',
        kind: 'screenshot',
        path: '/tmp/x.png',
        mimeType: 'image/png',
        byteLength: 42,
      );
      expect(
        TestArtifact.fromJson(
          jsonDecode(jsonEncode(art.toJson())) as Map<String, dynamic>,
        ).toJson(),
        art.toJson(),
      );
    });

    test('TestSessionConfiguration', () {
      final original = TestSessionConfiguration(
        sessionId: 's1',
        startScreen: 'Login',
        startScreenInputs: {'mode': 'test'},
        permissions: SessionPermissions.restrictedUi,
        defaultActionTimeout: Duration(seconds: 5),
      );
      final roundTrip = TestSessionConfiguration.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );
      expect(roundTrip.toJson(), original.toJson());
    });

    test('TestExecutionError codes round-trip', () {
      for (final code in TestExecutionErrorCode.values) {
        final error = TestExecutionError(code: code, message: code.name);
        final roundTrip = TestExecutionError.fromJson(
          jsonDecode(jsonEncode(error.toJson())) as Map<String, dynamic>,
        );
        expect(roundTrip.code, code);
      }
    });
  });
}
