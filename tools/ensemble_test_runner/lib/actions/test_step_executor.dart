import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'dart:async';
import 'package:ensemble/ensemble.dart';
import 'package:ensemble_test_runner/actions/test_execution_config.dart';
import 'package:ensemble_test_runner/actions/test_runtime_operation_dispatcher.dart';
import 'package:ensemble_test_runner/actions/runtime_operation_input.dart';
import 'package:ensemble_test_runner/actions/scrollable_waiter.dart';
import 'package:ensemble_test_runner/actions/test_service_expectations.dart';
import 'package:ensemble_test_runner/actions/test_mock_operations.dart';
import 'package:ensemble_test_runner/actions/test_step_target_resolver.dart';
import 'package:ensemble_test_runner/actions/test_step_wait_executor.dart';
import 'package:ensemble_test_runner/actions/test_step_gesture_operations.dart';
import 'package:ensemble_test_runner/actions/test_step_runtime.dart';
import 'package:ensemble_test_runner/actions/test_step_condition_waiter.dart';
import 'package:ensemble_test_runner/actions/test_step_widget_actions.dart';
import 'package:ensemble_test_runner/actions/lifecycle_actions.dart';
import 'package:ensemble_test_runner/application/application_test_driver.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/session/operation_target.dart';
import 'package:ensemble_test_runner/session/errors/test_execution_error.dart';
import 'package:ensemble_test_runner/src/runtime/operation_registry.dart'
    show operationRegistry;
import 'package:ensemble_test_runner/src/core/operation_registry.dart'
    show OperationDescriptor;
import 'package:ensemble_test_runner/src/core/operation.dart'
    show OperationKind, TestOperation;
