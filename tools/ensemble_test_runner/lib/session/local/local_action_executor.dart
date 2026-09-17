import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/session/actions/test_action.dart';
import 'package:ensemble_test_runner/session/errors/test_execution_error.dart';
import 'package:ensemble_test_runner/session/local/observation_registry.dart';
import 'package:flutter_test/flutter_test.dart';

/// Resolves [ElementTarget] for local execution.
///
/// Snapshot [elementId] targets always bind to the exact cached [Element]
/// (`identical`); they never fall back to testId / first-match.
class FlutterTargetResolver {
  FlutterTargetResolver({
    required this.tester,
    required this.assertions,
    required this.registry,
  });

  final WidgetTester tester;
  final AssertionEngine assertions;
  final ObservationRegistry registry;

  /// Returns a [Finder] for the target. Snapshot targets never fall back to testId.
  Finder resolveFinder(ElementTarget target) {
    if (target.usesSnapshotElement) {
      final observationId = target.observationId;
      if (observationId == null || observationId.isEmpty) {
        throw const TestExecutionError(
          code: TestExecutionErrorCode.staleObservation,
          message: 'elementId targets require observationId.',
        );
      }
      final handle = registry.revalidate(
        observationId: observationId,
        elementId: target.elementId!,
      );
      return find.byElementPredicate((e) => identical(e, handle.element));
    }

    final testId = target.testId;
    if (testId == null || testId.isEmpty) {
      throw const TestExecutionError(
        code: TestExecutionErrorCode.elementNotFound,
        message: 'ElementTarget requires testId or elementId+observationId.',
      );
    }

    final finder = assertions.finderForId(testId);
    final matches = finder.evaluate().toList();
    if (matches.isEmpty) {
      throw TestExecutionError(
        code: TestExecutionErrorCode.elementNotFound,
        message: 'Widget "$testId" not found.',
        details: {'testId': testId},
      );
    }
    final occurrence = target.occurrence ?? 0;
    if (target.occurrence == null && matches.length > 1) {
      throw TestExecutionError(
        code: TestExecutionErrorCode.ambiguousTarget,
        message:
            'Multiple widgets match testId "$testId" (${matches.length}). '
            'Provide occurrence or use a snapshot elementId.',
        details: {'testId': testId, 'count': matches.length},
      );
    }
    if (occurrence < 0 || occurrence >= matches.length) {
      throw TestExecutionError(
        code: TestExecutionErrorCode.elementNotFound,
        message:
            'occurrence $occurrence out of range for testId "$testId" '
            '(${matches.length} matches).',
        details: {'testId': testId, 'occurrence': occurrence},
      );
    }
    if (matches.length == 1) return finder;
    return find.byWidget(matches[occurrence].widget);
  }

  /// TestId for YAML/[TestStepExecutor.execute] dispatch only.
  ///
  /// Throws if [target] is a snapshot elementId (must use [resolveFinder]).
  String requireTestId(ElementTarget target) {
    if (target.usesSnapshotElement) {
      throw const TestExecutionError(
        code: TestExecutionErrorCode.unsupportedAction,
        message:
            'Snapshot elementId targets must use exact Element identity; '
            'they cannot be remapped to testId.',
      );
    }
    final testId = target.testId;
    if (testId == null || testId.isEmpty) {
      throw const TestExecutionError(
        code: TestExecutionErrorCode.elementNotFound,
        message: 'ElementTarget requires testId or elementId+observationId.',
      );
    }
    resolveFinder(target);
    return testId;
  }
}

/// Maps [TestAction] onto [TestStepExecutor] — the single Flutter execution path.
///
/// Snapshot targets use finder-based executor APIs (exact Element).
/// testId targets use [TestStepExecutor.execute] vocabulary dispatch.
class LocalActionExecutor {
  LocalActionExecutor({
    required this.executor,
    required this.resolver,
  });

  final TestStepExecutor executor;
  final FlutterTargetResolver resolver;

