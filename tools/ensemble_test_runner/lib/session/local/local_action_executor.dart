import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/session/actions/test_action.dart';
import 'package:ensemble_test_runner/session/errors/test_execution_error.dart';
import 'package:ensemble_test_runner/session/local/observation_registry.dart';
import 'package:ensemble_test_runner/session/local/element_semantics.dart';
import 'package:ensemble_test_runner/session/local/observable_fingerprint.dart';
import 'package:flutter/widgets.dart' show Element, Offset, ValueKey;
import 'package:flutter_test/flutter_test.dart';

/// Resolves [ElementTarget] for local execution.
///
/// Snapshot [elementId] targets always bind to the exact cached [Element]
/// (`identical`); they never fall back to testId / first-match.
///
/// Targets with [ElementTarget.occurrence] always resolve to a [Finder] so the
/// selected match is preserved through execution.
class FlutterTargetResolver {
  FlutterTargetResolver({
    required this.tester,
    required this.assertions,
    required this.registry,
    this.liveFingerprint,
  });

  final WidgetTester tester;
  final AssertionEngine assertions;
  final ObservationRegistry registry;

  /// When set, snapshot targets are revalidated against live observable state.
  final String Function(Element element, String? testId)? liveFingerprint;

  ResolvedTarget resolve(ElementTarget target,
      {bool requireInteractive = true}) {
    final finder =
        resolveFinder(target, requireInteractive: requireInteractive);
    final elements = finder.evaluate().toList();
    final element = elements.isEmpty ? null : elements.first;
    final testId = target.testId ?? target.normalizedLocator?.id;
    String? fingerprint;
    var visible = false;
    var interactable = false;
    if (element != null) {
      final described = describeElement(
        element: element,
        elementId: target.elementId ?? 'resolved',
        testId: testId,
        assertions: assertions,
        tester: tester,
        includeBounds: true,
      );
      fingerprint = fingerprintForElement(described);
      visible = described.state.visible == true;
      interactable = described.state.interactable == true;
    }
    return ResolvedTarget(
      finder: finder,
      description: target.usesSnapshotElement
          ? 'snapshot ${target.elementId}'
          : _describeLocator(target.normalizedLocator),
      observationId: target.observationId,
      elementId: target.elementId,
      testId: testId,
      fingerprint: fingerprint,
      visible: visible,
      interactable: interactable,
    );
  }

