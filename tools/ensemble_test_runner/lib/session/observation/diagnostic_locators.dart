import 'dart:convert';

import 'package:ensemble_test_runner/session/observation/suggested_locator.dart';
import 'package:ensemble_test_runner/session/observation/ui_element.dart';

/// Adds cheap locator hints to a complete diagnostic snapshot and removes
/// selectors that collide across separate branches of the observed tree.
///
/// Normal observations intentionally avoid this extra tree pass. Diagnostic
/// observations can pay for it to make a captured snapshot directly useful
/// when investigating a target-resolution problem.
List<UiElement> annotateDiagnosticLocators(List<UiElement> elements) {
  final withLocators = mapObservationLocatorTree(
    elements: elements,
    resolve: ({
      required element,
      parentScope,
      iconOccurrenceAmongSiblings,
      iconSiblingCount,
      occurrenceAmongSiblings,
    }) =>
        (
      locator: cheapSuggestedLocator(
        element,
        parentScope: parentScope,
        iconOccurrenceAmongSiblings: iconOccurrenceAmongSiblings,
        iconSiblingCount: iconSiblingCount,
        occurrenceAmongSiblings: occurrenceAmongSiblings,
      ),
      warning: null,
    ),
  );
  final locatorEntries = <String, List<_LocatorEntry>>{};
  var preorderIndex = 0;

  int collect(List<UiElement> nodes) {
    for (final element in nodes) {
      // Match report projection: hidden elements must not make a visible
      // locator ambiguous.
      if (element.state.visible == false && element.state.offscreen != true) {
        continue;
      }
      final start = preorderIndex++;
      final locator = element.suggestedLocator;
      final locatorKey = locator == null ? null : jsonEncode(locator.toJson());
      _LocatorEntry? entry;
      if (locatorKey != null) {
        entry = _LocatorEntry(element, start);
        locatorEntries.putIfAbsent(locatorKey, () => []).add(entry);
      }
      collect(element.children);
      if (entry != null) entry.end = preorderIndex;
    }
    return preorderIndex;
  }

  collect(withLocators);
  final ambiguousIds = <String>{};
  for (final entries in locatorEntries.values) {
    if (entries.length < 2) continue;

    // A selector can be shared by merged semantic parent/child nodes, but
    // separate branches make it ambiguous. Entries are collected in preorder;
    // subtree intervals detect whether they form one ancestor chain in linear
    // time, avoiding pairwise comparisons for repeated labels in large trees.
    var previousEnd = entries.first.end;
    var formsAncestorChain = true;
    for (final entry in entries.skip(1)) {
      if (entry.start >= previousEnd) {
        formsAncestorChain = false;
        break;
      }
      previousEnd = entry.end;
    }
    if (!formsAncestorChain) {
      ambiguousIds.addAll(entries.map((entry) => entry.element.elementId));
    }
  }

  // When selectors are unique, the locator projection is already complete.
  // Skip a second recursive copy of every unchanged element on this common
  // diagnostic path.
  if (ambiguousIds.isEmpty) return withLocators;

  UiElement markAmbiguities(UiElement element) {
    final ambiguous = ambiguousIds.contains(element.elementId);
    return element.copyWith(
      children: [for (final child in element.children) markAmbiguities(child)],
      suggestedLocator: ambiguous ? null : element.suggestedLocator,
      clearSuggestedLocator: ambiguous,
      locatorWarning: ambiguous
          ? 'Suggested locator matches multiple observed elements'
          : element.locatorWarning,
      clearLocatorWarning: !ambiguous && element.locatorWarning == null,
    );
  }

  return [for (final element in withLocators) markAmbiguities(element)];
}

final class _LocatorEntry {
  _LocatorEntry(this.element, this.start);

  final UiElement element;
  final int start;
  late int end;
}
