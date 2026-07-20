import 'dart:async';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/screen_tracker.dart';
import 'package:ensemble_test_runner/actions/extended_step_handlers.dart';
import 'package:ensemble_test_runner/actions/http_request_action.dart';
import 'package:ensemble_test_runner/actions/test_execution_config.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/debug_artifact_logs.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/runner/yaml_test_session.dart';
import 'package:ensemble_test_runner/vocabulary/test_step_vocabulary.dart';
import 'package:flutter/cupertino.dart';
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
  FutureOr<void> Function(TestStep step)? onWaitForTextMatched;

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
      case 'mocks':
        _applyMocks(step.mocks);
        return;
      case 'httpRequest':
        await HttpRequestAction.execute(step.args);
        return;
      case 'wait':
        final durationMs = step.args['durationMs'] as int? ?? 500;
        await tester.runAsync(() async {
          await Future<void>.delayed(Duration(milliseconds: durationMs));
        });
        await _pump(label: 'wait');
        return;
      case 'waitForText':
        await _waitFor(
          step: step,
          text: step.args['text']?.toString(),
          anyOf: _stringListArg(step.args['anyOf']),
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
        await _toggle(_requireId(step));
        break;
      case 'waitFor':
        await _waitFor(
          step: step,
          id: step.args['id']?.toString(),
          text: step.args['text']?.toString(),
          anyOf: _stringListArg(step.args['anyOf']),
          timeoutMs: step.args['timeoutMs'] as int? ??
              config.defaultWaitTimeout.inMilliseconds,
        );
        break;
      case 'pump':
        await _pump(
          duration: Duration(
            milliseconds: step.args['durationMs'] as int? ??
                config.waitPollInterval.inMilliseconds,
          ),
          label: 'pump',
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
        final anyOf = _stringListArg(step.args['anyOf']);
        final text = step.args['text']?.toString();
        if (anyOf.isNotEmpty) {
          assertions.expectTextAny(anyOf);
        } else if (text != null) {
          assertions.expectText(text);
        } else {
          throw EnsembleTestFailure('expectText requires "text" or "anyOf"');
        }
        break;
      case 'expectNoText':
        final anyOf = _stringListArg(step.args['anyOf']);
        final text = step.args['text']?.toString();
        if (anyOf.isNotEmpty) {
          assertions.expectNoTextAny(anyOf);
        } else if (text != null) {
          assertions.expectNoText(text);
        } else {
          throw EnsembleTestFailure('expectNoText requires "text" or "anyOf"');
        }
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
      case 'resetApiCalls':
        context.apiOverlay.resetCalls();
        break;
      case 'logApiCalls':
        final path = await tester.runAsync(() {
          return writeApiCallsLog(context);
        });
        context.logger.log('apiCalls: $path');
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

  Future<void> waitForTextContains({
    String? text,
    List<String> anyOf = const [],
    required int timeoutMs,
  }) async {
    final textCandidates = <String>[
      if (text != null && text.trim().isNotEmpty) text,
      ...anyOf.where((value) => value.trim().isNotEmpty),
    ];
    if (textCandidates.isEmpty) {
      throw EnsembleTestFailure(
        'expectTextContains requires "text" or "anyOf"',
      );
    }

    final stopwatch = Stopwatch()..start();
    while (stopwatch.elapsedMilliseconds < timeoutMs) {
      await _pump(duration: config.waitPollInterval, label: 'expectTextContains');
      if (assertions.isAnyTextContainingVisible(textCandidates)) {
        return;
      }
    }

    throw EnsembleTestFailure(
      'Timed out after ${timeoutMs}ms waiting for text containing one of: '
      '${textCandidates.map((t) => '"$t"').join(', ')}. '
      '${assertions.visibleWidgetIdSummary()} '
      '${assertions.visibleTextSummary()}',
    );
  }

  Future<void> unfocus() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await _settle();
  }

  Future<void> enterTextOn(String id, String value) =>
      _enterText(id, value, submit: false);

  Future<void> settle({Duration? timeout}) => _settle(timeout: timeout);

  void _applyMocks(TestMocks mocks) {
    for (final entry in mocks.apis.entries) {
      context.apiOverlay.setMock(entry.key, entry.value);
    }
  }

  Future<void> openScreenByName(String screen) async {
    final tc = context.testCase;
    _config = await harness.loadScreen(
      tester: tester,
      testCase: EnsembleTestCase(
        id: tc.id,
        startScreen: screen,
        mockFiles: tc.mockFiles,
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
    try {
      await tester.pumpAndSettle(
        config.settleStepDuration,
        EnginePhase.sendSemanticsUpdate,
        timeout ?? config.settleTimeout,
      );
    } catch (e) {
      if (e.toString().contains('timed out') ||
          e.toString().contains('timeout')) {
        // Swallow timeout error because background streams/listeners (e.g. Firestore)
        // might keep the event loop active, but the UI itself has settled.
      } else {
        rethrow;
      }
    }
    await _yieldToLiveApiWork();
  }

  /// Lets in-flight live HTTP (wrapped in [WidgetTester.runAsync]) finish and
  /// pumps a frame so Ensemble can apply API state. Uses [Duration.zero] so
  /// timers from departed screens are not advanced while draining live HTTP.
  Future<void> _yieldToLiveApiWork() async {
    for (var i = 0; i < 200; i++) {
      final hadPending = context.apiOverlay.hasPendingLiveCalls;
      if (hadPending) {
        try {
          await context.apiOverlay
              .waitForLiveCalls()
              .timeout(config.waitPollInterval);
        } on TimeoutException {
          // Keep polling; HTTP may still be in flight inside runAsync.
        }
      }
      await _pump(label: 'liveApi');
      if (!hadPending) {
        return;
      }
    }
  }

  Future<void> _tap(String id) async {
    final baseFinder = assertions.finderForId(id);
    if (baseFinder.evaluate().isEmpty) {
      await _waitFor(
        id: id,
        timeoutMs: config.defaultWaitTimeout.inMilliseconds,
      );
    }
    var finder = _interactiveFinder(baseFinder);
    _expectSingleWidget(finder, id, 'tap');
    await tester.ensureVisible(finder);
    await _pump(label: 'tap.ensureVisible');
    finder = _hitTestableFinderForTap(finder, id);
    await tester.tap(finder);
    await _settle();
  }

  Finder _hitTestableFinderForTap(Finder finder, String id) {
    final hitTestable = finder.hitTestable();
    final hitTestableCount = hitTestable.evaluate().length;
    if (hitTestableCount == 1) return hitTestable;
    if (hitTestableCount > 1) {
      throw EnsembleTestFailure(
        'tap expected exactly one hit-testable widget with id "$id", '
        'but found $hitTestableCount.',
      );
    }
    throw EnsembleTestFailure(
      'tap found widget with id "$id", but it is not hit-testable. '
      'It may be off-screen, disabled, or covered by another widget.',
    );
  }

  Future<void> _toggle(String id) async {
    final baseFinder = assertions.finderForId(id);
    if (baseFinder.evaluate().isEmpty) {
      await _waitFor(
        id: id,
        timeoutMs: config.defaultWaitTimeout.inMilliseconds,
      );
    }
    final finder = _interactiveFinder(baseFinder);
    _expectSingleWidget(finder, id, 'toggle');
    await tester.ensureVisible(finder);

    final control = find.descendant(
      of: finder,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Switch || widget is CupertinoSwitch || widget is Checkbox,
      ),
    );
    await tester.tap(control.evaluate().isNotEmpty ? control.first : finder);
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
    TestStep? step,
    String? id,
    String? text,
    List<String> anyOf = const [],
    required int timeoutMs,
  }) async {
    final textCandidates = <String>[
      if (text != null && text.trim().isNotEmpty) text,
      ...anyOf.where((value) => value.trim().isNotEmpty),
    ];
    if (id == null && textCandidates.isEmpty) {
      throw EnsembleTestFailure(
        'waitFor requires either "id", "text", or "anyOf"',
      );
    }

    final stopwatch = Stopwatch()..start();
    while (stopwatch.elapsedMilliseconds < timeoutMs) {
      await _pump(duration: config.waitPollInterval, label: 'waitFor');
      if (id != null &&
          assertions.finderForId(id).hitTestable().evaluate().isNotEmpty) {
        return;
      }
      if (textCandidates.isNotEmpty &&
          assertions.isAnyTextVisible(textCandidates)) {
        if (step?.type == 'waitForText' && onWaitForTextMatched != null) {
          await onWaitForTextMatched!(step!);
        }
        return;
      }
    }

    final textLabel = textCandidates.isEmpty
        ? null
        : textCandidates.length == 1
            ? 'text "${textCandidates.single}"'
            : 'any text in ${textCandidates.map((t) => '"$t"').join(', ')}';
    final target = id != null && textLabel != null
        ? 'id "$id" or $textLabel'
        : id != null
            ? 'id "$id"'
            : textLabel!;
    throw EnsembleTestFailure(
      'Timed out after ${timeoutMs}ms waiting for $target. '
      '${assertions.visibleWidgetIdSummary()} '
      '${assertions.visibleTextSummary()}',
    );
  }

  static List<String> _stringListArg(dynamic value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item != null && item.toString().trim().isNotEmpty) item.toString(),
    ];
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

  Finder _interactiveFinder(Finder finder) {
    if (finder.evaluate().length <= 1) return finder;
    final hitTestable = finder.hitTestable();
    return hitTestable.evaluate().length == 1 ? hitTestable : finder;
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
        mockFiles: tc.mockFiles,
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
      await _yieldToLiveApiWork();
      await _pump(duration: config.waitPollInterval, label: 'waitForApi');
      if (context.apiOverlay.callCount(name) >= times) {
        await _yieldToLiveApiWork();
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
    bool hasNavigated() =>
        tracker.isScreenVisible(screenName: screen) ||
        tracker.isScreenVisible(screenId: screen) ||
        YamlTestSession.navigationFlow.flow.contains(screen);

    while (stopwatch.elapsedMilliseconds < timeoutMs) {
      await YamlTestSession.navigationFlow.flushPending();
      if (hasNavigated()) {
        return;
      }
      await _yieldToLiveApiWork();
      await _pump(
        duration: config.waitPollInterval,
        label: 'waitForNavigation',
      );
      await YamlTestSession.navigationFlow.flushPending();
      if (hasNavigated()) {
        return;
      }
    }
    await _yieldToLiveApiWork();
    await _pump(label: 'waitForNavigation');
    await YamlTestSession.navigationFlow.flushPending();
    if (hasNavigated()) {
      return;
    }
    throw EnsembleTestFailure(
      'Timed out after ${timeoutMs}ms waiting for navigation to "$screen"',
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

  Future<void> _pump({
    Duration? duration,
    EnginePhase phase = EnginePhase.sendSemanticsUpdate,
    required String label,
  }) async {
    await tester.pump(duration, phase);
  }
}
