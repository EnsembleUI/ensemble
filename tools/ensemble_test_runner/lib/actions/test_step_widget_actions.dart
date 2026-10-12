import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'dart:async';

import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/actions/test_execution_config.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/actions/scrollable_waiter.dart';
import 'package:ensemble_test_runner/actions/test_step_runtime.dart';
import 'package:ensemble_test_runner/actions/select_index_options.dart';
import 'package:ensemble_test_runner/session/operation_target.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Executes widget-facing interactions for a test step.
///
/// This boundary keeps finder resolution, gesture delivery, and text input
/// mechanics together while the step executor remains focused on dispatch.
class TestStepWidgetActions {
  final WidgetTester tester;
  final AssertionEngine assertions;
  final TestExecutionConfig config;
  final TestStepRuntime runtime;
  final ScrollableWaiter scrollableWaiter;
  final Future<void> Function({
    TestStep? step,
    String? id,
    String? text,
    List<String> anyOf,
    ElementTarget? target,
    required int timeoutMs,
  }) waitFor;
  final FutureOr<void> Function(TestStep step)? onEvidenceBoundary;

  TestStepWidgetActions({
    required this.tester,
    required this.assertions,
    required this.config,
    required this.runtime,
    required this.scrollableWaiter,
    required this.waitFor,
    this.onEvidenceBoundary,
  });
  Future<void> tapWidget(String id, {int? timeoutMs}) =>
      tap(id, timeoutMs: timeoutMs);

  /// Taps an already-resolved [Finder] (exact element identity; no id rematch).
  Future<void> tapFinder(
    Finder finder, {
    TestStep? step,
    Future<void> Function()? onBeforeTap,
  }) async {
    return await RunnerBenchmark.async('execution', 'tapFinder', () async {
      if (finder.evaluate().isEmpty) {
        throw EnsembleTestFailure(
          'tapFinder: target element is not in the tree (detached or never found).',
        );
      }
      await tester.ensureVisible(finder);
      await runtime.pump(label: 'tapFinder.ensureVisible');
      final hitTestable = finder.hitTestable();
      if (hitTestable.evaluate().isEmpty) {
        throw EnsembleTestFailure(
          'tapFinder: target element is not hit-testable. '
          'It may be off-screen, disabled, or covered by another widget.',
        );
      }
      await onBeforeTap?.call();
      await tester.tap(hitTestable.first);
      await runtime.settleAfterAction();
    });
  }

  Future<void> doubleTapFinder(
    Finder finder, {
    TestStep? step,
    Future<void> Function()? onBeforeFirstTap,
  }) async {
    await tapFinder(
      finder,
      step: step,
      onBeforeTap: () async {
        if (step != null) await _emitEvidenceBoundary(step);
        await onBeforeFirstTap?.call();
      },
    );
    await tapFinder(finder);
  }

  Future<void> longPressWidget(
    String id, {
    TestStep? step,
    Future<void> Function()? onBeforeLongPress,
  }) async {
    final finder = assertions.finderForId(id);
    _expectSingleWidget(finder, id, 'longPress');
    await _emitEvidenceBoundary(step);
    await onBeforeLongPress?.call();
    await tester.longPress(finder);
    await runtime.settleAfterAction();
  }

  Future<void> longPressFinder(
    Finder finder, {
    TestStep? step,
    Future<void> Function()? onBeforeLongPress,
  }) async {
    if (finder.evaluate().isEmpty) {
      throw EnsembleTestFailure('longPressFinder: target element is detached.');
    }
    await tester.ensureVisible(finder);
    await _emitEvidenceBoundary(step);
    await onBeforeLongPress?.call();
    await tester.longPress(finder);
    await runtime.settleAfterAction();
  }

  Future<void> focusWidget(String id, {TestStep? step}) async {
    final finder = assertions.finderForId(id);
    _expectSingleWidget(finder, id, 'focus');
    await _emitEvidenceBoundary(step);
    await tester.tap(finder);
    await runtime.settleAfterAction();
  }

  Future<void> focusFinder(Finder finder, {TestStep? step}) async {
    await tapFinder(
      finder,
      step: step,
      onBeforeTap: step == null ? null : () => _emitEvidenceBoundary(step),
    );
  }

  Future<void> enterTextOn(String id, String value) =>
      enterText(id, value, submit: false);

