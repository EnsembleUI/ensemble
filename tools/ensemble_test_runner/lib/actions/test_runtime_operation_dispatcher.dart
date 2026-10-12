import 'package:ensemble_test_runner/actions/test_service_expectations.dart';
import 'package:ensemble_test_runner/actions/test_environment_operations.dart';
import 'package:ensemble_test_runner/actions/test_runtime_assertion_operations.dart';
import 'package:ensemble_test_runner/session/http_request_operation_handler.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/src/core/operation_registry.dart'
    show OperationDescriptor;
import 'package:ensemble_test_runner/src/core/operation.dart'
    show OperationKind, TestOperation;
import 'package:ensemble_test_runner/src/core/operation_input.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dispatches runtime and service operations shared by standalone and hosted
/// execution. Assertion behavior lives in [TestRuntimeAssertionOperations].
final class TestRuntimeOperationDispatcher {
  TestRuntimeOperationDispatcher({
    required this.tester,
    required this.context,
    required this.expectations,
    required this.applyMocks,
    required this.assertions,
    required this.finderForTargetStep,
    required this.defaultWaitTimeout,
    required this.waitForTextContains,
    required this.waitForText,
    required this.waitForVisible,
    required this.executeLifecycleOperation,
    required this.harness,
    required this.settle,
    required this.tapOperation,
    required this.selectOperation,
    required this.toggleOperation,
    required this.checkOperation,
    required this.uncheckOperation,
    required this.enterTextOperation,
    required this.clearTextOperation,
    required this.replaceTextOperation,
    required this.submitTextOperation,
    required this.scrollOperation,
    required this.scrollUntilVisibleOperation,
    required this.focusOperation,
    required this.unfocusOperation,
    required this.dragOperation,
    required this.swipeOperation,
    required this.pullToRefreshOperation,
    required this.doubleTapOperation,
    required this.longPressOperation,
    required this.selectIndexOperation,
    required this.setSliderOperation,
    required this.chooseDateOperation,
    required this.chooseTimeOperation,
  });

  final WidgetTester tester;
  final EnsembleTestContext context;
  final TestServiceExpectations expectations;
  late final TestRuntimeAssertionOperations _assertionOperations =
      TestRuntimeAssertionOperations(
    expectations: expectations,
    assertions: assertions,
    finderForTargetStep: finderForTargetStep,
    waitForTextContains: waitForTextContains,
    waitForText: waitForText,
    waitForVisible: waitForVisible,
  );
  final Future<void> Function(OperationInput input) applyMocks;
  final AssertionEngine assertions;
  final Finder Function(
    OperationInput step, {
    bool requireInteractive,
    bool allowEmpty,
  }) finderForTargetStep;
  final Duration defaultWaitTimeout;
  final Future<void> Function({
    String? text,
    List<String> anyOf,
    required int timeoutMs,
  }) waitForTextContains;
  final Future<void> Function(OperationInput step, {required int timeoutMs})
      waitForText;
  final Future<void> Function(OperationInput step, {required int timeoutMs})
      waitForVisible;
  final Future<void> Function(
    OperationDescriptor descriptor,
    OperationInput input,
  ) executeLifecycleOperation;
  final EnsembleTestHarness? harness;
  final Future<void> Function() settle;
  final Future<void> Function(OperationInput input) tapOperation;
  final Future<void> Function(OperationInput input) selectOperation;
  final Future<void> Function(OperationInput input) toggleOperation;
  final Future<void> Function(OperationInput input) checkOperation;
  final Future<void> Function(OperationInput input) uncheckOperation;
  final Future<void> Function(OperationInput input) enterTextOperation;
  final Future<void> Function(OperationInput input) clearTextOperation;
  final Future<void> Function(OperationInput input) replaceTextOperation;
  final Future<void> Function(OperationInput input) submitTextOperation;
  final Future<void> Function(OperationInput input) scrollOperation;
  final Future<void> Function(OperationInput input) scrollUntilVisibleOperation;
  final Future<void> Function(OperationInput input) focusOperation;
  final Future<void> Function(OperationInput input) unfocusOperation;
  final Future<void> Function(OperationInput input) dragOperation;
  final Future<void> Function(OperationInput input) swipeOperation;
  final Future<void> Function(OperationInput input) pullToRefreshOperation;
  final Future<void> Function(OperationInput input) doubleTapOperation;
  final Future<void> Function(OperationInput input) longPressOperation;
  final Future<void> Function(OperationInput input) selectIndexOperation;
  final Future<void> Function(OperationInput input) setSliderOperation;
  final Future<void> Function(OperationInput input) chooseDateOperation;
  final Future<void> Function(OperationInput input) chooseTimeOperation;

