import 'package:ensemble_test_runner/actions/test_execution_config.dart';
import 'package:ensemble_test_runner/actions/test_step_runtime.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/event_driven_settler.dart';
import 'package:ensemble_test_runner/session/errors/test_execution_error.dart';
import 'package:ensemble_test_runner/session/operation_target.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Evaluates visual conditions for a step without coupling them to action
/// dispatch. The executor owns lifecycle callbacks; this class owns the
/// bounded condition search and its diagnostics.
class TestStepConditionWaiter {
  final AssertionEngine assertions;
  final TestExecutionConfig config;
  final TestStepRuntime runtime;
  final EnsembleTestContext context;
  final Finder? Function(ElementTarget target)? resolveTargetFinder;

  TestStepConditionWaiter({
    required this.assertions,
    required this.config,
    required this.runtime,
    required this.context,
    this.resolveTargetFinder,
  });

  Future<void> waitFor({
    TestStep? step,
    String? id,
    String? text,
    List<String> anyOf = const [],
    ElementTarget? target,
    required int timeoutMs,
    bool requireHitTestable = true,
    Future<void> Function(String matchedText)? onMatched,
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

    // Inspect the current tree first. Most conditions are already available
    // after the preceding action and do not need another frame.
    if (id != null && _idMatches(id, target, requireHitTestable)) {
      return;
    }
    final initialText = firstVisibleText(textCandidates, target: target);
    if (initialText != null) {
      await _notifyTextMatched(initialText, onMatched);
      return;
    }

    var eventWaitTimedOut = false;
    if (context.apiOverlay.hasPendingLiveCalls) {
      String? matchedText;
      try {
        await EventDrivenSettler(
          tester: runtime.tester,
          hasExternalWork: () => context.apiOverlay.hasPendingLiveCalls,
          waitForExternalWork: context.apiOverlay.waitForLiveCalls,
          externalWorkPollTimeout: config.waitPollInterval,
          activeFrameDuration: config.settleStepDuration,
        ).waitFor(
          timeout: Duration(milliseconds: timeoutMs),
          condition: () {
            if (id != null && _idMatches(id, target, requireHitTestable)) {
              return true;
            }
            matchedText = firstVisibleText(textCandidates, target: target);
            return matchedText != null;
          },
        );
      } on FlutterError catch (error) {
        if (!error.toString().contains('timed out')) rethrow;
        eventWaitTimedOut = true;
      }
      if (matchedText != null) {
        await _notifyTextMatched(matchedText!, onMatched);
        return;
      }
      if (id != null && _idMatches(id, target, requireHitTestable)) {
        return;
      }
    }

    final stopwatch = Stopwatch()..start();
    while (!eventWaitTimedOut && stopwatch.elapsedMilliseconds < timeoutMs) {
      await runtime.pump(
        duration: config.waitPollInterval,
        label: 'waitFor',
      );
      if (id != null && _idMatches(id, target, requireHitTestable)) {
        return;
      }
      final matchedText = firstVisibleText(textCandidates, target: target);
      if (matchedText != null) {
        await _notifyTextMatched(matchedText, onMatched);
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

  List<String> stringListArg(dynamic value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item != null && item.toString().trim().isNotEmpty) item.toString(),
    ];
  }

  bool _idMatches(
    String id,
    ElementTarget? target,
    bool requireHitTestable,
  ) {
    if (target?.normalizedLocator?.bounds != null) return false;
    final finder = assertions.finderForId(id);
    return requireHitTestable
        ? finder.hitTestable().evaluate().isNotEmpty
        : assertions.hasVisibleElement(finder);
  }

  String? firstVisibleText(
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

  Future<void> _notifyTextMatched(
    String text,
    Future<void> Function(String matchedText)? onMatched,
  ) async {
    await onMatched?.call(text);
  }
}
