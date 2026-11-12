import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/event_driven_settler.dart';
import 'package:ensemble_test_runner/actions/test_execution_config.dart';
import 'package:ensemble_test_runner/actions/test_step_condition_waiter.dart';
import 'package:ensemble_test_runner/actions/navigation_waiter.dart';
import 'package:ensemble_test_runner/actions/test_step_runtime.dart';
import 'package:ensemble_test_runner/application/application_test_driver.dart';
import 'package:ensemble_test_runner/session/errors/test_execution_error.dart';
import 'package:ensemble_test_runner/session/operation_target.dart';
import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart'
    show APICallRecord;
import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'package:ensemble_test_runner/src/runtime/operation_registry.dart'
    show operationRegistry;
import 'package:ensemble_test_runner/src/core/operation_registry.dart'
    show OperationDescriptor;
import 'package:ensemble_test_runner/src/core/operation.dart'
    show OperationKind, TestOperation;
import 'package:ensemble_test_runner/src/core/operation_input.dart'
    show OperationInput;
import 'package:ensemble_test_runner/src/runtime/step_evidence_policy.dart';
import 'package:flutter_test/flutter_test.dart';

/// Owns state-based waits used by [TestStepExecutor].
///
/// Each wait is bounded and advances frames only through observable Flutter or
/// application work. Operation orchestration and evidence callbacks remain in
/// the caller, so this class has one responsibility: wait for a condition.
final class TestStepWaitExecutor {
  TestStepWaitExecutor({
    required this.tester,
    required this.context,
    required this.assertions,
    required this.services,
    required this.config,
    required this.runtime,
    required this.conditionWaiter,
    required this.finderForTargetStep,
    required this.finderForTarget,
    this.invalidateResolvedFinders,
    required this.drainTransientFlutterDiagnostics,
    this.onEvidenceBoundary,
    this.onOperationEvidenceBoundary,
  });

  final WidgetTester tester;
  final EnsembleTestContext context;
  final AssertionEngine assertions;
  final ApplicationTestServices services;
  final TestExecutionConfig config;
  final TestStepRuntime runtime;
  final TestStepConditionWaiter conditionWaiter;
  final Finder Function(TestStep step, {bool requireInteractive})
      finderForTargetStep;
  final Finder Function(ElementTarget target, {bool requireInteractive})
      finderForTarget;
  /// Drops any finder that captured concrete [Element]s before each target
  /// wait poll. Async list and conditional rebuilds can replace those Elements
  /// without an operation boundary advancing the observer revision.
  final VoidCallback? invalidateResolvedFinders;
  final void Function() drainTransientFlutterDiagnostics;
  final FutureOr<void> Function(TestStep step)? onEvidenceBoundary;
  final FutureOr<void> Function(OperationInput operation, String detail)?
      onOperationEvidenceBoundary;

  late final NavigationWaiter _navigationWaiter = NavigationWaiter(
    tester: tester,
    context: context,
    navigation: services.navigation,
    config: config,
  );

  /// Executes a registered wait request selected by the core registry.
  Future<void> executeOperation(TestOperation operation) async {
    final descriptor = operationRegistry.requireDescriptor(
      operation,
      expectedKind: OperationKind.wait,
    );
    await executeInput(operation, descriptor: descriptor);
  }

  /// Executes an authored or compiled operation through the same wait route.
  /// Authored [TestStep]s already implement [OperationInput], so this avoids a
  /// second step-specific dispatch path and keeps their evidence callbacks on
  /// the original input.
  Future<void> executeInput(
    OperationInput operation, {
    required OperationDescriptor descriptor,
  }) async {
    final selected = operationRegistry.lookup(operation.operationName);
    if (selected != descriptor || descriptor.kind != OperationKind.wait) {
      throw ArgumentError.value(
        operation,
        'operation',
        'Wait input does not match its selected registry descriptor.',
      );
    }
    final handler = _waitHandlers[descriptor.handlerKey];
    if (handler == null) {
      throw StateError(
        'No registered wait handler for operation "${descriptor.name}" '
        '(${descriptor.handlerKey}).',
      );
    }
    await handler(operation);
  }

  late final Map<String, Future<void> Function(OperationInput)> _waitHandlers =
      Map.unmodifiable({
    'settle': _executeSettle,
    'waitForGone': _executeWaitForGone,
    'waitForApi': _executeWaitForApi,
    'waitForNavigation': _waitForNavigation,
    'pump': _executePump,
    'wait': _executePump,
    'waitFor': _executeWaitFor,
  });

