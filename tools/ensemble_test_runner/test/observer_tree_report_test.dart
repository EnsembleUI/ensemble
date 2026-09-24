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
      expect(enabled, containsAll(['tap', 'longPress', 'waitFor', 'expectVisible']));

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

    test('unkeyed card still has no interaction steps', () {
      final steps = supportedActionsFor(
        'card',
        secure: false,
        enabled: true,
        text: 'KPN Box 12',
        label: 'KPN Box 12',
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
    expect(card['title'], 'DNS-instellingen');

    final checkbox = (card['children'] as List).single as Map;
    expect(checkbox['index'], 2);
    expect(checkbox['selector'], 'id=restore_dns_checkbox');
    expect(checkbox['supportedActions'], contains('check'));
    expect(checkbox.containsKey('kind'), isFalse);

    final heading = tree[1];
    expect(heading['index'], 3);
    expect(heading['selector'], 'text="Wat wil je terugzetten?"');
    expect(heading['supportedActions'], contains('waitForText'));
    expect(heading['interactable'], isFalse);
    expect(heading.containsKey('locatorStatus'), isFalse);
  });
}
