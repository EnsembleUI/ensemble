import 'dart:async';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/screen_tracker.dart';
import 'package:ensemble_test_runner/actions/extended_step_handlers.dart';
import 'package:ensemble_test_runner/actions/http_request_action.dart';
import 'package:ensemble_test_runner/actions/test_execution_config.dart';
import 'package:ensemble_test_runner/application/application_test_driver.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/debug_artifact_logs.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/runner/flutter_error_filters.dart';
import 'package:ensemble_test_runner/runner/yaml_test_session.dart';
import 'package:ensemble_test_runner/session/errors/test_execution_error.dart';
import 'package:ensemble_test_runner/session/actions/test_action.dart';
import 'package:ensemble_test_runner/vocabulary/test_step_vocabulary.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Translates declarative [TestStep]s into widget actions or assertions.
class TestStepExecutor {
  final WidgetTester tester;
  final EnsembleTestContext context;
  final AssertionEngine assertions;
  final EnsembleTestHarness? harness;
  final ApplicationTestServices services;
  final TestExecutionConfig config;
  EnsembleConfig? _config;
  FutureOr<void> Function(TestStep step)? onWaitForTextMatched;
  Finder Function(ElementTarget target, {bool requireInteractive})?
      resolveTargetFinder;
  FutureOr<void> Function(TestStep step)? onWaitForNavigationMatched;
  FutureOr<void> Function(TestStep step)? onBeforeActionStep;
  FutureOr<void> Function(TestStep step)? onAfterActionStep;

  TestStepExecutor({
    required this.tester,
    required this.context,
    required this.assertions,
    this.harness,
    this.services = const ApplicationTestServices(),
    EnsembleConfig? config,
    TestExecutionConfig? executionConfig,
  })  : _config = config,
        config = executionConfig ?? const TestExecutionConfig();

