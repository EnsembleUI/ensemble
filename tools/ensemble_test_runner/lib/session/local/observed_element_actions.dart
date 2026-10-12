import 'package:ensemble_test_runner/session/observation/ui_element.dart';

/// Derives executable and assertion steps from one observed element.
///
/// This module owns the action vocabulary projection so element semantics can
/// remain focused on describing Flutter elements.

/// Test-step names an automation client can run **against this observed node**.
///
/// Only lists steps that are actually targetable with the locators this node
/// exposes (`testId` → id-based steps; visible label/text → structured
/// `target: { label|text, role }` taps / text waits). Unkeyed tappable cards
/// without a caption still get no interaction steps — act on a keyed child.
///
/// Wait/assert steps (`waitFor`, `expectVisible`, …) are included alongside
/// gesture/edit steps so the list matches the test-step vocabulary.
List<String> actionsFor(
  String? type, {
  required bool secure,
  bool? enabled,
  String? testId,
  String? text,
  String? label,
  bool offscreen = false,
  bool hasBounds = false,
  bool hasScrollableAncestor = false,
}) {
  final t = (type ?? '').trim().toLowerCase();
  final hasId = testId != null && testId.trim().isNotEmpty;
  final hasText = text != null && text.trim().isNotEmpty;
  final hasLabel = label != null && label.trim().isNotEmpty;
  final hasCaption = hasText || hasLabel;
  final actions = <String>[];

  void addIdWaitAssert() {
    if (!hasId) return;
    actions.addAll(const [
      'waitFor',
      'waitForGone',
      'expectVisible',
      'expectNotVisible',
      'expectExists',
      'expectNotExists',
    ]);
  }

  void addEnabledAsserts() {
    if (!hasId) return;
    actions.addAll(const ['expectEnabled', 'expectDisabled']);
  }

  void addTextWaitAssert() {
    if (!hasText && !hasLabel) return;
    actions.addAll(const [
      'waitForText',
      'waitFor',
      'expectText',
      'expectNoText',
      'expectTextContains',
    ]);
  }

  final canGesture = enabled != false;
  addIdWaitAssert();

  switch (t) {
    case 'text':
      addTextWaitAssert();
      // Plain text is not a gesture target.
      break;
    case 'toast':
    case 'widget':
    case 'image':
    case 'svg':
    case 'gif':
    case 'lottie':
      break;
    case 'textinput':
    case 'textfield':
      // Caption (hint / absorbed label) unlocks edit steps without a testId.
      if (canGesture && (hasId || hasCaption)) {
        if (hasId) addEnabledAsserts();
        actions.addAll(secure
            ? const ['tap', 'enterText', 'clearText', 'focus', 'expectValue']
            : const [
                'tap',
                'enterText',
                'clearText',
                'replaceText',
                'submitText',
                'focus',
                'expectValue',
              ]);
      }
      break;
    case 'button':
      // Unkeyed Ensemble tabs / CTAs: tap via label+role (or text+role).
      if (canGesture && (hasId || hasCaption)) {
        if (hasId) addEnabledAsserts();
        actions.addAll(const ['tap', 'longPress', 'doubleTap']);
      }
      break;
    case 'card':
      // Tap when the row is positively enabled (InkWell onTap) and either
      // keyed or has a caption agents can target via label+role.
      if (enabled == true && (hasId || hasCaption)) {
        if (hasId) addEnabledAsserts();
        actions.addAll(const ['tap', 'longPress']);
      }
      break;
    case 'icon':
      // Keyed icons always expose enable asserts when we know the state
      // (including disabled Ensemble back buttons with isDisabled=true).
      if (hasId && enabled != null) {
        addEnabledAsserts();
      }
      // Gestures when positively enabled. Unlabeled icons stay addressable via
      // role=icon (or within+role) — keep sel + Supported actions in sync.
      if (enabled == true) {
        actions.addAll(const ['tap', 'longPress', 'doubleTap']);
      }
      break;
    case 'dropdown':
      if (canGesture && (hasId || hasCaption)) {
        if (hasId) addEnabledAsserts();
        actions.addAll(const ['tap', 'select', 'selectIndex']);
      }
      break;
    case 'switch':
    case 'toggle':
    case 'checkbox':
      // Enabled switches are tappable even without testId — agents use
      // absorbed label+role or within+role under a parent card.
      if (canGesture && (hasId || hasCaption || enabled == true)) {
        if (hasId) addEnabledAsserts();
        actions.addAll(const [
          'tap',
          'toggle',
          'check',
          'uncheck',
          'expectChecked',
        ]);
      }
      break;
    case 'slider':
      if (canGesture && (hasId || hasCaption || enabled == true)) {
        if (hasId) addEnabledAsserts();
        actions.addAll(const ['tap', 'setSlider']);
      }
      break;
    default:
      break;
  }

  // Offscreen nodes with geometry can be resolved as snapshot/bounds targets,
  // even when they have no test ID. Recommend scrolling them into view before
  // any gesture; the action executor supports locator-backed targets.
  if (offscreen && hasBounds && hasScrollableAncestor) {
    actions.insert(0, 'scrollUntilVisible');
  }

  // Stable order, unique.
  final seen = <String>{};
  return [
    for (final step in actions)
      if (seen.add(step)) step,
  ];
}

/// Recompute [UiElement.actions] / interactable after label absorb.
UiElement refreshObserveActions(UiElement element) {
  final secure = element.state.secure == true;
  final actions = actionsFor(
    element.type,
    secure: secure,
    enabled: element.state.enabled,
    testId: element.testId,
    text: element.text,
    label: element.label,
    offscreen: element.state.offscreen == true,
    hasBounds: element.bounds != null,
    hasScrollableAncestor: element.actions.contains('scrollUntilVisible'),
  );
  final visible = element.state.visible != false;
  final offscreen = element.state.offscreen == true;
  final interactable = visible &&
      !offscreen &&
      element.state.enabled != false &&
      actions.any(isInteractionStep);
  final prev = element.state;
  return element.copyWith(
    actions: actions,
    state: UiElementState(
      exists: prev.exists,
      visible: prev.visible,
      interactable: interactable,
      enabled: prev.enabled,
      focused: prev.focused,
      selected: prev.selected,
      checked: prev.checked,
      obscured: prev.obscured,
      offscreen: prev.offscreen,
      secure: prev.secure,
    ),
  );
}

bool isInteractionStep(String step) {
  switch (step) {
    case 'tap':
    case 'doubleTap':
    case 'longPress':
    case 'enterText':
    case 'clearText':
    case 'replaceText':
    case 'submitText':
    case 'focus':
    case 'select':
    case 'selectIndex':
    case 'check':
    case 'uncheck':
    case 'toggle':
    case 'setSlider':
      return true;
    default:
      return false;
  }
}
