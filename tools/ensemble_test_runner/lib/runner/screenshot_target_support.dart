import 'dart:ui' as ui;

import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/event_driven_settler.dart';
import 'package:ensemble_test_runner/runner/step_highlight_finder.dart';
import 'package:ensemble_test_runner/runner/step_policy.dart';
import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'package:ensemble_test_runner/session/local/modal_route_lookup.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Coordinates visibility and paint readiness for screenshot highlights.
///
/// This is deliberately independent from screenshot encoding and report
/// writing. It owns only the widget-tree work needed before a screenshot can
/// be captured, so the visual artifact facade remains an orchestration layer.
final class ScreenshotTargetSupport {
  const ScreenshotTargetSupport({required this.drainFlutterExceptions});

  final void Function(WidgetTester tester) drainFlutterExceptions;

  Future<void> waitForScreenshotTarget(
    TestStepExecutor executor,
    TestStep step,
  ) async {
    return await RunnerBenchmark.async('screenshot', 'waitForScreenshotTarget',
        () async {
      if (!shouldHighlightStep(step)) return;
      final finder = _highlightFinder(executor, step);
      if (finder == null) return;

      final waitsForHitTestable = isUserActionStep(step);
      final timeoutMs = step.args['timeoutMs'] as int? ??
          executor.config.defaultWaitTimeout.inMilliseconds;
      var scrollRequested = false;
      var scrollApplied = false;
      await EventDrivenSettler(
        tester: executor.tester,
        hasExternalWork: () => executor.context.apiOverlay.hasPendingLiveCalls,
        waitForExternalWork: executor.context.apiOverlay.waitForLiveCalls,
        onPump: () async {
          if (scrollRequested && !scrollApplied) {
            scrollApplied = true;
            await ensureHighlightTargetVisible(executor, step);
          }
        },
      ).waitFor(
        condition: () {
          final ready = _isScreenshotTargetReady(
                executor,
                finder,
                waitsForHitTestable,
              ) &&
              isHighlightTargetPainted(executor, finder, waitsForHitTestable);
          if (!ready && waitsForHitTestable && !scrollRequested) {
            scrollRequested = true;
          }
          return ready;
        },
        timeout: Duration(milliseconds: timeoutMs),
      );
    });
  }

  Future<void> waitForHighlightTargetToPaint(
    TestStepExecutor executor,
    TestStep step,
  ) async {
    return await RunnerBenchmark.async(
        'screenshot', 'waitForHighlightTargetToPaint', () async {
      if (step.type != 'waitForText') return;
      final finder = _highlightFinder(executor, step);
      if (finder == null) return;
      final initial =
          executor.assertions.firstVisuallyActionableElement(finder);
      if (initial == null) return;
      if (_effectiveOpacity(initial) >= 0.85) {
        // The successful wait already advanced Flutter to the matched frame.
        // A further pump can move the UI past the state being recorded.
        return;
      }

      await EventDrivenSettler(
        tester: executor.tester,
        hasExternalWork: () => executor.context.apiOverlay.hasPendingLiveCalls,
        waitForExternalWork: executor.context.apiOverlay.waitForLiveCalls,
        onPump: () => drainFlutterExceptions(executor.tester),
      ).waitFor(
        condition: () {
          final element =
              executor.assertions.firstVisuallyActionableElement(finder);
          return element == null || _effectiveOpacity(element) >= 0.85;
        },
        timeout: const Duration(milliseconds: 400),
      );
    });
  }

  ui.Rect? highlightRectForStep(
    TestStepExecutor executor,
    TestStep step, {
    bool forFailure = false,
  }) {
    if (!shouldHighlightStep(step, forFailure: forFailure)) return null;
    final finder = _highlightFinder(executor, step);
    if (finder == null) return null;
    final requireHitTestable =
        isUserActionStep(step) && !isTextMutationStep(step);
    final rect = executor.assertions.rectForVisuallyActionable(
      finder,
      requireHitTestable: requireHitTestable,
    );
    if (rect != null) return rect;
    if (!requireHitTestable) {
      return executor.assertions.rectForVisuallyActionable(finder);
    }
    return null;
  }