  /// Returns a [Finder] for the target. Snapshot targets never fall back to testId.
  ///
  /// When [requireInteractive] is true (default for actions), offstage and
  /// non-rendered matches are excluded. Existence checks pass false.
  Finder resolveFinder(
    ElementTarget target, {
    bool requireInteractive = true,
  }) {
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
        liveFingerprint: liveFingerprint,
      );
      return find.byElementPredicate((e) => identical(e, handle.element));
    }

    final locator = target.normalizedLocator;
    if (locator == null || locator.isEmpty) {
      throw const TestExecutionError(
        code: TestExecutionErrorCode.elementNotFound,
        message: 'ElementTarget requires a locator or elementId+observationId.',
      );
    }
    final finder = _finderForLocator(locator);
    var matches = finder.evaluate().toList();
    if (locator.label != null || locator.role != null) {
      matches = _deduplicateSemanticMatches(matches);
    }
    if (requireInteractive) {
      matches = matches
          .where((element) => assertions.isElementVisuallyActionable(element))
          .toList();
    }
    if (matches.isEmpty) {
      throw TestExecutionError(
        code: TestExecutionErrorCode.elementNotFound,
        message: '${_describeLocator(locator)} not found.',
        details: {'locator': locator.toJson()},
      );
    }
    final occurrence = locator.occurrence ?? 0;
    if (locator.occurrence == null && matches.length > 1) {
      throw TestExecutionError(
        code: TestExecutionErrorCode.ambiguousTarget,
        message: 'Multiple widgets match ${_describeLocator(locator)} '
            '(${matches.length}). '
            'Provide occurrence or use a snapshot elementId.',
        details: {'locator': locator.toJson(), 'count': matches.length},
      );
    }
    if (occurrence < 0 || occurrence >= matches.length) {
      throw TestExecutionError(
        code: TestExecutionErrorCode.elementNotFound,
        message: 'occurrence $occurrence out of range for '
            '${_describeLocator(locator)} '
            '(${matches.length} matches).',
        details: {'locator': locator.toJson(), 'occurrence': occurrence},
      );
    }
    if (matches.length == 1) return find.byWidget(matches.single.widget);
    return find.byWidget(matches[occurrence].widget);
  }

  List<Element> _deduplicateSemanticMatches(List<Element> matches) {
    final byNode = <Object, Element>{};
    for (final element in matches) {
      Object identity = element;
      try {
        identity = tester
            .getSemantics(
              find.byElementPredicate(
                  (candidate) => identical(candidate, element)),
            )
            .id;
      } catch (_) {}
      byNode.putIfAbsent(identity, () => element);
    }
    return byNode.values.toList(growable: false);
  }

  Finder _finderForLocator(ElementLocator locator) {
    final within = locator.within;
    Element? ancestor;
    if (within != null) {
      final scopeMatches = _finderForLocator(within).evaluate().toList();
      if (scopeMatches.length != 1) {
        throw TestExecutionError(
          code: scopeMatches.isEmpty
              ? TestExecutionErrorCode.elementNotFound
              : TestExecutionErrorCode.ambiguousTarget,
          message: scopeMatches.isEmpty
              ? 'Locator scope ${_describeLocator(within)} not found.'
              : 'Locator scope ${_describeLocator(within)} is ambiguous.',
          details: {'locator': within.toJson(), 'count': scopeMatches.length},
        );
      }
      ancestor = scopeMatches.single;
    }
    final scopedAncestor = ancestor;
    return find.byElementPredicate(
      (element) {
        if (scopedAncestor != null &&
            !_isDescendantOf(element, scopedAncestor)) {
          return false;
        }
        final id = locator.id;
        if (id != null) {
          final key = element.widget.key;
          if (key is! ValueKey || key.value != id) return false;
        }
        final text = locator.text;
        if (text != null &&
            (!isTextLocatorCandidate(element) || readText(element) != text)) {
          return false;
        }
        final label = locator.label;
        if (label != null &&
            (!isSemanticLocatorCandidate(element) ||
                readSemanticsLabel(tester, element) != label)) {
          return false;
        }
        final type = inferWidgetType(element);
        final role = locator.role;
        if (role != null &&
            (!isSemanticLocatorCandidate(element) ||
                inferSemanticRole(element, type) != role)) {
          return false;
        }
        return true;
      },
      skipOffstage: false,
    );
  }

  bool _isDescendantOf(Element element, Element ancestor) {
    var found = false;
    element.visitAncestorElements((candidate) {
      if (identical(candidate, ancestor)) {
        found = true;
        return false;
      }
      return true;
    });
    return found;
  }

  String _describeLocator(ElementLocator? locator) {
    if (locator == null) return 'element';
    final fields = <String>[
      if (locator.id != null) 'id="${locator.id}"',
      if (locator.text != null) 'text="${locator.text}"',
      if (locator.label != null) 'label="${locator.label}"',
      if (locator.role != null) 'role="${locator.role}"',
    ];
    return 'element(${fields.join(', ')})';
  }

  /// TestId for YAML/[TestStepExecutor.execute] dispatch only.
  ///
  /// Does not pre-resolve the widget — [TestStepExecutor] waits/polls with
  /// the step's timeoutMs. Snapshot / occurrence targets must use
  /// [resolveFinder] instead so identity is preserved.
  String requireTestId(ElementTarget target) {
    if (target.usesSnapshotElement) {
      throw const TestExecutionError(
        code: TestExecutionErrorCode.unsupportedAction,
        message: 'Snapshot elementId targets must use exact Element identity; '
            'they cannot be remapped to testId.',
      );
    }
    if (target.occurrence != null) {
      throw const TestExecutionError(
        code: TestExecutionErrorCode.unsupportedAction,
        message: 'occurrence targeting must use the resolved Finder path; '
            'it cannot be remapped to a bare testId.',
      );
    }
    final locator = target.normalizedLocator;
    final testId = target.testId ?? locator?.id;
    if (testId == null || testId.isEmpty) {
      throw const TestExecutionError(
        code: TestExecutionErrorCode.unsupportedAction,
        message: 'This operation requires an id locator.',
      );
    }
    return testId;
  }
}

class ResolvedTarget {
  final Finder finder;
  final String description;
  final String? observationId;
  final String? elementId;
  final String? testId;
  final String? fingerprint;
  final bool visible;
  final bool interactable;

  const ResolvedTarget({
    required this.finder,
    required this.description,
    this.observationId,
    this.elementId,
    this.testId,
    this.fingerprint,
    this.visible = false,
    this.interactable = false,
  });
}

