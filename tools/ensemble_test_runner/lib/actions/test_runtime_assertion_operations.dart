import 'package:ensemble_test_runner/actions/runtime_operation_input.dart';
import 'package:ensemble_test_runner/actions/test_service_expectations.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/src/core/operation_input.dart';
import 'package:flutter_test/flutter_test.dart';

/// Owns the assertion operations selected by the shared operation registry.
final class TestRuntimeAssertionOperations {
  TestRuntimeAssertionOperations({
    required this.expectations,
    required this.assertions,
    required this.finderForTargetStep,
    required this.waitForTextContains,
    required this.waitForText,
    required this.waitForVisible,
  });

  final TestServiceExpectations expectations;
  final AssertionEngine assertions;
  final Finder Function(
    OperationInput step, {
    bool requireInteractive,
    bool allowEmpty,
  }) finderForTargetStep;
  final Future<void> Function({
    String? text,
    List<String> anyOf,
    required int timeoutMs,
  }) waitForTextContains;
  final Future<void> Function(OperationInput step, {required int timeoutMs})
      waitForText;
  final Future<void> Function(OperationInput step, {required int timeoutMs})
      waitForVisible;

  late final Map<String, Future<bool> Function(OperationInput)>
      operationHandlers = Map.unmodifiable({
    'assertion.apiCalled': _expectApiCalled,
    'assertion.apiNotCalled': _expectApiNotCalled,
    'assertion.apiCallOrder': _expectApiCallOrder,
    'assertion.lastApiCall': _expectLastApiCall,
    'assertion.storageEquals': _expectStorage,
    'expectNavigateTo': _expectNavigateTo,
    'expectVisited': _expectVisited,
    'expectVisible': _expectVisible,
    'expectNotVisible': _expectNotVisible,
    'assertion.enabled': _expectEnabled,
    'assertion.disabled': _expectDisabled,
    'assertion.value': _expectValue,
    'assertion.count': _expectCount,
    'assertion.notVisited': _expectNotVisited,
    'assertion.backStack': _expectBackStack,
    'assertion.canGoBack': _expectCanGoBack,
    'assertion.consoleLog': _expectConsoleLog,
    'assertion.errorRecorded': _expectErrorRecorded,
    'assertion.noConsoleErrors': _expectNoConsoleErrors,
    'assertion.noRenderErrors': _expectNoRenderErrors,
    'assertion.accessible': _expectAccessible,
    'assertion.semanticsLabel': _expectSemanticsLabel,
    'assertion.noOverflow': _expectNoOverflow,
    'assertion.exists': _expectExists,
    'assertion.notExists': _expectNotExists,
    'assertion.textContains': _expectTextContains,
    'assertion.listCount': _expectListCount,
    'assertion.listContains': _expectListContains,
    'assertion.listItem': _expectListItem,
    'assertion.listEmpty': _expectEmpty,
    'assertion.listNotEmpty': _expectNotEmpty,
    'assertion.checked': _expectChecked,
    'assertion.property': _expectProperty,
    'assertion.style': _expectStyle,
    'assertion.text': _expectText,
    'assertion.textAbsent': _expectNoText,
  });

  Future<bool> execute(OperationInput operation, {required String handlerKey}) {
    final handler = operationHandlers[handlerKey];
    return handler == null ? Future.value(false) : handler(operation);
  }

  Future<bool> _expectChecked(OperationInput step) async {
    assertions.expectCheckedFinder(
      finderForTargetStep(step),
      step.arguments['equals'] as bool? ?? true,
      description: RuntimeOperationInput.targetDescription(step),
    );
    return true;
  }

  Future<bool> _expectProperty(OperationInput step) async {
    assertions.expectPropertyFinder(
      finderForTargetStep(step),
      step.arguments['property']?.toString() ?? 'label',
      step.arguments['equals'],
      description: RuntimeOperationInput.targetDescription(step),
    );
    return true;
  }

  Future<bool> _expectStyle(OperationInput step) async {
    assertions.expectPropertyFinder(
      finderForTargetStep(step),
      'style',
      step.arguments['equals'],
      description: RuntimeOperationInput.targetDescription(step),
    );
    return true;
  }

  Future<bool> _expectApiCalled(OperationInput step) async {
    final name = RuntimeOperationInput.required(step, 'expectApiCalled');
    expectations.expectApiCalled(name, step.arguments['times'] as int? ?? 1);
    return true;
  }

  Future<bool> _expectApiNotCalled(OperationInput step) async {
    final name = RuntimeOperationInput.required(step, 'expectApiNotCalled');
    expectations.expectApiCalled(name, 0);
    return true;
  }

