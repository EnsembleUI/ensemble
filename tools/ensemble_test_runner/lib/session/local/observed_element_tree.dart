import 'package:ensemble_test_runner/application/application_test_types.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/session/local/element_semantics.dart';
import 'package:ensemble_test_runner/session/local/observable_fingerprint.dart';
import 'package:ensemble_test_runner/session/local/observation_registry.dart';
import 'package:ensemble_test_runner/session/local/widget_locator_id.dart';
import 'package:ensemble_test_runner/session/observation/ui_element.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds the kept observe element tree from the live Flutter element walk.
///
/// When [enableSemantics] is true (live inspect-ui), briefly enables a
/// [SemanticsHandle] for richer labels. Diagnostic / report snapshots must
/// pass `enableSemantics: false` so hot-path captures never toggle semantics.
({List<UiElement> elements, Map<String, SnapshotElementHandle> handles})
    buildObservedElementTree({
  required WidgetTester tester,
  required AssertionEngine assertions,
  NavigationTestService? navigation,
  required bool includeBounds,
  bool keyedOnly = false,
  bool enableSemantics = true,
  bool useSemantics = true,
  bool registerRouteDependency = true,
}) {
  final kept = <({Element element, UiElement ui})>[];
  final handles = <String, SnapshotElementHandle>{};
  var index = 0;
  final seenRenderObjects = <Object>{};
  final claimedOwnedIds = <String>{};

  SemanticsHandle? semantics;
  if (enableSemantics) {
    semantics = tester.ensureSemantics();
  }
  try {
    final viewportSize =
        tester.view.physicalSize / tester.view.devicePixelRatio;
    final routeName = navigation?.currentRoute?.trim();

    for (final element in tester.allElements) {
      final ownedKey = hasCompactValueKey(element);
      final ownedId = readOwnedWidgetLocatorId(element);
      if (keyedOnly && ownedKey == false && ownedId == null) continue;

      final underKeyed = _hasCompactKeyedAncestor(element);

      var keep = false;
      // Owned keys / primaries may inherit exclusive wrapper ids; nested
      // content under a card must not be stamped with the parent card id.
      var allowInheritedId = false;
      if (ownedKey) {
        if (_isPageShellElement(
          element,
          ownedId,
          viewportSize,
          routeName: routeName,
        )) {
          keep = false;
        } else {
          keep = true;
          allowInheritedId = true;
          if (ownedId != null) claimedOwnedIds.add(ownedId);
        }
      } else if (underKeyed) {
        if (isPrimaryControlElement(element) &&
            !hasPrimaryControlAncestor(element)) {
          if (readInvokableLocatorId(element) != null &&
              nearestDescendantValueKeyLocatorId(element) != null) {
            keep = false;
          } else {
            final scopeId = ownedId ??
                nearestExclusiveKeyedWrapperId(
                  element,
                  viewport: viewportSize,
                  routeName: routeName,
                );
            if (scopeId != null) {
              keep = claimedOwnedIds.add(scopeId);
            } else {
              keep = true;
            }
            allowInheritedId = keep;
          }
        } else if (isNestedActionableElement(element)) {
          // Nested actions under a keyed card / page shell (icons, buttons, …).
          keep = true;
        } else if (isNestedContentTextElement(element)) {
          keep = true;
        } else if (isNestedContentMediaElement(element)) {
          keep = true;
        } else if (isVisualCardContainerElement(element)) {
          keep = true;
        } else if (isStandaloneTextElement(element)) {
          // Avoid KeyedSubtree(icon) + leaf media/text both observing as icon.
          keep = !isRedundantLeafUnderKeyedIconShell(element);
        } else if (isStandaloneMediaElement(element)) {
          keep = !isRedundantLeafUnderKeyedIconShell(element);
        }
      } else if (isPrimaryControlElement(element) &&
          !hasPrimaryControlAncestor(element)) {
        if (readInvokableLocatorId(element) != null &&
            nearestDescendantValueKeyLocatorId(element) != null) {
          keep = false;
        } else {
          final scopeId = ownedId ??
              nearestExclusiveKeyedWrapperId(
                element,
                viewport: viewportSize,
                routeName: routeName,
              );
          if (scopeId != null) {
            keep = claimedOwnedIds.add(scopeId);
          } else {
            keep = true;
          }
          allowInheritedId = keep;
        }
      } else if (isNestedActionableElement(element)) {
        // Nested actions under an unkeyed tappable settings row (card).
        keep = true;
      } else if (isNestedContentTextElement(element)) {
        keep = true;
      } else if (isNestedContentMediaElement(element)) {
        keep = true;
      } else if (isVisualCardContainerElement(element)) {
        // Non-interactive bordered panels (FeedbackInput, etc.).
        keep = true;
      } else if (isStandaloneTextElement(element) &&
          nearestOwnedLocatorIdAncestor(element) == null) {
        keep = true;
      } else if (isStandaloneMediaElement(element) &&
          nearestOwnedLocatorIdAncestor(element) == null) {
        keep = true;
      }
      if (!keep) continue;

      final testId = ownedId ??
          (allowInheritedId
              ? (observeLocatorId(
                    element,
                    viewport: viewportSize,
                    routeName: routeName,
                  ) ??
                  '')
              : '');

      final renderObject = element.renderObject;
      if (testId.isEmpty &&
          renderObject != null &&
          !seenRenderObjects.add(renderObject)) {
        continue;
      }

      final elementId = 'el_${index++}';
      final uiElement = describeElement(
        element: element,
        elementId: elementId,
        testId: testId.isEmpty ? null : testId,
        assertions: assertions,
        tester: tester,
        includeBounds: includeBounds,
        useSemantics: useSemantics,
        registerRouteDependency: registerRouteDependency,
      );
      kept.add((element: element, ui: uiElement));
      handles[elementId] = SnapshotElementHandle(
        observationId: '',
        elementId: elementId,
        testId: testId.isEmpty ? null : testId,
        element: element,
        observableFingerprint: fingerprintForElement(uiElement),
      );
    }
  } finally {
    semantics?.dispose();
  }

  final absorbed = absorbFormFieldLabels(kept);
  final deduped = dropRedundantNestedObserveLeaves(absorbed);
  final remainingIds = <String>{
    for (final item in deduped) item.ui.elementId,
  };
  handles.removeWhere((id, _) => !remainingIds.contains(id));
  for (final item in deduped) {
    handles[item.ui.elementId] = SnapshotElementHandle(
      observationId: '',
      elementId: item.ui.elementId,
      testId: item.ui.testId,
      element: item.element,
      observableFingerprint: fingerprintForElement(item.ui),
    );
  }
  return (elements: nestKeptElements(deduped), handles: handles);
}

