import 'package:ensemble_test_runner/session/actions/test_action.dart';
import 'package:ensemble_test_runner/session/errors/test_execution_error.dart';
import 'package:ensemble_test_runner/session/local/element_semantics.dart';
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
  ElementLocator? parentScope,
  int? iconOccurrenceAmongSiblings,
  int? iconSiblingCount,
}) {
  // Resolve this node before children so nested `within` can use our locator.
  final result = _suggestForElement(
    element: element,
    observationId: observationId,
    resolver: resolver,
    registry: registry,
    parentScope: parentScope,
    iconOccurrenceAmongSiblings: iconOccurrenceAmongSiblings,
    iconSiblingCount: iconSiblingCount,
  );
  // Inert cards still scope nested icons via caption+role (no card sel).
  final scopeForChildren =
      result.locator ?? containerScopeLocator(element) ?? parentScope;

  final iconKids = [
    for (final child in element.children)
      if ((child.type ?? '').toLowerCase() == 'icon') child,
  ];
  final children = <UiElement>[];
  var iconIndex = 0;
  for (final child in element.children) {
    final isIcon = (child.type ?? '').toLowerCase() == 'icon';
    children.add(
      _enrichTree(
        element: child,
        observationId: observationId,
        resolver: resolver,
        registry: registry,
        parentScope: scopeForChildren,
        iconOccurrenceAmongSiblings:
            isIcon && iconKids.length > 1 ? iconIndex : null,
        iconSiblingCount: isIcon ? iconKids.length : null,
      ),
    );
    if (isIcon) iconIndex++;
  }

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
  ElementLocator? parentScope,
  int? iconOccurrenceAmongSiblings,
  int? iconSiblingCount,
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

  final candidates = buildAgentLocatorCandidates(
    element,
    parentScope: parentScope,
    iconOccurrenceAmongSiblings: iconOccurrenceAmongSiblings,
    iconSiblingCount: iconSiblingCount,
  );

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
        // Prefer a meaningful selector with an explicit occurrence over
        // falling back to screen coordinates. Occurrence is resolved against
        // this selector's ordered match set, so it also works with bounds-free
        // actions and remains scoped when the candidate contains `within`.
        for (var occurrence = 0;
            occurrence < outcome.matchCount;
            occurrence++) {
          final occurrenceCandidate = _withOccurrence(candidate, occurrence);
          final occurrenceOutcome = _tryResolve(
            resolver: resolver,
            locator: occurrenceCandidate,
            expected: live,
          );
          if (occurrenceOutcome.kind == _ResolveKind.uniqueMatch) {
            return (locator: occurrenceCandidate, warning: null);
          }
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

/// Agent / report locator candidates in preference order.
///
/// Ranking: `id` → caption+role by type → `within` parent + local text/role.
/// Cheap/report paths take the first entry; live enrich verifies uniqueness.
///
/// Gesture-oriented types (card / button / icon / form / toast) only get
/// caption or `within` candidates when [UiElement.state.interactable] is true —
/// a non-tappable chrome card must not advertise `label=, role=card`.
/// Plain [text] keeps `text=` for wait/assert steps.
List<ElementLocator> buildAgentLocatorCandidates(
  UiElement element, {
  ElementLocator? parentScope,
  int? iconOccurrenceAmongSiblings,
  int? iconSiblingCount,
}) {
  final out = <ElementLocator>[];
  final id = _nonEmpty(element.testId);
  if (id != null) {
    out.add(ElementLocator(id: id));
  }

  final type = (element.type ?? '').toLowerCase();
  final label = _nonEmpty(element.label);
  final text = _nonEmpty(element.text);
  final caption = _firstLineCaption(label) ?? _firstLineCaption(text);
  final tappable = element.state.interactable == true;

  switch (type) {
    case 'text':
      // Skip list bullets / mask glyphs — never suggest text="•".
      if (text != null && !isDecorativeGlyphCaption(text)) {
        // A parent scope is more stable and meaningful than selecting the Nth
        // copy of the same text in the whole screen.
        if (parentScope != null && !_locatorIsEmpty(parentScope)) {
          out.add(ElementLocator(within: parentScope, text: text));
        }
        out.add(ElementLocator(text: text));
      }
    case 'button':
      if (tappable && caption != null) {
        // Prefer scoped selectors first so cheap/report snapshots do not emit
        // bare label+role when two ExtenderItem "Edit name" buttons share it.
        if (parentScope != null && !_locatorIsEmpty(parentScope)) {
          out.add(
            ElementLocator(
              within: parentScope,
              label: caption,
              role: 'button',
            ),
          );
        }
        final self = ElementLocator(label: caption, role: 'button');
        // Nested WifiCard show-password row inherits the parent row's merged
        // a11y label — do not emit a duplicate label+role=button selector.
        if (parentScope == null || !_locatorsEquivalent(self, parentScope)) {
          out.add(self);
        }
      } else if (tappable &&
          parentScope != null &&
          !_locatorIsEmpty(parentScope)) {
        out.add(ElementLocator(within: parentScope, role: 'button'));
      }
    case 'card':
      if (tappable && caption != null) {
        final self = ElementLocator(label: caption, role: 'card');
        if (parentScope == null || !_locatorsEquivalent(self, parentScope)) {
          out.add(self);
        }
      }
    case 'toast':
      // Toast hosts are rarely gesture targets; message Text owns text=.
      if (tappable && caption != null) {
        out.add(ElementLocator(label: caption, role: 'toast'));
      }
    case 'textinput':
    case 'textfield':
      if (tappable && caption != null) {
        out.add(ElementLocator(label: caption, role: 'textField'));
      }
    case 'checkbox':
    case 'switch':
    case 'toggle':
    case 'slider':
    case 'dropdown':
      final formRole = type == 'toggle' ? 'switch' : type;
      if (tappable && _isSupportedLocatorRole(formRole)) {
        if (caption != null) {
          out.add(ElementLocator(label: caption, role: formRole));
        } else if (parentScope != null && !_locatorIsEmpty(parentScope)) {
          out.add(ElementLocator(within: parentScope, role: formRole));
        }
      }
    case 'icon':
      // Standalone icon buttons with an a11y/tooltip caption.
      // When nested under a card/sheet scope, prefer within+role below —
      // IconData names ("close") are weak label= targets.
      if (tappable &&
          caption != null &&
          (parentScope == null || _locatorIsEmpty(parentScope))) {
        out.add(ElementLocator(label: caption, role: 'icon'));
      }
    default:
      break;
  }

  // Nested content under a scoped (usually tappable) parent.
  if (parentScope != null && !_locatorIsEmpty(parentScope)) {
    if (type == 'text' && text != null && !isDecorativeGlyphCaption(text)) {
      out.add(ElementLocator(within: parentScope, text: text));
    }
    if (type == 'icon' && tappable) {
      final occurrence = (iconSiblingCount != null &&
              iconSiblingCount > 1 &&
              iconOccurrenceAmongSiblings != null)
          ? iconOccurrenceAmongSiblings
          : null;
      out.add(
        ElementLocator(
          within: parentScope,
          role: 'icon',
          occurrence: occurrence,
        ),
      );
      // Secondary: real a11y caption still useful when unique.
      if (caption != null) {
        out.add(ElementLocator(label: caption, role: 'icon'));
      }
    }
  }

  // Last resort: tappable icon with no caption and no parent scope (e.g. sheet
  // dismiss X at the observe root) — role alone so Supported actions ≠ empty sel.
  if (type == 'icon' && tappable && caption == null && out.isEmpty) {
    out.add(ElementLocator(role: 'icon'));
  }

  return _dedupeLocators(out);
}

/// First preferred candidate for diagnostic / report snapshots (no finder).
ElementLocator? cheapSuggestedLocator(
  UiElement element, {
  ElementLocator? parentScope,
  int? iconOccurrenceAmongSiblings,
  int? iconSiblingCount,
  int? occurrenceAmongSiblings,
}) {
  final candidates = buildAgentLocatorCandidates(
    element,
    parentScope: parentScope,
    iconOccurrenceAmongSiblings: iconOccurrenceAmongSiblings,
    iconSiblingCount: iconSiblingCount,
  );
  if (candidates.isEmpty) return null;
  final candidate = candidates.first;
  return occurrenceAmongSiblings == null
      ? candidate
      : _withOccurrence(candidate, occurrenceAmongSiblings);
}

/// `within=` scope for descendants — includes non-tappable cards/toasts.
///
/// Gesture [cheapSuggestedLocator] stays null on inert cards (no `sel`), but
/// nested rating icons still need `within={label, role=card}, role=icon`.
ElementLocator? containerScopeLocator(UiElement element) {
  final id = _nonEmpty(element.testId);
  if (id != null) return ElementLocator(id: id);

  final type = (element.type ?? '').toLowerCase();
  final caption = _firstLineCaption(_nonEmpty(element.label)) ??
      _firstLineCaption(_nonEmpty(element.text));
  if (caption == null || !_isSupportedLocatorRole(type)) return null;

  switch (type) {
    case 'card':
    case 'toast':
    case 'button':
      return ElementLocator(label: caption, role: type);
    default:
      return null;
  }
}

String? _firstLineCaption(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed.split('\n').first.trim();
}

bool _locatorIsEmpty(ElementLocator locator) => locator.isEmpty;

bool _locatorsEquivalent(ElementLocator a, ElementLocator b) {
  return a.id == b.id &&
      a.label == b.label &&
      a.text == b.text &&
      a.role == b.role &&
      a.occurrence == b.occurrence &&
      _boundsEquivalent(a.bounds, b.bounds) &&
      ((a.within == null && b.within == null) ||
          (a.within != null &&
              b.within != null &&
              _locatorsEquivalent(a.within!, b.within!)));
}

ElementLocator _withOccurrence(ElementLocator locator, int occurrence) =>
    ElementLocator(
      id: locator.id,
      text: locator.text,
      label: locator.label,
      role: locator.role,
      within: locator.within,
      occurrence: occurrence,
      bounds: locator.bounds,
    );

bool _boundsEquivalent(ElementBounds? a, ElementBounds? b) =>
    (a == null && b == null) ||
    (a != null &&
        b != null &&
        a.left == b.left &&
        a.top == b.top &&
        a.width == b.width &&
        a.height == b.height);

List<ElementLocator> _dedupeLocators(List<ElementLocator> input) {
  final seen = <String>{};
  final out = <ElementLocator>[];
  for (final loc in input) {
    final key = loc.toJson().toString();
    if (seen.add(key)) out.add(loc);
  }
  return out;
}

/// Roles accepted by [ElementLocator] schema / YAML `target.role`.
bool _isSupportedLocatorRole(String? role) {
  final trimmed = role?.trim();
  if (trimmed == null || trimmed.isEmpty) return false;
  return const {
    'button',
    'card',
    'toast',
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
