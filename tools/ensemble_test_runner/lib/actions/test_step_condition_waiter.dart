import 'dart:async';

import 'package:ensemble_test_runner/actions/test_execution_config.dart';
import 'package:ensemble_test_runner/actions/test_step_runtime.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/session/errors/test_execution_error.dart';
import 'package:ensemble_test_runner/session/operation_target.dart';
import 'package:flutter_test/flutter_test.dart';

/// Evaluates visual conditions for a step without coupling them to action
/// dispatch. The executor owns lifecycle callbacks; this class owns the
/// bounded condition search and its diagnostics.
class TestStepConditionWaiter {
  final AssertionEngine assertions;
  final TestExecutionConfig config;
  final TestStepRuntime runtime;
  final Finder? Function(
    ElementTarget target, {
    bool requireInteractive,
  })? resolveTargetFinder;

  TestStepConditionWaiter({
    required this.assertions,
    required this.config,
    required this.runtime,
    this.resolveTargetFinder,
  });

  Future<void> waitFor({
    TestStep? step,
    String? id,
    String? text,
    List<String> anyOf = const [],
    ElementTarget? target,
    required int timeoutMs,
    bool requireHitTestable = false,
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

    final pollInterval = config.waitPollInterval <= Duration.zero
        ? const Duration(milliseconds: 1)
        : config.waitPollInterval;
    // DateTime.now() is controlled by Flutter's fake-async test clock, so it
    // advances only when pump() runs. On expensive app screens each pump may
    // take much longer than its simulated duration, making a 15s timeout take
    // minutes of wall-clock time. Stopwatch measures the actual elapsed wait.
    final stopwatch = Zone.root.run(() => Stopwatch()..start());
    while (Zone.root.run(() => stopwatch.elapsedMilliseconds) < timeoutMs) {
      await runtime.tester.pump(pollInterval);
      runtime.drainTransientFlutterDiagnostics();
      if (id != null && _idMatches(id, target, requireHitTestable)) return;
      final matchedText = firstVisibleText(textCandidates, target: target);
      if (matchedText != null) {
        await _notifyTextMatched(matchedText, onMatched);
        return;
      }
    }
    if (id != null && _idMatches(id, target, requireHitTestable)) {
      return;
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
    Finder finder = assertions.finderForId(id);
    if (target != null) {
      try {
        finder = resolveTargetFinder?.call(
              target,
              requireInteractive: false,
            ) ??
            finder;
      } on TestExecutionError catch (error) {
        if (error.code != TestExecutionErrorCode.elementNotFound) rethrow;
        return false;
      }
    }
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
