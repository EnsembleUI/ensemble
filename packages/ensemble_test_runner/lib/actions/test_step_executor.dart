import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/screen_tracker.dart';
import 'package:ensemble_test_runner/actions/extended_step_handlers.dart';
import 'package:ensemble_test_runner/actions/state_helper.dart';
import 'package:ensemble_test_runner/actions/test_execution_config.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/vocabulary/test_step_vocabulary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Translates declarative [TestStep]s into widget actions or assertions.
class TestStepExecutor {
  final WidgetTester tester;
  final EnsembleTestContext context;
  final AssertionEngine assertions;
  final EnsembleTestHarness harness;
  final TestExecutionConfig config;
  EnsembleConfig? _config;

  TestStepExecutor({
    required this.tester,
    required this.context,
    required this.assertions,
    required this.harness,
    EnsembleConfig? config,
    TestExecutionConfig? executionConfig,
  })  : _config = config,
        config = executionConfig ?? const TestExecutionConfig();

  Future<void> execute(TestStep step) async {
    if (step.type == 'group') {
      for (final nested in step.nestedSteps) {
        await execute(nested);
      }
      return;
    }
    if (step.type == 'repeat') {
      final times = step.args['times'] as int? ?? 1;
      for (var i = 0; i < times; i++) {
        for (final nested in step.nestedSteps) {
          await execute(nested);
        }
      }
      return;
    }
    if (step.type == 'ifVisible') {
      final id = step.args['id']?.toString();
      if (id == null || id.isEmpty) {
        throw EnsembleTestFailure('ifVisible requires "id"');
      }
      if (assertions.finderForId(id).evaluate().isNotEmpty) {
        for (final nested in step.nestedSteps) {
          await execute(nested);
        }
      }
      return;
    }
    if (step.type == 'optional') {
      try {
        for (final nested in step.nestedSteps) {
          await execute(nested);
        }
      } on EnsembleTestFailure {
        // Best-effort steps (e.g. dismiss cookie banner).
      }
      return;
    }

    switch (step.type) {
      case 'wait':
        await tester.pump(
          Duration(
            milliseconds: step.args['durationMs'] as int? ?? 500,
          ),
        );
        return;
      case 'waitForText':
        await _waitFor(
          text: step.args['text']?.toString(),
          timeoutMs: step.args['timeoutMs'] as int? ??
              config.defaultWaitTimeout.inMilliseconds,
        );
        return;
      case 'waitForGone':
        await _waitForGone(
          id: step.args['id']?.toString(),
          timeoutMs: step.args['timeoutMs'] as int? ??
              config.defaultWaitTimeout.inMilliseconds,
        );
        return;
      case 'waitForApi':
        await _waitForApi(
          name: step.args['name']?.toString(),
          times: step.args['times'] as int? ?? 1,
          timeoutMs: step.args['timeoutMs'] as int? ??
              config.defaultWaitTimeout.inMilliseconds,
        );
        return;
      case 'waitForNavigation':
        final screen = step.args['screen']?.toString();
        if (screen == null) {
          throw EnsembleTestFailure('waitForNavigation requires "screen"');
        }
        await _waitForNavigation(
          screen: screen,
          timeoutMs: step.args['timeoutMs'] as int? ??
              config.defaultWaitTimeout.inMilliseconds,
        );
        return;
      case 'waitUntil':
        String? statePath = step.args['path']?.toString();
        dynamic expected = step.args['equals'];
        final stateNode = step.args['state'];
        if (stateNode is Map) {
          statePath ??= stateNode['path']?.toString();
          expected ??= stateNode['equals'];
        }
        await _waitUntil(
          path: statePath,
          expected: expected,
          timeoutMs: step.args['timeoutMs'] as int? ??
              config.defaultWaitTimeout.inMilliseconds,
        );
        return;
      case 'expectScreen':
        final screen =
            step.args['name']?.toString() ?? step.args['screen']?.toString();
        if (screen == null) {
          throw EnsembleTestFailure('expectScreen requires "name" or "screen"');
        }
        assertions.expectNavigateTo(screen);
        return;
    }

    final canonical = TestStepVocabulary.resolveStepType(step.type);
    if (canonical != step.type) {
      return execute(step.withCanonicalType(canonical));
    }

    switch (step.type) {
      case 'openScreen':
        await _openScreen(step);
        break;
      case 'tap':
        await _tap(_requireId(step));
        break;
      case 'enterText':
        await _enterText(
          _requireId(step),
          step.args['value']?.toString() ?? '',
          submit: step.args['submit'] == true,
        );
        break;
      case 'clearText':
        await _clearText(_requireId(step));
        break;
      case 'replaceText':
        await _clearText(_requireId(step));
        await _enterText(
          _requireId(step),
          step.args['value']?.toString() ?? '',
          submit: step.args['submit'] == true,
        );
        break;
      case 'submitText':
        await _submitText(_requireId(step));
        break;
      case 'select':
        await _select(_requireId(step), step.args['value']?.toString());
        break;
      case 'toggle':
        await _tap(_requireId(step));
        break;
      case 'waitFor':
        await _waitFor(
          id: step.args['id']?.toString(),
          text: step.args['text']?.toString(),
          timeoutMs: step.args['timeoutMs'] as int? ??
              config.defaultWaitTimeout.inMilliseconds,
        );
        break;
      case 'pump':
        await tester.pump(
          Duration(
            milliseconds: step.args['durationMs'] as int? ??
                config.waitPollInterval.inMilliseconds,
          ),
        );
        break;
      case 'settle':
        await _settle(
          timeout: step.args['timeoutMs'] != null
              ? Duration(milliseconds: step.args['timeoutMs'] as int)
              : null,
        );
        break;
      case 'scrollUntilVisible':
        await _scrollUntilVisible(_requireId(step));
        break;
      case 'expectVisible':
        assertions.expectVisible(_requireId(step));
        break;
      case 'expectNotVisible':
        assertions.expectNotVisible(_requireId(step));
        break;
      case 'expectText':
        final text = step.args['text']?.toString();
        if (text == null) {
          throw EnsembleTestFailure('expectText requires "text"');
        }
        assertions.expectText(text);
        break;
      case 'expectNoText':
        final text = step.args['text']?.toString();
        if (text == null) {
          throw EnsembleTestFailure('expectNoText requires "text"');
        }
        assertions.expectNoText(text);
        break;
      case 'expectEnabled':
        assertions.expectEnabled(_requireId(step));
        break;
      case 'expectDisabled':
        assertions.expectDisabled(_requireId(step));
        break;
      case 'expectValue':
        assertions.expectValue(_requireId(step), step.args['equals']);
        break;
      case 'expectApiCalled':
        final name = step.args['name']?.toString();
        if (name == null) {
          throw EnsembleTestFailure('expectApiCalled requires "name"');
        }
        assertions.expectApiCalled(name, step.args['times'] as int? ?? 1);
        break;
      case 'expectApiNotCalled':
        final name = step.args['name']?.toString();
        if (name == null) {
          throw EnsembleTestFailure('expectApiNotCalled requires "name"');
        }
        assertions.expectApiNotCalled(name);
        break;
      case 'expectApiRequest':
        final name = step.args['name']?.toString();
        if (name == null) {
          throw EnsembleTestFailure('expectApiRequest requires "name"');
        }
        assertions.expectApiRequest(
          name,
          body: step.args['body'],
          query: step.args['query'],
          headers: step.args['headers'],
          times: step.args['times'] as int?,
        );
        break;
      case 'expectApiRequestContains':
        final containsName = step.args['name']?.toString();
        if (containsName == null) {
          throw EnsembleTestFailure('expectApiRequestContains requires "name"');
        }
        assertions.expectApiRequestContains(
          containsName,
          body: step.args['body'],
          query: step.args['query'],
          headers: step.args['headers'],
          times: step.args['times'] as int?,
        );
        break;
      case 'expectCount':
        final expected = step.args['equals'] as int?;
        if (expected == null) {
          throw EnsembleTestFailure('expectCount requires "equals"');
        }
        assertions.expectCount(_requireId(step), expected);
        break;
      case 'expectNavigateTo':
        final screen = step.args['screen']?.toString();
        if (screen == null) {
          throw EnsembleTestFailure('expectNavigateTo requires "screen"');
        }
        assertions.expectNavigateTo(screen);
        break;
      case 'expectVisited':
        final screen = step.args['screen']?.toString();
        if (screen == null) {
          throw EnsembleTestFailure('expectVisited requires "screen"');
        }
        assertions.expectVisited(screen);
        break;
      case 'expectStorage':
        final key = step.args['key']?.toString();
        if (key == null) {
          throw EnsembleTestFailure('expectStorage requires "key"');
        }
        assertions.expectStorage(key, step.args['equals']);
        break;
      case 'expectState':
        final path = step.args['path']?.toString();
        if (path == null) {
          throw EnsembleTestFailure('expectState requires "path"');
        }
        assertions.expectState(path, step.args['equals']);
        break;
      case 'setState':
        final path = step.args['path']?.toString();
        if (path == null) {
          throw EnsembleTestFailure('setState requires "path"');
        }
        final scope = assertions.activeScope();
        if (scope == null) {
          throw EnsembleTestFailure(
            'setState requires an active Ensemble screen.',
          );
        }
        setStatePath(scope, path, step.args['value']);
        break;
      case 'setStorage':
        final key = step.args['key']?.toString();
        if (key == null) {
          throw EnsembleTestFailure('setStorage requires "key"');
        }
        context.setStorage(key, step.args['value']);
        break;
      case 'setEnv':
        final key = step.args['key']?.toString();
        if (key == null) {
          throw EnsembleTestFailure('setEnv requires "key"');
        }
        context.setEnv(key, step.args['value']);
        break;
      case 'mockApi':
        final name = step.args['name']?.toString();
        if (name == null) {
          throw EnsembleTestFailure('mockApi requires "name"');
        }
        context.mockApiProvider.setMock(
          name,
          context.mockFromStepArgs(step.args),
        );
        break;
      case 'mockApiError':
        final name = step.args['name']?.toString();
        if (name == null) {
          throw EnsembleTestFailure('mockApiError requires "name"');
        }
        context.mockApiProvider.setMock(
          name,
          MockAPIResponse(
            statusCode: step.args['statusCode'] as int? ?? 500,
            body: step.args['body'],
            delayMs: step.args['delayMs'] as int?,
          ),
        );
        break;
      case 'resetApiCalls':
        context.mockApiProvider.resetCalls();
        break;
      case 'logApiCalls':
        for (final call in context.mockApiProvider.calls) {
          context.logger.log(
            'API ${call.name} body=${call.body} query=${call.query}',
          );
        }
        break;
      default:
        if (await ExtendedStepHandlers.tryExecute(this, step)) {
          return;
        }
        throw EnsembleTestFailure(
          'Unknown test step: ${step.type}. See STEP_VOCABULARY.md for supported steps.',
        );
    }
  }