  Set<String> get registeredHandlerKeys => Set.unmodifiable(_waitHandlers.keys);

  Future<void> _executePump(OperationInput operation) async {
    final args = operation.arguments;
    final duration = Duration(
      milliseconds: args['durationMs'] as int? ??
          (operation.operationName == 'wait'
              ? 500
              : config.waitPollInterval.inMilliseconds),
    );
    if (duration == Duration.zero) {
      await runtime.pump(label: 'pump');
    } else {
      await runtime.pumpWhileWaiting(duration);
    }
    await emitConditionBoundary(operation);
  }

  Future<void> _executeSettle(OperationInput operation) async {
    final timeoutMs = operation.arguments['timeoutMs'];
    await runtime.settle(
      timeout: timeoutMs is int ? Duration(milliseconds: timeoutMs) : null,
    );
    await emitConditionBoundary(operation);
  }

  Future<void> _executeWaitFor(OperationInput operation) async {
    await RunnerBenchmark.async('execution', 'waitFor', () async {
      final args = operation.arguments;
      final rawText = args['text'];
      final text = rawText is String ? rawText : null;
      final anyOf = <String>[
        if (rawText is List) ...conditionWaiter.stringListArg(rawText),
        ...conditionWaiter.stringListArg(args['anyOf']),
      ];
      final target = args['target'] is Map ||
              args['bounds'] is Map ||
              (args['id'] != null &&
                  (text == null || text.trim().isEmpty) &&
                  anyOf.isEmpty)
          ? _targetFromInput(operation)
          : null;
      if (target != null &&
          args['id'] == null &&
          (text == null || text.trim().isEmpty) &&
          anyOf.isEmpty) {
        await _waitForTargetToAppear(target, timeout: _timeoutFor(operation));
        await emitConditionBoundary(operation);
        return;
      }
      var matchedBoundaryEmitted = false;
      await conditionWaiter.waitFor(
        step: operation is TestStep ? operation : null,
        id: args['id']?.toString(),
        text: text,
        anyOf: anyOf,
        target: target,
        timeoutMs: _timeoutFor(operation).inMilliseconds,
        onMatched: (matchedText) async {
          matchedBoundaryEmitted = true;
          await _emitMatchedCondition(operation, matchedText);
        },
      );
      if (!matchedBoundaryEmitted) {
        await emitConditionBoundary(operation);
      }
    });
  }

  Future<void> _executeWaitForGone(OperationInput operation) async {
    await waitForGone(
      target: _targetFromInput(operation),
      timeoutMs: _timeoutFor(operation).inMilliseconds,
    );
    await emitConditionBoundary(operation);
  }

  Future<void> _executeWaitForApi(OperationInput operation) async {
    final args = operation.arguments;
    await waitForApi(
      name: args['name'],
      times: args['times'] as int? ?? 1,
      timeoutMs: _timeoutFor(operation).inMilliseconds,
    );
    await emitConditionBoundary(operation);
  }

  Future<void> _waitForTargetToAppear(
    ElementTarget target, {
    required Duration timeout,
  }) async {
    try {
      await _settler().waitFor(
        timeout: timeout,
        condition: () {
          try {
            // The target resolver memoizes Element-backed finders against the
            // observer revision. That revision is synchronized at operation
            // boundaries, but a wait spans async app rebuilds that can replace
            // keyed children within the same operation. Re-resolve each poll
            // so we test the currently mounted widget, not a stale Element.
            invalidateResolvedFinders?.call();
            final finder = finderForTarget(
              target,
              requireInteractive: false,
            );
            // `waitFor(target: ...)` means the requested target is visible on
            // the active screen. Tree membership alone also matches retained,
            // clipped, and loading-transition widgets; reporting success for
            // those states produces screenshots with no visible target.
            return assertions.hasVisibleElement(finder);
          } on TestExecutionError catch (error) {
            if (error.code == TestExecutionErrorCode.elementNotFound) {
              return false;
            }
            rethrow;
          }
        },
      );
    } on FlutterError catch (error) {
      if (!error.toString().contains('timed out')) rethrow;
      throw EnsembleTestFailure(
        'Timed out after ${timeout.inMilliseconds}ms waiting for target to appear',
      );
    }
  }

