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
          }
        } else if (isStandaloneTextElement(element)) {
          keep = true;
        } else if (isStandaloneMediaElement(element)) {
          keep = true;
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
        }
      } else if (isStandaloneTextElement(element) &&
          nearestOwnedLocatorIdAncestor(element) == null) {
        keep = true;
      } else if (isStandaloneMediaElement(element) &&
          nearestOwnedLocatorIdAncestor(element) == null) {
        keep = true;
      }
      if (!keep) continue;

      final testId = observeLocatorId(
            element,
            viewport: viewportSize,
            routeName: routeName,
          ) ??
          '';

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
  final remainingIds = <String>{
    for (final item in absorbed) item.ui.elementId,
  };
  handles.removeWhere((id, _) => !remainingIds.contains(id));
  for (final item in absorbed) {
    handles[item.ui.elementId] = SnapshotElementHandle(
      observationId: '',
      elementId: item.ui.elementId,
      testId: item.ui.testId,
      element: item.element,
      observableFingerprint: fingerprintForElement(item.ui),
    );
  }
  return (elements: nestKeptElements(absorbed), handles: handles);
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
      ui: control.copyWith(label: labelText),
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

  UiElement build(int i) {
    final children = [
      for (final childIndex in childIndexes[i]) build(childIndex),
    ];
    final ui = kept[i].ui;
    if (children.isEmpty) return ui;
    return ui.copyWith(children: children);
  }

  return [
    for (var i = 0; i < kept.length; i++)
      if (isRoot[i]) build(i),
  ];
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
