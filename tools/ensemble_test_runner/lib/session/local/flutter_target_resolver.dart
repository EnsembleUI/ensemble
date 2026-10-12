import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/session/local/observation_registry.dart';
import 'package:ensemble_test_runner/session/operation_target.dart';
import 'package:ensemble_test_runner/session/errors/test_execution_error.dart';
import 'package:ensemble_test_runner/session/local/element_semantics.dart';
import 'package:ensemble_test_runner/session/local/element_visibility.dart';
import 'package:ensemble_test_runner/session/local/modal_route_lookup.dart';
import 'package:ensemble_test_runner/session/observation/ui_element.dart';
import 'package:ensemble_test_runner/session/local/observable_fingerprint.dart';
import 'package:ensemble_test_runner/session/local/widget_locator_id.dart';
import 'package:flutter/widgets.dart' show Element, Text;
import 'package:flutter/rendering.dart' show RenderBox;
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
    this.currentRevision = _zeroRevision,
  });

  final WidgetTester tester;
  final AssertionEngine assertions;
  final ObservationRegistry registry;

  /// The observable UI revision. Cached finders are valid only at this
  /// revision and are discarded as soon as the observer advances it.
  final int Function() currentRevision;

  static int _zeroRevision() => 0;
  final Map<String, Finder> _resolvedFinders = {};
  int? _cacheRevision;

  /// Discard handles at an operation boundary, even if the observer's
  /// lightweight fingerprint did not detect a UI change.
  void invalidateResolvedFinders() {
    _resolvedFinders.clear();
    _cacheRevision = currentRevision();
  }

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
  /// When [requireInteractive] is true (default for actions), offstage,
  /// non-rendered, and explicitly disabled matches are excluded. Existence
  /// checks pass false.
  ///
  /// When [allowEmpty] is true, zero matches return a finder that evaluates
  /// empty instead of throwing [TestExecutionErrorCode.elementNotFound]. Used
  /// by negative assertions (`expectNotVisible` / `expectNotExists`).
  Finder resolveFinder(
    ElementTarget target, {
    bool requireInteractive = true,
    bool allowEmpty = false,
    bool allowOffscreen = false,
  }) {
    return RunnerBenchmark.sync('locator', 'resolveFinder', () {
      // Snapshot handles must revalidate their observation on every use.
      // Locator-based finders can be reused while the observed tree revision
      // is unchanged.
      if (!target.usesSnapshotElement) {
        final revision = currentRevision();
        if (_cacheRevision != revision) {
          _resolvedFinders.clear();
          _cacheRevision = revision;
        }
        // Finder reuse is a hot path for repeated waits and assertions. The
        // previous key serialized the complete target map on every lookup,
        // even though the target is already a typed value. Keep the same
        // field coverage while avoiding map/list allocation and JSON work.
        final key = _finderCacheKey(
          target,
          requireInteractive: requireInteractive,
          allowEmpty: allowEmpty,
          allowOffscreen: allowOffscreen,
        );
        final cached = _resolvedFinders[key];
        if (cached != null) return cached;

        final finder = _resolveFinderUncached(
          target,
          requireInteractive: requireInteractive,
          allowEmpty: allowEmpty,
          allowOffscreen: allowOffscreen,
        );
        // A zero-match finder is a snapshot of today's tree. Keeping it in the
        // cache prevents a bounded target wait from observing a widget that
        // mounts on a later frame. Cache only live matches; a later lookup can
        // resolve the target again after the tree changes.
        if (finder.evaluate().isEmpty) return finder;
        // Bound retained Elements and Finder closures even on a static tree.
        if (_resolvedFinders.length >= 32) _resolvedFinders.clear();
        _resolvedFinders[key] = finder;
        return finder;
      }
      return _resolveFinderUncached(
        target,
        requireInteractive: requireInteractive,
        allowEmpty: allowEmpty,
        allowOffscreen: allowOffscreen,
      );
    });
  }

  Finder _resolveFinderUncached(
    ElementTarget target, {
    required bool requireInteractive,
    required bool allowEmpty,
    required bool allowOffscreen,
  }) {
    final matches = resolveMatches(
      target,
      requireInteractive: requireInteractive,
      allowEmpty: allowEmpty,
      allowOffscreen: allowOffscreen,
    );
    if (matches.isEmpty) {
      return find.byElementPredicate((_) => false);
    }
    final selected = matches.length == 1
        ? matches.single
        : matches[target.normalizedLocator?.occurrence ?? 0];
    return find.byElementPredicate(
      (candidate) => identical(candidate, selected),
      // Finder's default would hide offstage matches even when the caller
      // explicitly requested non-interactive resolution.
      skipOffstage: requireInteractive,
    );
  }

  /// Candidate elements for [target], after semantic/text collapse and
  /// optional interactive filtering. Throws on ambiguity for positive
  /// resolution; returns `[]` when [allowEmpty] and nothing matches.
  List<Element> resolveMatches(
    ElementTarget target, {
    bool requireInteractive = true,
    bool allowEmpty = false,
    bool allowOffscreen = false,
  }) {
    return RunnerBenchmark.sync('locator', 'resolveMatches', () {
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
        RunnerBenchmark.count('locatorCandidates', 1);
        RunnerBenchmark.count('locatorMatches', 1);
        return [handle.element];
      }

      final locator = target.normalizedLocator;
      if (locator == null || locator.isEmpty) {
        throw const TestExecutionError(
          code: TestExecutionErrorCode.elementNotFound,
          message:
              'ElementTarget requires a locator or elementId+observationId.',
        );
      }
      final finder = _finderForLocator(
        locator,
        allowEmpty: allowEmpty,
        rootLocator: locator,
      );
      var matches = finder.evaluate().toList();
      RunnerBenchmark.count('locatorCandidates', matches.length);
      // A `within`-only target describes the logical descendants of a scope,
      // not the first implementation widget in its subtree. Filter to
      // actionable descendants before collapsing ancestor/descendant pairs;
      // otherwise a Padding/Builder wrapper can hide its actual button.
      final scopedDescendantsOnly = locator.within != null &&
          locator.id == null &&
          locator.text == null &&
          locator.label == null &&
          locator.role == null &&
          locator.bounds == null;
      if (requireInteractive && scopedDescendantsOnly) {
        matches = matches
            .where((element) => _isActionable(element, allowOffscreen))
            .toList();
      }
      matches = _collapseOverlappingMatches(matches, locator);
      if (requireInteractive && !scopedDescendantsOnly) {
        matches = matches
            .where((element) => _isActionable(element, allowOffscreen))
            .toList();
      }
      RunnerBenchmark.count('locatorMatches', matches.length);
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
    });
  }

  bool _isActionable(Element element, bool allowOffscreen) {
    if (readEnabled(element) == false) return false;
    if (!allowOffscreen) return assertions.isElementVisuallyActionable(element);
    final renderObject = element.renderObject;
    return isUnderCurrentModalRoute(element) &&
        !isUnderOffstageAncestor(element) &&
        renderObject is RenderBox &&
        renderObject.hasSize &&
        !renderObject.size.isEmpty &&
        effectiveElementOpacity(element) > 0.01;
  }

  /// Collapses ancestor/descendant and same-semantics-node duplicates so a
  /// single button containing [Text] is one logical target.
  List<Element> _collapseOverlappingMatches(
    List<Element> matches,
    ElementLocator locator,
  ) {
    if (matches.length <= 1) return matches;

    var collapsed = List<Element>.from(matches);
    if (locator.bounds != null) {
      collapsed = _deduplicateRenderObjects(collapsed);
    } else if (locator.text != null) {
      // Text locators promote nested Text → actionable ancestor first. Do not
      // semantics-node-dedup — Material may report unstable/shared nodes and
      // erase distinct sibling buttons.
      collapsed = _preferActionableAncestorsForText(collapsed);
    } else if (locator.label != null || locator.role != null) {
      collapsed = _deduplicateSemanticMatches(collapsed);
    }
    collapsed = _dropDescendantsOfOtherMatches(collapsed);
    return collapsed;
  }

  List<Element> _deduplicateRenderObjects(List<Element> matches) {
    final seen = <Object>{};
    return matches.where((element) {
      final renderObject = element.renderObject;
      return renderObject == null || seen.add(renderObject);
    }).toList(growable: false);
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

  Finder _finderForLocator(
    ElementLocator locator, {
    bool allowEmpty = false,
    ElementLocator? rootLocator,
  }) {
    final within = locator.within;
    Element? ancestor;
    if (within != null) {
      // Resolve a scope with the same exactness rules as the target itself.
      // Previously this evaluated the raw finder and ignored
      // `within.occurrence`, which made an otherwise deterministic nested
      // locator fail as ambiguous whenever two scope containers existed.
      var scopeMatches = _finderForLocator(
        within,
        allowEmpty: allowEmpty,
        rootLocator: rootLocator ?? locator,
      ).evaluate().toList();
      scopeMatches = _collapseOverlappingMatches(scopeMatches, within);
      if (scopeMatches.isEmpty) {
        if (allowEmpty) return find.byElementPredicate((_) => false);
        throw TestExecutionError(
          code: TestExecutionErrorCode.elementNotFound,
          message: 'Locator scope ${_describeLocator(within)} not found.',
          details: {
            'locator': (rootLocator ?? locator).toJson(),
            'count': scopeMatches.length,
          },
        );
      }
      final scopeOccurrence = within.occurrence;
      if (scopeOccurrence == null && scopeMatches.length > 1) {
        throw TestExecutionError(
          code: TestExecutionErrorCode.ambiguousTarget,
          message: 'Locator scope ${_describeLocator(within)} is ambiguous '
              '(${scopeMatches.length} matches). Provide occurrence.',
          details: {
            'locator': (rootLocator ?? locator).toJson(),
            'count': scopeMatches.length,
          },
        );
      }
      final selectedOccurrence = scopeOccurrence ?? 0;
      if (selectedOccurrence < 0 || selectedOccurrence >= scopeMatches.length) {
        if (allowEmpty) return find.byElementPredicate((_) => false);
        throw TestExecutionError(
          code: TestExecutionErrorCode.elementNotFound,
          message: 'occurrence $selectedOccurrence is out of range for '
              'locator scope ${_describeLocator(within)} '
              '(${scopeMatches.length} matches).',
          details: {
            'locator': (rootLocator ?? locator).toJson(),
            'occurrence': selectedOccurrence,
            'count': scopeMatches.length,
          },
        );
      }
      ancestor = scopeMatches[selectedOccurrence];
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
        final expectedBounds = locator.bounds;
        if (expectedBounds != null) {
          final actualBounds = boundsFor(element);
          if (actualBounds == null ||
              !_boundsMatch(expectedBounds, actualBounds)) {
            return false;
          }
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
      if (locator.bounds != null) 'bounds=${locator.bounds!.toJson()}',
    ];
    return 'element(${fields.join(', ')})';
  }

  bool _boundsMatch(ElementBounds expected, UiBounds actual) {
    const tolerance = 1.0;
    return (expected.left - actual.left).abs() <= tolerance &&
        (expected.top - actual.top).abs() <= tolerance &&
        (expected.width - actual.width).abs() <= tolerance &&
        (expected.height - actual.height).abs() <= tolerance;
  }

  /// TestId for direct step-executor dispatch only.
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

String _finderCacheKey(
  ElementTarget target, {
  required bool requireInteractive,
  required bool allowEmpty,
  required bool allowOffscreen,
}) {
  final buffer = StringBuffer()
    ..write(requireInteractive ? 'i1;' : 'i0;')
    ..write(allowEmpty ? 'e1;' : 'e0;')
    ..write(allowOffscreen ? 'o1;' : 'o0;');
  _writeNullable(buffer, target.testId);
  _writeNullable(buffer, target.elementId);
  _writeNullable(buffer, target.observationId);
  _writeNullableInt(buffer, target.occurrence);
  _writeLocator(buffer, target.locator);
  return buffer.toString();
}

void _writeNullable(StringBuffer buffer, String? value) {
  if (value == null) {
    buffer.write('n;');
    return;
  }
  buffer
    ..write('s')
    ..write(value.length)
    ..write(':')
    ..write(value)
    ..write(';');
}

void _writeNullableInt(StringBuffer buffer, int? value) {
  if (value == null) {
    buffer.write('n;');
    return;
  }
  buffer
    ..write('i')
    ..write(value)
    ..write(';');
}

void _writeLocator(StringBuffer buffer, ElementLocator? locator) {
  if (locator == null) {
    buffer.write('l0;');
    return;
  }
  buffer.write('l1;');
  _writeNullable(buffer, locator.id);
  _writeNullable(buffer, locator.text);
  _writeNullable(buffer, locator.label);
  _writeNullable(buffer, locator.role);
  _writeLocator(buffer, locator.within);
  _writeNullableInt(buffer, locator.occurrence);
  final bounds = locator.bounds;
  if (bounds == null) {
    buffer.write('b0;');
  } else {
    buffer
      ..write('b1;')
      ..write(bounds.left)
      ..write(',')
      ..write(bounds.top)
      ..write(',')
      ..write(bounds.width)
      ..write(',')
      ..write(bounds.height)
      ..write(';');
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
