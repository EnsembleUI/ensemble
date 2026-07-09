// ignore_for_file: avoid_print

import 'dart:io';

/// One-time / maintenance generator for [test_step_registry.dart].
/// Run: dart run tool/generate_step_registry.dart
void main() {
  Map<String, dynamic> step(
    String cat,
    String tier,
    String arg,
    String desc, {
    Map<String, dynamic>? example,
  }) =>
      {
        'cat': cat,
        'tier': tier,
        'arg': arg,
        'desc': desc,
        'example': example ?? defaultExampleForArg(arg),
      };

  final entries = <String, Map<String, dynamic>>{
    'openScreen': step(
      'lifecycle',
      'core',
      'openScreen',
      'Navigate to another screen by name or id mid-test',
    ),
    'reloadScreen': step(
      'lifecycle',
      'core',
      'empty',
      'Reload the current screen (same as re-opening it)',
    ),
    'restartApp': step(
      'lifecycle',
      'core',
      'empty',
      'Reset runtime and reopen the test case start screen',
    ),
    'resetAppState': step(
      'lifecycle',
      'core',
      'empty',
      'Clear screen tracker, API call log, and public storage',
    ),
    'trigger': step(
      'lifecycle',
      'core',
      'trigger',
      'Fire a widget action (onLoad, onTap, onLongPress) by testId',
    ),
    'launchApp': step(
      'lifecycle',
      'core',
      'empty',
      'Alias for restartApp — bootstrap from startScreen again',
    ),
    'tap': step(
      'interaction',
      'core',
      'idRequired',
      'Tap a widget by testId (ValueKey)',
    ),
    'doubleTap': step(
      'interaction',
      'core',
      'idRequired',
      'Double-tap a widget by testId',
    ),
    'longPress': step(
      'interaction',
      'core',
      'idRequired',
      'Long-press a widget by testId',
    ),
    'enterText': step(
      'interaction',
      'core',
      'enterText',
      'Type text into an input field by testId',
    ),
    'clearText': step(
      'interaction',
      'core',
      'idRequired',
      'Clear text in an input field by testId',
    ),
    'replaceText': step(
      'interaction',
      'core',
      'enterText',
      'Replace the full contents of an input field',
    ),
    'submitText': step(
      'interaction',
      'core',
      'idRequired',
      'Submit an input field (TextInputAction.done)',
    ),
    'focus': step(
      'interaction',
      'core',
      'idRequired',
      'Focus an input field by testId',
    ),
    'unfocus': step(
      'interaction',
      'core',
      'empty',
      'Remove focus from the current field',
    ),
    'select': step(
      'formControl',
      'core',
      'select',
      'Open a dropdown and choose an option by visible label',
    ),
    'selectIndex': step(
      'formControl',
      'core',
      'selectIndex',
      'Open a dropdown and choose the option at index',
    ),
    'check': step(
      'formControl',
      'core',
      'idRequired',
      'Check a checkbox or toggle by testId',
    ),
    'uncheck': step(
      'formControl',
      'core',
      'idRequired',
      'Uncheck a checkbox by testId if currently checked',
    ),
    'toggle': step(
      'formControl',
      'core',
      'idRequired',
      'Tap to toggle a switch or checkbox by testId',
    ),
    'setSlider': step(
      'formControl',
      'core',
      'setSlider',
      'Move a slider under testId to a normalized value (0–1)',
    ),
    'chooseDate': step(
      'formControl',
      'core',
      'chooseValue',
      'Set a date field by testId to the given value string',
    ),
    'chooseTime': step(
      'formControl',
      'core',
      'chooseValue',
      'Set a time field by testId to the given value string',
    ),
    'scroll': step(
      'gesture',
      'core',
      'scroll',
      'Drag the first Scrollable by delta pixels',
    ),
    'scrollUntilVisible': step(
      'gesture',
      'core',
      'idRequired',
      'Scroll until a widget with testId is visible',
    ),
    'swipe': step(
      'gesture',
      'core',
      'swipe',
      'Swipe on a scrollable or widget (direction: left/right/up/down)',
    ),
    'drag': step(
      'gesture',
      'core',
      'drag',
      'Drag a widget by testId by dx/dy offset',
    ),
    'pullToRefresh': step(
      'gesture',
      'core',
      'idOptional',
      'Pull down on a scrollable to trigger refresh',
    ),
    'wait': step(
      'wait',
      'extended',
      'pump',
      'Alias for pump — advance frame clock by durationMs',
    ),
    'pump': step(
      'wait',
      'core',
      'pump',
      'Advance the Flutter frame clock by durationMs',
    ),
    'settle': step(
      'wait',
      'core',
      'timeoutOptional',
      'Run pumpAndSettle until idle or timeout',
    ),
    'waitFor': step(
      'wait',
      'core',
      'waitFor',
      'Poll until a widget id and/or text appears',
    ),
    'waitForText': step(
      'wait',
      'core',
      'waitFor',
      'Poll until the given text appears on screen',
    ),
    'waitForGone': step(
      'wait',
      'core',
      'waitForGone',
      'Poll until a widget with testId is removed from the tree',
    ),
    'waitForApi': step(
      'wait',
      'core',
      'apiName',
      'Poll until a mocked API is called N times',
    ),
    'waitForNavigation': step(
      'wait',
      'core',
      'waitForNavigation',
      'Poll until the given screen is visible',
    ),
    'waitUntil': step(
      'wait',
      'core',
      'waitUntil',
      'Poll until app state at path equals expected value',
    ),
    'expectVisible': step(
      'uiAssertion',
      'core',
      'idRequired',
      'Assert a widget with testId is visible',
    ),
    'expectNotVisible': step(
      'uiAssertion',
      'core',
      'idRequired',
      'Assert a widget with testId is not visible',
    ),
    'expectExists': step(
      'uiAssertion',
      'core',
      'idRequired',
      'Assert a widget with testId exists in the tree',
    ),
    'expectNotExists': step(
      'uiAssertion',
      'core',
      'idRequired',
      'Assert no widget with testId exists',
    ),
    'expectText': step(
      'uiAssertion',
      'core',
      'textRequired',
      'Assert exact text is shown',
    ),
    'expectNoText': step(
      'uiAssertion',
      'core',
      'textRequired',
      'Assert text is not shown',
    ),
    'expectTextContains': step(
      'uiAssertion',
      'core',
      'textRequired',
      'Assert some text containing the given substring',
    ),
    'expectEnabled': step(
      'uiAssertion',
      'core',
      'idRequired',
      'Assert widget semantics report enabled',
    ),
    'expectDisabled': step(
      'uiAssertion',
      'core',
      'idRequired',
      'Assert widget semantics report disabled',
    ),
    'expectValue': step(
      'valueAssertion',
      'core',
      'expectEquals',
      'Assert input value equals expected (EditableText/TextField)',
    ),
    'expectChecked': step(
      'valueAssertion',
      'core',
      'expectChecked',
      'Assert checkbox checked state matches equals',
    ),
    'expectProperty': step(
      'valueAssertion',
      'core',
      'expectProperty',
      'Assert a widget property (e.g. label) equals expected',
    ),
    'expectStyle': step(
      'valueAssertion',
      'core',
      'expectProperty',
      'Assert style-related property equals expected',
    ),
    'expectSelected': step(
      'valueAssertion',
      'core',
      'expectChecked',
      'Assert selected/checked state matches equals',
    ),
    'expectCount': step(
      'listAssertion',
      'core',
      'expectCount',
      'Assert count of widgets with the same testId',
    ),
    'expectListCount': step(
      'listAssertion',
      'core',
      'expectListCount',
      'Assert number of list items under a list testId',
    ),
    'expectListContains': step(
      'listAssertion',
      'core',
      'expectListContains',
      'Assert list contains text',
    ),
    'expectListItem': step(
      'listAssertion',
      'core',
      'expectListItem',
      'Assert a list item widget with itemId is visible',
    ),
    'expectEmpty': step(
      'listAssertion',
      'core',
      'idRequired',
      'Assert a list has zero items',
    ),
    'expectNotEmpty': step(
      'listAssertion',
      'core',
      'idRequired',
      'Assert a list has at least one item',
    ),
    'expectScreen': step(
      'navigation',
      'core',
      'screenRequired',
      'Alias for expectNavigateTo — assert current screen',
    ),
    'expectNavigateTo': step(
      'navigation',
      'core',
      'screenRequired',
      'Assert the current visible screen name/id',
    ),
    'expectVisited': step(
      'navigation',
      'core',
      'expectVisited',
      'Assert a screen appears in navigation history',
    ),
    'expectNotVisited': step(
      'navigation',
      'core',
      'expectVisited',
      'Assert a screen was never visited',
    ),
    'expectBackStack': step(
      'navigation',
      'core',
      'expectBackStack',
      'Assert navigation history suffix matches screens',
    ),
    'expectCanGoBack': step(
      'navigation',
      'core',
      'expectCanGoBack',
      'Assert whether back navigation is possible',
    ),
    'goBack': step(
      'navigation',
      'core',
      'empty',
      'Navigate back (Ensemble navigateBack or Navigator.pop)',
    ),
    'mockApi': step(
      'apiMock',
      'core',
      'mockApi',
      'Register a mock HTTP API response by API name',
    ),
    'mockApiError': step(
      'apiMock',
      'core',
      'mockApiError',
      'Mock an API to return an error status/body',
    ),
    'mockApiFromFixture': step(
      'fixture',
      'core',
      'mockApiFromFixture',
      'Load mock response body from a JSON fixture asset',
    ),
    'mockApiException': step(
      'apiMock',
      'core',
      'mockApiException',
      'Force an API call to throw an exception',
    ),
    'mockTimeout': step(
      'network',
      'core',
      'mockTimeout',
      'Mock an API with a long delay (simulate timeout)',
    ),
    'resetApiCalls': step(
      'apiMock',
      'core',
      'empty',
      'Clear recorded API call history',
    ),
    'clearApiMocks': step(
      'apiMock',
      'core',
      'empty',
      'Remove all registered API mocks',
    ),
    'expectApiCalled': step(
      'apiAssertion',
      'core',
      'apiName',
      'Assert an API was called an exact number of times',
    ),
    'expectApiNotCalled': step(
      'apiAssertion',
      'core',
      'apiName',
      'Assert an API was never called',
    ),
    'expectApiCallOrder': step(
      'apiAssertion',
      'core',
      'expectApiCallOrder',
      'Assert APIs were called in order',
    ),
    'expectLastApiCall': step(
      'apiAssertion',
      'core',
      'apiName',
      'Assert the most recent API call name',
    ),
    'setState': step(
      'state',
      'core',
      'setState',
      'Set app data-context state at path to value',
    ),
    'expectState': step(
      'state',
      'core',
      'expectState',
      'Assert app state at path equals expected',
    ),
    'expectStateContains': step(
      'state',
      'core',
      'expectState',
      'Assert app state at path contains subset',
    ),
    'expectStateExists': step(
      'state',
      'core',
      'expectStatePath',
      'Assert state path resolves without error',
    ),
    'expectStateNotExists': step(
      'state',
      'core',
      'expectStatePath',
      'Assert state path is null or absent',
    ),
    'resetState': step(
      'state',
      'core',
      'resetStatePath',
      'Clear state at path (set to null)',
    ),
    'setStorage': step(
      'storage',
      'core',
      'storageKey',
      'Write a value to public GetStorage by key',
    ),
    'expectStorage': step(
      'storage',
      'core',
      'storageKey',
      'Assert public storage key equals expected',
    ),
    'removeStorage': step(
      'storage',
      'core',
      'storageKey',
      'Remove a key from public storage',
    ),
    'clearStorage': step(
      'storage',
      'core',
      'empty',
      'Clear all non-encrypted public storage keys',
    ),
    'setEnv': step(
      'runtime',
      'core',
      'storageKey',
      'Override an environment variable for the test',
    ),
    'setAuth': step(
      'runtime',
      'core',
      'setAuth',
      'Simulate a signed-in user',
    ),
    'clearAuth': step(
      'runtime',
      'core',
      'empty',
      'Clear the signed-in user',
    ),
    'setPermission': step(
      'runtime',
      'core',
      'setPermission',
      'Set a permission flag for the test runtime',
    ),
    'setDevice': step(
      'runtime',
      'core',
      'setDevice',
      'Override viewport physical size (width/height)',
    ),
    'setLocale': step(
      'runtime',
      'core',
      'setLocale',
      'Set APP_LOCALE environment override',
    ),
    'setTheme': step(
      'runtime',
      'core',
      'setTheme',
      'Set APP_THEME / theme mode override',
    ),
    'runScript': step(
      'script',
      'core',
      'runScript',
      'Evaluate a script expression in the data context',
    ),
    'expectScriptResult': step(
      'script',
      'core',
      'runScript',
      'Evaluate script and assert result equals expected',
    ),
    'expectConsoleLog': step(
      'script',
      'core',
      'expectConsoleLog',
      'Assert a console log line contains text',
    ),
    'group': step(
      'control',
      'core',
      'group',
      'Run nested steps as a named group',
    ),
    'repeat': step(
      'control',
      'core',
      'repeat',
      'Repeat nested steps N times',
    ),
    'optional': step(
      'control',
      'core',
      'optional',
      'Run nested steps; swallow failures',
    ),
    'ifVisible': step(
      'control',
      'core',
      'ifVisible',
      'Run nested steps only if testId is visible',
    ),
    'logApiCalls': step(
      'debug',
      'core',
      'empty',
      'Log all recorded API calls to the test log',
    ),
    'screenshot': step(
      'debug',
      'core',
      'screenshot',
      'Capture golden or dump widget tree for debugging',
    ),
    'dumpTree': step(
      'debug',
      'core',
      'empty',
      'Print the widget tree to the debug console',
    ),
    'logState': step(
      'debug',
      'core',
      'expectStatePath',
      'Log resolved state at path',
    ),
    'logStorage': step(
      'debug',
      'core',
      'optionalStorageKey',
      'Log one public storage value, or all public storage when key is omitted',
    ),
    'expectNoConsoleErrors': step(
      'quality',
      'core',
      'empty',
      'Assert no console errors were recorded',
    ),
    'expectNoRenderErrors': step(
      'quality',
      'core',
      'empty',
      'Assert no Flutter render errors were recorded',
    ),
    'expectError': step(
      'quality',
      'core',
      'expectErrorContains',
      'Assert a Flutter error was recorded (optional filter)',
    ),
    'expectNoErrors': step(
      'quality',
      'core',
      'empty',
      'Alias for expectNoRenderErrors',
    ),
    'expectAccessible': step(
      'quality',
      'core',
      'idRequired',
      'Assert widget has accessibility label or value',
    ),
    'expectSemanticsLabel': step(
      'quality',
      'core',
      'expectSemanticsLabel',
      'Assert semantics label equals expected',
    ),
    'expectNoOverflow': step(
      'quality',
      'core',
      'idRequired',
      'Assert widget renders without overflow issues',
    ),
    'loadFixture': step(
      'fixture',
      'core',
      'fixturePath',
      'Load a JSON fixture into the test fixture map',
    ),
    'setStateFromFixture': step(
      'fixture',
      'core',
      'fixturePath',
      'Apply all keys from a JSON fixture to state',
    ),
    'expectMatchesFixture': step(
      'fixture',
      'core',
      'fixturePath',
      'Assert state or path matches a JSON fixture',
    ),
  };

  const executorAliases = <String, String>{
    'waitForText': 'waitFor',
    'expectScreen': 'expectNavigateTo',
    'wait': 'pump',
    'launchApp': 'restartApp',
    'expectScript': 'expectScriptResult',
  };

  final buffer = StringBuffer('''
// GENERATED by tool/generate_step_registry.dart — do not edit by hand.
// Re-run: dart run tool/generate_step_registry.dart

import 'package:ensemble_test_runner/vocabulary/test_step_vocabulary.dart';

/// Single source of truth for declarative test steps (metadata + JSON Schema args).
class TestStepRegistryEntry {
  const TestStepRegistryEntry({
    required this.category,
    required this.tier,
    required this.argKind,
    required this.description,
    required this.example,
    this.executorCanonical,
  });

  final TestStepCategory category;
  final TestStepTier tier;
  final TestStepArgKind argKind;
  final String description;

  /// Example YAML args object for this step (also used in JSON Schema).
  final Map<String, dynamic> example;

  /// When set, [TestStepVocabulary.resolveStepType] maps this YAML key here
  /// (e.g. `wait` → `pump`). Schema/definition use this entry's [argKind].
  final String? executorCanonical;
}

abstract final class TestStepRegistry {
  TestStepRegistry._();

  static const Map<String, TestStepRegistryEntry> entries = {
''');

  for (final e in entries.entries) {
    final name = e.key;
    final v = e.value;
    final cat = v['cat'] as String;
    final tier = v['tier'] as String;
    final arg = v['arg'] as String;
    final desc = v['desc'] as String;
    final example = v['example'] as Map<String, dynamic>;
    final execAlias = executorAliases[name];
    buffer.writeln("    '$name': TestStepRegistryEntry(");
    buffer.writeln('      category: TestStepCategory.$cat,');
    buffer.writeln('      tier: TestStepTier.$tier,');
    buffer.writeln('      argKind: TestStepArgKind.$arg,');
    buffer.writeln("      description: '${_escapeDartString(desc)}',");
    buffer.writeln('      example: ${_dartLiteral(example)},');
    if (execAlias != null && execAlias != name) {
      buffer.writeln("      executorCanonical: '$execAlias',");
    }
    buffer.writeln('    ),');
  }

  buffer.writeln('  };');
  buffer.writeln('}');
  buffer.writeln();

  File('lib/vocabulary/test_step_registry.dart')
      .writeAsStringSync(buffer.toString());
  print('Wrote lib/vocabulary/test_step_registry.dart');
}