  Future<void> execute(TestAction action) async {
    switch (action) {
      case TapAction(:final target):
        await _withTarget(
          target,
          onSnapshot: executor.tapFinder,
          onTestId: (id) => _step('tap', {'id': id}),
        );
      case DoubleTapAction(:final target):
        await _withTarget(
          target,
          onSnapshot: executor.doubleTapFinder,
          onTestId: (id) => _step('doubleTap', {'id': id}),
        );
      case LongPressAction(:final target):
        await _withTarget(
          target,
          onSnapshot: executor.longPressFinder,
          onTestId: (id) => _step('longPress', {'id': id}),
        );
      case EnterTextAction(:final target, :final value):
        await _withTarget(
          target,
          onSnapshot: (finder) =>
              executor.enterTextOnFinder(finder, value),
          onTestId: (id) => _step('enterText', {'id': id, 'value': value}),
        );
      case ReplaceTextAction(:final target, :final value):
        await _withTarget(
          target,
          onSnapshot: (finder) => executor.enterTextOnFinder(
            finder,
            value,
            replace: true,
          ),
          onTestId: (id) => _step('replaceText', {'id': id, 'value': value}),
        );
      case ClearTextAction(:final target):
        await _withTarget(
          target,
          onSnapshot: (finder) =>
              executor.enterTextOnFinder(finder, '', replace: true),
          onTestId: (id) => _step('clearText', {'id': id}),
        );
      case SubmitTextAction(:final target):
        await _withTarget(
          target,
          onSnapshot: executor.submitTextOnFinder,
          onTestId: (id) => _step('submitText', {'id': id}),
        );
      case FocusAction(:final target):
        await _withTarget(
          target,
          onSnapshot: executor.focusFinder,
          onTestId: (id) => _step('focus', {'id': id}),
        );
      case UnfocusAction():
        await _step('unfocus', const {});
      case ToggleAction(:final target):
        await _withTarget(
          target,
          onSnapshot: executor.toggleFinder,
          onTestId: (id) => _step('toggle', {'id': id}),
        );
      case CheckAction(:final target):
        await _withTarget(
          target,
          onSnapshot: executor.tapFinder,
          onTestId: (id) => _step('check', {'id': id}),
        );
      case UncheckAction(:final target):
        await _withTarget(
          target,
          onSnapshot: executor.toggleFinder,
          onTestId: (id) => _step('uncheck', {'id': id}),
        );
      case SelectAction(:final target, :final value):
        await _withTarget(
          target,
          onSnapshot: (finder) => executor.selectOnFinder(finder, value),
          onTestId: (id) => _step('select', {'id': id, 'value': value}),
        );
      case SelectIndexAction(:final target, :final index):
        await _testIdOnly(
          target,
          'selectIndex',
          (id) => _step('selectIndex', {'id': id, 'index': index}),
        );
      case SetSliderAction(:final target, :final value):
        await _testIdOnly(
          target,
          'setSlider',
          (id) => _step('setSlider', {'id': id, 'value': value}),
        );
      case ScrollUntilVisibleAction(:final target, :final scrollableId):
        await _withTarget(
          target,
          onSnapshot: executor.scrollUntilVisibleFinder,
          onTestId: (id) => _step('scrollUntilVisible', {
                'id': id,
                if (scrollableId != null) 'scrollableId': scrollableId,
              }),
        );
      case ScrollAction(:final target, :final direction, :final distance):
        if (target != null && target.usesSnapshotElement) {
          throw const TestExecutionError(
            code: TestExecutionErrorCode.unsupportedAction,
            message:
                'scroll with snapshot elementId is not supported; use testId.',
          );
        }
        await _step('scroll', {
          if (target != null) 'id': resolver.requireTestId(target),
          'direction': direction.name,
          if (distance != null) 'distance': distance,
        });
      case SwipeAction(:final direction, :final target):
        if (target != null && target.usesSnapshotElement) {
          throw const TestExecutionError(
            code: TestExecutionErrorCode.unsupportedAction,
            message:
                'swipe with snapshot elementId is not supported; use testId.',
          );
        }
        await _step('swipe', {
          'direction': direction.name,
          if (target != null) 'id': resolver.requireTestId(target),
        });
      case DragAction(:final target, :final dx, :final dy):
        await _testIdOnly(
          target,
          'drag',
          (id) => _step('drag', {'id': id, 'dx': dx, 'dy': dy}),
        );
      case PullToRefreshAction(:final target):
        if (target != null && target.usesSnapshotElement) {
          throw const TestExecutionError(
            code: TestExecutionErrorCode.unsupportedAction,
            message:
                'pullToRefresh with snapshot elementId is not supported; '
                'use testId.',
          );
        }
        await _step('pullToRefresh', {
          if (target != null) 'id': resolver.requireTestId(target),
        });
      case ChooseDateAction(:final target, :final value):
        await _withTarget(
          target,
          onSnapshot: (finder) =>
              executor.enterTextOnFinder(finder, value),
          onTestId: (id) => _step('chooseDate', {'id': id, 'value': value}),
        );
      case ChooseTimeAction(:final target, :final value):
        await _withTarget(
          target,
          onSnapshot: (finder) =>
              executor.enterTextOnFinder(finder, value),
          onTestId: (id) => _step('chooseTime', {'id': id, 'value': value}),
        );
      case GenericAction(:final name, :final args):
        await _step(name, Map<String, dynamic>.from(args));
    }
  }

  Future<void> _withTarget(
    ElementTarget target, {
    required Future<void> Function(Finder finder) onSnapshot,
    required Future<void> Function(String id) onTestId,
  }) async {
    if (target.usesSnapshotElement) {
      await onSnapshot(resolver.resolveFinder(target));
      return;
    }
    await onTestId(resolver.requireTestId(target));
  }

  Future<void> _testIdOnly(
    ElementTarget target,
    String actionName,
    Future<void> Function(String id) onTestId,
  ) async {
    if (target.usesSnapshotElement) {
      throw TestExecutionError(
        code: TestExecutionErrorCode.unsupportedAction,
        message:
            '$actionName with snapshot elementId is not supported; use testId.',
      );
    }
    await onTestId(resolver.requireTestId(target));
  }

  Future<void> _step(String type, Map<String, dynamic> args) =>
      executor.execute(TestStep(type: type, args: args));
}
