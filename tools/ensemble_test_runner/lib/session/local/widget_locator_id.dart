import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Locator id for YAML `testId:` / `id:` as shown on an observed control.
///
/// Priority: **testId** ([ValueKey]) first; YAML **id** ([Invokable.id]) only
/// when this element itself has no testId key.
///
/// Finders use [finderForLocatorId] (ValueKey / `testId` only). Ensemble already
/// mirrors YAML `id:` onto a KeyedSubtree ValueKey via the controller `testId`
/// getter, so steps must wait for that key — matching bare [Invokable] too early
/// (before State builds the KeyedSubtree) caused mid-transition taps and
/// framework build-scope errors.
///
/// Prefer [observeLocatorId] when attaching `testId` on observe / inspect-ui
/// rows — this helper inherits any ancestor id (including page shells).
String? readWidgetLocatorId(Element element) {
  final direct = readOwnedWidgetLocatorId(element);
  if (direct != null) return direct;
  return nearestOwnedLocatorIdAncestor(element);
}

/// Locator id for observe / inspect-ui / failure Observer rows.
///
/// Same owned-id rules as [readWidgetLocatorId], but does **not** inherit a
/// structural page/card shell key (e.g. screen `Home` / `AutoSignIn`) onto
/// every descendant — that made every text row look like `id=Home`.
///
/// Pass [viewport] / [routeName] so full-screen route KeyedSubtrees are
/// rejected even when they wrap only unkeyed content (loading screens).
String? observeLocatorId(
  Element element, {
  Size? viewport,
  String? routeName,
}) {
  final owned = readOwnedWidgetLocatorId(element);
  if (owned != null) return owned;
  return nearestExclusiveKeyedWrapperId(
    element,
    viewport: viewport,
    routeName: routeName,
  );
}

/// Nearest keyed/Invokable ancestor that wraps only this element's lineage
/// (no other keyed widgets under the same wrapper).
///
/// Never inherits [isStructuralPageShell] ancestors (route-named or
/// ~full-viewport KeyedSubtree).
String? nearestExclusiveKeyedWrapperId(
  Element element, {
  Size? viewport,
  String? routeName,
}) {
  String? found;
  element.visitAncestorElements((ancestor) {
    final id = readOwnedWidgetLocatorId(ancestor);
    if (id == null) return true;
    if (isStructuralPageShell(
      ancestor,
      id,
      viewport: viewport,
      routeName: routeName,
    )) {
      // Ensemble page shell — stop without inheriting.
      return false;
    }
    if (_keyedWrapperHasOtherKeyedDescendant(ancestor, element)) {
      // Section shell with sibling keyed widgets — stop without inheriting.
      return false;
    }
    found = id;
    return false;
  });
  return found;
}

/// Route-named or ~full-viewport keyed host (Ensemble screen KeyedSubtree).
bool isStructuralPageShell(
  Element element,
  String id, {
  Size? viewport,
  String? routeName,
}) {
  final route = routeName?.trim();
  if (route != null && route.isNotEmpty && id == route) return true;
  if (viewport == null) return false;
  if (viewport.width <= 0 || viewport.height <= 0) return false;
  final box = element.renderObject;
  if (box is! RenderBox || !box.hasSize) return false;
  return box.size.width >= viewport.width * 0.8 &&
      box.size.height >= viewport.height * 0.8;
}

bool _keyedWrapperHasOtherKeyedDescendant(Element ancestor, Element self) {
  var foreign = false;
  void walk(Element node) {
    if (foreign) return;
    node.visitChildren((child) {
      if (foreign) return;
      if (_isSelfOrAncestorOf(child, self)) {
        if (!identical(child, self)) walk(child);
        return;
      }
      if (readOwnedWidgetLocatorId(child) != null) {
        foreign = true;
        return;
      }
      walk(child);
    });
  }

  walk(ancestor);
  return foreign;
}