  Future<void> enterTextOnFinder(
    Finder finder,
    String value, {
    bool submit = false,
    bool replace = false,
    TestStep? step,
    Future<void> Function()? onBeforeText,
  }) async {
    if (finder.evaluate().isEmpty) {
      throw EnsembleTestFailure('enterText: target element is detached.');
    }
    await _ensureTextTargetReady(finder, 'enterText');
    await _emitEvidenceBoundary(step);
    await onBeforeText?.call();
    if (replace) {
      await tester.enterText(finder, '');
      await runtime.pump(label: 'clearText');
    }
    await tester.enterText(finder, value);
    if (submit) {
      await tester.testTextInput.receiveAction(TextInputAction.done);
    }
    await runtime.settleAfterAction();
  }

  Future<void> submitTextOnFinder(
    Finder finder, {
    TestStep? step,
    Future<void> Function()? onBeforeSubmit,
  }) async {
    await _ensureTextTargetReady(finder, 'submitText');
    await tapFinder(
      finder,
      step: step,
      onBeforeTap: () async {
        if (step != null) await _emitEvidenceBoundary(step);
        await onBeforeSubmit?.call();
      },
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await runtime.settleAfterAction();
  }

  Future<void> toggleFinder(
    Finder finder, {
    TestStep? step,
    Future<void> Function()? onBeforeToggle,
  }) async {
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
    await _emitEvidenceBoundary(step);
    await onBeforeToggle?.call();
    await tester.tap(control.evaluate().isNotEmpty ? control.first : finder);
    await runtime.settleAfterAction();
  }

  /// Idempotent check — no-op when already checked (matches uncheck symmetry).
  Future<void> checkFinder(
    Finder finder, {
    TestStep? step,
    Future<void> Function()? onBeforeToggle,
  }) async {
    if (_finderIsChecked(finder) == true) return;
    await toggleFinder(
      finder,
      step: step,
      onBeforeToggle: onBeforeToggle,
    );
  }

  /// Idempotent uncheck — no-op when already unchecked.
  Future<void> uncheckFinder(
    Finder finder, {
    TestStep? step,
    Future<void> Function()? onBeforeToggle,
  }) async {
    if (_finderIsChecked(finder) != true) return;
    await toggleFinder(
      finder,
      step: step,
      onBeforeToggle: onBeforeToggle,
    );
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

  Future<void> selectOnFinder(
    Finder finder,
    String value, {
    TestStep? step,
    Future<void> Function()? onBeforeSelection,
  }) async {
    if (value.isEmpty) {
      throw EnsembleTestFailure('select requires "value"');
    }
    await tapFinder(
      finder,
      step: step,
      onBeforeTap: () async {
        if (step != null) await _emitEvidenceBoundary(step);
        await onBeforeSelection?.call();
      },
    );
    final option = find.text(value);
    if (option.evaluate().isEmpty) {
      throw EnsembleTestFailure('select could not find option "$value"');
    }
    await tester.tap(option);
    await runtime.settleAfterAction();
  }

  Future<void> selectIndexOnFinder(Finder finder, int index,
      {TestStep? step, Future<void> Function()? onBeforeSelection}) async {
    if (index < 0) {
      throw EnsembleTestFailure('selectIndex requires a non-negative index');
    }
    await tapFinder(
      finder,
      step: step,
      onBeforeTap: () async {
        if (step != null) await _emitEvidenceBoundary(step);
        await onBeforeSelection?.call();
      },
    );
    final options = selectIndexOptions().evaluate().toList();
    if (index >= options.length) {
      throw EnsembleTestFailure('selectIndex: no option at index $index');
    }
    await tester.tap(find.byWidget(options[index].widget));
    await runtime.settleAfterAction();
  }

  Future<void> setSliderOnFinder(
    Finder finder,
    double value, {
    TestStep? step,
    Future<void> Function()? onBeforeChange,
  }) async {
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
    final rect = tester.getRect(effective);
    final fraction = value.clamp(0.0, 1.0);
    await _emitEvidenceBoundary(step);
    await onBeforeChange?.call();
    await tester
        .tapAt(Offset(rect.left + rect.width * fraction, rect.center.dy));
    await runtime.settleAfterAction();
  }

  Future<void> dragFinder(Finder finder, Offset offset,
      {TestStep? step, Future<void> Function()? onBeforeDrag}) async {
    if (finder.evaluate().isEmpty) {
      throw EnsembleTestFailure('drag: target element is detached.');
    }
    await _emitEvidenceBoundary(step);
    await onBeforeDrag?.call();
    await tester.drag(finder, offset);
    await runtime.settleAfterAction();
  }

  Future<void> scrollUntilVisibleFinder(
    Finder finder, {
    String? scrollableId,
    int? timeoutMs,
  }) async {
    final scrollable = await scrollableWaiter.wait(
      scrollableId: scrollableId,
      timeoutMs: timeoutMs ?? config.defaultWaitTimeout.inMilliseconds,
    );
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: scrollable,
    );
    await runtime.settleAfterAction();
  }

  Future<void> tap(
    String id, {
    int? timeoutMs,
    TestStep? step,
    Future<void> Function()? onBeforeTap,
  }) async {
    return await RunnerBenchmark.async('execution', 'tap', () async {
      final effectiveTimeout =
          timeoutMs ?? config.defaultWaitTimeout.inMilliseconds;
      Finder? tappableFinder;
      var attemptedEnsureVisible = false;
      final stopwatch = Stopwatch()..start();
      while (stopwatch.elapsedMilliseconds < effectiveTimeout) {
        RunnerBenchmark.count('pollingAttempts', 1);
        tappableFinder = _findTappableFinder(id);
        if (tappableFinder != null) break;

        // Resolve the already-mounted target before advancing the clock. Most
        // actions start from a stable tree, so the old unconditional poll pump
        // added waitPollInterval latency to every tap. A frame is still
        // delivered when the target is absent, preserving the wait contract
        // for targets that are mounted by a later callback.
        await runtime.pump(duration: config.waitPollInterval, label: 'tap');

        // A target can be mounted below a scroll viewport before it becomes
        // hit-testable. Move the primary scroll surface once; repeated
        // scrollUntilVisible iterations add seconds on live bindings.
        if (!attemptedEnsureVisible) {
          final baseFinder = assertions.finderForId(id, skipOffstage: false);
          final interactive = _interactiveFinder(baseFinder);
          if (interactive.evaluate().isNotEmpty) {
            attemptedEnsureVisible = true;
            try {
              final targetElement = interactive.evaluate().first;
              final owner = Scrollable.maybeOf(targetElement);
              if (owner != null && owner.position.hasContentDimensions) {
                owner.position.jumpTo(owner.position.maxScrollExtent);
              }
              await Scrollable.ensureVisible(
                targetElement,
                duration: Duration.zero,
              );
              final scrollables = find.byType(Scrollable);
              if (owner == null && scrollables.evaluate().isNotEmpty) {
                for (final element in scrollables.evaluate()) {
                  final state = tester.state<ScrollableState>(
                    find.byWidget(element.widget),
                  );
                  final position = state.position;
                  if (position.hasContentDimensions) {
                    position.jumpTo(position.maxScrollExtent);
                  }
                }
              }
              await runtime.pump(label: 'tap.scrollIntoView');
            } catch (_) {
              // Continue polling so disabled/covered targets retain diagnostics.
            }
          }
        }
      }

      if (tappableFinder == null) {
        final baseFinder = assertions.finderForId(id);
        if (baseFinder.evaluate().isEmpty) {
          if (assertions
              .finderForIdIncludingOffstage(id)
              .evaluate()
              .isNotEmpty) {
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
        await runtime.pump(label: 'tap.ensureVisible');
      } else {
        await runtime.pump(label: 'tap.beforeTap');
      }
      tappableFinder = _hitTestableFinderForTap(
        _interactiveFinder(assertions.finderForId(id, skipOffstage: false)),
        id,
      );
      await onBeforeTap?.call();
      await tester.tap(tappableFinder);
      await runtime.settleAfterAction();
    });
  }

  Finder? _findTappableFinder(String id) {
    // Keep mounted offscreen widgets eligible for visibility recovery. The
    // default onstage filter would consume the whole action timeout first.
    final baseFinder = assertions.finderForId(id, skipOffstage: false);
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

  Future<void> toggle(
    String id, {
    TestStep? step,
    int? timeoutMs,
    Future<void> Function()? onBeforeToggle,
  }) async {
    final baseFinder = assertions.finderForId(id);
    if (baseFinder.evaluate().isEmpty) {
      await waitFor(
        id: id,
        timeoutMs: timeoutMs ?? config.defaultWaitTimeout.inMilliseconds,
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
    await _emitEvidenceBoundary(step);
    await onBeforeToggle?.call();
    await tester.tap(control.evaluate().isNotEmpty ? control.first : finder);
    await runtime.settleAfterAction();
  }

  Future<void> enterText(
    String id,
    String value, {
    bool submit = false,
    TestStep? step,
    int? timeoutMs,
    Future<void> Function()? onBeforeText,
  }) async {
    return await RunnerBenchmark.async('execution', 'enterText', () async {
      var finder = assertions.finderForId(id);
      if (finder.evaluate().isEmpty) {
        await waitFor(
          id: id,
          timeoutMs: timeoutMs ?? config.defaultWaitTimeout.inMilliseconds,
        );
        finder = assertions.finderForId(id);
      }
      _expectSingleWidget(finder, id, 'enterText');
      await _ensureTextTargetReady(finder, 'enterText');
      await _emitEvidenceBoundary(step);
      await onBeforeText?.call();
      await tester.enterText(finder, value);
      if (submit) {
        await tester.testTextInput.receiveAction(TextInputAction.done);
      }
      await runtime.settleAfterAction();
    });
  }

  Future<void> submitText(
    String id, {
    TestStep? step,
    int? timeoutMs,
    Future<void> Function()? onBeforeSubmit,
  }) async {
    var finder = assertions.finderForId(id);
    if (finder.evaluate().isEmpty) {
      await waitFor(
        id: id,
        timeoutMs: timeoutMs ?? config.defaultWaitTimeout.inMilliseconds,
      );
      finder = assertions.finderForId(id);
    }
    _expectSingleWidget(finder, id, 'submitText');
    await _ensureTextTargetReady(finder, 'submitText');
    await _emitEvidenceBoundary(step);
    await onBeforeSubmit?.call();
    await tester.tap(finder);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await runtime.settleAfterAction();
  }

  Future<void> clearText(
    String id, {
    TestStep? step,
    Future<void> Function()? onBeforeText,
  }) async {
    final finder = assertions.finderForId(id);
    _expectSingleWidget(finder, id, 'clearText');
    await _ensureTextTargetReady(finder, 'clearText');
    await _emitEvidenceBoundary(step);
    await onBeforeText?.call();
    await tester.enterText(finder, '');
    await runtime.settleAfterAction();
  }

  Future<void> select(
    String id,
    String? value, {
    TestStep? step,
    int? timeoutMs,
    Future<void> Function()? onBeforeSelection,
  }) async {
    if (value == null || value.isEmpty) {
      throw EnsembleTestFailure('select requires "value"');
    }
    await tap(
      id,
      timeoutMs: timeoutMs,
      onBeforeTap: () async {
        if (step != null) await _emitEvidenceBoundary(step);
        await onBeforeSelection?.call();
      },
    );
    final option = find.text(value);
    if (option.evaluate().isEmpty) {
      throw EnsembleTestFailure('select could not find option "$value"');
    }
    await tester.tap(option);
    await runtime.settleAfterAction();
  }

  Future<void> _emitEvidenceBoundary(TestStep? step) async {
    if (step != null) await onEvidenceBoundary?.call(step);
  }

  /// Text entry must capture the field that receives input. Avoid advancing a
  /// frame for the common visible case; only scroll and pump when hit testing
  /// shows that the target is currently outside the viewport.
  Future<void> _ensureTextTargetReady(Finder finder, String action) async {
    if (finder.hitTestable().evaluate().isNotEmpty) return;
    await tester.ensureVisible(finder);
    await runtime.pump(label: '$action.ensureVisible');
    if (finder.hitTestable().evaluate().isEmpty) {
      throw EnsembleTestFailure(
        '$action: target is not hit-testable after it was brought into view.',
      );
    }
  }

  Future<void> scrollUntilVisible(
    String id, {
    String? scrollableId,
    required int timeoutMs,
  }) =>
      scrollUntilVisibleFinder(
        assertions.finderForId(id, skipOffstage: false),
        scrollableId: scrollableId,
        timeoutMs: timeoutMs,
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
}