String _escapeDartString(String s) =>
    s.replaceAll(r'\', r'\\').replaceAll("'", r"\'");

/// Default argument map per [TestStepArgKind] name (override per step when needed).
Map<String, dynamic> defaultExampleForArg(String arg) {
  switch (arg) {
    case 'empty':
      return {};
    case 'openScreen':
      return {'screen': 'Home'};
    case 'trigger':
      return {'action': 'onTap', 'id': 'submit_button'};
    case 'idRequired':
      return {'id': 'my_widget'};
    case 'idOptional':
      return {'id': 'scroll_view'};
    case 'enterText':
      return {'id': 'email_field', 'value': 'user@test.com'};
    case 'select':
      return {'id': 'country_dropdown', 'value': 'USA'};
    case 'selectIndex':
      return {'id': 'country_dropdown', 'index': 0};
    case 'setSlider':
      return {'id': 'volume_slider', 'value': 0.5};
    case 'chooseValue':
      return {'id': 'birth_date', 'value': '2024-01-15'};
    case 'scroll':
      return {'delta': 300};
    case 'swipe':
      return {'direction': 'left', 'id': 'carousel'};
    case 'drag':
      return {'id': 'handle', 'dx': 50, 'dy': 0};
    case 'pump':
      return {'durationMs': 100};
    case 'timeoutOptional':
      return {'timeoutMs': 5000};
    case 'waitFor':
      return {'id': 'loading_spinner', 'timeoutMs': 5000};
    case 'waitForGone':
      return {'id': 'loading_spinner', 'timeoutMs': 5000};
    case 'waitForNavigation':
      return {'screen': 'Home', 'timeoutMs': 5000};
    case 'waitUntil':
      return {'path': 'user.name', 'equals': 'Jane'};
    case 'textRequired':
      return {'text': 'Welcome'};
    case 'expectEquals':
      return {'id': 'email_field', 'equals': 'user@test.com'};
    case 'expectChecked':
      return {'id': 'terms_checkbox', 'equals': true};
    case 'expectProperty':
      return {'id': 'title', 'property': 'label', 'equals': 'Hello'};
    case 'expectCount':
      return {'id': 'badge', 'equals': 2};
    case 'expectListCount':
      return {'id': 'items_list', 'equals': 3};
    case 'screenRequired':
      return {'screen': 'Home'};
    case 'expectVisited':
      return {'screen': 'Login'};
    case 'mockApi':
      return {
        'name': 'login',
        'response': {
          'statusCode': 200,
          'body': {'token': 'test-token'},
        },
      };
    case 'mockApiError':
      return {
        'name': 'login',
        'statusCode': 401,
        'body': {'error': 'Unauthorized'}
      };
    case 'mockApiFromFixture':
      return {'name': 'users', 'fixture': 'fixtures/users.json'};
    case 'mockApiException':
      return {'name': 'login', 'message': 'Network error'};
    case 'mockTimeout':
      return {'name': 'slow_api', 'delayMs': 60000};
    case 'apiName':
      return {'name': 'login', 'times': 1};
    case 'setState':
      return {'path': 'user.name', 'value': 'Jane'};
    case 'expectState':
      return {'path': 'user.name', 'equals': 'Jane'};
    case 'storageKey':
      return {'key': 'onboarding_done', 'value': true};
    case 'optionalStorageKey':
      return {'key': 'onboarding_done'};
    case 'group':
      return {
        'name': 'login_flow',
        'steps': [
          {
            'tap': {'id': 'login_button'}
          },
        ],
      };
    case 'repeat':
      return {
        'times': 3,
        'steps': [
          {
            'tap': {'id': 'next_button'}
          },
        ],
      };
    case 'optional':
      return {
        'steps': [
          {
            'tap': {'id': 'dismiss_banner'}
          },
        ],
      };
    case 'ifVisible':
      return {
        'id': 'promo_banner',
        'steps': [
          {
            'tap': {'id': 'close_banner'}
          },
        ],
      };
    case 'screenshot':
      return {'name': 'home_screen'};
    case 'expectStatePath':
      return {'path': 'user.id'};
    case 'resetStatePath':
      return {'path': 'cart'};
    case 'setAuth':
      return {
        'user': {'id': '1', 'email': 'user@test.com'},
      };
    case 'setPermission':
      return {'name': 'camera', 'value': 'granted'};
    case 'setDevice':
      return {'width': 390, 'height': 844};
    case 'setLocale':
      return {'locale': 'en_US'};
    case 'setTheme':
      return {'mode': 'dark'};
    case 'runScript':
      return {'script': '1 + 1', 'equals': 2};
    case 'expectConsoleLog':
      return {'contains': 'Screen loaded'};
    case 'expectErrorContains':
      return {'contains': 'overflow'};
    case 'fixturePath':
      return {'fixture': 'fixtures/user.json'};
    case 'expectApiCallOrder':
      return {
        'names': ['auth', 'profile']
      };
    case 'expectListContains':
      return {'id': 'items_list', 'text': 'Item 1'};
    case 'expectListItem':
      return {'itemId': 'row_0'};
    case 'expectBackStack':
      return {
        'screens': ['Home', 'Details']
      };
    case 'expectCanGoBack':
      return {'equals': true};
    case 'expectSemanticsLabel':
      return {'id': 'submit_button', 'label': 'Submit'};
    default:
      throw ArgumentError('No default example for arg kind: $arg');
  }
}

String _dartLiteral(dynamic value) {
  if (value is Map) {
    if (value.isEmpty) return 'const {}';
    final parts = value.entries
        .map((e) => "'${e.key}': ${_dartLiteral(e.value)}")
        .join(', ');
    return 'const {$parts}';
  }
  if (value is List) {
    if (value.isEmpty) return 'const []';
    return 'const [${value.map(_dartLiteral).join(', ')}]';
  }
  if (value is String) return "'${_escapeDartString(value)}'";
  if (value is bool || value is int || value is double) return value.toString();
  throw ArgumentError('Unsupported literal type: ${value.runtimeType}');
}