import 'package:ensemble_test_runner/src/core/operation_input.dart';
import 'package:ensemble_test_runner/src/runtime/step_evidence_policy.dart';
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
  late final TestStepRuntime _runtime = TestStepRuntime(
    tester: tester,
    context: context,
    config: config,
  );
  Finder Function(
    ElementTarget target, {
    bool requireInteractive,
    bool allowEmpty,
    bool allowOffscreen,
  })? resolveTargetFinder;
  FutureOr<void> Function(TestStep step)? onEvidenceBoundary;
  FutureOr<void> Function(OperationInput operation, String detail)?
      onOperationEvidenceBoundary;
  FutureOr<void> Function(String operationName)?
      onNamedOperationEvidenceBoundary;
  late final TestStepTargetResolver _targetResolver = TestStepTargetResolver(
    assertions: assertions,
    resolveTargetFinder: () => resolveTargetFinder,
  );
  late final ScrollableWaiter _scrollableWaiter = ScrollableWaiter(
    tester: tester,
    config: config,
  );
  late final TestServiceExpectations _serviceExpectations =
      TestServiceExpectations(
    services: services,
    assertions: assertions,
    context: context,
    hasHarness: harness != null,
  );
  late final TestStepGestureOperations _gestureOperations =
      TestStepGestureOperations(
    finderForInput: finderForOperationInput,
    finderForId: assertions.finderForId,
    dragFinder: dragFinderForOperation,
    emitEvidenceBoundary: _emitOperationInputEvidenceBoundary,
  );
  late final TestRuntimeOperationDispatcher _runtimeOperations =
      TestRuntimeOperationDispatcher(
    tester: tester,
    context: context,
    expectations: _serviceExpectations,
    applyMocks: _applyMocksOperationInput,
    assertions: assertions,
    finderForTargetStep: finderForOperationInput,
    defaultWaitTimeout: config.defaultWaitTimeout,
    waitForTextContains: _waitOperations.waitForTextContains,
    waitForText: (operation, {required timeoutMs}) => _waitFor(
      id: operation.arguments['id']?.toString(),
      text: operation.arguments['text']?.toString(),
      anyOf: _conditionWaiter.stringListArg(operation.arguments['anyOf']),
      target: operation.arguments['target'] is Map ||
              operation.arguments['bounds'] is Map
          ? _targetResolver.targetForInput(operation)
          : null,
      timeoutMs: timeoutMs,
    ),
    waitForVisible: _waitForVisibleOperationInput,
    executeLifecycleOperation: executeRegisteredLifecycleInput,
    harness: harness,
    settle: _runtime.settle,
    tapOperation: _tapOperationInput,
    selectOperation: _selectOperationInput,
    toggleOperation: _toggleOperationInput,
    checkOperation: (input) => _setCheckedOperationInput(input, checked: true),
    uncheckOperation: (input) =>
        _setCheckedOperationInput(input, checked: false),
    enterTextOperation: _enterTextOperationInput,
    clearTextOperation: _clearTextOperationInput,
    replaceTextOperation: _replaceTextOperationInput,
    submitTextOperation: _submitTextOperationInput,
    scrollOperation: _scrollOperationInput,
    scrollUntilVisibleOperation: _scrollUntilVisibleOperationInput,
    focusOperation: _focusOperationInput,
    unfocusOperation: _unfocusOperationInput,
    dragOperation: _gestureOperations.drag,
    swipeOperation: _gestureOperations.swipe,
    pullToRefreshOperation: _gestureOperations.pullToRefresh,
    doubleTapOperation: _doubleTapOperationInput,
    longPressOperation: _longPressOperationInput,
    selectIndexOperation: _selectIndexOperationInput,
    setSliderOperation: _setSliderOperationInput,
    chooseDateOperation: _chooseDateTimeOperationInput,
    chooseTimeOperation: _chooseDateTimeOperationInput,
  );
  late final TestStepConditionWaiter _conditionWaiter = TestStepConditionWaiter(
    assertions: assertions,
    config: config,
    runtime: _runtime,
    context: context,
    resolveTargetFinder: (target) => resolveTargetFinder?.call(target),
  );
  late final TestStepWidgetActions _widgetActions = TestStepWidgetActions(
    tester: tester,
    assertions: assertions,
    config: config,
    runtime: _runtime,
    scrollableWaiter: _scrollableWaiter,
    waitFor: ({
      TestStep? step,
      String? id,
      String? text,
      List<String> anyOf = const [],
      ElementTarget? target,
      required int timeoutMs,
    }) =>
        _waitFor(
      step: step,
      id: id,
      text: text,
      anyOf: anyOf,
      target: target,
      timeoutMs: timeoutMs,
    ),
    onEvidenceBoundary: _emitEvidenceBoundary,
  );
  late final TestStepWaitExecutor _waitOperations = TestStepWaitExecutor(
    tester: tester,
    context: context,
    assertions: assertions,
    services: services,
    config: config,
    runtime: _runtime,
    conditionWaiter: _conditionWaiter,
    finderForTargetStep: finderForTargetStep,
    finderForTarget: (target, {bool requireInteractive = true}) =>
        _targetResolver.finderForTarget(
      target,
      operationName: 'waitForGone',
      requireInteractive: requireInteractive,
    ),
    settleLiveApiWork: _runtime.yieldToLiveApiWork,
    drainTransientFlutterDiagnostics: _runtime.drainTransientFlutterDiagnostics,
    onEvidenceBoundary: _emitEvidenceBoundary,
    onOperationEvidenceBoundary: (operation, detail) =>
        onOperationEvidenceBoundary?.call(operation, detail),
  );
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
  EnsembleTestHarness get requireHarness =>
      harness ??
      (throw const UnsupportedApplicationCapability('ensembleHarness'));

  Future<bool> executeRegisteredAssertion(
    TestOperation operation, {
    required OperationDescriptor descriptor,
  }) =>
      _runtimeOperations.executeAssertionOperation(
        operation,
        descriptor: descriptor,
      );

  Future<bool> executeRegisteredInteraction(
    OperationInput input, {
    required OperationDescriptor descriptor,
  }) =>
      _runtimeOperations.executeOperation(input, descriptor: descriptor);

  Future<void> emitOperationEvidenceBoundary(TestOperation operation) async {
    if (!StepEvidencePolicy.isConditionStep(operation.operationName)) return;
    await onOperationEvidenceBoundary?.call(
      operation,
      '${StepEvidencePolicy.conditionBoundaryPrefix}${operation.operationName}',
    );
  }

  /// Publishes a lifecycle boundary without materializing a legacy step.
  Future<void> emitLifecycleEvidenceBoundary(
    String operationName, {
    TestStep? step,
  }) async {
    if (step != null) {
      await onEvidenceBoundary?.call(step);
      return;
    }
    await onNamedOperationEvidenceBoundary?.call(operationName);
  }

  Future<void> executeWaitOperation(TestOperation operation) {
    final descriptor = operationRegistry.requireDescriptor(
      operation,
      expectedKind: OperationKind.wait,
    );
    return executeRegisteredWaitInput(operation, descriptor: descriptor);
  }

  /// Executes a wait input after its registry descriptor has been selected.
  Future<void> executeRegisteredWaitInput(
    OperationInput input, {
    required OperationDescriptor descriptor,
  }) =>
      _waitOperations.executeInput(input, descriptor: descriptor);

  /// Handler identities supported by the authored-step execution route.
  /// Kept inspectable so registry coverage can be audited in one place.
  Set<String> get registeredOperationHandlerKeys => Set.unmodifiable({
        ..._runtimeOperations.registeredHandlerKeys,
        ..._waitOperations.registeredHandlerKeys,
      });

  Future<void> _waitForVisibleOperationInput(
    OperationInput operation, {
    required int timeoutMs,
  }) {
    final target = operation.arguments['target'] is Map ||
            operation.arguments['bounds'] is Map
        ? _targetResolver.targetForInput(operation)
        : null;
    return _conditionWaiter.waitFor(
      id: operation.arguments['id']?.toString() ?? target?.testId,
      text: target?.normalizedLocator?.text,
      target: target,
      timeoutMs: timeoutMs,
      requireHitTestable: false,
    );
  }

  Future<void> notifyWaitConditionOperationMatched(
    TestOperation operation,
  ) async {
    await onOperationEvidenceBoundary?.call(operation, operation.name);
  }

  Future<void> _emitOperationInputEvidenceBoundary(
    OperationInput input,
  ) async {
    if (input is TestStep) {
      await _emitEvidenceBoundary(input);
      return;
    }
    await onOperationEvidenceBoundary?.call(input, input.operationName);
  }

  Future<void> _tapOperationInput(OperationInput input) async {
    Future<void> boundary() async {
      await _emitOperationInputEvidenceBoundary(input);
    }

    if (input.arguments['target'] is Map ||
        input.arguments['bounds'] is Map ||
        input.arguments['id'] is String) {
      final target = _targetResolver.targetForInput(input);
      final locator = target.normalizedLocator;
      final isSimpleId = locator != null &&
          locator.id != null &&
          locator.text == null &&
          locator.label == null &&
          locator.role == null &&
          locator.within == null &&
          locator.occurrence == null &&
          locator.bounds == null;
      final canWaitForLocator = !target.usesSnapshotElement &&
          target.occurrence == null &&
          !_locatorHasOccurrence(locator) &&
          locator != null &&
          (isSimpleId || input.arguments['timeoutMs'] is int);
      Finder? resolvedFinder;
      if (canWaitForLocator && isSimpleId) {
        final timeout = Duration(
          milliseconds: input.arguments['timeoutMs'] as int? ??
              config.defaultWaitTimeout.inMilliseconds,
        );
        bool targetExists() => assertions
            .finderForId(locator.id!, skipOffstage: false)
            .evaluate()
            .isNotEmpty;

        // A locator can match an Element before it is actionable (for example
        // during a route transition). Existence is the wait condition; the
        // normal tap path then waits for hit testing and handles visibility.
        if (!targetExists()) {
          try {
            await _runtime.waitForCondition(
              condition: targetExists,
              timeout: timeout,
            );
          } on FlutterError catch (timeoutError) {
            if (!timeoutError.toString().contains('timed out')) rethrow;
            throw _tapTargetNotFound(input, target, timeout);
          }
        }

        // IDs in existing apps can be shared by mirrored/offstage controls.
        // The regular tap path selects the hit-testable match; existence must
        // not reject the action before that selection and readiness check.
        await tapForOperation(
          locator.id!,
          timeoutMs: input.arguments['timeoutMs'] as int?,
          onBeforeTap: boundary,
        );
        return;
      } else if (canWaitForLocator) {
        final timeout = Duration(
          milliseconds: input.arguments['timeoutMs'] as int,
        );
        try {
          // Preserve the fast path for already-present locators. Only enter
          // the polling path when resolution reports a genuinely missing
          // target; ambiguity and other resolution failures remain immediate.
          resolvedFinder = finderForOperationInput(input);
        } on TestExecutionError catch (error) {
          if (error.code != TestExecutionErrorCode.elementNotFound) rethrow;
          final mounted = finderForOperationInput(
            input,
            requireInteractive: false,
            allowEmpty: true,
          );
          if (mounted.evaluate().isNotEmpty) rethrow;

          bool targetExists() {
            final current = finderForOperationInput(
              input,
              requireInteractive: false,
              allowEmpty: true,
            );
            return current.evaluate().isNotEmpty;
          }

          try {
            await _runtime.waitForCondition(
              condition: targetExists,
              timeout: timeout,
            );
          } on FlutterError catch (timeoutError) {
            if (!timeoutError.toString().contains('timed out')) rethrow;
            throw _tapTargetNotFound(input, target, timeout);
          }
          resolvedFinder = finderForOperationInput(input);
        }
      }
      await tapFinderForOperation(
        resolvedFinder ?? finderForOperationInput(input),
        onBeforeTap: boundary,
      );
      return;
    }
    await tapForOperation(
      RuntimeOperationInput.requiredTarget(input),
      timeoutMs: input.arguments['timeoutMs'] as int?,
      onBeforeTap: boundary,
    );
  }

  TestExecutionError _tapTargetNotFound(
    OperationInput input,
    ElementTarget target,
    Duration timeout,
  ) {
    final id = target.testId;
    final message = id == null || id.isEmpty
        ? 'Timed out after ${timeout.inMilliseconds}ms waiting for target to appear'
        : 'Timed out after ${timeout.inMilliseconds}ms waiting for id "$id". '
            '${assertions.widgetIdFailureHint(id)}';
    return TestExecutionError(
      code: TestExecutionErrorCode.elementNotFound,
      message: message,
      details: {
        'locator': target.normalizedLocator?.toJson() ??
            {'operation': input.operationName},
      },
    );
  }

  bool _locatorHasOccurrence(ElementLocator? locator) {
    var current = locator;
    while (current != null) {
      if (current.occurrence != null) return true;
      current = current.within;
    }
    return false;
  }

  Future<void> _selectOperationInput(OperationInput input) async {
    final value = input.arguments['value']?.toString();
    if (value == null || value.isEmpty) {
      throw EnsembleTestFailure('select requires "value"');
    }
    Future<void> boundary() async {
      await _emitOperationInputEvidenceBoundary(input);
    }

    if (input.arguments['target'] is Map || input.arguments['bounds'] is Map) {
      final finder = await _finderForInputWithTimeout(input);
      await selectFinderForOperation(
        finder,
        value,
        onBeforeSelection: boundary,
      );
      return;
    }
    await selectForOperation(
      RuntimeOperationInput.requiredTarget(input),
      value,
      timeoutMs: input.arguments['timeoutMs'] as int?,
      onBeforeSelection: boundary,
    );
  }

  Future<Finder> _finderForInputWithTimeout(
    OperationInput input, {
    bool useConfiguredDefault = false,
  }) async {
    final configuredTimeout = input.arguments['timeoutMs'];
    final timeoutMs = configuredTimeout is int
        ? configuredTimeout
        : useConfiguredDefault
            ? config.defaultWaitTimeout.inMilliseconds
            : null;
    if (timeoutMs == null) return finderForOperationInput(input);

    try {
      return finderForOperationInput(input);
    } on TestExecutionError catch (error) {
      if (error.code != TestExecutionErrorCode.elementNotFound) rethrow;

      final mountedFinder = finderForOperationInput(
        input,
        requireInteractive: false,
        allowEmpty: true,
      );
      if (mountedFinder.evaluate().isNotEmpty) rethrow;

      bool targetExists() => finderForOperationInput(
            input,
            requireInteractive: false,
            allowEmpty: true,
          ).evaluate().isNotEmpty;
      try {
        await _runtime.waitForCondition(
          condition: targetExists,
          timeout: Duration(milliseconds: timeoutMs),
        );
      } on FlutterError catch (waitError) {
        if (!waitError.toString().contains('timed out')) rethrow;
        throw error;
      }
      return finderForOperationInput(input);
    }
  }

  Future<void> _toggleOperationInput(OperationInput input) async {
    final boundary = () => _emitOperationInputEvidenceBoundary(input);
    if (input.arguments['target'] is Map || input.arguments['bounds'] is Map) {
      await toggleFinderForOperation(
        await _finderForInputWithTimeout(input, useConfiguredDefault: true),
        onBeforeToggle: boundary,
      );
      return;
    }
    await toggleForOperation(
      RuntimeOperationInput.requiredTarget(input),
      timeoutMs: input.arguments['timeoutMs'] as int?,
      onBeforeToggle: boundary,
    );
  }

  Future<void> _setCheckedOperationInput(
    OperationInput input, {
    required bool checked,
  }) async {
    final finder = await _finderForInputWithTimeout(input);
    final boundary = () => _emitOperationInputEvidenceBoundary(input);
    if (checked) {
      await checkFinderForOperation(finder, onBeforeToggle: boundary);
    } else {
      await uncheckFinderForOperation(finder, onBeforeToggle: boundary);
    }
  }

  Future<void> _enterTextOperationInput(OperationInput input) async {
    final value = input.arguments['value']?.toString() ?? '';
    final beforeText = () => _emitOperationInputEvidenceBoundary(input);
    if (input.arguments['target'] is Map) {
      await enterTextFinderForOperation(
        await _finderForInputWithTimeout(input, useConfiguredDefault: true),
        value,
        submit: input.arguments['submit'] == true,
        onBeforeText: beforeText,
      );
      return;
    }
    await enterTextForOperation(
      RuntimeOperationInput.requiredTarget(input),
      value,
      submit: input.arguments['submit'] == true,
      timeoutMs: input.arguments['timeoutMs'] as int?,
      onBeforeText: beforeText,
    );
  }

  Future<void> _clearTextOperationInput(OperationInput input) async {
    final beforeText = () => _emitOperationInputEvidenceBoundary(input);
    await editTextFinderForOperation(
      await _finderForInputWithTimeout(input),
      '',
      replace: true,
      onBeforeText: beforeText,
    );
  }

  Future<void> _replaceTextOperationInput(OperationInput input) async {
    final value = input.arguments['value']?.toString() ?? '';
    final beforeText = () => _emitOperationInputEvidenceBoundary(input);
    final structured = input.arguments['target'] is Map;
    final hasTimeout = input.arguments['timeoutMs'] is int;
    if (structured || hasTimeout) {
      final finder = await _finderForInputWithTimeout(input);
      if (structured) {
        await editTextFinderForOperation(
          finder,
          value,
          replace: true,
          submit: input.arguments['submit'] == true,
          onBeforeText: beforeText,
        );
        return;
      }
    }
    final id = RuntimeOperationInput.requiredTarget(input);
    await clearTextForOperation(id, onBeforeText: beforeText);
    await enterTextForOperation(
      id,
      value,
      submit: input.arguments['submit'] == true,
    );
  }

  Future<void> _submitTextOperationInput(OperationInput input) async {
    final structured = input.arguments['target'] is Map;
    Future<void> beforeSubmit() async {
      await _emitOperationInputEvidenceBoundary(input);
    }

    if (structured) {
      await submitTextFinderForOperation(
        await _finderForInputWithTimeout(input, useConfiguredDefault: true),
        onBeforeSubmit: beforeSubmit,
      );
      return;
    }
    await submitTextForOperation(
      RuntimeOperationInput.requiredTarget(input),
      timeoutMs: input.arguments['timeoutMs'] as int?,
      onBeforeSubmit: () => _emitOperationInputEvidenceBoundary(input),
    );
  }

  Future<void> _scrollOperationInput(OperationInput input) async {
    final structured =
        input.arguments['target'] is Map || input.arguments['bounds'] is Map;
    final scrollable =
        structured ? finderForOperationInput(input) : find.byType(Scrollable);
    if (scrollable.evaluate().isEmpty) {
      throw EnsembleTestFailure('scroll: no Scrollable found');
    }
    await dragFinderForOperation(
      scrollable.first,
      Offset(0, ((input.arguments['delta'] as num?) ?? -300).toDouble()),
      onBeforeDrag: () => _emitOperationInputEvidenceBoundary(input),
    );
  }

  Future<void> _scrollUntilVisibleOperationInput(OperationInput input) async {
    final structured =
        input.arguments['target'] is Map || input.arguments['bounds'] is Map;
    final target = structured
        ? _deferredOperationTargetFinder(input)
        : assertions.finderForId(
            RuntimeOperationInput.requiredTarget(input),
            skipOffstage: false,
          );
    await scrollUntilVisibleForOperation(
      target,
      scrollableId: input.arguments['scrollableId']?.toString(),
      timeoutMs: (input.arguments['timeoutMs'] as num?)?.toInt() ??
          config.defaultWaitTimeout.inMilliseconds,
    );
    if (input is TestOperation) {
      await notifyWaitConditionOperationMatched(input);
    }
  }

  Future<void> _focusOperationInput(OperationInput input) async {
    final finder = await _finderForInputWithTimeout(
      input,
      useConfiguredDefault: true,
    );
    Future<void> beforeFocus() async {
      await _emitOperationInputEvidenceBoundary(input);
    }

    await tapFinderForOperation(finder, onBeforeTap: beforeFocus);
  }

  Future<void> _unfocusOperationInput(OperationInput input) async {
    await _emitOperationInputEvidenceBoundary(input);
    await unfocus();
  }

  Future<void> _doubleTapOperationInput(OperationInput input) async {
    final finder = await _finderForInputWithTimeout(
      input,
      useConfiguredDefault: true,
    );
    Future<void> beforeFirstTap() async {
      await _emitOperationInputEvidenceBoundary(input);
    }

    await doubleTapFinderForOperation(
      finder,
      onBeforeFirstTap: beforeFirstTap,
    );
  }

  Future<void> _longPressOperationInput(OperationInput input) async {
    final finder = await _finderForInputWithTimeout(
      input,
      useConfiguredDefault: true,
    );
    await longPressFinderForOperation(
      finder,
      onBeforeLongPress: () async {
        await _emitOperationInputEvidenceBoundary(input);
      },
    );
  }

  Future<void> _selectIndexOperationInput(OperationInput input) async {
    final index = (input.arguments['index'] as num?)?.toInt() ?? 0;
    await selectIndexFinderForOperation(
      finderForOperationInput(input),
      index,
      onBeforeSelection: () async {
        await _emitOperationInputEvidenceBoundary(input);
      },
    );
  }

  Future<void> _setSliderOperationInput(OperationInput input) async {
    final value = (input.arguments['value'] as num?)?.toDouble() ?? 0.5;
    await setSliderFinderForOperation(
      finderForOperationInput(input),
      value,
      onBeforeChange: () async {
        await _emitOperationInputEvidenceBoundary(input);
      },
    );
  }

  Future<void> _chooseDateTimeOperationInput(OperationInput input) async {
    await _enterTextOperationInput(input);
  }

  Finder _deferredOperationTargetFinder(OperationInput input) {
    final target = _targetResolver.targetForInput(input);
    final locator = target.normalizedLocator;
    final id = target.testId ?? locator?.id;
    if (id != null && id.isNotEmpty) {
      return assertions.finderForId(id, skipOffstage: false);
    }
    final text = locator?.text;
    if (text != null && text.isNotEmpty) {
      return find.text(text, skipOffstage: false);
    }
    final label = locator?.label;
    if (label != null && label.isNotEmpty) return find.bySemanticsLabel(label);
    return finderForOperationInput(
      input,
      requireInteractive: false,
      allowEmpty: true,
    );
  }

  /// Executes lifecycle behavior selected by the already-validated registry
  /// descriptor, avoiding a second name-based dispatch pass.
  Future<void> executeRegisteredLifecycleOperation(
    OperationDescriptor descriptor,
    Map<String, dynamic> input, {
    String? operationName,
    TestStep? step,
  }) async {
    if (descriptor.kind != OperationKind.lifecycle) {
      throw ArgumentError.value(
        descriptor.kind,
        'descriptor.kind',
        'Expected a lifecycle operation.',
      );
    }
    final name = operationName ?? descriptor.name;
    Future<void> beforeMutation() async {
      await emitLifecycleEvidenceBoundary(name, step: step);
    }

    await LifecycleActions.execute(
      this,
      descriptor,
      name,
      input,
      step: step,
      beforeMutation: beforeMutation,
    );
  }

  /// Executes lifecycle behavior with its original authored or compiled input.
  /// Authored steps retain their evidence callback; compiled inputs are passed
  /// through without creating a TestStep adapter.
  Future<void> executeRegisteredLifecycleInput(
    OperationDescriptor descriptor,
    OperationInput input,
  ) =>
      executeRegisteredLifecycleOperation(
        descriptor,
        Map<String, dynamic>.from(input.arguments),
        operationName: input.operationName,
        step: input is TestStep ? input : null,
      );

  String requireId(TestStep step) => _requireId(step);
  Finder finderForTargetStep(
    TestStep step, {
    bool requireInteractive = true,
    bool allowEmpty = false,
  }) =>
      _targetResolver.finderForStep(
        step,
        requireInteractive: requireInteractive,
        allowEmpty: allowEmpty,
      );
  Finder finderForOperationInput(
    OperationInput operation, {
    bool requireInteractive = true,
    bool allowEmpty = false,
    bool allowOffscreen = false,
  }) =>
      _targetResolver.finderForInput(
        operation,
        requireInteractive: requireInteractive,
        allowEmpty: allowEmpty,
        allowOffscreen: allowOffscreen,
      );
  Finder finderForTargetArgs(
    Map<String, dynamic> args, {
    bool requireInteractive = true,
    bool allowEmpty = false,
  }) =>
      _targetResolver.finderForTargetArgs(
        args,
        requireInteractive: requireInteractive,
        allowEmpty: allowEmpty,
      );
  String targetDescription(TestStep step) =>
      _targetResolver.descriptionFor(step);
  Future<void> tapWidget(String id, {int? timeoutMs}) =>
      _widgetActions.tapWidget(id, timeoutMs: timeoutMs);
  Future<void> tapWidgetForOperation(
    String id, {
    Future<void> Function()? beforeMutation,
  }) =>
      _widgetActions.tap(
        id,
        onBeforeTap: () async {
          await beforeMutation?.call();
        },
      );
  Future<void> longPressWidgetForOperation(
    String id, {
    Future<void> Function()? beforeMutation,
  }) =>
      _widgetActions.longPressWidget(
        id,
        onBeforeLongPress: () async {
          await beforeMutation?.call();
        },
      );

  Future<void> dragFinderForOperation(
    Finder finder,
    Offset offset, {
    required Future<void> Function() onBeforeDrag,
  }) =>
      _widgetActions.dragFinder(
        finder,
        offset,
        onBeforeDrag: onBeforeDrag,
      );

  Future<void> scrollUntilVisibleForOperation(
    Finder target, {
    String? scrollableId,
    required int timeoutMs,
  }) =>
      _widgetActions.scrollUntilVisibleFinder(
        target,
        scrollableId: scrollableId,
        timeoutMs: timeoutMs,
      );

  Future<void> selectIndexFinderForOperation(
    Finder finder,
    int index, {
    required Future<void> Function() onBeforeSelection,
  }) =>
      _widgetActions.selectIndexOnFinder(
        finder,
        index,
        onBeforeSelection: onBeforeSelection,
      );

  Future<void> setSliderFinderForOperation(
    Finder finder,
    double value, {
    required Future<void> Function() onBeforeChange,
  }) =>
      _widgetActions.setSliderOnFinder(
        finder,
        value,
        onBeforeChange: onBeforeChange,
      );

  Future<void> tapFinderForOperation(
    Finder finder, {
    required Future<void> Function() onBeforeTap,
  }) =>
      _widgetActions.tapFinder(finder, onBeforeTap: onBeforeTap);

  Future<void> tapForOperation(
    String id, {
    int? timeoutMs,
    Future<void> Function()? onBeforeTap,
  }) =>
      _widgetActions.tap(id, timeoutMs: timeoutMs, onBeforeTap: onBeforeTap);

  Future<void> enterTextFinderForOperation(
    Finder finder,
    String value, {
    bool submit = false,
    required Future<void> Function() onBeforeText,
  }) =>
      _widgetActions.enterTextOnFinder(
        finder,
        value,
        submit: submit,
        onBeforeText: onBeforeText,
      );

  Future<void> editTextFinderForOperation(
    Finder finder,
    String value, {
    bool replace = false,
    bool submit = false,
    required Future<void> Function() onBeforeText,
  }) =>
      _widgetActions.enterTextOnFinder(
        finder,
        value,
        replace: replace,
        submit: submit,
        onBeforeText: onBeforeText,
      );

  Future<void> enterTextForOperation(
    String id,
    String value, {
    bool submit = false,
    int? timeoutMs,
    Future<void> Function()? onBeforeText,
  }) =>
      _widgetActions.enterText(
        id,
        value,
        submit: submit,
        timeoutMs: timeoutMs,
        onBeforeText: onBeforeText,
      );

  Future<void> clearTextForOperation(
    String id, {
    required Future<void> Function() onBeforeText,
  }) =>
      _widgetActions.clearText(id, onBeforeText: onBeforeText);

  Future<void> submitTextForOperation(
    String id, {
    int? timeoutMs,
    required Future<void> Function() onBeforeSubmit,
  }) =>
      _widgetActions.submitText(
        id,
        timeoutMs: timeoutMs,
        onBeforeSubmit: onBeforeSubmit,
      );

  Future<void> submitTextFinderForOperation(
    Finder finder, {
    required Future<void> Function() onBeforeSubmit,
  }) =>
      _widgetActions.submitTextOnFinder(
        finder,
        onBeforeSubmit: onBeforeSubmit,
      );

  Future<void> selectFinderForOperation(
    Finder finder,
    String value, {
    required Future<void> Function() onBeforeSelection,
  }) =>
      _widgetActions.selectOnFinder(
        finder,
        value,
        onBeforeSelection: onBeforeSelection,
      );

  Future<void> selectForOperation(
    String id,
    String value, {
    int? timeoutMs,
    required Future<void> Function() onBeforeSelection,
  }) =>
      _widgetActions.select(
        id,
        value,
        timeoutMs: timeoutMs,
        onBeforeSelection: onBeforeSelection,
      );

  Future<void> toggleFinderForOperation(
    Finder finder, {
    required Future<void> Function() onBeforeToggle,
  }) =>
      _widgetActions.toggleFinder(finder, onBeforeToggle: onBeforeToggle);

  Future<void> toggleForOperation(
    String id, {
    int? timeoutMs,
    required Future<void> Function() onBeforeToggle,
  }) =>
      _widgetActions.toggle(
        id,
        timeoutMs: timeoutMs,
        onBeforeToggle: onBeforeToggle,
      );

  Future<void> checkFinderForOperation(
    Finder finder, {
    required Future<void> Function() onBeforeToggle,
  }) =>
      _widgetActions.checkFinder(finder, onBeforeToggle: onBeforeToggle);

  Future<void> uncheckFinderForOperation(
    Finder finder, {
    required Future<void> Function() onBeforeToggle,
  }) =>
      _widgetActions.uncheckFinder(finder, onBeforeToggle: onBeforeToggle);

  Future<void> doubleTapFinderForOperation(
    Finder finder, {
    required Future<void> Function() onBeforeFirstTap,
  }) =>
      _widgetActions.doubleTapFinder(
        finder,
        onBeforeFirstTap: onBeforeFirstTap,
      );

  Future<void> longPressFinderForOperation(
    Finder finder, {
    required Future<void> Function() onBeforeLongPress,
  }) =>
      _widgetActions.longPressFinder(
        finder,
        onBeforeLongPress: onBeforeLongPress,
      );

  Future<void> doubleTapFinder(Finder finder, {TestStep? step}) =>
      _widgetActions.doubleTapFinder(finder, step: step);

  Future<void> longPressWidget(String id) => _widgetActions.longPressWidget(id);

  Future<void> longPressFinder(Finder finder, {TestStep? step}) =>
      _widgetActions.longPressFinder(finder, step: step);

  Future<void> focusWidget(String id) => _widgetActions.focusWidget(id);

  Future<void> focusFinder(Finder finder, {TestStep? step}) =>
      _widgetActions.focusFinder(finder, step: step);

  Future<void> enterTextOn(String id, String value) =>
      _widgetActions.enterTextOn(id, value);

  Future<void> enterTextOnFinder(
    Finder finder,
    String value, {
    bool submit = false,
    bool replace = false,
    TestStep? step,
  }) =>
      _widgetActions.enterTextOnFinder(
        finder,
        value,
        submit: submit,
        replace: replace,
        step: step,
      );

  Future<void> submitTextOnFinder(Finder finder, {TestStep? step}) =>
      _widgetActions.submitTextOnFinder(finder, step: step);

  Future<void> toggleFinder(Finder finder, {TestStep? step}) =>
      _widgetActions.toggleFinder(finder, step: step);

  Future<void> checkFinder(Finder finder, {TestStep? step}) =>
      _widgetActions.checkFinder(finder, step: step);

  Future<void> uncheckFinder(Finder finder, {TestStep? step}) =>
      _widgetActions.uncheckFinder(finder, step: step);

  Future<void> selectOnFinder(
    Finder finder,
    String value, {
    TestStep? step,
  }) =>
      _widgetActions.selectOnFinder(finder, value, step: step);

  Future<void> selectIndexOnFinder(Finder finder, int index,
          {TestStep? step}) =>
      _widgetActions.selectIndexOnFinder(finder, index, step: step);

  Future<void> setSliderOnFinder(Finder finder, double value,
          {TestStep? step}) =>
      _widgetActions.setSliderOnFinder(finder, value, step: step);

  Future<void> dragFinder(Finder finder, Offset offset, {TestStep? step}) =>
      _widgetActions.dragFinder(finder, offset, step: step);

  Future<void> scrollUntilVisibleFinder(
    Finder finder, {
    String? scrollableId,
    TestStep? step,
  }) async {
    await _widgetActions.scrollUntilVisibleFinder(
      finder,
      scrollableId: scrollableId,
    );
    if (step != null) await _waitOperations.emitConditionBoundary(step);
  }

  Future<void> _emitEvidenceBoundary(TestStep step) async {
    await onEvidenceBoundary?.call(step);
  }

  /// Publishes evidence at a lifecycle operation's mutation boundary.
  Future<void> emitEvidenceBoundary(TestStep step) =>
      _emitEvidenceBoundary(step);

  Future<void> waitForTextContains({
    String? text,
    List<String> anyOf = const [],
    required int timeoutMs,
  }) =>
      _waitOperations.waitForTextContains(
        text: text,
        anyOf: anyOf,
        timeoutMs: timeoutMs,
      );

  Future<void> waitForTextCondition({
    String? text,
    List<String> anyOf = const [],
    required int timeoutMs,
    required Future<void> Function(String matchedText) onMatched,
  }) =>
      _waitOperations.waitForTextCondition(
        text: text,
        anyOf: anyOf,
        timeoutMs: timeoutMs,
        onMatched: onMatched,
      );

  Future<void> unfocus() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await _runtime.settle();
  }

  Future<void> settle({Duration? timeout}) => _runtime.settle(timeout: timeout);

  Future<void> pumpForTargetReadiness() =>
      _runtime.pump(label: 'tapFinder.ensureVisible');

  Future<void> settleAfterAction() => _runtime.settleAfterAction();

  Future<void> _waitFor({
    TestStep? step,
    String? id,
    String? text,
    List<String> anyOf = const [],
    ElementTarget? target,
    required int timeoutMs,
  }) =>
      RunnerBenchmark.async(
        'execution',
        'waitFor',
        () => _conditionWaiter.waitFor(
          step: step,
          id: id,
          text: text,
          anyOf: anyOf,
          target: target,
          timeoutMs: timeoutMs,
        ),
      );

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

  Future<void> _applyMocksOperationInput(OperationInput input) async {
    _applyMocks(TestMockOperations.decode(input));
  }

  Future<void> openScreenByName(
    String screen, {
    Future<void> Function()? beforeMutation,
  }) async {
    await beforeMutation?.call();
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
    await _runtime.settle();
  }

  String _requireId(TestStep step) => _targetResolver.requireId(step);
}