/// Drop host/leaf duplicates that survived the keep walk.
///
/// Examples: `icon` → child `icon` (IconButton + Icon), button → caption text
/// that only repeats the button title, card → title text matching the card.
List<({Element element, UiElement ui})> dropRedundantNestedObserveLeaves(
  List<({Element element, UiElement ui})> kept,
) {
  if (kept.length < 2) return kept;

  final elementToIndex = <Element, int>{
    for (var i = 0; i < kept.length; i++) kept[i].element: i,
  };
  final drop = <int>{};

  for (var i = 0; i < kept.length; i++) {
    final child = kept[i].ui;
    UiElement? parentUi;
    int? parentIndex;
    kept[i].element.visitAncestorElements((ancestor) {
      final idx = elementToIndex[ancestor];
      if (idx == null || drop.contains(idx)) return true;
      parentIndex = idx;
      parentUi = kept[idx].ui;
      return false;
    });
    if (parentUi == null || parentIndex == null) continue;

    final pType = parentUi!.type;
    final cType = child.type;
    // Keyed leaves are locator targets — never collapse them away.
    final childKeyed = child.testId != null && child.testId!.trim().isNotEmpty;
    final parentKeyed =
        parentUi!.testId != null && parentUi!.testId!.trim().isNotEmpty;
    if (pType == 'icon' && (cType == 'icon' || cType == 'text')) {
      if (!childKeyed) drop.add(i);
      continue;
    }
    if ((pType == 'button' || pType == 'dropdown') && cType == 'text') {
      if (!childKeyed && _sameObserveCaption(parentUi!, child)) drop.add(i);
      continue;
    }
    // Trailing arrows on LabelArrowButton / compact CTAs — decorative chrome;
    // tap the button, not a selector-less nested icon. Dropdown expand
    // chevrons stay visible; status icons under cards stay too.
    if (pType == 'button' && cType == 'icon') {
      if (!childKeyed && child.state.interactable != true) drop.add(i);
      continue;
    }
    // AppIcon / inline SVG under a password row must not linger as a
    // selector-less `image` leaf when the eye affordance is the icon host.
    if (pType == 'button' &&
        (cType == 'image' ||
            cType == 'svg' ||
            cType == 'gif' ||
            cType == 'lottie')) {
      if (!childKeyed && child.state.interactable != true) drop.add(i);
      continue;
    }
    // KeyedSubtree(testId) + child InkWell both observe as button — keep the
    // keyed host only. Also collapse nested WifiCard show-password InkWell
    // under the outer "Wachtwoord" row button (same semantics label).
    if (pType == 'button' && cType == 'button') {
      if (parentKeyed && !childKeyed) {
        drop.add(i);
        continue;
      }
      if (!childKeyed) {
        final pb = parentUi!.bounds;
        final cb = child.bounds;
        if (pb != null &&
            cb != null &&
            pb.width * pb.height > cb.width * cb.height * 1.15) {
          drop.add(i);
        }
      }
      continue;
    }
    // Section shell (Recommendations) typed widget/button wrapping notification
    // chrome — drop the shell so the banner card is the root.
    if ((pType == 'widget' || pType == 'button') &&
        cType == 'card' &&
        parentKeyed) {
      final pb = parentUi!.bounds;
      if (pb != null && pb.width >= 140 && pb.height >= 64) {
        drop.add(parentIndex!);
      }
      continue;
    }
  }

  if (drop.isEmpty) return kept;
  return [
    for (var i = 0; i < kept.length; i++)
      if (!drop.contains(i)) kept[i],
  ];
}