  Future<bool> _expectApiCallOrder(OperationInput step) async {
    final names = step.arguments['names'];
    expectations.expectApiCallOrder(
      names is List ? names.map((name) => name.toString()).toList() : const [],
    );
    return true;
  }

  Future<bool> _expectLastApiCall(OperationInput step) async {
    expectations.expectLastApiCall(step.arguments['name']?.toString() ?? '');
    return true;
  }

  Future<bool> _expectStorage(OperationInput step) async {
    final key = RuntimeOperationInput.required(step, 'expectStorage');
    expectations.expectStorage(key, step.arguments['equals']);
    return true;
  }

  Future<bool> _expectNavigateTo(OperationInput step) async {
    final screen = step.arguments['screen']?.toString();
    if (screen == null) {
      throw EnsembleTestFailure('expectNavigateTo requires "screen"');
    }
    expectations.expectNavigateTo(screen);
    return true;
  }

  Future<bool> _expectVisited(OperationInput step) async {
    final screen = step.arguments['screen']?.toString();
    if (screen == null) {
      throw EnsembleTestFailure('expectVisited requires "screen"');
    }
    expectations.expectVisited(screen);
    return true;
  }

  Future<bool> _expectVisible(OperationInput step) async {
    final timeoutMs = step.arguments['timeoutMs'];
    if (timeoutMs is int && timeoutMs > 0) {
      await waitForVisible(step, timeoutMs: timeoutMs);
    }
    assertions.expectVisibleFinder(
      finderForTargetStep(step, requireInteractive: false),
    );
    return true;
  }

  Future<bool> _expectNotVisible(OperationInput step) async {
    assertions.expectVisibleFinder(
      finderForTargetStep(
        step,
        requireInteractive: false,
        allowEmpty: true,
      ),
      visible: false,
    );
    return true;
  }

  Future<bool> _expectEnabled(OperationInput step) async {
    assertions.expectEnabledFinder(finderForTargetStep(step));
    return true;
  }

  Future<bool> _expectDisabled(OperationInput step) async {
    assertions.expectEnabledFinder(
      finderForTargetStep(step),
      enabled: false,
    );
    return true;
  }

  Future<bool> _expectValue(OperationInput step) async {
    assertions.expectValueFinder(
      finderForTargetStep(step),
      step.arguments['equals'],
      description: step.arguments['id']?.toString() ??
          RuntimeOperationInput.targetDescription(step),
    );
    return true;
  }

  Future<bool> _expectCount(OperationInput step) async {
    final expected = step.arguments['equals'] as int?;
    if (expected == null) {
      throw EnsembleTestFailure('expectCount requires "equals"');
    }
    assertions.expectCountFinder(
      finderForTargetStep(step),
      expected,
      description: step.arguments['id']?.toString() ??
          RuntimeOperationInput.targetDescription(step),
    );
    return true;
  }

  Future<bool> _expectText(OperationInput step) async {
    final anyOf = RuntimeOperationInput.stringList(step.arguments['anyOf']);
    final text = step.arguments['text']?.toString();
    final timeoutMs = step.arguments['timeoutMs'] as int?;
    if (timeoutMs != null && timeoutMs > 0) {
      await waitForText(step, timeoutMs: timeoutMs);
    }
    if (anyOf.isNotEmpty) {
      assertions.expectTextAny(anyOf);
    } else if (text != null) {
      assertions.expectText(text);
    } else {
      throw EnsembleTestFailure('expectText requires "text" or "anyOf"');
    }
    return true;
  }

  Future<bool> _expectNoText(OperationInput step) async {
    final anyOf = RuntimeOperationInput.stringList(step.arguments['anyOf']);
    final text = step.arguments['text']?.toString();
    if (anyOf.isNotEmpty) {
      assertions.expectNoTextAny(anyOf);
    } else if (text != null) {
      assertions.expectNoText(text);
    } else {
      throw EnsembleTestFailure(
        'expectNoText requires "text" or "anyOf"',
      );
    }
    return true;
  }

  Future<bool> _expectNotVisited(OperationInput step) async {
    final screen = step.arguments['screen']?.toString();
    if (screen == null) {
      throw EnsembleTestFailure('expectNotVisited requires "screen"');
    }
    assertions.expectNotVisited(screen);
    return true;
  }

  Future<bool> _expectBackStack(OperationInput step) async {
    assertions.expectBackStack(
      step.arguments['screens'] is List
          ? (step.arguments['screens'] as List)
              .map((item) => item.toString())
              .toList()
          : const [],
    );
    return true;
  }

