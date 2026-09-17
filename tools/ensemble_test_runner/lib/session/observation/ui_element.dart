/// Visibility / interaction flags for a rendered element.
///
/// Prefer explicit unknown (`null`) over a misleading boolean when Flutter
/// cannot establish the property reliably.
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
  final String? label;
  final String? text;
  final UiElementState state;
  final UiBounds? bounds;
  final List<String> supportedActions;
  final List<UiElement> children;

  const UiElement({
    required this.elementId,
    this.testId,
    this.type,
    this.label,
    this.text,
    this.state = const UiElementState(),
    this.bounds,
    this.supportedActions = const [],
    this.children = const [],
  });

  Map<String, dynamic> toJson() => {
        'elementId': elementId,
        if (testId != null) 'testId': testId,
        if (type != null) 'type': type,
        if (label != null) 'label': label,
        if (text != null) 'text': text,
        'state': state.toJson(),
        if (bounds != null) 'bounds': bounds!.toJson(),
        if (supportedActions.isNotEmpty) 'supportedActions': supportedActions,
        if (children.isNotEmpty)
          'children': children.map((c) => c.toJson()).toList(),
      };

  factory UiElement.fromJson(Map<String, dynamic> json) {
    final stateRaw = json['state'];
    final boundsRaw = json['bounds'];
    final childrenRaw = json['children'];
    final actionsRaw = json['supportedActions'];
    return UiElement(
      elementId: json['elementId']?.toString() ?? '',
      testId: json['testId']?.toString(),
      type: json['type']?.toString(),
      label: json['label']?.toString(),
      text: json['text']?.toString(),
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
    );
  }
}