  String requireId(TestStep step) => _requireId(step);

  Future<void> tapWidget(String id) => _tap(id);

  Future<void> longPressWidget(String id) async {
    final finder = assertions.finderForId(id);
    _expectSingleWidget(finder, id, 'longPress');
    await tester.longPress(finder);
    await _settle();
  }

  Future<void> focusWidget(String id) async {
    final finder = assertions.finderForId(id);
    _expectSingleWidget(finder, id, 'focus');
    await tester.tap(finder);
    await _settle();
  }

  Future<void> unfocus() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await _settle();
  }

  Future<void> enterTextOn(String id, String value) =>
      _enterText(id, value, submit: false);

  Future<void> settle({Duration? timeout}) => _settle(timeout: timeout);

  Future<void> openScreenByName(String screen) async {
    final tc = context.testCase;
    _config = await harness.loadScreen(
      tester: tester,
      testCase: EnsembleTestCase(
        id: tc.id,
        startScreen: screen,
        initialState: tc.initialState,
        mocks: tc.mocks,
        steps: const [],
      ),
      existingConfig: _config,
      context: context,
    );
    await _settle();
  }

  String _requireId(TestStep step) {
    final id = step.args['id']?.toString();
    if (id == null || id.isEmpty) {
      throw EnsembleTestFailure('Step "${step.type}" requires "id"');
    }
    return id;
  }

  Future<void> _settle({Duration? timeout}) async {
    await tester.pumpAndSettle(
      config.settleStepDuration,
      EnginePhase.sendSemanticsUpdate,
      timeout ?? config.settleTimeout,
    );
  }

  Future<void> _tap(String id) async {
    final finder = assertions.finderForId(id);
    if (finder.evaluate().isEmpty) {
      await _waitFor(
        id: id,
        timeoutMs: config.defaultWaitTimeout.inMilliseconds,
      );
    }
    _expectSingleWidget(finder, id, 'tap');
    await tester.tap(finder);
    await _settle();
  }

  Future<void> _enterText(String id, String value,
      {bool submit = false}) async {
    final finder = assertions.finderForId(id);
    _expectSingleWidget(finder, id, 'enterText');
    await tester.enterText(finder, value);
    if (submit) {
      await tester.testTextInput.receiveAction(TextInputAction.done);
    }
    await _settle();
  }

  Future<void> _submitText(String id) async {
    final finder = assertions.finderForId(id);
    _expectSingleWidget(finder, id, 'submitText');
    await tester.tap(finder);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settle();
  }

  Future<void> _clearText(String id) async {
    final finder = assertions.finderForId(id);
    _expectSingleWidget(finder, id, 'clearText');
    await tester.enterText(finder, '');
    await _settle();
  }

  Future<void> _select(String id, String? value) async {
    if (value == null || value.isEmpty) {
      throw EnsembleTestFailure('select requires "value"');
    }
    await _tap(id);
    final option = find.text(value);
    if (option.evaluate().isEmpty) {
      throw EnsembleTestFailure('select could not find option "$value"');
    }
    await tester.tap(option);
    await _settle();
  }

  Future<void> _scrollUntilVisible(String id) async {
    final finder = assertions.finderForId(id);
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await _settle();
  }

  Future<void> _waitFor({
    String? id,
    String? text,
    required int timeoutMs,
  }) async {
    if (id == null && text == null) {
      throw EnsembleTestFailure('waitFor requires either "id" or "text"');
    }

    final stopwatch = Stopwatch()..start();
    while (stopwatch.elapsedMilliseconds < timeoutMs) {
      await tester.pump(config.waitPollInterval);
      if (id != null && assertions.finderForId(id).evaluate().isNotEmpty) {
        return;
      }
      if (text != null && find.text(text).evaluate().isNotEmpty) {
        return;
      }
    }

    final target = id != null && text != null
        ? 'id "$id" or text "$text"'
        : id != null
            ? 'id "$id"'
            : 'text "$text"';
    throw EnsembleTestFailure(
      'Timed out after ${timeoutMs}ms waiting for $target. '
      '${assertions.visibleWidgetIdSummary()}',
    );
  }

  void _expectSingleWidget(Finder finder, String id, String stepType) {
    final count = finder.evaluate().length;
    if (count != 1) {
      throw EnsembleTestFailure(
        '$stepType expected exactly one widget with id "$id", but found $count. '
        '${assertions.visibleWidgetIdSummary()}',
      );
    }
  }

  Future<void> _openScreen(TestStep step) async {
    final screen =
        step.args['name']?.toString() ?? step.args['screen']?.toString();
    if (screen == null || screen.isEmpty) {
      throw EnsembleTestFailure('openScreen requires "name" or "screen"');
    }
    final tc = context.testCase;
    _config = await harness.loadScreen(
      tester: tester,
      testCase: EnsembleTestCase(
        id: tc.id,
        startScreen: screen,
        initialState: tc.initialState,
        mocks: tc.mocks,
        steps: const [],
      ),
      existingConfig: _config,
      context: context,
    );
    await _settle();
  }

  Future<void> _waitForApi({
    String? name,
    required int times,
    required int timeoutMs,
  }) async {
    if (name == null || name.isEmpty) {
      throw EnsembleTestFailure('waitForApi requires "name"');
    }

    final stopwatch = Stopwatch()..start();
    while (stopwatch.elapsedMilliseconds < timeoutMs) {
      await tester.pump(config.waitPollInterval);
      if (context.mockApiProvider.callCount(name) >= times) {
        return;
      }
    }
    throw EnsembleTestFailure(
      'Timed out after ${timeoutMs}ms waiting for API "$name" '
      'to be called $times time(s)',
    );
  }

  Future<void> _waitForNavigation({
    required String screen,
    required int timeoutMs,
  }) async {
    final stopwatch = Stopwatch()..start();
    final tracker = ScreenTracker();
    while (stopwatch.elapsedMilliseconds < timeoutMs) {
      await tester.pump(config.waitPollInterval);
      if (tracker.isScreenVisible(screenName: screen) ||
          tracker.isScreenVisible(screenId: screen)) {
        return;
      }
    }
    throw EnsembleTestFailure(
      'Timed out after ${timeoutMs}ms waiting for navigation to "$screen"',
    );
  }

  Future<void> _waitUntil({
    String? path,
    dynamic expected,
    required int timeoutMs,
  }) async {
    if (path == null || path.isEmpty) {
      throw EnsembleTestFailure('waitUntil requires "path"');
    }

    final stopwatch = Stopwatch()..start();
    while (stopwatch.elapsedMilliseconds < timeoutMs) {
      await tester.pump(config.waitPollInterval);
      if (assertions.matchesState(path, expected)) {
        return;
      }
    }
    throw EnsembleTestFailure(
      'Timed out after ${timeoutMs}ms waiting for state "$path" '
      'to equal "$expected"',
    );
  }

  Future<void> _waitForGone({
    String? id,
    required int timeoutMs,
  }) async {
    if (id == null || id.isEmpty) {
      throw EnsembleTestFailure('waitForGone requires "id"');
    }

    final stopwatch = Stopwatch()..start();
    while (stopwatch.elapsedMilliseconds < timeoutMs) {
      await tester.pump(config.waitPollInterval);
      if (assertions.finderForId(id).evaluate().isEmpty) {
        return;
      }
    }
    throw EnsembleTestFailure(
      'Timed out after ${timeoutMs}ms waiting for id "$id" to disappear',
    );
  }
}
