import 'package:flutter_test/flutter_test.dart';
import 'package:ensemble_test_runner/vocabulary/test_step_vocabulary.dart';
import 'package:ensemble_test_runner/src/runtime/operation_registry.dart';

// Independent contract: keep this list explicit instead of deriving expected
// kinds from categories or operation names, so mixed-category drift is caught.
const Map<TestStepExecutionKind, List<String>> _expectedKeysByKind = {
  TestStepExecutionKind.interaction: [
    'tap',
    'doubleTap',
    'longPress',
    'enterText',
    'clearText',
    'replaceText',
    'submitText',
    'focus',
    'unfocus',
    'select',
    'selectIndex',
    'check',
    'uncheck',
    'toggle',
    'setSlider',
    'chooseDate',
    'chooseTime',
    'scroll',
    'scrollUntilVisible',
    'swipe',
    'drag',
    'pullToRefresh',
  ],
  TestStepExecutionKind.wait: [
    'wait',
    'pump',
    'settle',
    'waitFor',
    'waitForText',
    'waitForGone',
    'waitForApi',
    'waitForNavigation',
  ],
  TestStepExecutionKind.assertion: [
    'expectVisible',
    'expectNotVisible',
    'expectExists',
    'expectNotExists',
    'expectText',
    'expectNoText',
    'expectTextContains',
    'expectEnabled',
    'expectDisabled',
    'expectValue',
    'expectChecked',
    'expectProperty',
    'expectStyle',
    'expectSelected',
    'expectCount',
    'expectListCount',
    'expectListContains',
    'expectListItem',
    'expectEmpty',
    'expectNotEmpty',
    'expectScreen',
    'expectNavigateTo',
    'expectVisited',
    'expectNotVisited',
    'expectBackStack',
    'expectCanGoBack',
    'expectApiCalled',
    'expectApiNotCalled',
    'expectApiCallOrder',
    'expectLastApiCall',
    'expectStorage',
    'expectConsoleLog',
    'expectNoConsoleErrors',
    'expectNoRenderErrors',
    'expectError',
    'expectNoErrors',
    'expectAccessible',
    'expectSemanticsLabel',
    'expectNoOverflow',
  ],
  TestStepExecutionKind.lifecycle: [
    'openScreen',
    'reloadScreen',
    'restartApp',
    'resetAppState',
    'trigger',
    'launchApp',
    'goBack',
  ],
  TestStepExecutionKind.environment: [
    'httpRequest',
    'mocks',
    'resetApiCalls',
    'setEnv',
    'setPermission',
    'setDevice',
    'setLocale',
    'setTheme',
    'setStorage',
    'removeStorage',
    'clearStorage',
  ],
  TestStepExecutionKind.control: ['group', 'repeat', 'optional', 'ifVisible'],
};

void main() {
  final expectedKindByKey = <String, TestStepExecutionKind>{
    for (final entry in _expectedKeysByKind.entries)
      for (final key in entry.value) key: entry.key,
  };

  test('every generated YAML key has its established execution kind', () {
    expect(expectedKindByKey.keys.toSet(), TestStepVocabulary.stepKeys.toSet());

    for (final entry in expectedKindByKey.entries) {
      expect(
        TestStepVocabulary.definitions[entry.key]?.executionKind,
        entry.value,
        reason: 'Unexpected execution kind for "${entry.key}".',
      );
    }
  });

  test('aliases have the execution kind of their canonical operation', () {
    for (final entry in TestStepVocabulary.definitions.entries) {
      final canonical = TestStepVocabulary.resolveStepType(entry.key);
      if (canonical == entry.key) continue;

      expect(
        entry.value.executionKind,
        TestStepVocabulary.definitions[canonical]?.executionKind,
        reason: 'Alias "${entry.key}" differs from "$canonical".',
      );
    }
  });

  test('lifecycle reset and trigger operations have registered handlers', () {
    expect(operationRegistry.lookup('restartApp')?.handlerKey,
        'lifecycle.restartApp');
    expect(operationRegistry.lookup('launchApp')?.handlerKey,
        'lifecycle.restartApp');
    expect(operationRegistry.lookup('resetAppState')?.handlerKey,
        'lifecycle.resetAppState');
    expect(
        operationRegistry.lookup('trigger')?.handlerKey, 'lifecycle.trigger');
  });
}
