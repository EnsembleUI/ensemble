import 'package:ensemble_test_runner/session/actions/test_action.dart';
import 'package:ensemble_test_runner/session/observation/observe_formatter.dart';
import 'package:ensemble_test_runner/session/observation/ui_element.dart';
import 'package:ensemble_test_runner/session/observation/ui_observation.dart';
import 'package:flutter_test/flutter_test.dart';

UiObservation _observation({
  ScreenObservation screen = const ScreenObservation(name: 'Hello Home'),
  List<UiElement> elements = const [],
}) {
  return UiObservation(
    observationId: 'obs-1',
    revision: 1,
    timestamp: DateTime.utc(2026, 1, 2, 3, 4, 5),
    screen: screen,
    elements: elements,
  );
}

UiElement _element({
  String elementId = 'e1',
  String? testId,
  String? type,
  String? role,
  String? text,
  String? label,
  bool? visible,
  bool? enabled,
  List<UiElement> children = const [],
}) {
  return UiElement(
    elementId: elementId,
    testId: testId,
    type: type,
    role: role,
    text: text,
    label: label,
    state: UiElementState(visible: visible, enabled: enabled),
    children: children,
  );
}

void main() {
  test('ObserveFormat.parse defaults to text and accepts json', () {
    expect(ObserveFormat.parse(null), ObserveFormat.text);
    expect(ObserveFormat.parse(''), ObserveFormat.text);
    expect(ObserveFormat.parse('TEXT'), ObserveFormat.text);
    expect(ObserveFormat.parse('json'), ObserveFormat.json);
    expect(() => ObserveFormat.parse('yaml'), throwsArgumentError);
  });

  test('text outline uses numbered Elements sections', () {
    final text = const ObserveFormatter().format(
      _observation(
        elements: [
          _element(
            testId: 'login_btn',
            type: 'button',
            text: 'Log in',
            visible: true,
            enabled: false,
          ),
          _element(
            type: 'text',
            text: 'Welcome',
            visible: true,
          ),
        ],
      ),
    );

    expect(text, contains('Screen: Hello Home'));
    expect(text, contains('Observation: obs-1'));
    expect(text, contains('Elements (2):'));
    expect(text, contains('[1] button: Log in'));
    expect(text, contains('enabled: false'));
    expect(text, contains('[2] text: Welcome'));
    expect(
      text,
      contains('[1] button: Log in\n'
          '      id: login_btn\n'
          '      enabled: false\n'
          '      selector: unavailable\n'
          '\n'
          '  [2] text: Welcome'),
    );
    expect(text, isNot(contains('interactive:')));
    expect(text, isNot(contains('visible=')));
  });

  test('text outline prints verified selector, id, and warning', () {
    final text = const ObserveFormatter().format(
      _observation(
        elements: [
          UiElement(
            elementId: 'e1',
            testId: 'login_test_token',
            type: 'button',
            text: 'Login with test token',
            suggestedLocator:
                const ElementLocator(id: 'login_test_token'),
            state: const UiElementState(visible: true, enabled: true),
          ),
          UiElement(
            elementId: 'e2',
            type: 'button',
            text: 'Login with test token',
            role: 'button',
            suggestedLocator: const ElementLocator(
              label: 'Login with test token',
              role: 'button',
            ),
            state: const UiElementState(visible: true, enabled: true),
          ),
          UiElement(
            elementId: 'e3',
            type: 'icon',
            locatorWarning: 'No stable locator available',
            state: const UiElementState(visible: true),
          ),
        ],
      ),
    );

    expect(
      text,
      contains('[1] button: Login with test token\n'
          '      id: login_test_token\n'
          '      enabled: true\n'
          '      selector: id=login_test_token'),
    );
    expect(
      text,
      contains(
        'selector: label="Login with test token", role=button',
      ),
    );
    expect(
      text,
      contains('[3] icon:\n'
          '      selector: unavailable\n'
          '      warning: No stable locator available'),
    );
    expect(text, isNot(contains('interactive:')));
  });

  test('text outline flattens nested children into one numbered list', () {
    final text = const ObserveFormatter().format(
      _observation(
        elements: [
          _element(
            elementId: 'form',
            testId: 'form',
            type: 'widget',
            visible: true,
            children: [
              _element(
                elementId: 'email',
                testId: 'email',
                type: 'textInput',
                label: 'Email',
                visible: true,
                enabled: true,
              ),
            ],
          ),
        ],
      ),
    );

    expect(text, contains('Elements (2):'));
    expect(text, contains('[1] widget: form'));
    expect(text, contains('[2] textInput: Email'));
    expect(text, contains('value: (empty)'));
  });

  test('text outline falls back to Unknown and empty widget title', () {
    final text = const ObserveFormatter().format(
      _observation(
        screen: ScreenObservation.unknown(),
        elements: [_element()],
      ),
    );

    expect(text, contains('Screen: Unknown'));
    expect(text, contains('Elements (1):'));
    expect(text, contains('[1] widget:'));
  });

  test('text outline shows checked for switch on/off state', () {
    final text = const ObserveFormatter().format(
      _observation(
        elements: [
          UiElement(
            elementId: 'sw',
            testId: 'stub_switch',
            type: 'switch',
            label: 'Use Stub URL',
            state: const UiElementState(
              visible: true,
              enabled: true,
              checked: false,
            ),
          ),
        ],
      ),
    );

    expect(text, contains('[1] switch: Use Stub URL'));
    expect(text, contains('checked: false'));
    expect(text, isNot(contains('interactive:')));
  });

  test('text outline shows labeled inputs, hints, and dropdown options', () {
    final text = const ObserveFormatter().format(
      _observation(
        elements: [
          UiElement(
            elementId: 't1',
            type: 'text',
            text: 'Hello',
            state: const UiElementState(visible: true),
          ),
          UiElement(
            elementId: 't2',
            type: 'textInput',
            text: 'http://instellen.local/ws',
            label: 'Local API Endpoint',
            state: const UiElementState(visible: true, enabled: true),
          ),
          UiElement(
            elementId: 't3',
            type: 'textInput',
            label: 'Generated Password Override',
            hint: 'Optional INHOME_GENERATED_PASSWORD',
            state: const UiElementState(visible: true, enabled: true),
          ),
          UiElement(
            elementId: 't4',
            type: 'textInput',
            label: 'Secret',
            state: const UiElementState(
              visible: true,
              enabled: true,
              secure: true,
            ),
          ),
          UiElement(
            elementId: 't5',
            type: 'dropdown',
            text: 'HGW_SAH',
            label: 'Device Type',
            options: const ['HGW_SAH', 'HGW_OTHER', 'STB'],
            state: const UiElementState(visible: true),
          ),
        ],
      ),
    );

    expect(text, contains('[1] text: Hello'));
    expect(text, contains('[2] textInput: Local API Endpoint'));
    expect(text, contains('value: http://instellen.local/ws'));
    expect(text, contains('[3] textInput: Generated Password Override'));
    expect(text, contains('value: (empty)'));
    expect(text, contains('hint: Optional INHOME_GENERATED_PASSWORD'));
    expect(text, contains('[4] textInput: Secret'));
    expect(text, contains('value: (secure)'));
    expect(text, contains('[5] dropdown: Device Type'));
    expect(text, contains('value: HGW_SAH'));
    expect(text, contains('options: [HGW_SAH, HGW_OTHER, STB]'));
  });

  test('text outline splits hidden elements into a second section', () {
    final text = const ObserveFormatter().format(
      _observation(
        elements: [
          UiElement(
            elementId: 'v1',
            type: 'text',
            text: 'Visible',
            state: const UiElementState(visible: true),
          ),
          UiElement(
            elementId: 'h1',
            type: 'button',
            text: 'Login with test token',
            state: const UiElementState(visible: false, enabled: true),
          ),
          UiElement(
            elementId: 'h2',
            type: 'text',
            text: 'v0.6.0 (60)',
            state: const UiElementState(visible: false),
          ),
        ],
      ),
    );

    expect(text, contains('Elements (1):'));
    expect(text, contains('[1] text: Visible'));
    expect(text, contains('Hidden elements (2):'));
    expect(text, contains('[2] button: Login with test token'));
    expect(text, contains('enabled: true'));
    expect(text, isNot(contains('interactive:')));
    expect(text, contains('[3] text: v0.6.0 (60)'));
  });

  test('json format is pretty UiObservation.toJson()', () {
    final json = const ObserveFormatter().format(
      _observation(),
      format: ObserveFormat.json,
    );

    expect(json, contains('"observationId": "obs-1"'));
    expect(json, contains('"name": "Hello Home"'));
    expect(json, startsWith('{'));
  });

  test('text outline includes screenshot path when provided', () {
    final text = const ObserveFormatter().format(
      _observation(),
      screenshotPaths: ['/tmp/Login_light_nl.png'],
    );
    expect(text, contains('Screenshots:'));
    expect(text, contains('file:///tmp/Login_light_nl.png'));
  });

  test('json format includes screenshotPath when provided', () {
    final json = const ObserveFormatter().format(
      _observation(),
      format: ObserveFormat.json,
      screenshotPaths: ['/tmp/Login_light_nl.png'],
    );
    expect(json, contains('"screenshotPath": "/tmp/Login_light_nl.png"'));
    expect(json, contains('"screenshotPaths"'));
  });

  test('json format includes suggestedLocator and locatorWarning', () {
    final json = const ObserveFormatter().format(
      _observation(
        elements: [
          UiElement(
            elementId: 'e1',
            testId: 'login_btn',
            type: 'button',
            suggestedLocator: const ElementLocator(id: 'login_btn'),
            state: const UiElementState(enabled: true),
          ),
          UiElement(
            elementId: 'e2',
            type: 'icon',
            locatorWarning: 'No stable locator available',
            state: const UiElementState(enabled: true),
          ),
        ],
      ),
      format: ObserveFormat.json,
    );

    expect(json, contains('"suggestedLocator"'));
    expect(json, contains('"id": "login_btn"'));
    expect(json, contains('"locatorWarning": "No stable locator available"'));
    expect(json, contains('"enabled": true'));
  });

  test('extractObservePayload reads marked body', () {
    const output = '''
00:00 +0: loading
ENSEMBLE_TEST_OBSERVE_V1_BEGIN
Screen: Hello Home
Elements (0):
ENSEMBLE_TEST_OBSERVE_V1_END
00:00 +1: All tests passed!
''';

    expect(
      extractObservePayload(output),
      'Screen: Hello Home\nElements (0):',
    );
  });

  test('extractObservePayload strips flutter log prefixes', () {
    const output = '''
flutter: ENSEMBLE_TEST_OBSERVE_V1_BEGIN
flutter: Screen: Home
I/flutter (12345): more
flutter: ENSEMBLE_TEST_OBSERVE_V1_END
''';

    expect(
      extractObservePayload(output),
      'Screen: Home\nmore',
    );
  });

  test('extractObservePayload returns null without markers', () {
    expect(extractObservePayload('no payload here'), isNull);
    expect(
      extractObservePayload('ENSEMBLE_TEST_OBSERVE_V1_BEGIN\nonly begin'),
      isNull,
    );
  });

  test('extractObservePayload keeps JSON body intact for --format=json', () {
    const output = '''
00:00 +0: loading
ENSEMBLE_TEST_OBSERVE_V1_BEGIN
{
  "observationId": "obs-1",
  "elements": []
}
ENSEMBLE_TEST_OBSERVE_V1_END
00:00 +1: All tests passed!
''';

    final payload = extractObservePayload(output);
    expect(payload, contains('"observationId": "obs-1"'));
    expect(payload, startsWith('{'));
    expect(payload, isNot(contains('All tests passed')));
  });
}