  EnsembleTestHarness get requireHarness {
    final value = harness;
    if (value == null) {
      throw const UnsupportedApplicationCapability('ensembleHarness');
    }
    return value;
  }

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
      var isVisible = false;
      try {
        isVisible = finderForTargetStep(step).evaluate().isNotEmpty;
      } on TestExecutionError catch (error) {
        if (error.code != TestExecutionErrorCode.elementNotFound) rethrow;
      }
      if (isVisible) {
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
      } on EnsembleTestFailure catch (e) {
        // Optional may skip missing UI (cookie banners, etc.) — never swallow
        // framework/build failures. Those leave a red ErrorWidget and the next
        // steps become meaningless.
        if (e.toString().contains('Unexpected Flutter framework error')) {
          rethrow;
        }
      } on TestExecutionError {
        // Session/dispatcher path may surface structured errors.
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
        // LiveTestWidgetsFlutterBinding: plain delayed is enough. Do not wrap
        // in tester.runAsync — live HTTP already owns runAsync and nesting
        // throws "Reentrant call to runAsync() denied".
        await _liveDelay(Duration(milliseconds: durationMs));
        await _pump(label: 'wait');
        return;
      case 'waitForText':
        await _waitFor(
          step: step,
          text: step.args['text']?.toString(),
          anyOf: _stringListArg(step.args['anyOf']),
          target: step.args['target'] is Map
              ? ElementTarget(
                  locator: ElementLocator.fromJson(
                    Map<String, dynamic>.from(step.args['target'] as Map),
                  ),
                )
              : step.args['bounds'] is Map
                  ? ElementTarget(
                      locator: ElementLocator(
                        bounds: ElementBounds.fromJson(
                          Map<String, dynamic>.from(
                            step.args['bounds'] as Map,
                          ),
                        ),
                      ),
                    )
                  : step.args['id'] != null
                      ? ElementTarget(testId: step.args['id'].toString())
                      : null,
          timeoutMs: step.args['timeoutMs'] as int? ??
              config.defaultWaitTimeout.inMilliseconds,
        );
        return;
      case 'waitForGone':
        await _waitForGone(
          target: _targetForStep(step),
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
        final navigation = services.navigation;
        if (navigation != null) {
          // Prefer history over currentRoute alone: transient screens
          // (Loading → Status, Home → Devices) are often left during the
          // previous action's settle before this wait starts.
          final timeoutMs = step.args['timeoutMs'] as int? ??
              config.defaultWaitTimeout.inMilliseconds;
          final stopwatch = Stopwatch()..start();
          while (stopwatch.elapsedMilliseconds <= timeoutMs) {
            await YamlTestSession.navigationFlow.flushPending();
            if (navigation.currentRoute == screen ||
                navigation.routeHistory.contains(screen)) {
              return;
            }
            await _pump(
              duration: config.waitPollInterval,
              label: 'waitForNavigation.history',
            );
          }
          await YamlTestSession.navigationFlow.flushPending();
          if (navigation.currentRoute == screen ||
              navigation.routeHistory.contains(screen)) {
            return;
          }
          throw EnsembleTestFailure(
            'Timed out after ${timeoutMs}ms waiting for route "$screen"',
          );
        }
        await _waitForNavigation(
          step: step,
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
        _expectNavigateTo(screen);
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
        await _tap(
          _requireId(step),
          timeoutMs: step.args['timeoutMs'] as int?,
          step: step,
        );
        break;
      case 'enterText':
        await _enterText(
          _requireId(step),
          step.args['value']?.toString() ?? '',
          submit: step.args['submit'] == true,
        );
        await onAfterActionStep?.call(step);
        break;
      case 'clearText':
        await _clearText(_requireId(step));
        await onAfterActionStep?.call(step);
        break;
      case 'replaceText':
        await _clearText(_requireId(step));
        await _enterText(
          _requireId(step),
          step.args['value']?.toString() ?? '',
          submit: step.args['submit'] == true,
        );
        await onAfterActionStep?.call(step);
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
        await _scrollUntilVisible(
          _requireId(step),
          scrollableId: step.args['scrollableId']?.toString(),
        );
        break;
      case 'expectVisible':
        assertions.expectVisibleFinder(finderForTargetStep(step));
        break;
      case 'expectNotVisible':
        assertions.expectVisibleFinder(
          finderForTargetStep(step, requireInteractive: false),
          visible: false,
        );
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
        assertions.expectEnabledFinder(finderForTargetStep(step));
        break;
      case 'expectDisabled':
        assertions.expectEnabledFinder(
          finderForTargetStep(step),
          enabled: false,
        );
        break;
      case 'expectValue':
        assertions.expectValueFinder(
          finderForTargetStep(step),
          step.args['equals'],
          description: targetDescription(step),
        );
        break;
      case 'expectApiCalled':
        final name = step.args['name']?.toString();
        if (name == null) {
          throw EnsembleTestFailure('expectApiCalled requires "name"');
        }
        _expectApiCalled(name, step.args['times'] as int? ?? 1);
        break;
      case 'expectApiNotCalled':
        final name = step.args['name']?.toString();
        if (name == null) {
          throw EnsembleTestFailure('expectApiNotCalled requires "name"');
        }
        _expectApiCalled(name, 0);
        break;
      case 'expectCount':
        final expected = step.args['equals'] as int?;
        if (expected == null) {
          throw EnsembleTestFailure('expectCount requires "equals"');
        }
        assertions.expectCountFinder(
          finderForTargetStep(step),
          expected,
          description: targetDescription(step),
        );
        break;
      case 'expectNavigateTo':
        final screen = step.args['screen']?.toString();
        if (screen == null) {
          throw EnsembleTestFailure('expectNavigateTo requires "screen"');
        }
        _expectNavigateTo(screen);
        break;
      case 'expectVisited':
        final screen = step.args['screen']?.toString();
        if (screen == null) {
          throw EnsembleTestFailure('expectVisited requires "screen"');
        }
        _expectVisited(screen);
        break;
      case 'expectStorage':
        final key = step.args['key']?.toString();
        if (key == null) {
          throw EnsembleTestFailure('expectStorage requires "key"');
        }
        _expectStorage(key, step.args['equals']);
        break;
      case 'setStorage':
        final key = step.args['key']?.toString();
        if (key == null) {
          throw EnsembleTestFailure('setStorage requires "key"');
        }
        await _setStorage(key, step.args['value']);
        break;
      case 'setEnv':
        final key = step.args['key']?.toString();
        if (key == null) {
          throw EnsembleTestFailure('setEnv requires "key"');
        }
        context.setEnv(key, step.args['value']);
        break;
      case 'resetApiCalls':
        _resetApiCalls();
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

  Finder finderForTargetStep(
    TestStep step, {
    bool requireInteractive = true,
  }) {
    final target = _targetForStep(step);
    if (target.locator != null || target.usesSnapshotElement) {
      final resolve = resolveTargetFinder;
      if (resolve == null) {
        throw EnsembleTestFailure(
          'Step "${step.type}" requires a session target resolver.',
        );
      }
      return resolve(target, requireInteractive: requireInteractive);
    }
    final id = target.testId;
    if (id == null || id.isEmpty) {
      throw EnsembleTestFailure(
          'Step "${step.type}" requires "id" or "target"');
    }
    return assertions.finderForId(id, skipOffstage: requireInteractive);
  }

  ElementTarget _targetForStep(TestStep step) {
    final raw = step.args['target'];
    if (raw is Map) {
      return ElementTarget(
        locator: ElementLocator.fromJson(Map<String, dynamic>.from(raw)),
      );
    }
    final id = step.args['id']?.toString() ?? step.args['itemId']?.toString();
    return ElementTarget(testId: id == null || id.isEmpty ? null : id);
  }

  String targetDescription(TestStep step) =>
      step.args['id']?.toString() ??
      step.args['itemId']?.toString() ??
      step.args['target']?.toString() ??
      'target';

  Future<void> tapWidget(String id, {int? timeoutMs}) =>
      _tap(id, timeoutMs: timeoutMs);

  /// Taps an already-resolved [Finder] (exact element identity; no id rematch).
  Future<void> tapFinder(Finder finder, {TestStep? step}) async {
    if (finder.evaluate().isEmpty) {
      throw EnsembleTestFailure(
        'tapFinder: target element is not in the tree (detached or never found).',
      );
    }
    await tester.ensureVisible(finder);
    await _pump(label: 'tapFinder.ensureVisible');
    final hitTestable = finder.hitTestable();
    if (hitTestable.evaluate().isEmpty) {
      throw EnsembleTestFailure(
        'tapFinder: target element is not hit-testable. '
        'It may be off-screen, disabled, or covered by another widget.',
      );
    }
    if (step != null && onBeforeActionStep != null) {
      await onBeforeActionStep!(step);
    }
    await tester.tap(hitTestable.first);
    await _settleAfterAction();
  }

  Future<void> doubleTapFinder(Finder finder) async {
    await tapFinder(finder);
    await tapFinder(finder);
  }

  Future<void> longPressWidget(String id) async {
    final finder = assertions.finderForId(id);
    _expectSingleWidget(finder, id, 'longPress');
    await tester.longPress(finder);
    await _settleAfterAction();
  }

  Future<void> longPressFinder(Finder finder) async {
    if (finder.evaluate().isEmpty) {
      throw EnsembleTestFailure('longPressFinder: target element is detached.');
    }
    await tester.ensureVisible(finder);
    await tester.longPress(finder);
    await _settleAfterAction();
  }

  Future<void> focusWidget(String id) async {
    final finder = assertions.finderForId(id);
    _expectSingleWidget(finder, id, 'focus');
    await tester.tap(finder);
    await _settleAfterAction();
  }

  Future<void> focusFinder(Finder finder) async {
    await tapFinder(finder);
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
      await _pump(
          duration: config.waitPollInterval, label: 'expectTextContains');
      if (assertions.isAnyTextContainingVisible(textCandidates)) {
        return;
      }
    }

    throw EnsembleTestFailure(
      'Timed out after ${timeoutMs}ms waiting for text containing one of: '
      '${textCandidates.map((t) => '"$t"').join(', ')}. '
      '${assertions.textFailureHint(textCandidates)}',
    );
  }

  Future<void> unfocus() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await _settle();
  }

  Future<void> enterTextOn(String id, String value) =>
      _enterText(id, value, submit: false);

  Future<void> enterTextOnFinder(
    Finder finder,
    String value, {
    bool submit = false,
    bool replace = false,
  }) async {
    if (finder.evaluate().isEmpty) {
      throw EnsembleTestFailure('enterText: target element is detached.');
    }
    if (replace) {
      await tester.enterText(finder, '');
      await _pump(label: 'clearText');
    }
    await tester.enterText(finder, value);
    if (submit) {
      await tester.testTextInput.receiveAction(TextInputAction.done);
    }
    await _settleAfterAction();
  }

  Future<void> submitTextOnFinder(Finder finder) async {
    await tapFinder(finder);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settleAfterAction();
  }

  Future<void> toggleFinder(Finder finder) async {
    if (finder.evaluate().isEmpty) {
      throw EnsembleTestFailure('toggle: target element is detached.');
    }
    await tester.ensureVisible(finder);
    final control = find.descendant(
      of: finder,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Switch || widget is CupertinoSwitch || widget is Checkbox,
      ),
    );
    await tester.tap(control.evaluate().isNotEmpty ? control.first : finder);
    await _settleAfterAction();
  }

