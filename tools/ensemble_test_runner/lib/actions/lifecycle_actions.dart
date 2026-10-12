import 'package:ensemble/action/navigation_action.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/framework/screen_tracker.dart';
import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/src/core/operation_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _TriggerActionHandler = Future<void> Function(
  TestStepExecutor executor,
  Map<String, dynamic> input, {
  Future<void> Function()? beforeMutation,
});

typedef _LifecycleActionHandler = Future<void> Function(
  TestStepExecutor executor,
  Map<String, dynamic> input, {
  Future<void> Function()? beforeMutation,
});

/// Runtime behavior shared by compiled lifecycle operations and raw steps.
final class LifecycleActions {
  const LifecycleActions._();

  static final Map<String, _TriggerActionHandler> _triggerHandlers =
      Map.unmodifiable({
    'onLoad': _triggerOnLoad,
    'onTap': _triggerOnTap,
    'onLongPress': _triggerOnLongPress,
  });

  static final Map<String, _LifecycleActionHandler> _handlers =
      Map.unmodifiable({
    'lifecycle.openScreen': _openScreen,
    'lifecycle.reloadScreen': _reloadScreen,
    'lifecycle.trigger': _executeTrigger,
  });

  static Future<void> execute(
      TestStepExecutor executor,
      OperationDescriptor descriptor,
      String operationName,
      Map<String, dynamic> input,
      {Future<void> Function()? beforeMutation,
      TestStep? step}) async {
    final handlerKey = descriptor.handlerKey;
    if (handlerKey == 'lifecycle.resetAppState') {
      // Keep the boundary at the reset operation itself. This makes the
      // lifecycle operation publish its ordered event immediately before it
      // clears runtime state, without a caller-installed mutation callback.
      await executor.emitLifecycleEvidenceBoundary(
        operationName,
        step: step,
      );
      await _resetAppState(executor, input);
      return;
    }
    if (handlerKey == 'lifecycle.restartApp' ||
        handlerKey == 'lifecycle.launchApp') {
      // Publish before resetTestRuntime clears the current UI and runtime
      // state. Keep lifecycle evidence ownership here, beside the mutation.
      await executor.emitLifecycleEvidenceBoundary(
        operationName,
        step: step,
      );
      await _restartApp(executor, input);
      return;
    }
    if (handlerKey == 'lifecycle.goBack') {
      // Keep evidence ownership beside the route mutation, after resolving
      // which navigator will be popped and immediately before that pop.
      await _goBack(executor, operationName, step);
      return;
    }
    final handler = _handlers[handlerKey];
    if (handler == null) {
      throw ArgumentError.value(
        operationName,
        'name',
        'Unsupported lifecycle action',
      );
    }
    await handler(executor, input, beforeMutation: beforeMutation);
  }

  static Future<void> _openScreen(
    TestStepExecutor executor,
    Map<String, dynamic> input, {
    Future<void> Function()? beforeMutation,
  }) async {
    final screen = input['name']?.toString() ?? input['screen']?.toString();
    if (screen == null || screen.isEmpty) {
      throw EnsembleTestFailure('openScreen requires "name" or "screen"');
    }
    await executor.openScreenByName(screen, beforeMutation: beforeMutation);
  }

  static Future<void> _reloadScreen(
    TestStepExecutor executor,
    Map<String, dynamic> input, {
    Future<void> Function()? beforeMutation,
  }) async {
    final current = ScreenTracker().getCurrentScreenIdentifier() ??
        executor.context.testCase.startScreen;
    if (current == null || current.isEmpty) {
      throw EnsembleTestFailure('No current screen to reload');
    }
    await executor.openScreenByName(current, beforeMutation: beforeMutation);
  }

  static Future<void> _restartApp(
    TestStepExecutor executor,
    Map<String, dynamic> input,
  ) async {
    EnsembleTestHarness.resetTestRuntime(
      navigationFlow: executor.context.navigationFlow,
    );
    executor.context.runtime.clear();
    executor.context.apiOverlay.resetCalls();
    final screen = executor.context.testCase.startScreen ??
        ScreenTracker().getCurrentScreenIdentifier();
    if (screen == null || screen.isEmpty) {
      throw EnsembleTestFailure(
        'restartApp requires startScreen or a tracked current screen',
      );
    }
    await executor.openScreenByName(screen);
  }

  static Future<void> _resetAppState(
    TestStepExecutor executor,
    Map<String, dynamic> input,
  ) async {
    ScreenTracker().clearAll();
    executor.context.apiOverlay.resetCalls();
    executor.context.runtime.clear();
    await executor.context.clearStorage();
  }

  static Future<void> _executeTrigger(
    TestStepExecutor executor,
    Map<String, dynamic> input, {
    Future<void> Function()? beforeMutation,
  }) =>
      _trigger(executor, input, beforeMutation: beforeMutation);

  static Future<void> _trigger(
    TestStepExecutor executor,
    Map<String, dynamic> input, {
    Future<void> Function()? beforeMutation,
  }) async {
    final action = input['action']?.toString() ?? 'onTap';
    final handler = _triggerHandlers[action];
    if (handler == null) {
      throw EnsembleTestFailure('Unsupported trigger action: $action');
    }
    await handler(
      executor,
      input,
      beforeMutation: beforeMutation,
    );
  }

  static Future<void> _triggerOnLoad(
    TestStepExecutor executor,
    Map<String, dynamic> input, {
    Future<void> Function()? beforeMutation,
  }) async {
    final current = ScreenTracker().getCurrentScreenIdentifier() ??
        executor.context.testCase.startScreen;
    if (current == null || current.isEmpty) {
      throw EnsembleTestFailure('No current screen to reload');
    }
    await executor.openScreenByName(current, beforeMutation: beforeMutation);
  }

  static Future<void> _triggerOnTap(
    TestStepExecutor executor,
    Map<String, dynamic> input, {
    Future<void> Function()? beforeMutation,
  }) async {
    await executor.tapWidgetForOperation(
      _triggerTargetId(input),
      beforeMutation: beforeMutation,
    );
  }

  static Future<void> _triggerOnLongPress(
    TestStepExecutor executor,
    Map<String, dynamic> input, {
    Future<void> Function()? beforeMutation,
  }) async {
    await executor.longPressWidgetForOperation(
      _triggerTargetId(input),
      beforeMutation: beforeMutation,
    );
  }

  static String _triggerTargetId(Map<String, dynamic> input) {
    final id = input['id']?.toString();
    if (id == null || id.isEmpty) {
      throw EnsembleTestFailure('trigger onTap requires "id"');
    }
    return id;
  }

  static Future<void> _goBack(
    TestStepExecutor executor,
    String operationName,
    TestStep? step,
  ) async {
    final scope = executor.assertions.activeScope();
    if (scope != null) {
      await executor.emitLifecycleEvidenceBoundary(
        operationName,
        step: step,
      );
      ScreenController().executeAction(
        // ignore: deprecated_member_use
        scope.dataContext.buildContext,
        NavigateBackAction.from(payload: null),
      );
      await executor.settle();
      return;
    }
    final navigator = find.byType(Navigator);
    if (navigator.evaluate().isNotEmpty) {
      final state = executor.tester.state<NavigatorState>(navigator.first);
      await executor.emitLifecycleEvidenceBoundary(
        operationName,
        step: step,
      );
      state.pop();
      await executor.settle();
      return;
    }
    throw EnsembleTestFailure('goBack: no navigator or active scope');
  }
}
