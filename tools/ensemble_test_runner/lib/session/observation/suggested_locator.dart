import 'package:ensemble_test_runner/session/actions/test_action.dart';
import 'package:ensemble_test_runner/session/errors/test_execution_error.dart';
import 'package:ensemble_test_runner/session/local/local_action_executor.dart';
import 'package:ensemble_test_runner/session/local/observation_registry.dart';
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
  // to label/role (labels localize / churn). Verify uniqueness when possible;
  // still suggest the id if the keyed host is a sibling wrapper of [live].
  final id = _nonEmpty(element.testId);
  if (id != null) {
    final idLocator = ElementLocator(id: id);
    final idOutcome = _tryResolve(
      resolver: resolver,
      locator: idLocator,
      expected: live,
    );
    if (idOutcome.kind == _ResolveKind.ambiguous) {
      return (
        locator: null,
        warning: 'Ambiguous locator (${idOutcome.matchCount} matches)',
      );
    }
    return (locator: idLocator, warning: null);
  }

  final candidates = <ElementLocator>[
    if (_nonEmpty(element.label) != null &&
        _isSupportedLocatorRole(element.role))
      ElementLocator(label: element.label!.trim(), role: element.role!.trim()),
    if (_nonEmpty(element.text) != null &&
        _isSupportedLocatorRole(element.role))
      ElementLocator(text: element.text!.trim(), role: element.role!.trim()),
    if (_nonEmpty(element.label) != null)
      ElementLocator(label: element.label!.trim()),
    if (_nonEmpty(element.text) != null)
      ElementLocator(text: element.text!.trim()),
  ];

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

/// Roles accepted by [ElementLocator] schema / YAML `target.role`.
bool _isSupportedLocatorRole(String? role) {
  final trimmed = role?.trim();
  if (trimmed == null || trimmed.isEmpty) return false;
  return const {
    'button',
    'text',
    'textField',
    'checkbox',
    'switch',
    'slider',
    'dropdown',
    'icon',
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
  return _isDescendantOf(a, b) || _isDescendantOf(b, a);
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