  Future<bool> _expectCanGoBack(OperationInput step) async {
    assertions.expectCanGoBack(step.arguments['equals'] as bool? ?? true);
    return true;
  }

  Future<bool> _expectConsoleLog(OperationInput step) async {
    assertions.expectConsoleLog(step.arguments['contains']?.toString() ?? '');
    return true;
  }

  Future<bool> _expectErrorRecorded(OperationInput step) async {
    assertions.expectErrorRecorded(step.arguments['contains']?.toString());
    return true;
  }

  Future<bool> _expectNoConsoleErrors(OperationInput step) async {
    assertions.expectNoConsoleErrors();
    return true;
  }

  Future<bool> _expectNoRenderErrors(OperationInput step) async {
    assertions.expectNoRenderErrors();
    return true;
  }

  Future<bool> _expectAccessible(OperationInput step) async {
    assertions.expectAccessibleFinder(
      finderForTargetStep(step),
      description: RuntimeOperationInput.targetDescription(step),
    );
    return true;
  }

  Future<bool> _expectSemanticsLabel(OperationInput step) async {
    assertions.expectSemanticsLabelFinder(
      finderForTargetStep(step),
      step.arguments['label']?.toString() ?? '',
      description: RuntimeOperationInput.targetDescription(step),
    );
    return true;
  }

  Future<bool> _expectNoOverflow(OperationInput step) async {
    assertions.expectNoOverflowFinder(
      finderForTargetStep(step),
      description: RuntimeOperationInput.targetDescription(step),
    );
    return true;
  }

  Future<bool> _expectExists(OperationInput step) =>
      _expectPresence(step, exists: true);

  Future<bool> _expectNotExists(OperationInput step) =>
      _expectPresence(step, exists: false);

  Future<bool> _expectPresence(
    OperationInput step, {
    required bool exists,
  }) async {
    assertions.expectExistsFinder(
      finderForTargetStep(
        step,
        requireInteractive: false,
        allowEmpty: !exists,
      ),
      exists: exists,
    );
    return true;
  }

  Future<bool> _expectTextContains(OperationInput step) async {
    final rawAnyOf = step.arguments['anyOf'];
    final anyOf = <String>[
      if (rawAnyOf is List)
        for (final item in rawAnyOf)
          if (item != null && item.toString().trim().isNotEmpty)
            item.toString(),
    ];
    final text = step.arguments['text']?.toString();
    final timeoutMs = step.arguments['timeoutMs'] as int?;
    if (timeoutMs != null && timeoutMs > 0) {
      await waitForTextContains(text: text, anyOf: anyOf, timeoutMs: timeoutMs);
    } else if (anyOf.isNotEmpty) {
      assertions.expectTextContainsAny(anyOf);
    } else if (text != null) {
      assertions.expectTextContains(text);
    } else {
      throw EnsembleTestFailure(
        'expectTextContains requires "text" or "anyOf"',
      );
    }
    return true;
  }

  Future<bool> _expectListCount(OperationInput step) async {
    final expected = step.arguments['equals'] as int?;
    if (expected == null) {
      throw EnsembleTestFailure('expectListCount requires "equals"');
    }
    assertions.expectListCountFinder(
      finderForTargetStep(step),
      expected: expected,
      itemFinder: step.arguments['itemId'] == null
          ? null
          : assertions.finderForId(step.arguments['itemId'].toString()),
      description: RuntimeOperationInput.targetDescription(step),
    );
    return true;
  }

  Future<bool> _expectListContains(OperationInput step) async {
    assertions.expectListContainsFinder(
      finderForTargetStep(step),
      step.arguments['text']?.toString() ?? '',
      description: RuntimeOperationInput.targetDescription(step),
    );
    return true;
  }

  Future<bool> _expectListItem(OperationInput step) async {
    assertions.expectVisibleFinder(finderForTargetStep(step), visible: true);
    return true;
  }

  Future<bool> _expectEmpty(OperationInput step) async {
    assertions.expectListCountFinder(
      finderForTargetStep(step),
      expected: 0,
      description: RuntimeOperationInput.targetDescription(step),
    );
    return true;
  }

  Future<bool> _expectNotEmpty(OperationInput step) async {
    assertions.expectListCountFinder(
      finderForTargetStep(step),
      expected: 1,
      atLeast: true,
      description: RuntimeOperationInput.targetDescription(step),
    );
    return true;
  }
}