/// Maps [TestAction] onto [TestStepExecutor] — the single Flutter execution path.
///
/// Snapshot / occurrence targets use finder-based executor APIs (exact Element).
/// Plain testId targets use [TestStepExecutor.execute] vocabulary dispatch.
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
          onSnapshot: (finder) => executor.enterTextOnFinder(finder, value),
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
          onSnapshot: executor.checkFinder,
          onTestId: (id) => _step('check', {'id': id}),
        );
      case UncheckAction(:final target):
        await _withTarget(
          target,
          onSnapshot: executor.uncheckFinder,
          onTestId: (id) => _step('uncheck', {'id': id}),
        );
      case SelectAction(:final target, :final value):
        await _withTarget(
          target,
          onSnapshot: (finder) => executor.selectOnFinder(finder, value),
          onTestId: (id) => _step('select', {'id': id, 'value': value}),
        );
      case SelectIndexAction(:final target, :final index):
        await _withTarget(
          target,
          onSnapshot: (finder) => executor.selectIndexOnFinder(finder, index),
          onTestId: (id) => _step('selectIndex', {'id': id, 'index': index}),
        );
      case SetSliderAction(:final target, :final value):
        await _withTarget(
          target,
          onSnapshot: (finder) => executor.setSliderOnFinder(finder, value),
          onTestId: (id) => _step('setSlider', {'id': id, 'value': value}),
        );
      case ScrollUntilVisibleAction(:final target, :final scrollableId):
        // Do not pre-resolve — the target may be off-list until scrolled.
        final testId = target.testId ?? target.normalizedLocator?.id;
        if (target.usesSnapshotElement ||
            (target.locator != null && testId == null)) {
          await executor.scrollUntilVisibleFinder(
            resolver.resolveFinder(target, requireInteractive: false),
          );
        } else if (testId != null && testId.isNotEmpty) {
          await _step('scrollUntilVisible', {
            'id': testId,
            if (scrollableId != null) 'scrollableId': scrollableId,
          });
        } else {
          throw const TestExecutionError(
            code: TestExecutionErrorCode.unsupportedAction,
            message: 'scrollUntilVisible requires an id or snapshot target.',
          );
        }
      case ScrollAction(:final target, :final direction, :final distance):
        if (target != null &&
            (target.usesSnapshotElement ||
                target.occurrence != null ||
                target.locator != null)) {
          await executor.dragFinder(
            resolver.resolveFinder(target),
            _offset(direction, distance ?? 300),
          );
        } else {
          await _step('scroll', {
            if (target != null) 'id': resolver.requireTestId(target),
            'direction': direction.name,
            if (distance != null) 'distance': distance,
          });
        }
      case SwipeAction(:final direction, :final target):
        if (target != null &&
            (target.usesSnapshotElement ||
                target.occurrence != null ||
                target.locator != null)) {
          await executor.dragFinder(
            resolver.resolveFinder(target),
            _offset(direction, 300),
          );
        } else {
          await _step('swipe', {
            'direction': direction.name,
            if (target != null) 'id': resolver.requireTestId(target),
          });
        }
      case DragAction(:final target, :final dx, :final dy):
        await _withTarget(
          target,
          onSnapshot: (finder) => executor.dragFinder(finder, Offset(dx, dy)),
          onTestId: (id) => _step('drag', {'id': id, 'dx': dx, 'dy': dy}),
        );
      case PullToRefreshAction(:final target):
        if (target != null &&
            (target.usesSnapshotElement ||
                target.occurrence != null ||
                target.locator != null)) {
          await executor.pullToRefreshFinder(resolver.resolveFinder(target));
        } else {
          await _step('pullToRefresh', {
            if (target != null) 'id': resolver.requireTestId(target),
          });
        }
      case ChooseDateAction(:final target, :final value):
        // Matches ExtendedStepHandlers chooseDate (enterTextOn).
        await _withTarget(
          target,
          onSnapshot: (finder) => executor.enterTextOnFinder(finder, value),
          onTestId: (id) => _step('chooseDate', {'id': id, 'value': value}),
        );
      case ChooseTimeAction(:final target, :final value):
        // Matches ExtendedStepHandlers chooseTime (enterTextOn).
        await _withTarget(
          target,
          onSnapshot: (finder) => executor.enterTextOnFinder(finder, value),
          onTestId: (id) => _step('chooseTime', {'id': id, 'value': value}),
        );
      case GenericAction(:final name, :final args):
        await _step(name, Map<String, dynamic>.from(args));
    }
  }

  /// Snapshot elementId and occurrence targets keep the resolved Finder.
  Future<void> _withTarget(
    ElementTarget target, {
    required Future<void> Function(Finder finder) onSnapshot,
    required Future<void> Function(String id) onTestId,
  }) async {
    if (target.usesSnapshotElement ||
        target.occurrence != null ||
        target.locator != null) {
      await onSnapshot(resolver.resolveFinder(target));
      return;
    }
    await onTestId(resolver.requireTestId(target));
  }

  Future<void> _step(String type, Map<String, dynamic> args) =>
      executor.execute(TestStep(type: type, args: args));

  Offset _offset(SwipeDirection direction, double distance) {
    switch (direction) {
      case SwipeDirection.up:
        return Offset(0, -distance);
      case SwipeDirection.down:
        return Offset(0, distance);
      case SwipeDirection.left:
        return Offset(-distance, 0);
      case SwipeDirection.right:
        return Offset(distance, 0);
    }
  }
}
