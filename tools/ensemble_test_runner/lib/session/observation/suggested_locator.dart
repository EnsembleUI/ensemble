import 'package:ensemble_test_runner/session/actions/test_action.dart';
import 'package:ensemble_test_runner/session/errors/test_execution_error.dart';
import 'package:ensemble_test_runner/session/local/local_action_executor.dart';
import 'package:ensemble_test_runner/session/local/observation_registry.dart';
import 'package:ensemble_test_runner/session/local/widget_locator_id.dart';
import 'package:ensemble_test_runner/session/observation/ui_element.dart';
import 'package:ensemble_test_runner/session/observation/ui_observation.dart';
import 'package:flutter/widgets.dart';

export 'package:ensemble_test_runner/session/observation/suggested_locator_format.dart';

/// Attaches verified [UiElement.suggestedLocator] values using the live resolver.
///
/// Only unique matches that resolve to the observed element (by identity) are
/// kept — never prints an ambiguous selector.
UiObservation enrichSuggestedLocators({
  required UiObservation observation,
  required FlutterTargetResolver resolver,
  required ObservationRegistry registry,
}) {
  final enriched = [
    for (final root in observation.elements)
      _enrichTree(
        element: root,
        observationId: observation.observationId,
        resolver: resolver,
        registry: registry,
      ),
  ];
  return UiObservation(
    schemaVersion: observation.schemaVersion,
    observationId: observation.observationId,
    revision: observation.revision,
    timestamp: observation.timestamp,
    screen: observation.screen,
    elements: enriched,
    viewport: observation.viewport,
    observableFingerprint: observation.observableFingerprint,
    completeness: observation.completeness,
    screenshotArtifactId: observation.screenshotArtifactId,
  );
}

UiElement _enrichTree({
  required UiElement element,
  required String observationId,
  required FlutterTargetResolver resolver,
  required ObservationRegistry registry,
}) {
  final children = [
    for (final child in element.children)
      _enrichTree(
        element: child,
        observationId: observationId,
        resolver: resolver,
        registry: registry,
      ),
  ];
  final result = _suggestForElement(
    element: element,
    observationId: observationId,
    resolver: resolver,
    registry: registry,
  );
  return element.copyWith(
    children: children,
    suggestedLocator: result.locator,
    clearSuggestedLocator: true,
    locatorWarning: result.warning,
    clearLocatorWarning: true,
  );
}

({ElementLocator? locator, String? warning}) _suggestForElement({
  required UiElement element,
  required String observationId,
  required FlutterTargetResolver resolver,
  required ObservationRegistry registry,
}) {
  Element? live;
  try {
    live = registry
        .resolve(
          observationId: observationId,
          elementId: element.elementId,
        )
        .element;
  } on TestExecutionError {
    return (locator: null, warning: 'No stable locator available');
  }

  // Authoring priority: id → label+role → text (+role) → unavailable.
  // Prefer a stable id whenever the observation surfaces one — do not demote
  // to label/role (labels localize / churn). Only keep the id when it resolves
  // uniquely to this element (or its exclusive keyed host).
  final id = _nonEmpty(element.testId);
  if (id != null) {
    final idLocator = ElementLocator(id: id);
    final idOutcome = _tryResolve(
      resolver: resolver,
      locator: idLocator,
      expected: live,
    );
    switch (idOutcome.kind) {
      case _ResolveKind.uniqueMatch:
        return (locator: idLocator, warning: null);
      case _ResolveKind.ambiguous:
        return (
          locator: null,
          warning: 'Ambiguous locator (${idOutcome.matchCount} matches)',
        );
      case _ResolveKind.noMatch:
      case _ResolveKind.wrongElement:
        // Fall through to label/text — do not stamp a page-shell id onto
        // unrelated descendants.
        break;
    }
  }

  final candidates = _locatorCandidates(element);

  var bestAmbiguousCount = 0;
  for (final candidate in candidates) {
    final outcome = _tryResolve(
      resolver: resolver,
      locator: candidate,
      expected: live,
    );
    switch (outcome.kind) {
      case _ResolveKind.uniqueMatch:
        return (locator: candidate, warning: null);
      case _ResolveKind.ambiguous:
        if (outcome.matchCount > bestAmbiguousCount) {
          bestAmbiguousCount = outcome.matchCount;
        }
      case _ResolveKind.noMatch:
      case _ResolveKind.wrongElement:
        break;
    }
  }

  if (bestAmbiguousCount > 1) {
    return (
      locator: null,
      warning: 'Ambiguous locator ($bestAmbiguousCount matches)',
    );
  }
  return (locator: null, warning: 'No stable locator available');
}