  /// Waits for a text condition using the same exact-match semantics as
  /// registered `waitFor` operations, without constructing an intermediate
  /// [TestStep].
  Future<void> waitForTextCondition({
    String? text,
    List<String> anyOf = const [],
    required int timeoutMs,
    required Future<void> Function(String matchedText) onMatched,
  }) =>
      conditionWaiter.waitFor(
        text: text,
        anyOf: anyOf,
        timeoutMs: timeoutMs,
        onMatched: onMatched,
      );

  Future<void> _waitForNavigation(OperationInput operation) async {
    final screen = operation.arguments['screen']?.toString();
    if (screen == null || screen.isEmpty) {
      throw EnsembleTestFailure('waitForNavigation requires "screen"');
    }
    await waitForNavigation(
      screen: screen,
      timeoutMs: NavigationWaiter.timeoutMsFor(
        operation,
        defaultTimeout: config.defaultWaitTimeout,
      ),
      onMatched: () => _emitNavigationBoundary(operation),
    );
  }

  Future<void> emitConditionBoundary(OperationInput operation) async {
    if (!StepEvidencePolicy.isConditionStep(operation.operationName)) return;
    final detail =
        '${StepEvidencePolicy.conditionBoundaryPrefix}${operation.operationName}';
    if (operation is TestStep) {
      await onEvidenceBoundary?.call(
        TestStep(
          type: detail,
          args: operation.args,
          mocks: operation.mocks,
          nestedSteps: operation.nestedSteps,
        ),
      );
    } else {
      await _emitOperationBoundary(operation, detail);
    }
  }

  Future<void> _emitMatchedCondition(
    OperationInput operation,
    String matchedText,
  ) async {
    if (operation is TestStep) {
      final matchedStep = TestStep(
        type: operation.type,
        args: {
          ...operation.args,
          'text': matchedText,
        }..remove('anyOf'),
        mocks: operation.mocks,
        nestedSteps: operation.nestedSteps,
      );
      if (operation.type == 'waitForText') {
        await onEvidenceBoundary?.call(matchedStep);
      } else {
        await emitConditionBoundary(matchedStep);
      }
    } else if (operation is TestOperation) {
      final matchedOperation = TestOperation(
        id: operation.id,
        name: operation.name,
        kind: operation.kind,
        handlerKey: operation.handlerKey,
        input: {
          ...operation.input,
          'text': matchedText,
        }..remove('anyOf'),
        source: operation.source,
      );
      final detail = operation.name == 'waitForText'
          ? operation.name
          : '${StepEvidencePolicy.conditionBoundaryPrefix}${operation.name}';
      await _emitOperationBoundary(matchedOperation, detail);
    }
  }

  Future<void> _emitNavigationBoundary(OperationInput operation) async {
    if (operation is TestStep) {
      await onEvidenceBoundary?.call(operation);
    } else {
      await _emitOperationBoundary(operation, operation.operationName);
    }
  }

  Future<void> _emitOperationBoundary(
    OperationInput operation,
    String detail,
  ) async {
    await onOperationEvidenceBoundary?.call(operation, detail);
  }

  Duration _timeoutFor(OperationInput operation) => Duration(
        milliseconds: operation.arguments['timeoutMs'] as int? ??
            config.defaultWaitTimeout.inMilliseconds,
      );

  /// Real-time delay and idle-settle operations share the condition path used
  /// by session callers. `pump` enters through the registered dispatcher and
  /// delegates to that same path.

  ElementTarget _targetFromInput(OperationInput operation) {
    final args = operation.arguments;
    if (args['target'] is Map) {
      return ElementTarget.fromOperationArgs(Map<String, dynamic>.from(args));
    }
    final rawBounds = args['bounds'];
    if (rawBounds is Map) {
      return ElementTarget(
        locator: ElementLocator(
          bounds: ElementBounds.fromJson(Map<String, dynamic>.from(rawBounds)),
        ),
      );
    }
    return ElementTarget.fromOperationArgs(Map<String, dynamic>.from(args));
  }

