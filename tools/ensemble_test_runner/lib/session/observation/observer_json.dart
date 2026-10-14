import 'package:ensemble_test_runner/session/observation/observer_action_examples.dart';
import 'package:ensemble_test_runner/session/observation/ui_element.dart';
import 'package:ensemble_test_runner/session/observation/ui_observation.dart';

/// Root observer payload. Report-only screenshot overlays are deliberately kept
/// outside this object so consumers get the same Observer JSON directly.
Map<String, dynamic> observerPayloadToJson({
  required int stepIndex,
  required String? screen,
  required Map<String, dynamic>? viewport,
  required List<Map<String, dynamic>> elements,
}) =>
    {
      if (screen != null) 'screen': screen,
      if (viewport != null) 'viewport': viewport,
      'coordinateSpace': const {
        'unit': 'logicalPixels',
        'origin': 'topLeft',
      },
      'stepIndex': stepIndex,
      'elements': elements,
    };

/// Canonical consumer-facing element tree produced from an Observer snapshot.
/// The HTML report renders and copies this data; it does not create it.
List<Map<String, dynamic>> observerElementsToJson(UiObservation observation) {
  return buildObserverReportTree(observation).elements;
}

/// The serialized report tree plus its indexed live elements.
///
/// Report serialization and screenshot overlays are produced in the same
/// snapshot turn. Keeping the indexed entries lets the overlay path reuse the
/// already filtered tree instead of walking every [UiElement] a second time.
final class ObserverReportTree {
  const ObserverReportTree({required this.elements, required this.entries});

  final List<Map<String, dynamic>> elements;
  final List<ObserverReportEntry> entries;
}

final class ObserverReportEntry {
  const ObserverReportEntry({
    required this.index,
    required this.element,
    required this.subtreeHasKeyedCardOrToast,
  });

  final int index;
  final UiElement element;
  final bool subtreeHasKeyedCardOrToast;
}

/// Builds the report representation once for all consumers of one snapshot.
ObserverReportTree buildObserverReportTree(UiObservation observation) {
  final elements = <Map<String, dynamic>>[];
  final entries = <ObserverReportEntry>[];
  var index = 1;

  ({Map<String, dynamic> json, bool subtree})? build(UiElement element) {
    if (element.state.visible == false && element.state.offscreen != true) {
      return null;
    }
    final elementIndex = index++;
    final entryPosition = entries.length;
    // Reserve the pre-order position before descending so indexes remain
    // stable even when children are recursively serialized.
    entries.add(ObserverReportEntry(
      index: elementIndex,
      element: element,
      subtreeHasKeyedCardOrToast: false,
    ));
    final children = <Map<String, dynamic>>[];
    var subtreeHasKeyedCardOrToast = false;
    for (final child in element.children) {
      final childResult = build(child);
      if (childResult != null) children.add(childResult.json);
      if (childResult?.subtree == true) {
        subtreeHasKeyedCardOrToast = true;
      }
    }
    final hasUsableId =
        (element.suggestedLocator?.id?.trim().isNotEmpty ?? false) ||
            (element.testId?.trim().isNotEmpty ?? false);
    final type = (element.type ?? '').toLowerCase();
    if (hasUsableId && (type == 'card' || type == 'toast')) {
      subtreeHasKeyedCardOrToast = true;
    }
    entries[entryPosition] = ObserverReportEntry(
      index: elementIndex,
      element: element,
      subtreeHasKeyedCardOrToast: subtreeHasKeyedCardOrToast,
    );
    return (
      json: _elementToJson(elementIndex, element, children),
      subtree: subtreeHasKeyedCardOrToast,
    );
  }

  for (final element in observation.elements) {
    final node = build(element);
    if (node != null) elements.add(node.json);
  }
  return ObserverReportTree(
    elements: List.unmodifiable(elements),
    entries: List.unmodifiable(entries),
  );
}

Map<String, dynamic> _elementToJson(
  int index,
  UiElement element,
  List<Map<String, dynamic>> children,
) {
  final type = (element.type ?? element.role ?? 'widget').trim();
  final title = observerElementTitleForFields(
    type: element.type,
    label: element.label,
    text: element.text,
    testId: element.testId,
  );
  final locator = element.suggestedLocator?.toJson();
  final warning = element.locatorWarning?.trim();
  final value = _elementValue(element, type: type, title: title);
  final bounds = element.bounds?.toJson();
  final actions = observerActionExamples(
    actions: element.actions,
    title: title,
    id: element.testId,
    locator: locator,
    bounds: bounds,
    warning: warning,
    value: value,
    secure: element.state.secure,
    checked: element.state.checked,
    options: element.options,
  );

  return {
    'index': index,
    // `elementId` is the observation-scoped handle. Keep it separate from
    // the developer locator (`id`) so a locator can never become a snapshot
    // identity by omission or fallback.
    'elementId': element.elementId,
    'type': type,
    if (title != null && title.isNotEmpty) 'title': title,
    if (element.testId != null &&
        element.testId!.trim().isNotEmpty &&
        warning == null &&
        (locator == null || locator['id'] != element.testId!.trim()))
      'id': element.testId!.trim(),
    if (locator != null) 'locator': locator,
    if (warning != null && warning.isNotEmpty) 'warning': warning,
    if (element.state.enabled != null) 'enabled': element.state.enabled,
    if (element.state.visible != null) 'visible': element.state.visible,
    if (element.state.offscreen != null) 'offscreen': element.state.offscreen,
    if (element.state.focused != null) 'focused': element.state.focused,
    if (element.state.selected != null) 'selected': element.state.selected,
    if (element.state.checked != null) 'checked': element.state.checked,
    if (element.state.obscured != null) 'obscured': element.state.obscured,
    if (element.state.secure != null) 'secure': element.state.secure,
    if (element.state.interactable != null)
      'interactable': element.state.interactable,
    if (bounds != null) 'bounds': bounds,
    if (value != null) 'value': value,
    if (element.hint != null && element.hint!.trim().isNotEmpty)
      'hint': element.hint!.trim(),
    if (element.options.isNotEmpty) 'options': element.options,
    if (actions.isNotEmpty) 'actions': actions,
    if (children.isNotEmpty) 'children': children,
  };
}

/// Editable / selected content only — never repeat a button/icon label as value.
String? _elementValue(
  UiElement element, {
  required String type,
  required String? title,
}) {
  switch (type.toLowerCase()) {
    case 'textinput':
    case 'textfield':
    case 'dropdown':
      break;
    default:
      return null;
  }
  if (element.state.secure == true) return null;
  // An empty string is a verified input value, not an unknown value. Keep it
  // so a downstream consumer can distinguish a cleared field from an
  // unobserved value.
  final text = element.text;
  if (text == null) return null;
  if (text.isNotEmpty && title != null && title.trim() == text.trim()) {
    return null;
  }
  return text;
}
