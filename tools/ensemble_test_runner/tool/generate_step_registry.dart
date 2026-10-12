// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

/// One-time / maintenance generator for [test_step_registry.dart].
/// Check with `dart run tool/generate_step_registry.dart --check`.
/// Write with `dart run tool/generate_step_registry.dart --write`.
Future<void> main(List<String> args) async {
  final checkOnly = args.contains('--check');
  final writeRequested = args.contains('--write');
  final unknownArgs =
      args.where((arg) => arg != '--check' && arg != '--write').toList();
  if (unknownArgs.isNotEmpty) {
    stderr.writeln('Unknown arguments: ${unknownArgs.join(', ')}');
    exitCode = 64;
    return;
  }
  if (checkOnly == writeRequested) {
    stderr.writeln('Choose exactly one of --check or --write.');
    exitCode = 64;
    return;
  }
  Map<String, dynamic> step(
    String cat,
    String tier,
    String arg,
    String desc, {
    Map<String, dynamic>? example,
    String? handlerKey,
    bool restrictedUiAllowed = true,
    bool acceptsTimeout = false,
    bool userAction = false,
    bool notifiesConditionMatched = false,
    List<String> requiredCapabilities = const [],
    String? waitKind,
    String? waitTargetState,
    String? controlKind,
  }) =>
      {
        'cat': cat,
        'tier': tier,
        'arg': arg,
        'desc': desc,
        'example': example ?? defaultExampleForArg(arg),
        if (handlerKey != null) 'handler': handlerKey,
        if (!restrictedUiAllowed) 'restrictedUiAllowed': false,
        if (acceptsTimeout) 'acceptsTimeout': true,
        if (userAction) 'userAction': true,
        if (notifiesConditionMatched) 'notifiesConditionMatched': true,
        if (requiredCapabilities.isNotEmpty)
          'requiredCapabilities': requiredCapabilities,
        if (waitKind != null) 'waitKind': waitKind,
        if (waitTargetState != null) 'waitTargetState': waitTargetState,
        if (controlKind != null) 'controlKind': controlKind,
      };

  final entries = <String, Map<String, dynamic>>{
    'openScreen': step(
      'lifecycle',
      'core',
      'openScreen',
      'Navigate to another screen by name or id mid-test',
      handlerKey: 'lifecycle.openScreen',
      requiredCapabilities: const ['ensembleHarness'],
    ),
    'reloadScreen': step(
      'lifecycle',
      'core',
      'empty',
      'Reload the current screen (same as re-opening it)',
      handlerKey: 'lifecycle.reloadScreen',
      requiredCapabilities: const ['ensembleHarness'],
    ),
    'restartApp': step(
      'lifecycle',
      'core',
      'empty',
      'Reset runtime and reopen the test case start screen',
      handlerKey: 'lifecycle.restartApp',
      requiredCapabilities: const ['ensembleHarness'],
    ),
    'resetAppState': step(
      'lifecycle',
      'core',
      'empty',
      'Clear screen tracker, API call log, and public storage',
      handlerKey: 'lifecycle.resetAppState',
    ),
    'trigger': step(
      'lifecycle',
      'core',
      'trigger',
      'Fire a widget action (onLoad, onTap, onLongPress) by testId',
      handlerKey: 'lifecycle.trigger',
    ),
    'launchApp': step(
      'lifecycle',
      'core',
      'empty',
      'Alias for restartApp — bootstrap from startScreen again',
      requiredCapabilities: const ['ensembleHarness'],
    ),
    'tap': step(
      'interaction',
      'core',
      'idRequired',
      'Tap a widget by testId (ValueKey)',
      example: const {'id': 'my_widget', 'timeoutMs': 5000},
      handlerKey: 'interaction.tap',
      acceptsTimeout: true,
      userAction: true,
    ),
    'doubleTap': step(
      'interaction',
      'core',
      'idRequired',
      'Double-tap a widget by testId',
      handlerKey: 'interaction.doubleTap',
      acceptsTimeout: true,
      userAction: true,
    ),
    'longPress': step(
      'interaction',
      'core',
      'idRequired',
      'Long-press a widget by testId',
      handlerKey: 'interaction.longPress',
      acceptsTimeout: true,
      userAction: true,
    ),
    'enterText': step(
      'interaction',
      'core',
      'enterText',
      'Type text into an input field by testId',
      handlerKey: 'interaction.enterText',
      acceptsTimeout: true,
      userAction: true,
    ),
    'clearText': step(
      'interaction',
      'core',
      'idRequired',
      'Clear text in an input field by testId',
      handlerKey: 'interaction.clearText',
      acceptsTimeout: true,
      userAction: true,
    ),
    'replaceText': step(
      'interaction',
      'core',
      'enterText',
      'Replace the full contents of an input field',
      handlerKey: 'interaction.replaceText',
      userAction: true,
    ),
    'submitText': step(
      'interaction',
      'core',
      'idRequired',
      'Submit an input field (TextInputAction.done)',
      handlerKey: 'interaction.submitText',
      acceptsTimeout: true,
      userAction: true,
    ),
    'focus': step(
      'interaction',
      'core',
      'idRequired',
      'Focus an input field by testId',
      handlerKey: 'interaction.focus',
      acceptsTimeout: true,
      userAction: true,
    ),
    'unfocus': step(
      'interaction',
      'core',
      'empty',
      'Remove focus from the current field',
      handlerKey: 'interaction.unfocus',
    ),
    'select': step(
      'formControl',
      'core',
      'select',
      'Open a dropdown and choose an option by visible label',
      handlerKey: 'interaction.select',
      userAction: true,
    ),
    'selectIndex': step(
      'formControl',
      'core',
      'selectIndex',
      'Open a dropdown and choose the option at index',
      handlerKey: 'interaction.selectIndex',
      userAction: true,
    ),
    'check': step(
      'formControl',
      'core',
      'idRequired',
      'Check a checkbox or toggle by testId',
      handlerKey: 'interaction.check',
      acceptsTimeout: true,
      userAction: true,
    ),
    'uncheck': step(
      'formControl',
      'core',
      'idRequired',
      'Uncheck a checkbox by testId if currently checked',
      handlerKey: 'interaction.uncheck',
      acceptsTimeout: true,
      userAction: true,
    ),
    'toggle': step(
      'formControl',
      'core',
      'idRequired',
      'Tap to toggle a switch or checkbox by testId',
      handlerKey: 'interaction.toggle',
      acceptsTimeout: true,
      userAction: true,
    ),
    'setSlider': step(
      'formControl',
      'core',
      'setSlider',
      'Move a slider under testId to a normalized value (0–1)',
      handlerKey: 'interaction.setSlider',
      restrictedUiAllowed: false,
      userAction: true,
    ),
    'chooseDate': step(
      'formControl',
      'core',
      'chooseValue',
      'Set a date field by testId to the given value string',
      handlerKey: 'interaction.chooseDate',
      restrictedUiAllowed: false,
    ),
    'chooseTime': step(
      'formControl',
      'core',
      'chooseValue',
      'Set a time field by testId to the given value string',
      handlerKey: 'interaction.chooseTime',
      restrictedUiAllowed: false,
    ),
    'scroll': step(
      'gesture',
      'core',
      'scroll',
      'Drag the first Scrollable by delta pixels',
      handlerKey: 'interaction.scroll',
    ),
    'scrollUntilVisible': step(
      'gesture',
      'core',
      'idRequired',
      'Scroll until a widget with testId is visible',
      handlerKey: 'interaction.scrollUntilVisible',
      acceptsTimeout: true,
      notifiesConditionMatched: true,
    ),
    'swipe': step(
      'gesture',
      'core',
      'swipe',
      'Swipe on a scrollable or widget (direction: left/right/up/down)',
      handlerKey: 'interaction.swipe',
    ),
    'drag': step(
      'gesture',
      'core',
      'drag',
      'Drag a widget by testId by dx/dy offset',
      handlerKey: 'interaction.drag',
    ),
    'pullToRefresh': step(
      'gesture',
      'core',
      'idOptional',
      'Pull down on a scrollable to trigger refresh',
      handlerKey: 'interaction.pullToRefresh',
      restrictedUiAllowed: false,
    ),
    'wait': step(
      'wait',
      'extended',
      'pump',
      'Real-time delay using runAsync, followed by a frame pump',
      waitKind: 'pump',
    ),
    'pump': step(
      'wait',
      'core',
      'pump',
      'Advance the Flutter frame clock by durationMs',
      waitKind: 'pump',
    ),
    'settle': step(
      'wait',
      'core',
      'timeoutOptional',
      'Wait for the UI to become idle or until timeout',
      waitKind: 'settle',
    ),
    'waitFor': step(
      'wait',
      'core',
      'waitFor',
      'Poll until a widget id and/or text appears',
      waitKind: 'uiElement',
    ),
    'waitForText': step(
      'wait',
      'core',
      'waitFor',
      'Poll until the given text appears on screen',
      waitKind: 'text',
    ),
    'waitForGone': step(
      'wait',
      'core',
      'waitForGone',
      'Poll until a widget with testId is removed from the tree',
      waitKind: 'uiElement',
      waitTargetState: 'absent',
    ),
    'waitForApi': step(
      'wait',
      'core',
      'apiName',
      'Wait until N calls to the named API complete',
      example: const {'name': 'login', 'times': 1, 'timeoutMs': 5000},
      waitKind: 'api',
      requiredCapabilities: const ['api'],
    ),
    'httpRequest': step(
      'runtime',
      'core',
      'httpRequest',
      'Send an HTTP request to a test support service',
      handlerKey: 'http.request.direct',
    ),
    'mocks': step(
      'apiMock',
      'core',
      'empty',
      'Replace active API mocks for subsequent steps',
      handlerKey: 'api.mocks',
      requiredCapabilities: const ['apiMocking'],
      example: const {
        'getDevices': {
          'body': {'count': 2},
        },
      },
    ),
    'waitForNavigation': step(
      'wait',
      'core',
      'waitForNavigation',
      'Poll until the given screen is visible',
      waitKind: 'navigation',
      requiredCapabilities: const ['navigation'],
    ),
    'expectVisible': step(
      'uiAssertion',
      'core',
      'idRequired',
      'Assert a widget with testId is visible',
      handlerKey: 'expectVisible',
      acceptsTimeout: true,
    ),
    'expectNotVisible': step(
      'uiAssertion',
      'core',
      'idRequiredNoTimeout',
      'Assert a widget with testId is not visible',
      handlerKey: 'expectNotVisible',
    ),
    'expectExists': step(
      'uiAssertion',
      'core',
      'idRequiredNoTimeout',
      'Assert a widget with testId exists in the tree',
      handlerKey: 'assertion.exists',
    ),
    'expectNotExists': step(
      'uiAssertion',
      'core',
      'idRequiredNoTimeout',
      'Assert no widget with testId exists',
      handlerKey: 'assertion.notExists',
    ),
    'expectText': step(
      'uiAssertion',
      'core',
      'textOrAnyOf',
      'Assert exact text is shown (or anyOf list)',
      handlerKey: 'assertion.text',
      acceptsTimeout: true,
    ),
    'expectNoText': step(
      'uiAssertion',
      'core',
      'textOrAnyOf',
      'Assert text is not shown (or none of anyOf)',
      handlerKey: 'assertion.textAbsent',
    ),
    'expectTextContains': step(
      'uiAssertion',
      'core',
      'textContains',
      'Assert some text containing the given substring (or anyOf list)',
      handlerKey: 'assertion.textContains',
    ),
    'expectEnabled': step(
      'uiAssertion',
      'core',
      'idRequiredNoTimeout',
      'Assert widget semantics report enabled',
      handlerKey: 'assertion.enabled',
    ),
    'expectDisabled': step(
      'uiAssertion',
      'core',
      'idRequiredNoTimeout',
      'Assert widget semantics report disabled',
      handlerKey: 'assertion.disabled',
    ),
    'expectValue': step(
      'valueAssertion',
      'core',
      'expectEquals',
      'Assert input value equals expected (EditableText/TextField)',
      handlerKey: 'assertion.value',
    ),
    'expectChecked': step(
      'valueAssertion',
      'core',
      'expectChecked',
      'Assert checkbox checked state matches equals',
      handlerKey: 'assertion.checked',
    ),
    'expectProperty': step(
      'valueAssertion',
      'core',
      'expectProperty',
      'Assert a widget property (e.g. label) equals expected',
      handlerKey: 'assertion.property',
    ),
    'expectStyle': step(
      'valueAssertion',
      'core',
      'expectProperty',
      'Assert style-related property equals expected',
      handlerKey: 'assertion.style',
    ),
    'expectSelected': step(
      'valueAssertion',
      'core',
      'expectChecked',
      'Assert selected/checked state matches equals',
      handlerKey: 'assertion.checked',
    ),
    'expectCount': step(
      'listAssertion',
      'core',
      'expectCount',
      'Assert count of widgets with the same testId',
      handlerKey: 'assertion.count',
    ),
    'expectListCount': step(
      'listAssertion',
      'core',
      'expectListCount',
      'Assert number of list items under a list testId',
      handlerKey: 'assertion.listCount',
    ),
    'expectListContains': step(
      'listAssertion',
      'core',
      'expectListContains',
      'Assert list contains text',
      handlerKey: 'assertion.listContains',
    ),
    'expectListItem': step(
      'listAssertion',
      'core',
      'expectListItem',
      'Assert a list item widget with itemId is visible',
      handlerKey: 'assertion.listItem',
    ),
    'expectEmpty': step(
      'listAssertion',
      'core',
      'idRequired',
      'Assert a list has zero items',
      handlerKey: 'assertion.listEmpty',
    ),
    'expectNotEmpty': step(
      'listAssertion',
      'core',
      'idRequired',
      'Assert a list has at least one item',
      handlerKey: 'assertion.listNotEmpty',
    ),
    'expectScreen': step(
      'navigation',
      'core',
      'screenRequired',
      'Alias for expectNavigateTo — assert current screen',
      requiredCapabilities: const ['navigation'],
    ),
    'expectNavigateTo': step(
      'navigation',
      'core',
      'screenRequired',
      'Assert the current visible screen name/id',
      handlerKey: 'expectNavigateTo',
      requiredCapabilities: const ['navigation'],
    ),
    'expectVisited': step(
      'navigation',
      'core',
      'expectVisited',
      'Assert a screen appears in navigation history',
      handlerKey: 'expectVisited',
      requiredCapabilities: const ['navigation'],
    ),
    'expectNotVisited': step(
      'navigation',
      'core',
      'expectVisited',
      'Assert a screen was never visited',
      handlerKey: 'assertion.notVisited',
      requiredCapabilities: const ['navigation'],
    ),
    'expectBackStack': step(
      'navigation',
      'core',
      'expectBackStack',
      'Assert navigation history suffix matches screens',
      handlerKey: 'assertion.backStack',
      requiredCapabilities: const ['navigation'],
    ),
    'expectCanGoBack': step(
      'navigation',
      'core',
      'expectCanGoBack',
      'Assert whether back navigation is possible',
      handlerKey: 'assertion.canGoBack',
      requiredCapabilities: const ['navigation'],
    ),
    'goBack': step(
      'navigation',
      'core',
      'empty',
      'Navigate back (Ensemble navigateBack or Navigator.pop)',
      handlerKey: 'lifecycle.goBack',
      requiredCapabilities: const ['navigation'],
    ),
    'resetApiCalls': step(
      'apiMock',
      'core',
      'empty',
      'Clear recorded API call history',
      handlerKey: 'environment.resetApiCalls',
      requiredCapabilities: const ['api'],
    ),
    'expectApiCalled': step(
      'apiAssertion',
      'core',
      'apiName',
      'Assert an API was called an exact number of times',
      handlerKey: 'assertion.apiCalled',
      requiredCapabilities: const ['api'],
    ),
    'expectApiNotCalled': step(
      'apiAssertion',
      'core',
      'apiName',
      'Assert an API was never called',
      handlerKey: 'assertion.apiNotCalled',
      requiredCapabilities: const ['api'],
    ),
    'expectApiCallOrder': step(
      'apiAssertion',
      'core',
      'expectApiCallOrder',
      'Assert APIs were called in order',
      handlerKey: 'assertion.apiCallOrder',
      requiredCapabilities: const ['api'],
    ),
    'expectLastApiCall': step(
      'apiAssertion',
      'core',
      'apiName',
      'Assert the most recent API call name',
      handlerKey: 'assertion.lastApiCall',
      requiredCapabilities: const ['api'],
    ),
    'setStorage': step(
      'storage',
      'core',
      'storageKey',
      'Write a value to public GetStorage by key',
      handlerKey: 'storage.set',
      requiredCapabilities: const ['storage'],
    ),
    'expectStorage': step(
      'storage',
      'core',
      'storageKey',
      'Assert public storage key equals expected',
      handlerKey: 'assertion.storageEquals',
      requiredCapabilities: const ['storage'],
    ),
    'removeStorage': step(
      'storage',
      'core',
      'storageKey',
      'Remove a key from public storage',
      handlerKey: 'storage.remove',
      requiredCapabilities: const ['storage'],
    ),
    'clearStorage': step(
      'storage',
      'core',
      'empty',
      'Clear all non-encrypted public storage keys',
      handlerKey: 'storage.clear',
      requiredCapabilities: const ['storage'],
    ),
    'setEnv': step(
      'runtime',
      'core',
      'storageKey',
      'Override an environment variable for the test',
      handlerKey: 'environment.set',
    ),
    'setPermission': step(
      'runtime',
      'core',
      'setPermission',
      'Set a permission flag for the test runtime',
      handlerKey: 'environment.setPermission',
    ),
    'setDevice': step(
      'runtime',
      'core',
      'setDevice',
      'Override viewport physical size (width/height)',
      handlerKey: 'environment.setDevice',
    ),
    'setLocale': step(
      'runtime',
      'core',
      'setLocale',
      'Set APP_LOCALE environment override',
      handlerKey: 'environment.setLocale',
    ),
    'setTheme': step(
      'runtime',
      'core',
      'setTheme',
      'Set Ensemble theme via EnsembleThemeManager (e.g. light/dark)',
      handlerKey: 'environment.setTheme',
    ),
    'expectConsoleLog': step(
      'script',
      'core',
      'expectConsoleLog',
      'Assert a console log line contains text',
      handlerKey: 'assertion.consoleLog',
    ),
    'group': step(
      'control',
      'core',
      'group',
      'Run nested steps as a named group',
      controlKind: 'group',
    ),
    'repeat': step(
      'control',
      'core',
      'repeat',
      'Repeat nested steps N times',
      controlKind: 'repeat',
    ),
    'optional': step(
      'control',
      'core',
      'optional',
      'Run nested steps; swallow failures',
      controlKind: 'optional',
    ),
    'ifVisible': step(
      'control',
      'core',
      'ifVisible',
      'Run nested steps only if testId is visible',
      controlKind: 'ifVisible',
    ),
    'expectNoConsoleErrors': step(
      'quality',
      'core',
      'empty',
      'Assert no console errors were recorded',
      handlerKey: 'assertion.noConsoleErrors',
    ),
    'expectNoRenderErrors': step(
      'quality',
      'core',
      'empty',
      'Assert no Flutter render errors were recorded',
      handlerKey: 'assertion.noRenderErrors',
    ),
    'expectError': step(
      'quality',
      'core',
      'expectErrorContains',
      'Assert a Flutter error was recorded (optional filter)',
      handlerKey: 'assertion.errorRecorded',
    ),
    'expectNoErrors': step(
      'quality',
      'core',
      'empty',
      'Alias for expectNoRenderErrors',
      handlerKey: 'assertion.noRenderErrors',
    ),
    'expectAccessible': step(
      'quality',
      'core',
      'idRequired',
      'Assert widget has accessibility label or value',
      handlerKey: 'assertion.accessible',
    ),
    'expectSemanticsLabel': step(
      'quality',
      'core',
      'expectSemanticsLabel',
      'Assert semantics label equals expected',
      handlerKey: 'assertion.semanticsLabel',
    ),
    'expectNoOverflow': step(
      'quality',
      'core',
      'idRequired',
      'Assert widget renders without overflow issues',
      handlerKey: 'assertion.noOverflow',
    ),
  };

  const executorAliases = <String, String>{
    'waitForText': 'waitFor',
    'expectScreen': 'expectNavigateTo',
    'launchApp': 'restartApp',
  };

  // Steps that emit a before-mutation or matched-state evidence boundary.
  // This is distinct from `userAction`: gestures, lifecycle navigation, and
  // matched waits also own ordered capture timing.
  const orderedEvidenceSteps = <String>{
    'tap',
    'select',
    'toggle',
    'enterText',
    'clearText',
    'replaceText',
    'submitText',
    'scroll',
    'swipe',
    'drag',
    'pullToRefresh',
    'check',
    'uncheck',
    'doubleTap',
    'longPress',
    'focus',
    'unfocus',
    'selectIndex',
    'setSlider',
    'chooseDate',
    'chooseTime',
    'openScreen',
    'reloadScreen',
    'trigger',
    'goBack',
    'restartApp',
    'launchApp',
    'resetAppState',
    'waitForNavigation',
    'waitForText',
  };
  for (final name in orderedEvidenceSteps) {
    final entry = entries[name];
    if (entry == null) {
      throw StateError('Ordered evidence step "$name" is not registered.');
    }
    entry['orderedEvidence'] = true;
  }

  // Explicit mixed-category exceptions. The generated metadata is consumed by
  // execution adapters, so operation kind must not depend on name prefixes.
  const executionKindOverrides = <String, String>{
    'expectScreen': 'assertion',
    'expectNavigateTo': 'assertion',
    'expectVisited': 'assertion',
    'expectNotVisited': 'assertion',
    'expectBackStack': 'assertion',
    'expectCanGoBack': 'assertion',
    'expectStorage': 'assertion',
    'expectConsoleLog': 'assertion',
  };

  String executionKind(String name, String category) =>
      executionKindOverrides[name] ??
      switch (category) {
        'interaction' || 'formControl' || 'gesture' => 'interaction',
        'wait' => 'wait',
        'uiAssertion' ||
        'valueAssertion' ||
        'listAssertion' ||
        'apiAssertion' ||
        'quality' =>
          'assertion',
        'lifecycle' => 'lifecycle',
        'navigation' => 'lifecycle',
        'apiMock' ||
        'storage' ||
        'runtime' ||
        'script' ||
        'network' =>
          'environment',
        'control' => 'control',
        'debug' => 'diagnostic',
        _ =>
          throw StateError('Missing execution kind for "$name" ($category).'),
      };

  final buffer = StringBuffer('''
// GENERATED by tool/generate_step_registry.dart — do not edit by hand.
// Re-run: dart run tool/generate_step_registry.dart --write

import 'package:ensemble_test_runner/vocabulary/test_step_vocabulary.dart';

/// Single source of truth for declarative test steps (metadata + JSON Schema args).
class TestStepRegistryEntry {
  const TestStepRegistryEntry({
    required this.category,
    required this.executionKind,
    required this.tier,
    required this.argKind,
    required this.description,
    required this.example,
    this.executorCanonical,
    this.handlerKey,
    this.restrictedUiAllowed = true,
    this.acceptsTimeout = false,
    this.userAction = false,
    this.orderedEvidence = false,
    this.notifiesConditionMatched = false,
    this.requiredCapabilities = const {},
    this.waitKind,
    this.waitTargetState,
    this.controlKind,
  });

  final TestStepCategory category;
  final TestStepExecutionKind executionKind;
  final TestStepTier tier;
  final TestStepArgKind argKind;
  final String description;

  /// Example YAML args object for this step (also used in JSON Schema).
  final Map<String, dynamic> example;

  /// When set, [TestStepVocabulary.resolveStepType] maps this YAML key here
  /// (e.g. `wait` → `pump`). Schema/definition use this entry's [argKind].
  final String? executorCanonical;

  /// Stable runtime dispatch key shared by all execution adapters.
  final String? handlerKey;

  /// Whether restricted UI sessions may invoke this operation.
  final bool restrictedUiAllowed;

  /// Whether callers may bound this operation with optional `timeoutMs`.
  final bool acceptsTimeout;

  /// Whether this operation mutates or submits the user-facing interface.
  final bool userAction;

  /// Whether the step owns a before-mutation or matched-state capture point.
  final bool orderedEvidence;

  /// Whether operation success indicates that its requested condition matched.
  final bool notifiesConditionMatched;

  /// Application services required by this operation during validation.
  final Set<String> requiredCapabilities;

  /// Permission/synchronization category for wait operations.
  final String? waitKind;

  /// Required final state when a wait resolves an element target.
  final String? waitTargetState;

  /// Plan-node kind for control-flow entries; absent on operations.
  final TestStepControlKind? controlKind;

  /// Effective argument schema after shared timeout metadata is applied.
  Map<String, dynamic> get argumentSchema {
    final schema = argKind.jsonSchema;
    if (!acceptsTimeout) return schema;
    final properties = Map<String, dynamic>.from(
      schema['properties'] as Map? ?? const {},
    );
    properties.putIfAbsent('timeoutMs', () => const {'type': 'integer'});
    return {
      ...schema,
      'properties': Map<String, dynamic>.unmodifiable(properties),
    };
  }
}

abstract final class TestStepRegistry {
  TestStepRegistry._();

  static const Map<String, TestStepRegistryEntry> entries = {
''');

  for (final e in entries.entries) {
    final name = e.key;
    final v = e.value;
    final cat = v['cat'] as String;
    final kind = executionKind(name, cat);
    final tier = v['tier'] as String;
    final arg = v['arg'] as String;
    final desc = v['desc'] as String;
    final example = v['example'] as Map<String, dynamic>;
    final execAlias = executorAliases[name];
    final handlerKey = v['handler'] as String?;
    final restrictedUiAllowed = v['restrictedUiAllowed'] != false;
    final acceptsTimeout = v['acceptsTimeout'] == true;
    final userAction = v['userAction'] == true;
    final orderedEvidence = v['orderedEvidence'] == true;
    final notifiesConditionMatched = v['notifiesConditionMatched'] == true;
    final requiredCapabilities =
        List<String>.from(v['requiredCapabilities'] as List? ?? const []);
    final waitKind = v['waitKind'] as String?;
    final waitTargetState = v['waitTargetState'] as String?;
    final controlKind = v['controlKind'] as String?;
    if ((cat == 'control') != (controlKind != null)) {
      throw StateError('Control metadata mismatch for "$name".');
    }
    buffer.writeln("    '$name': TestStepRegistryEntry(");
    buffer.writeln('      category: TestStepCategory.$cat,');
    buffer.writeln('      executionKind: TestStepExecutionKind.$kind,');
    if (controlKind != null) {
      buffer.writeln('      controlKind: TestStepControlKind.$controlKind,');
    }
    buffer.writeln('      tier: TestStepTier.$tier,');
    buffer.writeln('      argKind: TestStepArgKind.$arg,');
    buffer.writeln("      description: '${_escapeDartString(desc)}',");
    buffer.writeln('      example: ${_dartLiteral(example, indent: 6)},');
    if (execAlias != null && execAlias != name) {
      buffer.writeln("      executorCanonical: '$execAlias',");
    }
    if (handlerKey != null) {
      buffer.writeln("      handlerKey: '$handlerKey',");
    }
    if (!restrictedUiAllowed) {
      buffer.writeln('      restrictedUiAllowed: false,');
    }
    if (acceptsTimeout) {
      buffer.writeln('      acceptsTimeout: true,');
    }
    if (userAction) {
      buffer.writeln('      userAction: true,');
    }
    if (orderedEvidence) {
      buffer.writeln('      orderedEvidence: true,');
    }
    if (notifiesConditionMatched) {
      buffer.writeln('      notifiesConditionMatched: true,');
    }
    if (requiredCapabilities.isNotEmpty) {
      buffer.writeln(
        '      requiredCapabilities: const {${requiredCapabilities.map((value) => "'${_escapeDartString(value)}'").join(', ')}},',
      );
    }
    if (waitKind != null) {
      buffer.writeln("      waitKind: '$waitKind',");
    }
    if (waitTargetState != null) {
      buffer.writeln("      waitTargetState: '$waitTargetState',");
    }
    buffer.writeln('    ),');
  }

  buffer.writeln('  };');
  buffer.writeln('}');

  final formatter = await Process.start(
    'dart',
    [
      'format',
      '--language-version=3.5',
      '--output=show',
      '/dev/stdin',
    ],
  );
  final generatedFuture = formatter.stdout.transform(utf8.decoder).join();
  final formatterErrorFuture = formatter.stderr.transform(utf8.decoder).join();
  formatter.stdin.write(buffer.toString());
  await formatter.stdin.close();
  final formatterExitCode = await formatter.exitCode;
  final formatterOutput = await generatedFuture;
  final formatterError = await formatterErrorFuture;
  if (formatterExitCode != 0) {
    stderr.write(formatterError);
    exitCode = formatterExitCode;
    return;
  }
  // `dart format --output=show` writes a human-readable summary after the
  // formatted source. Keep only the source so --check compares deterministic
  // content and remains safe to run in CI.
  final generated = formatterOutput.replaceFirst(
    RegExp(r'\nFormatted \d+ files? \([^\n]*\) in [^\n]*\n?$'),
    '\n',
  );
  final target = File('lib/vocabulary/test_step_registry.dart');
  if (checkOnly) {
    if (!target.existsSync()) {
      stderr.writeln('Missing generated file: ${target.path}');
      exitCode = 1;
      return;
    }
    final current = target.readAsStringSync();
    if (current != generated) {
      stderr.writeln('Generated registry is out of date: ${target.path}');
      _printDifferences(current, generated);
      exitCode = 1;
      return;
    }
    print('Registry matches generator output.');
    return;
  }

  target.writeAsStringSync(generated);
  print('Wrote ${target.path}');
}

