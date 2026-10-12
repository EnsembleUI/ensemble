import 'package:ensemble_test_runner/session/observation/diagnostic_locators.dart';
import 'package:ensemble_test_runner/session/observation/ui_element.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unique diagnostic locators keep the projected observer fields', () {
    const input = [
      UiElement(
        elementId: 'first',
        type: 'text',
        text: 'First',
        state: UiElementState(visible: true),
      ),
      UiElement(
        elementId: 'second',
        type: 'text',
        text: 'Second',
        state: UiElementState(visible: true),
      ),
    ];

    final projected = annotateDiagnosticLocators(input);

    expect(
      projected.map((element) => element.toJson()).toList(),
      [
        {
          'elementId': 'first',
          'type': 'text',
          'text': 'First',
          'suggestedLocator': {'text': 'First'},
          'state': {'visible': true},
        },
        {
          'elementId': 'second',
          'type': 'text',
          'text': 'Second',
          'suggestedLocator': {'text': 'Second'},
          'state': {'visible': true},
        },
      ],
    );
  });

  test('duplicate diagnostic locators are still cleared with warnings', () {
    const input = [
      UiElement(elementId: 'first', type: 'text', text: 'Duplicate'),
      UiElement(elementId: 'second', type: 'text', text: 'Duplicate'),
    ];

    final projected = annotateDiagnosticLocators(input);

    expect(projected.map((element) => element.suggestedLocator),
        everyElement(isNull));
    expect(
      projected.map((element) => element.locatorWarning),
      everyElement('Suggested locator matches multiple observed elements'),
    );
  });

  test('a shared locator on one ancestor chain remains usable', () {
    const input = [
      UiElement(
        elementId: 'parent',
        type: 'toast',
        label: 'Details',
        state: UiElementState(interactable: true),
        children: [
          UiElement(
            elementId: 'child',
            type: 'toast',
            label: 'Details',
            state: UiElementState(interactable: true),
          ),
        ],
      ),
    ];

    final projected = annotateDiagnosticLocators(input);

    expect(projected.single.suggestedLocator, isNotNull);
    expect(projected.single.locatorWarning, isNull);
    expect(projected.single.children.single.suggestedLocator, isNotNull);
    expect(projected.single.children.single.locatorWarning, isNull);
  });

  test('repeated locators in separate descendant branches are ambiguous', () {
    const input = [
      UiElement(
        elementId: 'root',
        type: 'screen',
        children: [
          UiElement(
            elementId: 'left-branch',
            type: 'widget',
            children: [
              UiElement(
                elementId: 'left',
                type: 'toast',
                label: 'Details',
                state: UiElementState(interactable: true),
              ),
            ],
          ),
          UiElement(
            elementId: 'right-branch',
            type: 'widget',
            children: [
              UiElement(
                elementId: 'right',
                type: 'toast',
                label: 'Details',
                state: UiElementState(interactable: true),
              ),
            ],
          ),
        ],
      ),
    ];

    final projected = annotateDiagnosticLocators(input);
    final descendants = projected.single.children;
    final repeatedElements = [
      descendants[0].children.single,
      descendants[1].children.single,
    ];

    expect(repeatedElements.map((element) => element.suggestedLocator),
        everyElement(isNull));
    expect(
      repeatedElements.map((element) => element.locatorWarning),
      everyElement('Suggested locator matches multiple observed elements'),
    );
  });
}