bool _sameObserveCaption(UiElement parent, UiElement child) {
  final childText = (child.text ?? child.label)?.trim();
  if (childText == null || childText.isEmpty) return true;
  final parentText = (parent.text ?? parent.label)?.trim();
  if (parentText == null || parentText.isEmpty) return false;
  if (parentText == childText) return true;
  return parentText.split('\n').first.trim() == childText;
}

/// Fold nearby standalone label [Text] into form controls and drop duplicates.
List<({Element element, UiElement ui})> absorbFormFieldLabels(
  List<({Element element, UiElement ui})> kept,
) {
  const formTypes = {'textInput', 'switch', 'toggle', 'checkbox', 'dropdown'};
  final claimed = <int>{};
  final updated = List<({Element element, UiElement ui})>.of(kept);

  for (var i = 0; i < kept.length; i++) {
    final control = kept[i].ui;
    if (!formTypes.contains(control.type)) continue;
    final controlBounds = control.bounds;
    if (controlBounds == null) continue;

    int? bestTextIndex;
    var bestScore = double.infinity;
    for (var j = 0; j < kept.length; j++) {
      if (i == j || claimed.contains(j)) continue;
      final textUi = kept[j].ui;
      if (textUi.type != 'text') continue;
      if (textUi.testId != null && textUi.testId!.isNotEmpty) continue;
      final textBounds = textUi.bounds;
      if (textBounds == null) continue;
      final label = (textUi.text ?? textUi.label)?.trim();
      if (label == null || label.isEmpty) continue;
      final score = labelAssociationScore(textBounds, controlBounds);
      if (score != null && score < bestScore) {
        bestScore = score;
        bestTextIndex = j;
      }
    }

    if (bestTextIndex == null) continue;
    claimed.add(bestTextIndex);
    final labelText =
        (kept[bestTextIndex].ui.text ?? kept[bestTextIndex].ui.label)!.trim();
    updated[i] = (
      element: kept[i].element,
      ui: refreshObserveActions(control.copyWith(label: labelText)),
    );
  }

  return [
    for (var i = 0; i < updated.length; i++)
      if (!claimed.contains(i)) updated[i],
  ];
}