  Future<void> ensureHighlightTargetVisible(
    TestStepExecutor executor,
    TestStep step,
  ) async {
    return await RunnerBenchmark.async(
        'screenshot', 'ensureHighlightTargetVisible', () async {
      if (!shouldHighlightStep(step)) return;
      final finder = _highlightFinder(executor, step);
      if (finder == null) return;

      final requireHitTestable = isUserActionStep(step);
      final visibleElement = executor.assertions.firstVisuallyActionableElement(
        finder,
        requireHitTestable: requireHitTestable,
      );
      if (visibleElement != null) {
        // The matched state is already on screen. Calling ensureVisible here
        // can advance a live frame before the evidence is frozen, replacing a
        // transient match with whatever arrives next. Off-screen targets use
        // the recovery path below.
        return;
      }

      Element? currentRouteMatch;
      for (final candidate in finder.evaluate()) {
        if (!isUnderCurrentModalRoute(candidate)) continue;
        currentRouteMatch = candidate;
        break;
      }
      if (currentRouteMatch == null) return;

      var visibilityTarget = find.byWidget(currentRouteMatch.widget);
      if (step.type == 'toggle' ||
          step.type == 'check' ||
          step.type == 'uncheck') {
        final control = find.descendant(
          of: visibilityTarget,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Switch ||
                widget is CupertinoSwitch ||
                widget is Checkbox,
          ),
        );
        if (control.evaluate().isNotEmpty) visibilityTarget = control.first;
      }
      await executor.tester.ensureVisible(visibilityTarget);
      await executor.tester.pump();
    });
  }

  Finder? highlightFinder(TestStepExecutor executor, TestStep step) =>
      _highlightFinder(executor, step);

  bool isHighlightTargetPainted(
    TestStepExecutor executor,
    Finder finder,
    bool prefersHitTestable,
  ) {
    final element = executor.assertions.firstVisuallyActionableElement(
      finder,
      requireHitTestable: prefersHitTestable,
    );
    return element != null && _effectiveOpacity(element) >= 0.85;
  }

  Future<void> paintAfterUserAction(
    TestStepExecutor executor,
    EnsembleTestContext _,
  ) async {
    // The action executor already performs the bounded, event-driven wait for
    // the resulting state. Keep a short paint boundary for the next operation
    // without waiting for global idleness on screens with active timers.
    await executor.tester.pump();
    await executor.tester.pump(const Duration(milliseconds: 100));
    await executor.tester.pump();
  }

  Finder? _highlightFinder(TestStepExecutor executor, TestStep step) =>
      stepHighlightFinderForExecutor(executor, step);

  bool _isScreenshotTargetReady(
    TestStepExecutor executor,
    Finder finder,
    bool waitsForHitTestable,
  ) =>
      executor.assertions.firstVisuallyActionableElement(
        finder,
        requireHitTestable: waitsForHitTestable,
      ) !=
      null;

  double _effectiveOpacity(Element element) {
    var opacity = 1.0;
    element.visitAncestorElements((ancestor) {
      final renderObject = ancestor.renderObject;
      if (renderObject is RenderOpacity) {
        opacity *= renderObject.opacity;
      } else if (renderObject != null &&
          renderObject.runtimeType.toString() == 'RenderAnimatedOpacity') {
        try {
          final animatedOpacity = (renderObject as dynamic).opacity;
          if (animatedOpacity is Animation<double>) {
            opacity *= animatedOpacity.value;
          } else if (animatedOpacity is double) {
            opacity *= animatedOpacity;
          }
        } catch (_) {
          // Keep the known opacity from other ancestors.
        }
      }
      return true;
    });
    return opacity;
  }
}