  /// Runtime handlers are selected by the canonical registry key. This keeps
  /// aliases and source-document spellings out of the execution layer.
  late final Map<String, Future<void> Function(OperationInput)>
      _environmentHandlers = Map.unmodifiable({
    'environment.set': (input) async => applyTestEnvironmentOverride(
          context: context,
          input: input,
        ),
    'environment.setPermission': (input) async => applyTestPermission(
          context: context,
          input: input,
        ),
    'environment.setLocale': (input) async => applyTestLocale(context, input),
    'environment.setDevice': (input) => applyTestDeviceSize(
          tester: tester,
          context: context,
          harness: harness,
          input: input,
          settle: settle,
        ),
    'environment.setTheme': (input) => applyTestTheme(
          context: context,
          theme: input.arguments['mode']?.toString() ??
              input.arguments['theme']?.toString(),
          pump: tester.pump,
        ),
    'environment.resetApiCalls': (_) async => expectations.resetApiCalls(),
  });
  late final Map<String,
          Future<void> Function(OperationDescriptor, OperationInput)>
      _lifecycleHandlers = Map.unmodifiable({
    'lifecycle.openScreen': executeLifecycleOperation,
    'lifecycle.reloadScreen': executeLifecycleOperation,
    'lifecycle.restartApp': executeLifecycleOperation,
    'lifecycle.resetAppState': executeLifecycleOperation,
    'lifecycle.trigger': executeLifecycleOperation,
    'lifecycle.goBack': executeLifecycleOperation,
  });
  late final Map<String, Future<void> Function(OperationInput)>
      _operationInputHandlers = Map.unmodifiable({
    'interaction.tap': tapOperation,
    'interaction.select': selectOperation,
    'interaction.toggle': toggleOperation,
    'interaction.check': checkOperation,
    'interaction.uncheck': uncheckOperation,
    'interaction.enterText': enterTextOperation,
    'interaction.clearText': clearTextOperation,
    'interaction.replaceText': replaceTextOperation,
    'interaction.submitText': submitTextOperation,
    'interaction.scroll': scrollOperation,
    'interaction.scrollUntilVisible': scrollUntilVisibleOperation,
    'interaction.focus': focusOperation,
    'interaction.unfocus': unfocusOperation,
    'interaction.drag': dragOperation,
    'interaction.swipe': swipeOperation,
    'interaction.pullToRefresh': pullToRefreshOperation,
    'interaction.doubleTap': doubleTapOperation,
    'interaction.longPress': longPressOperation,
    'interaction.selectIndex': selectIndexOperation,
    'interaction.setSlider': setSliderOperation,
    'interaction.chooseDate': chooseDateOperation,
    'interaction.chooseTime': chooseTimeOperation,
    'storage.set': expectations.setStorage,
    'storage.remove': expectations.removeStorage,
    'storage.clear': (_) => expectations.clearStorage(),
    'api.mocks': applyMocks,
    'http.request.direct': const HttpRequestOperationHandler().execute,
  });

  Set<String> get registeredHandlerKeys => Set.unmodifiable({
        ..._environmentHandlers.keys,
        ..._lifecycleHandlers.keys,
        ..._operationInputHandlers.keys,
        ..._assertionOperations.operationHandlers.keys,
      });

  Future<bool> executeOperation(
    OperationInput input, {
    required OperationDescriptor descriptor,
  }) async {
    if (descriptor.kind == OperationKind.assertion) {
      return _assertionOperations.execute(
        input,
        handlerKey: descriptor.handlerKey,
      );
    }
    final environmentHandler = _environmentHandlers[descriptor.handlerKey];
    if (environmentHandler != null) {
      await environmentHandler(input);
      return true;
    }
    final lifecycleHandler = _lifecycleHandlers[descriptor.handlerKey];
    if (lifecycleHandler != null) {
      await lifecycleHandler(descriptor, input);
      return true;
    }
    final handler = _operationInputHandlers[descriptor.handlerKey];
    if (handler == null) return false;
    await handler(input);
    return true;
  }

  Future<bool> executeAssertionOperation(
    TestOperation operation, {
    required OperationDescriptor descriptor,
  }) {
    if (descriptor.kind != OperationKind.assertion) {
      throw ArgumentError.value(
        descriptor.kind,
        'descriptor.kind',
        'Expected an assertion operation.',
      );
    }
    return _assertionOperations.execute(
      operation,
      handlerKey: descriptor.handlerKey,
    );
  }
}