/// Lower is better; null when the text is not a plausible label for [control].
double? labelAssociationScore(UiBounds text, UiBounds control) {
  final textRect = Rect.fromLTWH(text.left, text.top, text.width, text.height);
  final controlRect =
      Rect.fromLTWH(control.left, control.top, control.width, control.height);

  final verticalOverlap =
      textRect.bottom > controlRect.top && textRect.top < controlRect.bottom;
  final leftOfControl = textRect.right <= controlRect.left + 8;
  if (verticalOverlap && leftOfControl) {
    final gap = controlRect.left - textRect.right;
    if (gap >= -8 && gap <= 48) return gap.abs();
  }

  final above = textRect.bottom <= controlRect.top + 12;
  if (!above) return null;
  final gap = controlRect.top - textRect.bottom;
  if (gap < -12 || gap > 40) return null;
  final horizontalOverlap =
      textRect.left < controlRect.right && textRect.right > controlRect.left;
  final leftAligned = (textRect.left - controlRect.left).abs() <= 24;
  if (!horizontalOverlap && !leftAligned) return null;
  return 100 + gap;
}

/// Nests kept nodes under their nearest kept Flutter ancestor.
///
/// Sibling / root order is visual reading order (top→bottom, then left→right),
/// not Flutter's [Element] walk — Scaffold often visits body before the app
/// bar, which would otherwise put the back button at the end of the tree.
List<UiElement> nestKeptElements(
  List<({Element element, UiElement ui})> kept,
) {
  if (kept.isEmpty) return const [];

  final elementToIndex = <Element, int>{
    for (var i = 0; i < kept.length; i++) kept[i].element: i,
  };
  final childIndexes = List.generate(kept.length, (_) => <int>[]);
  final isRoot = List<bool>.filled(kept.length, true);

  for (var i = 0; i < kept.length; i++) {
    kept[i].element.visitAncestorElements((ancestor) {
      final parentIndex = elementToIndex[ancestor];
      if (parentIndex == null) return true;
      childIndexes[parentIndex].add(i);
      isRoot[i] = false;
      return false;
    });
  }

  int compareVisual(int a, int b) {
    final ba = kept[a].ui.bounds;
    final bb = kept[b].ui.bounds;
    if (ba == null && bb == null) return a.compareTo(b);
    if (ba == null) return 1;
    if (bb == null) return -1;
    final topCmp = ba.top.compareTo(bb.top);
    if (topCmp != 0) return topCmp;
    final leftCmp = ba.left.compareTo(bb.left);
    if (leftCmp != 0) return leftCmp;
    return a.compareTo(b);
  }

  for (final kids in childIndexes) {
    kids.sort(compareVisual);
  }

  UiElement build(int i) {
    final children = [
      for (final childIndex in childIndexes[i]) build(childIndex),
    ];
    final ui = kept[i].ui;
    if (children.isEmpty) return ui;
    return ui.copyWith(children: children);
  }

  final roots = <int>[
    for (var i = 0; i < kept.length; i++)
      if (isRoot[i]) i,
  ]..sort(compareVisual);

  return [for (final i in roots) build(i)];
}

bool _hasCompactKeyedAncestor(Element element) {
  var found = false;
  element.visitAncestorElements((ancestor) {
    if (hasCompactValueKey(ancestor)) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

bool _isPageShellElement(
  Element element,
  String? ownedId,
  Size viewport, {
  required String? routeName,
}) {
  if (ownedId == null) return false;
  return isStructuralPageShell(
    element,
    ownedId,
    viewport: viewport,
    routeName: routeName,
  );
}
