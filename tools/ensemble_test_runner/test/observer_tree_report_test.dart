import 'package:ensemble_test_runner/runner/failure_observer_capture.dart';
import 'package:ensemble_test_runner/session/actions/test_action.dart';
import 'package:ensemble_test_runner/session/local/element_semantics.dart';
import 'package:ensemble_test_runner/session/observation/ui_element.dart';
import 'package:ensemble_test_runner/session/observation/ui_observation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('supportedActionsFor', () {
    test('plain text lists wait/assert steps, not gestures', () {
      final steps = supportedActionsFor(
        'text',
        secure: false,
        text: 'Wat wil je terugzetten?',
      );
      expect(steps, containsAll(['waitForText', 'expectText', 'waitFor']));
      expect(steps, isNot(contains('tap')));
    });

    test('keyed icon lists tap only when enabled is true', () {
      final enabled = supportedActionsFor(
        'icon',
        secure: false,
        enabled: true,
        testId: 'back_button',
      );
      expect(enabled,
          containsAll(['tap', 'longPress', 'waitFor', 'expectVisible']));

      final unknown = supportedActionsFor(
        'icon',
        secure: false,
        testId: 'back_button',
      );
      expect(unknown, contains('waitFor'));
      expect(unknown, isNot(contains('tap')));

      final disabled = supportedActionsFor(
        'icon',
        secure: false,
        enabled: false,
        testId: 'back_button',
      );
      expect(disabled, contains('waitFor'));
      expect(disabled, contains('expectDisabled'));
      expect(disabled, isNot(contains('tap')));
    });

    test('unkeyed button with caption lists tap via label/text', () {
      final steps = supportedActionsFor(
        'button',
        secure: false,
        enabled: true,
        text: 'Netwerk',
        label: 'Netwerk',
      );
      expect(steps, containsAll(['tap', 'longPress', 'doubleTap']));
      expect(steps, isNot(contains('waitFor'))); // no id → no id waits
    });

    test('unkeyed button without caption has no gestures', () {
      expect(
        supportedActionsFor('button', secure: false, enabled: true),
        isEmpty,
      );
    });

    test('unkeyed enabled card with caption lists tap', () {
      final steps = supportedActionsFor(
        'card',
        secure: false,
        enabled: true,
        text: 'KPN Box 12',
        label: 'KPN Box 12',
      );
      expect(steps, containsAll(['tap', 'longPress']));
    });

    test('offscreen bounds-backed card recommends scrolling into view', () {
      final steps = supportedActionsFor(
        'card',
        secure: false,
        enabled: true,
        offscreen: true,
        hasBounds: true,
        hasScrollableAncestor: true,
      );
      expect(steps, contains('scrollUntilVisible'));
      expect(steps.first, 'scrollUntilVisible');
    });

    test('offscreen element outside a scrollable does not suggest scrolling',
        () {
      final steps = supportedActionsFor(
        'button',
        secure: false,
        enabled: true,
        testId: 'next_screen_button',
        offscreen: true,
        hasBounds: true,
      );
      expect(steps, isNot(contains('scrollUntilVisible')));
    });

    test('unkeyed non-tappable card has no interaction steps', () {
      final steps = supportedActionsFor(
        'card',
        secure: false,
        enabled: null,
        text: 'Wat vind je van deze pagina?',
        label: 'Wat vind je van deze pagina?',
      );
      expect(steps, isEmpty);
    });

    test('keyed checkbox lists form + wait steps', () {
      final steps = supportedActionsFor(
        'checkbox',
        secure: false,
        testId: 'restore_dns_checkbox',
      );
      expect(
        steps,
        containsAll([
          'tap',
          'check',
          'uncheck',
          'toggle',
          'expectChecked',
          'waitFor',
          'expectVisible',
        ]),
      );
    });

    test('unkeyed enabled switch lists toggle steps', () {
      final steps = supportedActionsFor(
        'switch',
        secure: false,
        enabled: true,
        label: 'Kinder-Phone',
      );
      expect(
        steps,
        containsAll(['tap', 'toggle', 'check', 'uncheck', 'expectChecked']),
      );
    });

    test('textInput lists edit steps when keyed', () {
      expect(
        supportedActionsFor(
          'textInput',
          secure: false,
          testId: 'email',
        ),
        containsAll(['enterText', 'replaceText', 'expectValue']),
      );
      expect(
        supportedActionsFor(
          'textInput',
          secure: true,
          testId: 'token',
        ),
        isNot(contains('replaceText')),
      );
    });

    test('disabled keyed control keeps wait asserts but drops gestures', () {
      final steps = supportedActionsFor(
        'button',
        secure: false,
        enabled: false,
        testId: 'go',
      );
      expect(steps, contains('waitFor'));
      expect(steps, isNot(contains('tap')));
    });

    test('dropdown lists select steps', () {
      expect(
        supportedActionsFor(
          'dropdown',
          secure: false,
          testId: 'country',
        ),
        containsAll(['select', 'selectIndex', 'tap']),
      );
    });
  });

  test('observationElementsTreeForReport nests children with pre-order indices',
      () {
    final observation = UiObservation(
      observationId: 'obs',
      revision: 0,
      timestamp: DateTime.utc(2026, 1, 1),
      screen: const ScreenObservation(name: 'Restore'),
      elements: [
        const UiElement(
          elementId: 'card1',
          type: 'card',
          text: 'DNS-instellingen',
          state: UiElementState(visible: true, enabled: true),
          children: [
            UiElement(
              elementId: 'cb1',
              testId: 'restore_dns_checkbox',
              type: 'checkbox',
              suggestedLocator: ElementLocator(id: 'restore_dns_checkbox'),
              supportedActions: [
                'waitFor',
                'tap',
                'check',
                'uncheck',
                'toggle',
              ],
              state: UiElementState(
                visible: true,
                enabled: true,
                checked: false,
                interactable: true,
              ),
            ),
          ],
        ),
        const UiElement(
          elementId: 'heading',
          type: 'text',
          text: 'Wat wil je terugzetten?',
          suggestedLocator: ElementLocator(text: 'Wat wil je terugzetten?'),
          supportedActions: ['waitForText', 'expectText'],
          state: UiElementState(visible: true, interactable: false),
        ),
      ],
      viewport: const UiViewport(width: 390, height: 844, devicePixelRatio: 2),
      observableFingerprint: '',
      completeness: const ObservationCompleteness(
        semanticTree: false,
        runtimeMetadata: true,
        navigationState: true,
        screenshot: false,
      ),
    );

    final tree = observationElementsTreeForReport(observation);
    expect(tree, hasLength(2));

    final card = tree.first;
    expect(card['index'], 1);
    expect(card['type'], 'card');
    expect(card.containsKey('kind'), isFalse);
    expect(card.containsKey('locatorStatus'), isFalse);
    expect(card.containsKey('selector'), isFalse);
    expect(card.containsKey('locator'), isFalse);
    expect(
      card.containsKey('title'),
      isFalse,
      reason: 'unkeyed cards are anonymous containers — no caption title',
    );

    final checkbox = (card['children'] as List).single as Map;
    expect(checkbox['index'], 2);
    expect(checkbox.containsKey('selector'), isFalse);
    expect(checkbox['locator'], {'id': 'restore_dns_checkbox'});
    expect(
      checkbox['actionExamples'],
      contains(startsWith('check:')),
    );
    expect(checkbox.containsKey('supportedActions'), isFalse);
    expect(checkbox.containsKey('kind'), isFalse);

    final heading = tree[1];
    expect(heading['index'], 3);
    expect(heading.containsKey('selector'), isFalse);
    expect(heading['locator'], {'text': 'Wat wil je terugzetten?'});
    expect(
      heading['actionExamples'],
      contains(startsWith('waitForText:')),
    );
    expect(heading.containsKey('supportedActions'), isFalse);
    expect(heading['interactable'], isFalse);
    expect(heading.containsKey('locatorStatus'), isFalse);
  });

  test('keyed card report node uses id, not borrowed child text as title', () {
    final observation = UiObservation(
      observationId: 'obs',
      revision: 0,
      timestamp: DateTime.utc(2026, 1, 1),
      screen: const ScreenObservation(name: 'Devices'),
      elements: [
        const UiElement(
          elementId: 'card1',
          testId: 'gateway_card',
          type: 'card',
          text: 'KPN Box 12',
          label: 'KPN Box 12',
          suggestedLocator: ElementLocator(id: 'gateway_card'),
          state: UiElementState(
            visible: true,
            enabled: true,
            interactable: true,
          ),
          children: [
            UiElement(
              elementId: 't1',
              type: 'text',
              text: 'KPN Box 12',
              state: UiElementState(visible: true, interactable: false),
            ),
          ],
        ),
      ],
      viewport: const UiViewport(width: 390, height: 844, devicePixelRatio: 2),
      observableFingerprint: '',
      completeness: const ObservationCompleteness(
        semanticTree: false,
        runtimeMetadata: true,
        navigationState: true,
        screenshot: false,
      ),
    );

    final card = observationElementsTreeForReport(observation).single;
    expect(card['locator'], {'id': 'gateway_card'});
    expect(
      card.containsKey('title'),
      isFalse,
      reason: 'card must not promote nested Text as its own title',
    );
    final textChild = (card['children'] as List).single as Map;
    expect(textChild['title'], 'KPN Box 12');
  });

  test('textInput report node includes hint placeholder', () {
    final observation = UiObservation(
      observationId: 'obs',
      revision: 0,
      timestamp: DateTime.utc(2026, 1, 1),
      screen: const ScreenObservation(name: 'Manual'),
      elements: [
        const UiElement(
          elementId: 'pw1',
          testId: 'fwa_admin_password_input',
          type: 'textInput',
          label: 'Enter the admin password',
          hint: 'It is on the sticker under your modem',
          suggestedLocator: ElementLocator(id: 'fwa_admin_password_input'),
          state: UiElementState(
            visible: true,
            enabled: true,
            interactable: true,
          ),
        ),
      ],
      viewport: const UiViewport(width: 390, height: 844, devicePixelRatio: 2),
      observableFingerprint: '',
      completeness: const ObservationCompleteness(
        semanticTree: false,
        runtimeMetadata: true,
        navigationState: true,
        screenshot: false,
      ),
    );

    final input = observationElementsTreeForReport(observation).single;
    expect(input['locator'], {'id': 'fwa_admin_password_input'});
    expect(input['hint'], 'It is on the sticker under your modem');
    expect(input['title'], 'Enter the admin password');
  });

  test('toast report node does not borrow message text as title', () {
    final observation = UiObservation(
      observationId: 'obs',
      revision: 0,
      timestamp: DateTime.utc(2026, 1, 1),
      screen: const ScreenObservation(name: 'InitApp'),
      elements: [
        const UiElement(
          elementId: 'toast1',
          type: 'toast',
          text: 'Geen token gevonden, open de app opnieuw.',
          state: UiElementState(visible: true, interactable: false),
          children: [
            UiElement(
              elementId: 't1',
              type: 'text',
              text: 'Geen token gevonden, open de app opnieuw.',
              state: UiElementState(visible: true, interactable: false),
            ),
          ],
        ),
      ],
      viewport: const UiViewport(width: 390, height: 844, devicePixelRatio: 2),
      observableFingerprint: '',
      completeness: const ObservationCompleteness(
        semanticTree: false,
        runtimeMetadata: true,
        navigationState: true,
        screenshot: false,
      ),
    );

    final toast = observationElementsTreeForReport(observation).single;
    expect(toast['type'], 'toast');
    expect(
      toast.containsKey('title'),
      isFalse,
      reason: 'toast must not promote nested Text as its own title',
    );
    final textChild = (toast['children'] as List).single as Map;
    expect(textChild['title'], 'Geen token gevonden, open de app opnieuw.');
  });

  test('report tree includes bounds, state, and offscreen elements', () {
    final observation = UiObservation(
      observationId: 'obs',
      revision: 0,
      timestamp: DateTime.utc(2026, 1, 1),
      screen: const ScreenObservation(name: 'Scroll'),
      elements: const [
        UiElement(
          elementId: 'offscreen',
          type: 'button',
          label: 'Continue',
          state: UiElementState(
            exists: true,
            visible: false,
            offscreen: true,
            interactable: false,
            selected: true,
          ),
          bounds: UiBounds(left: 12, top: 900, width: 120, height: 48),
        ),
      ],
      viewport: const UiViewport(width: 390, height: 844),
      observableFingerprint: '',
      completeness: const ObservationCompleteness(),
    );

    final node = observationElementsTreeForReport(observation).single;
    expect(node['visible'], false);
    expect(node['offscreen'], true);
    expect(node['selected'], true);
    expect(node['interactable'], false);
    expect(node['bounds'],
        {'left': 12.0, 'top': 900.0, 'width': 120.0, 'height': 48.0});
    expect(node.containsKey('obscured'), isFalse,
        reason: 'unknown state is omitted rather than reported as false');
  });
}
