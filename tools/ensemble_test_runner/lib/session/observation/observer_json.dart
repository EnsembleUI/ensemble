import 'package:ensemble_test_runner/session/observation/observer_action_examples.dart';
import 'package:ensemble_test_runner/session/observation/ui_element.dart';
import 'package:ensemble_test_runner/session/observation/ui_observation.dart';

/// Root agent payload. Report-only screenshot overlays are deliberately kept
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

/// Canonical agent-facing element tree produced from an Observer snapshot.
/// The HTML report renders and copies this data; it does not create it.
List<Map<String, dynamic>> observerElementsToJson(UiObservation observation) {
  final elements = <Map<String, dynamic>>[];
  var index = 1;

  Map<String, dynamic>? build(UiElement element) {
    if (element.state.visible == false && element.state.offscreen != true) {
      return null;
    }
    final elementIndex = index++;
    final children = <Map<String, dynamic>>[];
    for (final child in element.children) {
      final childJson = build(child);
      if (childJson != null) children.add(childJson);
    }
    return _elementToJson(elementIndex, element, children);
  }

  for (final element in observation.elements) {
    final node = build(element);
    if (node != null) elements.add(node);
  }
  return elements;
}

/// @nodoc Legacy report name retained for callers while the Observer JSON
/// serializer is adopted throughout the runner.
List<Map<String, dynamic>> observationElementsTreeForReport(
  UiObservation observation,
) =>
    observerElementsToJson(observation);

/// @nodoc Legacy alias.
List<Map<String, dynamic>> flattenObservationElementsForReport(
  UiObservation observation,
) =>
    observerElementsToJson(observation);

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
  final actionExamples = observerActionExamples(
    actions: element.supportedActions,
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
    if (actionExamples.isNotEmpty) 'actionExamples': actionExamples,
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
  final text = element.text?.trim();
  if (text == null || text.isEmpty) return null;
  if (title != null && title.trim() == text) return null;
  return text;
}