  Future<void> waitForTextContains({
    String? text,
    List<String> anyOf = const [],
    required int timeoutMs,
  }) async {
    return RunnerBenchmark.async('execution', 'waitForTextContains', () async {
      final textCandidates = <String>[
        if (text != null && text.trim().isNotEmpty) text,
        ...anyOf.where((value) => value.trim().isNotEmpty),
      ];
      if (textCandidates.isEmpty) {
        throw EnsembleTestFailure(
          'expectTextContains requires "text" or "anyOf"',
        );
      }

      try {
        await _settler(onPump: drainTransientFlutterDiagnostics).waitFor(
          timeout: Duration(milliseconds: timeoutMs),
          condition: () {
            RunnerBenchmark.count('pollingAttempts', 1);
            return assertions.isAnyTextContainingVisible(textCandidates);
          },
        );
        return;
      } on FlutterError catch (error) {
        if (!error.toString().contains('timed out')) rethrow;
      }

      throw EnsembleTestFailure(
        'Timed out after ${timeoutMs}ms waiting for text containing one of: '
        '${textCandidates.map((t) => '"$t"').join(', ')}. '
        '${assertions.textFailureHint(textCandidates)}',
      );
    });
  }

  Future<void> waitForApi({
    required Object? name,
    required int times,
    required int timeoutMs,
  }) async {
    return RunnerBenchmark.async('execution', 'waitForApi', () async {
      final rawNames = name is List ? name : [name];
      final apiNames = <String>{
        for (final candidate in rawNames)
          if (candidate != null && candidate.toString().isNotEmpty)
            candidate.toString(),
      }.toList(growable: false);
      if (apiNames.isEmpty) {
        throw EnsembleTestFailure('waitForApi requires "name"');
      }

      // A case may have issued the same API earlier (for example, Landing
      // warmed the cache before a detail screen requests it again). Waiting
      // for any historical completed call can return immediately while the
      // current screen's newer request is still pending. Track the newest
      // `times` matching invocations and wait for those exact calls instead.
      List<APICallRecord> latestCalls() => [
            for (final apiName in apiNames)
              ...context.apiOverlay.callsFor(apiName),
          ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      List<APICallRecord> selectedCalls() =>
          latestCalls().take(times).toList(growable: false);

      try {
        await _settler().waitFor(
          timeout: Duration(milliseconds: timeoutMs),
          condition: () {
            final selected = selectedCalls();
            return selected.length >= times &&
                selected.every((call) => call.isCompleted);
          },
        );
        final selected = selectedCalls();
        final failedCalls = selected.where((call) {
          final statusCode = call.statusCode;
          return call.error != null ||
              (statusCode != null && (statusCode < 200 || statusCode >= 300));
        });
        if (failedCalls.isNotEmpty) {
          final details = failedCalls.map((call) {
            final status =
                call.statusCode == null ? '' : ' (status ${call.statusCode})';
            final error = call.error ?? call.responseBody?.toString();
            return '"${call.name}"$status${error == null ? '' : ': $error'}';
          }).join('; ');
          throw EnsembleTestFailure(
            'API call completed but failed: $details',
          );
        }
        return;
      } on FlutterError catch (error) {
        if (!error.toString().contains('timed out')) rethrow;
      }
      final expectedNames = apiNames.length == 1
          ? 'API "${apiNames.single}"'
          : 'an API call named one of ${apiNames.join(', ')}';
      throw EnsembleTestFailure(
        'Timed out after ${timeoutMs}ms waiting for $expectedNames '
        'to complete $times time(s)',
      );
    });
  }

  Future<void> waitForNavigation({
    TestStep? step,
    required String screen,
    required int timeoutMs,
    Future<void> Function()? onMatched,
  }) =>
      _navigationWaiter.waitForNavigation(
        screen: screen,
        timeoutMs: timeoutMs,
        onMatched: onMatched,
      );

  Future<void> waitForGone({
    required ElementTarget target,
    required int timeoutMs,
  }) async {
    return RunnerBenchmark.async('execution', 'waitForGone', () async {
      try {
        await _settler().waitFor(
          timeout: Duration(milliseconds: timeoutMs),
          condition: () {
            try {
              return finderForTarget(
                target,
                requireInteractive: false,
              ).evaluate().isEmpty;
            } on TestExecutionError catch (error) {
              if (error.code == TestExecutionErrorCode.elementNotFound)
                return true;
              rethrow;
            }
          },
        );
        return;
      } on FlutterError catch (error) {
        if (!error.toString().contains('timed out')) rethrow;
      }
      throw EnsembleTestFailure(
        'Timed out after ${timeoutMs}ms waiting for target to disappear',
      );
    });
  }

  EventDrivenSettler _settler({
    FutureOr<void> Function()? onPump,
  }) =>
      EventDrivenSettler(
        tester: tester,
        activeFrameDuration: config.settleStepDuration,
        onPump: onPump,
      );
}