/// Build locator candidates. Plain [text] nodes prefer exact `text=` — Flutter
/// often merges adjacent label+value into one semantics `label` shared by both.
List<ElementLocator> _locatorCandidates(UiElement element) {
  final label = _nonEmpty(element.label);
  final text = _nonEmpty(element.text);
  final role = _nonEmpty(element.role);
  final roleOk = _isSupportedLocatorRole(role);
  final isPlainText = (element.type ?? '').toLowerCase() == 'text';

  if (isPlainText) {
    return [
      if (text != null && roleOk) ElementLocator(text: text, role: role),
      if (text != null) ElementLocator(text: text),
      // Only fall back to label when this node has no visible text of its own.
      if (text == null && label != null && roleOk)
        ElementLocator(label: label, role: role),
      if (text == null && label != null) ElementLocator(label: label),
    ];
  }

  return [
    // Prefer label+role — matches YAML `target: { label, role: button }`.
    // When observe only has [text] (no semantics label), still try label=text.
    if (label != null && roleOk) ElementLocator(label: label, role: role),
    if (label == null && text != null && roleOk)
      ElementLocator(label: text, role: role),
    if (text != null && roleOk) ElementLocator(text: text, role: role),
    if (label != null) ElementLocator(label: label),
    if (text != null) ElementLocator(text: text),
  ];
}

/// Roles accepted by [ElementLocator] schema / YAML `target.role`.
bool _isSupportedLocatorRole(String? role) {
  final trimmed = role?.trim();
  if (trimmed == null || trimmed.isEmpty) return false;
  return const {
    'button',
    'card',
    'text',
    'textField',
    'checkbox',
    'switch',
    'slider',
    'dropdown',
    'icon',
    'image',
    'svg',
    'gif',
    'lottie',
    'widget',
  }.contains(trimmed);
}

enum _ResolveKind { uniqueMatch, noMatch, wrongElement, ambiguous }

({_ResolveKind kind, int matchCount}) _tryResolve({
  required FlutterTargetResolver resolver,
  required ElementLocator locator,
  required Element expected,
}) {
  try {
    final matches = resolver.resolveMatches(
      ElementTarget(locator: locator),
      requireInteractive: false,
      allowEmpty: true,
    );
    if (matches.isEmpty) {
      return (kind: _ResolveKind.noMatch, matchCount: 0);
    }
    if (matches.length == 1) {
      return identical(matches.single, expected) ||
              _isSameLogicalTarget(matches.single, expected)
          ? (kind: _ResolveKind.uniqueMatch, matchCount: 1)
          : (kind: _ResolveKind.wrongElement, matchCount: 1);
    }
    return (kind: _ResolveKind.ambiguous, matchCount: matches.length);
  } on TestExecutionError catch (error) {
    if (error.code == TestExecutionErrorCode.ambiguousTarget) {
      final count = error.details['count'];
      return (
        kind: _ResolveKind.ambiguous,
        matchCount: count is int ? count : 2,
      );
    }
    return (kind: _ResolveKind.noMatch, matchCount: 0);
  }
}

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

bool _isSameLogicalTarget(Element a, Element b) {
  if (identical(a, b)) return true;
  // KeyedSubtree host ↔ wrapped control only when the host does not also
  // contain other keyed widgets / sibling texts (merged semantics parents
  // must not unique-match every child).
  if (_isDescendantOf(a, b)) {
    return !_wrapperHasForeignObservable(b, a);
  }
  if (_isDescendantOf(b, a)) {
    return !_wrapperHasForeignObservable(a, b);
  }
  return false;
}

bool _wrapperHasForeignObservable(Element wrapper, Element self) {
  var foreign = false;
  void walk(Element node) {
    if (foreign) return;
    node.visitChildren((child) {
      if (foreign) return;
      if (identical(child, self) || _isDescendantOf(self, child)) {
        if (!identical(child, self)) walk(child);
        return;
      }
      if (readOwnedWidgetLocatorId(child) != null) {
        foreign = true;
        return;
      }
      final w = child.widget;
      if (w is Text) {
        final data = w.data?.trim();
        if (data != null && data.isNotEmpty) {
          foreign = true;
          return;
        }
      } else if (w is RichText) {
        final data = w.text.toPlainText().trim();
        if (data.isNotEmpty &&
            child.findAncestorWidgetOfExactType<Text>() == null) {
          foreign = true;
          return;
        }
      }
      walk(child);
    });
  }

  walk(wrapper);
  return foreign;
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
