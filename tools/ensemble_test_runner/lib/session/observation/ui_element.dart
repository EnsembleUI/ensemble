/// Visibility / interaction flags for a rendered element.
///
/// Prefer explicit unknown (`null`) over a misleading boolean when Flutter
/// cannot establish the property reliably.
import 'package:ensemble_test_runner/session/actions/test_action.dart';

class UiElementState {
  final bool? exists;
  final bool? visible;
  final bool? interactable;
  final bool? enabled;
  final bool? focused;
  final bool? selected;
  final bool? checked;
  final bool? obscured;
  final bool? offscreen;
  final bool? secure;

  const UiElementState({
    this.exists,
    this.visible,
    this.interactable,
    this.enabled,
    this.focused,
    this.selected,
    this.checked,
    this.obscured,
    this.offscreen,
    this.secure,
  });

  Map<String, dynamic> toJson() => {
        if (exists != null) 'exists': exists,
        if (visible != null) 'visible': visible,
        if (interactable != null) 'interactable': interactable,
        if (enabled != null) 'enabled': enabled,
        if (focused != null) 'focused': focused,
        if (selected != null) 'selected': selected,
        if (checked != null) 'checked': checked,
        if (obscured != null) 'obscured': obscured,
        if (offscreen != null) 'offscreen': offscreen,
        if (secure != null) 'secure': secure,
      };

  factory UiElementState.fromJson(Map<String, dynamic> json) => UiElementState(
        exists: json['exists'] as bool?,
        visible: json['visible'] as bool?,
        interactable: json['interactable'] as bool?,
        enabled: json['enabled'] as bool?,
        focused: json['focused'] as bool?,
        selected: json['selected'] as bool?,
        checked: json['checked'] as bool?,
        obscured: json['obscured'] as bool?,
        offscreen: json['offscreen'] as bool?,
        secure: json['secure'] as bool?,
      );
}

/// Axis-aligned bounds in logical pixels.
class UiBounds {
  final double left;
  final double top;
  final double width;
  final double height;

  const UiBounds({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  Map<String, dynamic> toJson() => {
        'left': left,
        'top': top,
        'width': width,
        'height': height,
      };

  factory UiBounds.fromJson(Map<String, dynamic> json) => UiBounds(
        left: (json['left'] as num).toDouble(),
        top: (json['top'] as num).toDouble(),
        width: (json['width'] as num).toDouble(),
        height: (json['height'] as num).toDouble(),
      );
}

/// One rendered element in a [UiObservation].
///
/// [elementId] is snapshot-scoped and ephemeral. [testId] is the developer
/// EDL id when present; they are not interchangeable.
class UiElement {
  final String elementId;
  final String? testId;
  final String? type;
  final String? role;
  final String? label;
  final String? text;

  /// Placeholder / hint for text inputs (never treated as [text] value).
  final String? hint;

  /// Selectable labels for dropdowns (from widget `items`, not the open menu).
  final List<String> options;

  /// Verified YAML-oriented locator for this element, when unique in the tree.
  final ElementLocator? suggestedLocator;

  /// Why [suggestedLocator] is missing (no stable locator / ambiguous).
  final String? locatorWarning;

  final UiElementState state;
  final UiBounds? bounds;
  final List<String> supportedActions;
  final List<UiElement> children;
  final Map<String, Object?> metadata;

  const UiElement({
    required this.elementId,
    this.testId,
    this.type,
    this.role,
    this.label,
    this.text,
    this.hint,
    this.options = const [],
    this.suggestedLocator,
    this.locatorWarning,
    this.state = const UiElementState(),
    this.bounds,
    this.supportedActions = const [],
    this.children = const [],
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
        'elementId': elementId,
        if (testId != null) 'testId': testId,
        if (type != null) 'type': type,
        if (role != null) 'role': role,
        if (label != null) 'label': label,
        if (text != null) 'text': text,
        if (hint != null) 'hint': hint,
        if (options.isNotEmpty) 'options': options,
        if (suggestedLocator != null)
          'suggestedLocator': suggestedLocator!.toJson(),
        if (locatorWarning != null) 'locatorWarning': locatorWarning,
        'state': state.toJson(),
        if (bounds != null) 'bounds': bounds!.toJson(),
        if (supportedActions.isNotEmpty) 'supportedActions': supportedActions,
        if (children.isNotEmpty)
          'children': children.map((c) => c.toJson()).toList(),
        if (metadata.isNotEmpty) 'metadata': metadata,
      };

  factory UiElement.fromJson(Map<String, dynamic> json) {
    final stateRaw = json['state'];
    final boundsRaw = json['bounds'];
    final childrenRaw = json['children'];
    final actionsRaw = json['supportedActions'];
    final optionsRaw = json['options'];
    final locatorRaw = json['suggestedLocator'];
    return UiElement(
      elementId: json['elementId']?.toString() ?? '',
      testId: json['testId']?.toString(),
      type: json['type']?.toString(),
      role: json['role']?.toString(),
      label: json['label']?.toString(),
      text: json['text']?.toString(),
      hint: json['hint']?.toString(),
      options: optionsRaw is List
          ? optionsRaw.map((e) => e.toString()).toList()
          : const [],
      suggestedLocator: locatorRaw is Map
          ? ElementLocator.fromJson(Map<String, dynamic>.from(locatorRaw))
          : null,
      locatorWarning: json['locatorWarning']?.toString(),
      state: stateRaw is Map
          ? UiElementState.fromJson(Map<String, dynamic>.from(stateRaw))
          : const UiElementState(),
      bounds: boundsRaw is Map
          ? UiBounds.fromJson(Map<String, dynamic>.from(boundsRaw))
          : null,
      supportedActions: actionsRaw is List
          ? actionsRaw.map((e) => e.toString()).toList()
          : const [],
      children: childrenRaw is List
          ? childrenRaw
              .whereType<Map>()
              .map((e) => UiElement.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      metadata: json['metadata'] is Map
          ? Map<String, Object?>.from(json['metadata'] as Map)
          : const {},
    );
  }

  /// Copy with selected fields replaced.
  ///
  /// Pass [clearSuggestedLocator] / [clearLocatorWarning] to null those fields.
  UiElement copyWith({
    String? elementId,
    String? testId,
    String? type,
    String? role,
    String? label,
    String? text,
    String? hint,
    List<String>? options,
    ElementLocator? suggestedLocator,
    bool clearSuggestedLocator = false,
    String? locatorWarning,
    bool clearLocatorWarning = false,
    UiElementState? state,
    UiBounds? bounds,
    List<String>? supportedActions,
    List<UiElement>? children,
    Map<String, Object?>? metadata,
  }) {
    return UiElement(
      elementId: elementId ?? this.elementId,
      testId: testId ?? this.testId,
      type: type ?? this.type,
      role: role ?? this.role,
      label: label ?? this.label,
      text: text ?? this.text,
      hint: hint ?? this.hint,
      options: options ?? this.options,
      suggestedLocator: clearSuggestedLocator
          ? suggestedLocator
          : (suggestedLocator ?? this.suggestedLocator),
      locatorWarning: clearLocatorWarning
          ? locatorWarning
          : (locatorWarning ?? this.locatorWarning),
      state: state ?? this.state,
      bounds: bounds ?? this.bounds,
      supportedActions: supportedActions ?? this.supportedActions,
      children: children ?? this.children,
      metadata: metadata ?? this.metadata,
    );
  }
}