  /// Idempotent check — no-op when already checked (matches uncheck symmetry).
  Future<void> checkFinder(Finder finder) async {
    if (_finderIsChecked(finder) == true) return;
    await toggleFinder(finder);
  }

  /// Idempotent uncheck — no-op when already unchecked.
  Future<void> uncheckFinder(Finder finder) async {
    if (_finderIsChecked(finder) != true) return;
    await toggleFinder(finder);
  }

  bool? _finderIsChecked(Finder finder) {
    if (finder.evaluate().isEmpty) return null;
    final control = find.descendant(
      of: finder,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Switch || widget is CupertinoSwitch || widget is Checkbox,
      ),
    );
    final target = control.evaluate().isNotEmpty ? control.first : finder;
    final widget = tester.widget(target);
    if (widget is Switch) return widget.value;
    if (widget is CupertinoSwitch) return widget.value;
    if (widget is Checkbox) return widget.value;
    return null;
  }

  Future<void> selectOnFinder(Finder finder, String value) async {
    if (value.isEmpty) {
      throw EnsembleTestFailure('select requires "value"');
    }
    await tapFinder(finder);
    final option = find.text(value);
    if (option.evaluate().isEmpty) {
      throw EnsembleTestFailure('select could not find option "$value"');
    }
    await tester.tap(option);
    await _settleAfterAction();
  }

  Future<void> selectIndexOnFinder(Finder finder, int index) async {
    if (index < 0) {
      throw EnsembleTestFailure('selectIndex requires a non-negative index');
    }
    await tapFinder(finder);
    final options = find.byType(DropdownMenuItem).evaluate().toList();
    if (index >= options.length) {
      throw EnsembleTestFailure('selectIndex: no option at index $index');
    }
    await tester.tap(find.byWidget(options[index].widget));
    await _settleAfterAction();
  }

  Future<void> setSliderOnFinder(Finder finder, double value) async {
    if (finder.evaluate().isEmpty) {
      throw EnsembleTestFailure('setSlider: target element is detached.');
    }
    final sliderFinder = find.descendant(
      of: finder,
      matching: find.byType(Slider),
    );
    final effective =
        sliderFinder.evaluate().isNotEmpty ? sliderFinder.first : finder;
    final widget = tester.widget(effective);
    if (widget is! Slider) {
      throw EnsembleTestFailure('setSlider target is not a Slider.');
    }
    if (value < widget.min || value > widget.max) {
      throw EnsembleTestFailure(
        'setSlider value $value is outside ${widget.min}..${widget.max}.',
      );
    }
    final rect = tester.getRect(effective);
    final fraction = widget.max == widget.min
        ? 0.0
        : (value - widget.min) / (widget.max - widget.min);
    await tester
        .tapAt(Offset(rect.left + rect.width * fraction, rect.center.dy));
    await _settleAfterAction();
  }

  Future<void> dragFinder(Finder finder, Offset offset) async {
    if (finder.evaluate().isEmpty) {
      throw EnsembleTestFailure('drag: target element is detached.');
    }
    await tester.drag(finder, offset);
    await _settleAfterAction();
  }

  Future<void> pullToRefreshFinder(Finder finder) =>
      dragFinder(finder, const Offset(0, 300));

  Future<void> scrollUntilVisibleFinder(Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await _settleAfterAction();
  }

  Future<void> settle({Duration? timeout}) => _settle(timeout: timeout);

  void _applyMocks(TestMocks mocks) {
    final api = services.api;
    if (api is ApiMockingTestService) {
      api.applyMocks(mocks);
      return;
    }
    if (api != null) {
      throw const UnsupportedApplicationCapability('apiMocking');
    }
    for (final entry in mocks.apis.entries) {
      context.apiOverlay.setMock(entry.key, entry.value);
    }
  }

  Future<void> openScreenByName(String screen) async {
    final tc = context.testCase;
    _config = await requireHarness.loadScreen(
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
    await _throwIfRecordedFlutterErrors(phase: 'settle', allowNavRetry: true);
    if (treeHasFlutterErrorWidget(tester)) {
      throw EnsembleTestFailure(
        'Unexpected Flutter ErrorWidget on screen after settle. Hint: a '
        'navigateScreen / dialog build failed during the previous action.',
      );
    }
    await _yieldToLiveApiWork();
  }

  /// After taps/enterText: Ensemble `onComplete` often calls navigateScreen /
  /// clearAllScreens. Alternate short live yields with single-frame pumps so
  /// we do not build mid-`pushAndRemoveUntil` (Overlay / ErrorWidget races).
  Future<void> _settleAfterAction() async {
    final deadline = DateTime.now().add(config.actionSettleTimeout);
    while (DateTime.now().isBefore(deadline)) {
      await _liveDelay(const Duration(milliseconds: 50));
      await tester.pump(null, EnginePhase.sendSemanticsUpdate);
      _drainTransientFlutterDiagnostics();

      if (treeHasFlutterErrorWidget(tester)) {
        continue;
      }
      if (tester.binding.transientCallbackCount == 0 &&
          !context.apiOverlay.hasPendingLiveCalls) {
        break;
      }
    }
    if (treeHasFlutterErrorWidget(tester)) {
      throw EnsembleTestFailure(
        'Unexpected Flutter ErrorWidget on screen after action settle. '
        'Hint: navigateScreen/clearAllScreens raced the test pump loop.',
      );
    }
    await _yieldToLiveApiWork();
  }

  /// Lets in-flight live HTTP (wrapped in [WidgetTester.runAsync]) finish and
  /// pumps a frame so Ensemble can apply API state.
  ///
  /// After navigateScreen/clearAllScreens, avoid multi-frame thrashing — that
  /// re-enters Overlay while entries are still finalizing (Duplicate GlobalKeys /
  /// `_dependents.isEmpty` → ErrorWidget).
  Future<void> _yieldToLiveApiWork() async {
    if (!context.apiOverlay.hasPendingLiveCalls) {
      await tester.pump(null, EnginePhase.sendSemanticsUpdate);
      _drainTransientFlutterDiagnostics();
      return;
    }
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
      await _liveDelay(const Duration(milliseconds: 20));
      await tester.pump(null, EnginePhase.sendSemanticsUpdate);
      _drainTransientFlutterDiagnostics();
      if (treeHasFlutterErrorWidget(tester)) {
        throw EnsembleTestFailure(
          'Unexpected Flutter ErrorWidget on screen while draining live API '
          'work after an action.',
        );
      }
      if (!hadPending) {
        return;
      }
    }
  }

  /// Live-binding only — FakeAsync widget tests must still fail-fast on
  /// recorded "wrong build scope" / overlay races (see fail_fast tests).
  bool get _isLiveBinding => tester.binding is LiveTestWidgetsFlutterBinding;

  void _drainTransientFlutterDiagnostics() {
    final swallowTransient = _isLiveBinding;
    while (true) {
      final pending = tester.takeException();
      if (pending == null) break;
      if (isNonFatalFlutterDiagnostic(pending) ||
          (swallowTransient && isTransientNavigationDiagnostic(pending))) {
        continue;
      }
      context.runtime.flutterErrors.clear();
      throw EnsembleTestFailure(
        'Unexpected Flutter framework error during liveApi: '
        '${_compactFlutterDiagnostic(pending)} '
        'Hint: inspect the previous action and fix the async work or widget '
        'lifecycle before continuing.',
      );
    }
    context.runtime.flutterErrors.removeWhere(isNonFatalFlutterDiagnostic);
    if (swallowTransient) {
      context.runtime.flutterErrors
          .removeWhere(isTransientNavigationDiagnostic);
    }
  }

  /// Binding-aware delay (FakeAsync + live).
  ///
  /// Widget tests use [AutomatedTestWidgetsFlutterBinding] / FakeAsync — a
  /// plain [Future.delayed] never completes without advancing virtual time.
  /// [TestWidgetsFlutterBinding.delayed] advances FakeAsync and falls through
  /// to wall-clock delay under [LiveTestWidgetsFlutterBinding].
  ///
  /// Must not call [WidgetTester.runAsync] — live HTTP already uses that API,
  /// and nesting throws "Reentrant call to runAsync() denied".
  Future<void> _liveDelay(Duration duration) async {
    if (duration <= Duration.zero) return;
    await tester.binding.delayed(duration);
  }

  Future<void> _tap(String id, {int? timeoutMs, TestStep? step}) async {
    final effectiveTimeout =
        timeoutMs ?? config.defaultWaitTimeout.inMilliseconds;
    final stopwatch = Stopwatch()..start();
    Finder? tappableFinder;

    while (stopwatch.elapsedMilliseconds < effectiveTimeout) {
      await _pump(duration: config.waitPollInterval, label: 'tap');
      tappableFinder = _findTappableFinder(id);
      if (tappableFinder != null) break;
    }

    if (tappableFinder == null) {
      final baseFinder = assertions.finderForId(id);
      if (baseFinder.evaluate().isEmpty) {
        if (assertions.finderForIdIncludingOffstage(id).evaluate().isNotEmpty) {
          throw EnsembleTestFailure(
            'Timed out after ${effectiveTimeout}ms waiting for id "$id" to become '
            'hit-testable. It may be off-screen, disabled, or covered by another widget. '
            '${assertions.widgetIdFailureHint(id)}',
          );
        }
        throw EnsembleTestFailure(
          'Timed out after ${effectiveTimeout}ms waiting for id "$id". '
          '${assertions.widgetIdFailureHint(id)}',
        );
      }
      throw EnsembleTestFailure(
        'Timed out after ${effectiveTimeout}ms waiting for id "$id" to become '
        'hit-testable. It may be off-screen, disabled, or covered by another widget. '
        '${assertions.widgetIdFailureHint(id)}',
      );
    }

    // Already hit-testable finders do not need ensureVisible. Calling it can
    // still drive scrollables / rebuilds that race Live-binding navigation and
    // trip UnmanagedRestorationScope assertions on some Ensemble screens.
    if (tappableFinder.hitTestable().evaluate().length != 1) {
      await tester.ensureVisible(tappableFinder);
      await _pump(label: 'tap.ensureVisible');
    } else {
      await _pump(label: 'tap.beforeTap');
    }
    tappableFinder = _hitTestableFinderForTap(
      _interactiveFinder(assertions.finderForId(id)),
      id,
    );
    if (step != null && onBeforeActionStep != null) {
      await onBeforeActionStep!(step);
    }
    await tester.tap(tappableFinder);
    await _settleAfterAction();
  }

  Finder? _findTappableFinder(String id) {
    final baseFinder = assertions.finderForId(id);
    if (baseFinder.evaluate().isEmpty) return null;

    final finder = _interactiveFinder(baseFinder);
    final count = finder.evaluate().length;
    if (count == 0) return null;
    if (count > 1) {
      final hitTestable = finder.hitTestable();
      final hitTestableCount = hitTestable.evaluate().length;
      if (hitTestableCount > 1) {
        throw EnsembleTestFailure(
          'tap expected exactly one hit-testable widget with id "$id", '
          'but found $hitTestableCount.',
        );
      }
      return hitTestableCount == 1 ? hitTestable : null;
    }

    final hitTestable = finder.hitTestable();
    return hitTestable.evaluate().length == 1 ? hitTestable : null;
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
    await _settleAfterAction();
  }

  Future<void> _enterText(String id, String value,
      {bool submit = false}) async {
    var finder = assertions.finderForId(id);
    if (finder.evaluate().isEmpty) {
      await _waitFor(
        id: id,
        timeoutMs: config.defaultWaitTimeout.inMilliseconds,
      );
      finder = assertions.finderForId(id);
    }
    _expectSingleWidget(finder, id, 'enterText');
    await tester.enterText(finder, value);
    if (submit) {
      await tester.testTextInput.receiveAction(TextInputAction.done);
    }
    await _settleAfterAction();
  }

  Future<void> _submitText(String id) async {
    final finder = assertions.finderForId(id);
    _expectSingleWidget(finder, id, 'submitText');
    await tester.tap(finder);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settleAfterAction();
  }

  Future<void> _clearText(String id) async {
    final finder = assertions.finderForId(id);
    _expectSingleWidget(finder, id, 'clearText');
    await tester.enterText(finder, '');
    await _settleAfterAction();
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
    await _settleAfterAction();
  }

  Future<void> _scrollUntilVisible(
    String id, {
    String? scrollableId,
  }) async {
    final finder = assertions.finderForId(id, skipOffstage: false);
    final scrollable = scrollableId == null || scrollableId.isEmpty
        ? find.byType(Scrollable).first
        : find.descendant(
            of: find.byKey(ValueKey(scrollableId)),
            matching: find.byType(Scrollable),
          );
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: scrollable,
    );
    await _settleAfterAction();
  }

  Future<void> _waitFor({
    TestStep? step,
    String? id,
    String? text,
    List<String> anyOf = const [],
    ElementTarget? target,
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
          target?.normalizedLocator?.bounds == null &&
          assertions.finderForId(id).hitTestable().evaluate().isNotEmpty) {
        return;
      }
      final matchedText = _firstVisibleText(
        textCandidates,
        target: target,
      );
      if (matchedText != null) {
        if (step?.type == 'waitForText' && onWaitForTextMatched != null) {
          await onWaitForTextMatched!(_stepWithMatchedText(step!, matchedText));
        }
        return;
      }
    }

    final textLabel = textCandidates.isEmpty
        ? null
        : textCandidates.length == 1
            ? 'text "${textCandidates.single}"'
            : 'any text in ${textCandidates.map((t) => '"$t"').join(', ')}';
    final targetLabel = id != null && textLabel != null
        ? 'id "$id" or $textLabel'
        : id != null
            ? 'id "$id"'
            : textLabel!;
    throw EnsembleTestFailure(
      'Timed out after ${timeoutMs}ms waiting for $targetLabel. '
      '${id != null ? '${assertions.widgetIdFailureHint(id)} ${assertions.visibleTextSummary()}' : assertions.textFailureHint(textCandidates)}',
    );
  }

  static List<String> _stringListArg(dynamic value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item != null && item.toString().trim().isNotEmpty) item.toString(),
    ];
  }

  String? _firstVisibleText(
    List<String> candidates, {
    ElementTarget? target,
  }) {
    Finder? targetFinder;
    if (target != null) {
      try {
        targetFinder = resolveTargetFinder?.call(target);
      } on TestExecutionError catch (error) {
        if (error.code != TestExecutionErrorCode.elementNotFound) rethrow;
      }
      if (targetFinder == null || targetFinder.evaluate().isEmpty) return null;
    }
    for (final text in candidates) {
      if (target == null) {
        if (assertions.isTextVisible(text)) return text;
        continue;
      }
      final matching = find.text(text, skipOffstage: false).evaluate().where(
        (element) {
          if (!assertions.isElementVisuallyActionable(element)) return false;
          if (targetFinder != null) {
            final targetElements = targetFinder.evaluate();
            return targetElements.any((targetElement) {
              if (identical(element, targetElement)) return true;
              var withinTarget = false;
              element.visitAncestorElements((ancestor) {
                if (identical(ancestor, targetElement)) {
                  withinTarget = true;
                  return false;
                }
                return true;
              });
              return withinTarget;
            });
          }
          return false;
        },
      );
      if (matching.isNotEmpty) return text;
    }
    return null;
  }

  TestStep _stepWithMatchedText(TestStep step, String text) => TestStep(
        type: step.type,
        args: {
          ...step.args,
          'text': text,
        }..remove('anyOf'),
        mocks: step.mocks,
        nestedSteps: step.nestedSteps,
      );

  void _expectSingleWidget(Finder finder, String id, String stepType) {
    final count = finder.evaluate().length;
    if (count != 1) {
      throw EnsembleTestFailure(
        '$stepType expected exactly one widget with id "$id", but found $count. '
        '${assertions.widgetIdFailureHint(id)}',
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
    _config = await requireHarness.loadScreen(
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
    required TestStep step,
    required String screen,
    required int timeoutMs,
  }) async {
    final stopwatch = Stopwatch()..start();
    final tracker = ScreenTracker();
    var captureFired = false;

    bool isTargetVisible() =>
        tracker.isScreenVisible(screenName: screen) ||
        tracker.isScreenVisible(screenId: screen);

    bool visitedInHistory() =>
        YamlTestSession.navigationFlow.flow.contains(screen);

    void throwIfErrorWidgetBlocking(String phase) {
      if (!treeHasFlutterErrorWidget(tester)) return;
      throw EnsembleTestFailure(
        'Navigation to "$screen" failed during $phase: Flutter ErrorWidget is '
        'on screen (destination did not build). Hint: a prior navigateScreen / '
        'clearAllScreens raced a Live-binding pump — inspect flutter errors.',
      );
    }

    Future<void> captureIfVisible() async {
      if (captureFired || onWaitForNavigationMatched == null) return;
      if (!isTargetVisible()) return;
      throwIfErrorWidgetBlocking('waitForNavigation capture');
      captureFired = true;
      await onWaitForNavigationMatched!(step);
    }

    // Capture as soon as ScreenTracker reports the target — before the next
    // navigateScreen (e.g. AutoSignIn_Gateway → Home) can replace the pixels.
    final screenSub = tracker.onScreenChange.listen((visible) async {
      final name = visible?.screenName ?? visible?.screenId;
      if (name == screen) {
        await captureIfVisible();
      }
    });

    final previousOnScreenAdded = YamlTestSession.navigationFlow.onScreenAdded;
    YamlTestSession.navigationFlow.onScreenAdded = (name) async {
      final prior = previousOnScreenAdded;
      if (prior != null) {
        await prior(name);
      }
      if (name == screen) {
        await captureIfVisible();
      }
    };

    try {
      // Target may already be visible when the step starts.
      if (isTargetVisible()) {
        await captureIfVisible();
        return;
      }

      while (stopwatch.elapsedMilliseconds < timeoutMs) {
        await YamlTestSession.navigationFlow.flushPending();
        throwIfErrorWidgetBlocking('waitForNavigation');
        if (isTargetVisible()) {
          await captureIfVisible();
          return;
        }
        if (visitedInHistory()) {
          // Transient screen already left — only OK if the tree is healthy.
          throwIfErrorWidgetBlocking('waitForNavigation');
          return;
        }
        await _yieldToLiveApiWork();
        await _pump(
          duration: config.waitPollInterval,
          label: 'waitForNavigation',
        );
        await YamlTestSession.navigationFlow.flushPending();
        throwIfErrorWidgetBlocking('waitForNavigation');
        if (isTargetVisible()) {
          await captureIfVisible();
          return;
        }
        if (visitedInHistory()) {
          throwIfErrorWidgetBlocking('waitForNavigation');
          return;
        }
      }
      await _yieldToLiveApiWork();
      await _pump(label: 'waitForNavigation');
      await YamlTestSession.navigationFlow.flushPending();
      throwIfErrorWidgetBlocking('waitForNavigation');
      if (isTargetVisible()) {
        await captureIfVisible();
        return;
      }
      if (visitedInHistory()) {
        throwIfErrorWidgetBlocking('waitForNavigation');
        return;
      }
      throw EnsembleTestFailure(
        'Timed out after ${timeoutMs}ms waiting for navigation to "$screen"',
      );
    } finally {
      await screenSub.cancel();
      YamlTestSession.navigationFlow.onScreenAdded = previousOnScreenAdded;
    }
  }

  Future<void> _waitForGone({
    required ElementTarget target,
    required int timeoutMs,
  }) async {
    final stopwatch = Stopwatch()..start();
    while (stopwatch.elapsedMilliseconds < timeoutMs) {
      await _pump(duration: config.waitPollInterval, label: 'waitForGone');
      try {
        if (finderForTargetStep(
          TestStep(
            type: 'waitForGone',
            args: target.normalizedLocator != null
                ? {'target': target.normalizedLocator!.toJson()}
                : {'id': target.testId},
          ),
          requireInteractive: false,
        ).evaluate().isEmpty) {
          return;
        }
      } on TestExecutionError catch (error) {
        if (error.code == TestExecutionErrorCode.elementNotFound) return;
        rethrow;
      }
    }
    throw EnsembleTestFailure(
      'Timed out after ${timeoutMs}ms waiting for target to disappear',
    );
  }

  Future<void> _pump({
    Duration? duration,
    EnginePhase phase = EnginePhase.sendSemanticsUpdate,
    required String label,
  }) async {
    // LiveTestWidgetsFlutterBinding.pump(duration) does Future.delayed then
    // builds a frame in the same turn. Ensemble Timer / live HTTP callbacks
    // can navigateScreen during that delay and race the build. Yield with a
    // plain Future.delayed (not tester.runAsync — that nests with live HTTP
    // and throws "Reentrant call to runAsync() denied"), then pump cleanly.
    if (duration != null && duration > Duration.zero) {
      await _liveDelay(duration);
      await tester.pump(null, phase);
      // Route transitions / dialogs scheduled during the yield often need a
      // second frame before finders and hit-tests are stable.
      await tester.pump(null, phase);
    } else {
      await tester.pump(duration, phase);
    }
    await _throwIfRecordedFlutterErrors(phase: label, allowNavRetry: true);
  }

  Future<void> _throwIfRecordedFlutterErrors({
    required String phase,
    bool allowNavRetry = false,
  }) async {
    // Transient nav races only happen under LiveTestWidgetsFlutterBinding.
    // Under FakeAsync, treat the same diagnostics as fatal so unit tests
    // (and fail-fast coverage) still surface them immediately.
    final canRetryNav = allowNavRetry && _isLiveBinding;
    Object? pending;
    while ((pending = tester.takeException()) != null) {
      if (isNonFatalFlutterDiagnostic(pending!)) continue;
      if (canRetryNav && isTransientNavigationDiagnostic(pending)) {
        await _retryAfterTransientNavError(phase: phase);
        return;
      }
      context.runtime.flutterErrors.clear();
      throw EnsembleTestFailure(
        'Unexpected Flutter framework error during $phase: '
        '${_compactFlutterDiagnostic(pending)} '
        'Hint: inspect the previous action and fix the async work or widget '
        'lifecycle before continuing.',
      );
    }
    context.runtime.flutterErrors.removeWhere(isNonFatalFlutterDiagnostic);
    if (context.runtime.flutterErrors.isEmpty) return;

    final first = context.runtime.flutterErrors.first;
    if (canRetryNav && isTransientNavigationDiagnostic(first)) {
      await _retryAfterTransientNavError(phase: phase);
      return;
    }
    context.runtime.flutterErrors.clear();
    throw EnsembleTestFailure(
      'Unexpected Flutter framework error during $phase: '
      '${_compactFlutterDiagnostic(first)} '
      'Hint: inspect the previous action and fix the async work or widget '
      'lifecycle before continuing.',
    );
  }

  /// Clears a one-shot Live-binding navigation race and pumps again.
  Future<void> _retryAfterTransientNavError({required String phase}) async {
    context.runtime.flutterErrors.clear();
    while (tester.takeException() != null) {}
    for (var i = 0; i < 5; i++) {
      await _liveDelay(const Duration(milliseconds: 50));
      await tester.pump(null, EnginePhase.sendSemanticsUpdate);
      while (true) {
        final pending = tester.takeException();
        if (pending == null) break;
        if (isNonFatalFlutterDiagnostic(pending) ||
            isTransientNavigationDiagnostic(pending)) {
          continue;
        }
        throw EnsembleTestFailure(
          'Unexpected Flutter framework error during $phase: '
          '${_compactFlutterDiagnostic(pending)} '
          'Hint: inspect the previous action and fix the async work or widget '
          'lifecycle before continuing.',
        );
      }
      context.runtime.flutterErrors.removeWhere(isNonFatalFlutterDiagnostic);
      context.runtime.flutterErrors
          .removeWhere(isTransientNavigationDiagnostic);
      if (!treeHasFlutterErrorWidget(tester)) {
        return;
      }
    }
    if (treeHasFlutterErrorWidget(tester)) {
      throw EnsembleTestFailure(
        'Unexpected Flutter framework error during $phase: Flutter ErrorWidget '
        'is on screen after a navigation/build race. Hint: inspect the previous '
        'action and fix the async work or widget lifecycle before continuing.',
      );
    }
  }

  String _compactFlutterDiagnostic(Object error, {int maxLength = 600}) {
    final normalized = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxLength) return normalized;
    return '${normalized.substring(0, maxLength - 3)}...';
  }

  void _expectApiCalled(String name, int times) {
    final api = services.api;
    if (api != null) {
      final actual = api.callCount(name);
      if (actual != times) {
        throw EnsembleTestFailure(
          'Expected API "$name" to be called $times times, got $actual.',
        );
      }
      return;
    }
    if (harness == null) {
      throw const UnsupportedApplicationCapability('api');
    }
    if (times == 0) {
      assertions.expectApiNotCalled(name);
    } else {
      assertions.expectApiCalled(name, times);
    }
  }

  void _resetApiCalls() {
    final api = services.api;
    if (api is ApiMockingTestService) {
      api.resetCalls();
      return;
    }
    if (api != null) {
      throw const UnsupportedApplicationCapability('apiMocking');
    }
    if (harness == null) {
      throw const UnsupportedApplicationCapability('api');
    }
    context.apiOverlay.resetCalls();
  }

  void _expectStorage(String key, Object? expected) {
    final storage = services.storage;
    if (storage != null) {
      final actual = storage.read(key);
      if (actual != expected) {
        throw EnsembleTestFailure(
          'Expected storage "$key" to equal "$expected", got "$actual".',
        );
      }
      return;
    }
    if (harness == null) {
      throw const UnsupportedApplicationCapability('storage');
    }
    assertions.expectStorage(key, expected);
  }

  Future<void> _setStorage(String key, Object? value) async {
    final storage = services.storage;
    if (storage != null) {
      await storage.write(key, value);
      return;
    }
    if (harness == null) {
      throw const UnsupportedApplicationCapability('storage');
    }
    context.setStorage(key, value);
  }

  void _expectNavigateTo(String screen) {
    final navigation = services.navigation;
    if (navigation != null) {
      if (navigation.currentRoute != screen) {
        throw EnsembleTestFailure(
          'Expected route "$screen", got "${navigation.currentRoute}".',
        );
      }
      return;
    }
    if (harness == null) {
      throw const UnsupportedApplicationCapability('navigation');
    }
    assertions.expectNavigateTo(screen);
  }

  void _expectVisited(String screen) {
    final navigation = services.navigation;
    if (navigation != null) {
      if (!navigation.routeHistory.contains(screen)) {
        throw EnsembleTestFailure(
          'Expected screen "$screen" in navigation history, but visited '
          '${navigation.routeHistory}',
        );
      }
      return;
    }
    if (harness == null) {
      throw const UnsupportedApplicationCapability('navigation');
    }
    assertions.expectVisited(screen);
  }
}