bool _isSelfOrAncestorOf(Element candidate, Element self) {
  if (identical(candidate, self)) return true;
  var found = false;
  self.visitAncestorElements((ancestor) {
    if (identical(ancestor, candidate)) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

/// Nearest ancestor (not [element] itself) that owns a locator id.
String? nearestOwnedLocatorIdAncestor(Element element) {
  String? fromAncestor;
  element.visitAncestorElements((ancestor) {
    fromAncestor = readOwnedWidgetLocatorId(ancestor);
    return fromAncestor == null;
  });
  return fromAncestor;
}

/// Id attached specifically to [element] (observe / hints).
///
/// Prefer [finderForLocatorId] for tap/enterText/wait — that path is ValueKey
/// only so it matches historical `find.byKey(ValueKey(id))`.
String? readOwnedWidgetLocatorId(Element element) {
  final testId = readValueKeyLocatorId(element);
  if (testId != null) return testId;

  final invokableId = readInvokableLocatorId(element);
  if (invokableId == null) return null;
  if (ancestorClaimsLocatorId(element, invokableId)) return null;
  return invokableId;
}

/// Finder for YAML `id:` / `testId:` steps — **ValueKey only**.
///
/// Same contract as the pre-Invokable `find.byKey(ValueKey(id))`. Ensemble
/// widgets with YAML `id:` still get a ValueKey because `testId` falls back to
/// `id` when building KeyedSubtree.
Finder finderForLocatorId(String id, {bool skipOffstage = true}) =>
    find.byKey(ValueKey(id), skipOffstage: skipOffstage);

/// True when an ancestor already claims [id] via testId ValueKey or Invokable.
bool ancestorClaimsLocatorId(Element element, String id) {
  var claimed = false;
  element.visitAncestorElements((ancestor) {
    if (readValueKeyLocatorId(ancestor) == id ||
        readInvokableLocatorId(ancestor) == id) {
      claimed = true;
      return false;
    }
    return true;
  });
  return claimed;
}

/// Compact string [ValueKey] on [element] itself (= Ensemble `testId`).
String? readValueKeyLocatorId(Element element) {
  final key = element.widget.key;
  final keyValue = key is ValueKey ? key.value : null;
  if (keyValue is! String) return null;
  final compact = compactWidgetLocatorId(keyValue);
  return compact.isEmpty ? null : compact;
}

/// YAML `id:` from an [Invokable] mixed onto [element]'s widget, if any.
String? readInvokableLocatorId(Element element) {
  final widget = element.widget;
  if (widget is! Invokable) return null;
  final id = (widget as Invokable).id;
  if (id == null) return null;
  final compact = compactWidgetLocatorId(id);
  return compact.isEmpty ? null : compact;
}

/// Depth-first: first compact [ValueKey] under [element] (not on [element]).
///
/// Used only by observe keep-logic (rare), not by per-step finders.
String? nearestDescendantValueKeyLocatorId(Element element) {
  String? found;
  void walk(Element node) {
    if (found != null) return;
    node.visitChildren((child) {
      if (found != null) return;
      final keyId = readValueKeyLocatorId(child);
      if (keyId != null) {
        found = keyId;
        return;
      }
      walk(child);
    });
  }

  walk(element);
  return found;
}

/// True when [element] itself carries a compact string [ValueKey] (testId).
bool hasCompactValueKey(Element element) {
  return readValueKeyLocatorId(element) != null;
}

/// Compact authoring id, or empty if not usable as a YAML `id:` / key.
String compactWidgetLocatorId(String value) {
  final singleLine = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (singleLine.isEmpty || singleLine.length > 120) return '';
  if (singleLine.startsWith('_')) return '';
  if (RegExp(r'\s').hasMatch(singleLine)) return '';
  if (!RegExp(r'^[A-Za-z][A-Za-z0-9_:.:-]*$').hasMatch(singleLine)) {
    return '';
  }
  return singleLine;
}
