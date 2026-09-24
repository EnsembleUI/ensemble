import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/session/actions/test_action.dart';
import 'package:ensemble_test_runner/session/errors/test_execution_error.dart';
import 'package:ensemble_test_runner/session/local/observation_registry.dart';
import 'package:ensemble_test_runner/session/local/element_semantics.dart';
import 'package:ensemble_test_runner/session/local/observable_fingerprint.dart';
import 'package:ensemble_test_runner/session/local/widget_locator_id.dart';
import 'package:flutter/widgets.dart' show Element, Offset, Text;
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
  ///
  /// When [allowEmpty] is true, zero matches return a finder that evaluates
  /// empty instead of throwing [TestExecutionErrorCode.elementNotFound]. Used
  /// by negative assertions (`expectNotVisible` / `expectNotExists`).
  Finder resolveFinder(
    ElementTarget target, {
    bool requireInteractive = true,
    bool allowEmpty = false,
  }) {
    final matches = resolveMatches(
      target,
      requireInteractive: requireInteractive,
      allowEmpty: allowEmpty,
    );
    if (matches.isEmpty) {
      return find.byElementPredicate((_) => false);
    }
    final selected = matches.length == 1
        ? matches.single
        : matches[target.normalizedLocator?.occurrence ?? 0];
    return find.byElementPredicate(
      (candidate) => identical(candidate, selected),
    );
  }

  /// Candidate elements for [target], after semantic/text collapse and
  /// optional interactive filtering. Throws on ambiguity for positive
  /// resolution; returns `[]` when [allowEmpty] and nothing matches.
  List<Element> resolveMatches(
    ElementTarget target, {
    bool requireInteractive = true,
    bool allowEmpty = false,
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
      return [handle.element];
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
    matches = _collapseOverlappingMatches(matches, locator);
    if (requireInteractive) {
      matches = matches
          .where((element) => assertions.isElementVisuallyActionable(element))
          .toList();
    }
    if (matches.isEmpty) {
      if (allowEmpty) return const [];
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
      if (allowEmpty) return const [];
      throw TestExecutionError(
        code: TestExecutionErrorCode.elementNotFound,
        message: 'occurrence $occurrence out of range for '
            '${_describeLocator(locator)} '
            '(${matches.length} matches).',
        details: {'locator': locator.toJson(), 'occurrence': occurrence},
      );
    }
    if (matches.length == 1) return matches;
    return [matches[occurrence]];
  }

  /// Collapses ancestor/descendant and same-semantics-node duplicates so a
  /// single button containing [Text] is one logical target.
  List<Element> _collapseOverlappingMatches(
    List<Element> matches,
    ElementLocator locator,
  ) {
    if (matches.length <= 1) return matches;

    var collapsed = List<Element>.from(matches);
    // Text locators: promote nested Text → actionable ancestor first, then
    // drop descendants. Do not semantics-node-dedup — Material may report
    // unstable/shared nodes and erase distinct sibling buttons.
    if (locator.text != null) {
      collapsed = _preferActionableAncestorsForText(collapsed);
      collapsed = _dropDescendantsOfOtherMatches(collapsed);
      return collapsed;
    }
    if (locator.label != null || locator.role != null) {
      collapsed = _deduplicateSemanticMatches(collapsed);
    }
    collapsed = _dropDescendantsOfOtherMatches(collapsed);
    return collapsed;
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

  /// For text locators, keep the nearest actionable ancestor when both the
  /// [Text] and its button/gesture parent matched.
  ///
  /// Bare [Semantics] wrappers are not preferred — a high tree Semantics can
  /// wrap multiple buttons and would incorrectly collapse distinct targets.
  List<Element> _preferActionableAncestorsForText(List<Element> matches) {
    if (matches.length <= 1) return matches;
    final preferred = <Element>[];
    for (final element in matches) {
      Element? actionableAncestor;
      element.visitAncestorElements((ancestor) {
        if (matches.any((m) => identical(m, ancestor)) &&
            isActionableControl(ancestor)) {
          actionableAncestor = ancestor;
          return false;
        }
        return true;
      });
      final chosen = actionableAncestor ??
          (isActionableControl(element) || element.widget is Text
              ? element
              : null);
      if (chosen == null) continue;
      if (!preferred.any((e) => identical(e, chosen))) {
        preferred.add(chosen);
      }
    }
    return preferred.isEmpty ? matches : preferred;
  }

  List<Element> _dropDescendantsOfOtherMatches(List<Element> matches) {
    if (matches.length <= 1) return matches;
    return matches.where((element) {
      for (final other in matches) {
        if (identical(other, element)) continue;
        if (_isDescendantOf(element, other)) return false;
      }
      return true;
    }).toList(growable: false);
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
    final id = locator.id;
    // Resolve id via testId-first finder once; avoid O(n²) Invokable subtree
    // walks inside the per-element predicate.
    final idMatches = id == null
        ? null
        : finderForLocatorId(id, skipOffstage: false).evaluate().toSet();
    return find.byElementPredicate(
      (element) {
        if (scopedAncestor != null &&
            !_isDescendantOf(element, scopedAncestor)) {
          return false;
        }
        if (idMatches != null && !idMatches.contains(element)) {
          return false;
        }
        final text = locator.text;
        if (text != null &&
            (!isTextLocatorCandidate(element) || readText(element) != text)) {
          return false;
        }
        final label = locator.label;
        if (label != null) {
          if (!isSemanticLocatorCandidate(element)) return false;
          final semantic = readSemanticsLabel(tester, element)?.trim();
          if (semantic != label) {
            // Ensemble tabs / InkWell CTAs / inert visual cards often lack a
            // Semantics label — the visible caption still authors as `label:`.
            if (readText(element) != label) return false;
            if (!isActionableControl(element) && !isCardScopeHost(element)) {
              return false;
            }
          }
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
      case TapAction(:final target, :final timeoutMs):
        await _withTarget(
          target,
          timeoutMs: timeoutMs,
          onSnapshot: executor.tapFinder,
          onTestId: (id) => _step('tap', {
            'id': id,
            if (timeoutMs != null) 'timeoutMs': timeoutMs,
          }),
        );
      case DoubleTapAction(:final target, :final timeoutMs):
        await _withTarget(
          target,
          timeoutMs: timeoutMs,
          onSnapshot: executor.doubleTapFinder,
          onTestId: (id) => _step('doubleTap', {
            'id': id,
            if (timeoutMs != null) 'timeoutMs': timeoutMs,
          }),
        );
      case LongPressAction(:final target, :final timeoutMs):
        await _withTarget(
          target,
          timeoutMs: timeoutMs,
          onSnapshot: executor.longPressFinder,
          onTestId: (id) => _step('longPress', {
            'id': id,
            if (timeoutMs != null) 'timeoutMs': timeoutMs,
          }),
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
  ///
  /// When [timeoutMs] is set for a structured locator, poll until the target
  /// appears (same wait semantics as plain `id:` taps).
  Future<void> _withTarget(
    ElementTarget target, {
    required Future<void> Function(Finder finder) onSnapshot,
    required Future<void> Function(String id) onTestId,
    int? timeoutMs,
  }) async {
    if (target.usesSnapshotElement ||
        target.occurrence != null ||
        target.locator != null) {
      if (timeoutMs != null && timeoutMs > 0 && !target.usesSnapshotElement) {
        await _waitForStructuredTarget(target, timeoutMs: timeoutMs);
      }
      await onSnapshot(resolver.resolveFinder(target));
      return;
    }
    await onTestId(resolver.requireTestId(target));
  }

  Future<void> _waitForStructuredTarget(
    ElementTarget target, {
    required int timeoutMs,
  }) async {
    final stopwatch = Stopwatch()..start();
    while (true) {
      final matches = resolver.resolveMatches(
        target,
        requireInteractive: true,
        allowEmpty: true,
      );
      if (matches.isNotEmpty) return;
      if (stopwatch.elapsedMilliseconds >= timeoutMs) {
        throw TestExecutionError(
          code: TestExecutionErrorCode.elementNotFound,
          message:
              'Timed out after ${timeoutMs}ms waiting for structured target.',
          details: {'locator': target.normalizedLocator?.toJson()},
        );
      }
      await executor.tester.pump(const Duration(milliseconds: 50));
    }
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