void _printDifferences(String current, String generated) {
  final currentLines = current.split('\n');
  final generatedLines = generated.split('\n');
  final commonLength = currentLines.length < generatedLines.length
      ? currentLines.length
      : generatedLines.length;
  var differenceCount = 0;
  for (var index = 0; index < commonLength; index++) {
    if (currentLines[index] == generatedLines[index]) continue;
    stderr.writeln('Difference at line ${index + 1}:');
    stderr.writeln('  current:   ${currentLines[index]}');
    stderr.writeln('  generated: ${generatedLines[index]}');
    differenceCount++;
    if (differenceCount == 20) {
      stderr.writeln('Further differences omitted.');
      return;
    }
  }
  stderr.writeln(
    'Line counts differ: current ${currentLines.length}, '
    'generated ${generatedLines.length}.',
  );
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
    case 'idRequiredNoTimeout':
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
    case 'httpRequest':
      return {
        'method': 'POST',
        'url': 'http://127.0.0.1:5001/api/test/reset',
        'body': {'enabled': true},
        'expectStatus': 200,
      };
    case 'waitFor':
      return {'id': 'loading_spinner', 'timeoutMs': 5000};
    case 'waitForGone':
      return {'id': 'loading_spinner', 'timeoutMs': 5000};
    case 'waitForNavigation':
      return {'screen': 'Home', 'timeoutMs': 5000};
    case 'textRequired':
      return {'text': 'Welcome'};
    case 'textOrAnyOf':
      return {'text': 'Welcome'};
    case 'textContains':
      return {'text': 'Welcome', 'timeoutMs': 5000};
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
    case 'apiName':
      return {'name': 'login', 'times': 1};
    case 'storageKey':
      return {'key': 'onboarding_done', 'value': true};
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
    case 'setPermission':
      return {'name': 'camera', 'value': 'granted'};
    case 'setDevice':
      return {'width': 390, 'height': 844};
    case 'setLocale':
      return {'locale': 'en_US'};
    case 'setTheme':
      return {'mode': 'dark'};
    case 'expectConsoleLog':
      return {'contains': 'Screen loaded'};
    case 'expectErrorContains':
      return {'contains': 'overflow'};
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

String _dartLiteral(dynamic value, {required int indent}) {
  final padding = ' ' * indent;
  String line(String key, dynamic child) =>
      "${' ' * (indent + 2)}'${_escapeDartString(key)}': "
      '${_dartLiteral(child, indent: indent + 2)}';

  if (value is Map) {
    if (value.isEmpty) return 'const {}';
    final nested = value.values.any((item) => item is Map || item is List);
    if (!nested) {
      final parts = value.entries
          .map((entry) => "'${_escapeDartString(entry.key.toString())}': "
              '${_dartLiteral(entry.value, indent: indent + 2)}')
          .join(', ');
      return 'const {$parts}';
    }
    final parts = value.entries.map((entry) => line(
          entry.key.toString(),
          entry.value,
        ));
    return 'const {\n${parts.join(',\n')}\n$padding}';
  }
  if (value is List) {
    if (value.isEmpty) return 'const []';
    final nested = value.any((item) => item is Map || item is List);
    if (!nested) {
      return 'const [${value.map((item) => _dartLiteral(
            item,
            indent: indent + 2,
          )).join(', ')}]';
    }
    final parts = value.map((item) => '${' ' * (indent + 2)}'
        '${_dartLiteral(item, indent: indent + 2)}');
    return 'const [\n${parts.join(',\n')}\n$padding]';
  }
  if (value is String) return "'${_escapeDartString(value)}'";
  if (value is bool || value is int || value is double) return value.toString();
  throw ArgumentError('Unsupported literal type: ${value.runtimeType}');
}
