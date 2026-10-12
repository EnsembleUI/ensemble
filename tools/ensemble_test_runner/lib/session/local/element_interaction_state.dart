part of 'element_semantics.dart';

bool looksSecure(Element element) {
  final editable = _selfOrAncestor<EditableText>(element);
  if (editable != null && editable.obscureText) return true;
  final field = _selfOrAncestor<TextField>(element);
  if (field != null && field.obscureText) return true;
  final cupertino = _selfOrAncestor<CupertinoTextField>(element);
  if (cupertino != null && cupertino.obscureText) return true;
  return false;
}

bool? readEnabled(Element element) {
  if (_isPointerIgnoringAncestor(element)) return false;

  // Ensemble often keeps InkWell.onTap wired and gates the action in YAML
  // (BackButton: executeConditionalAction if: ${!isDisabled}). Prefer the
  // authoring flags on Invokable / custom-widget scope over onTap != null.
  if (_ensembleAuthoringSuggestsDisabled(element)) return false;

  final elevated = _selfOrAncestor<ElevatedButton>(element);
  if (elevated != null) return elevated.onPressed != null;
  final textButton = _selfOrAncestor<TextButton>(element);
  if (textButton != null) return textButton.onPressed != null;
  final outlined = _selfOrAncestor<OutlinedButton>(element);
  if (outlined != null) return outlined.onPressed != null;
  final filled = _selfOrAncestor<FilledButton>(element);
  if (filled != null) return filled.onPressed != null;
  final icon = _selfOrAncestor<IconButton>(element);
  if (icon != null) return icon.onPressed != null;

  final sw = _selfOrAncestor<Switch>(element);
  if (sw != null) return sw.onChanged != null;
  final cupertino = _selfOrAncestor<CupertinoSwitch>(element);
  if (cupertino != null) return cupertino.onChanged != null;
  final cb = _selfOrAncestor<Checkbox>(element);
  if (cb != null) return cb.onChanged != null;

  // Explicit Semantics(enabled: false) from Ensemble / Material.
  final semanticsEnabled = _semanticsEnabledFlag(element);
  if (semanticsEnabled == false) return false;

  // Icon / custom tap targets (Ensemble FrameworkIconButton → InkWell).
  final inkWell = _selfOrAncestor<InkWell>(element);
  if (inkWell != null) return inkWell.onTap != null;
  final inkResponse = _selfOrAncestor<InkResponse>(element);
  if (inkResponse != null) return inkResponse.onTap != null;
  final gesture = _selfOrAncestor<GestureDetector>(element);
  if (gesture != null) {
    return gesture.onTap != null ||
        gesture.onTapUp != null ||
        gesture.onTapDown != null ||
        gesture.onDoubleTap != null ||
        gesture.onLongPress != null ||
        gesture.onLongPressStart != null ||
        gesture.onLongPressMoveUpdate != null ||
        gesture.onLongPressUp != null ||
        gesture.onLongPressEnd != null ||
        gesture.onVerticalDragStart != null ||
        gesture.onVerticalDragUpdate != null ||
        gesture.onVerticalDragEnd != null ||
        gesture.onHorizontalDragStart != null ||
        gesture.onHorizontalDragUpdate != null ||
        gesture.onHorizontalDragEnd != null ||
        gesture.onPanStart != null ||
        gesture.onPanUpdate != null ||
        gesture.onPanEnd != null ||
        gesture.onScaleStart != null ||
        gesture.onScaleUpdate != null ||
        gesture.onScaleEnd != null ||
        gesture.onForcePressStart != null ||
        gesture.onForcePressPeak != null ||
        gesture.onForcePressUpdate != null ||
        gesture.onForcePressEnd != null;
  }
  return null;
}

/// True when Ensemble authoring marks this control disabled without clearing
/// [InkWell.onTap] — Invokable `enabled`/`isDisabled`/`disabled`, or the same
/// keys on a custom-widget [DataScopeWidget] (e.g. BackButton inputs).
bool _ensembleAuthoringSuggestsDisabled(Element element) {
  if (_invokableSuggestsDisabled(element)) return true;
  return _scopeExplicitlyDisabled(element) == true;
}

bool _invokableSuggestsDisabled(Element element) {
  var hit = false;
  void consider(Widget widget) {
    if (hit || widget is! Invokable) return;
    if (_invokableDisableFlag(widget as Invokable) == true) {
      hit = true;
    }
  }

  consider(element.widget);
  if (hit) return true;
  element.visitAncestorElements((ancestor) {
    consider(ancestor.widget);
    return !hit;
  });
  return hit;
}

/// `true` = disabled, `false` = explicitly enabled, `null` = unknown.
bool? _invokableDisableFlag(Invokable invokable) {
  if (invokable.hasGettableProperty('isDisabled')) {
    final value = _asBool(_invokableProperty(invokable, 'isDisabled'));
    if (value != null) return value;
  }
  if (invokable.hasGettableProperty('disabled')) {
    final value = _asBool(_invokableProperty(invokable, 'disabled'));
    if (value != null) return value;
  }
  if (invokable.hasGettableProperty('enabled')) {
    final value = _asBool(_invokableProperty(invokable, 'enabled'));
    if (value != null) return !value;
  }
  return null;
}

dynamic _invokableProperty(Invokable invokable, String name) {
  try {
    return invokable.getProperty(name);
  } catch (_) {
    return null;
  }
}

bool? _asBool(dynamic value) {
  if (value is bool) return value;
  if (value == 'true') return true;
  if (value == 'false') return false;
  return null;
}

/// Custom-widget inputs like BackButton's `isDisabled` live on [DataScopeWidget].
///
/// Walks ancestors (no [BuildContext.dependOnInheritedWidgetOfExactType]) so
/// observe does not subscribe every element to scope changes.
bool? _scopeExplicitlyDisabled(Element element) {
  DataScopeWidget? scopeWidget;
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    if (widget is DataScopeWidget) {
      scopeWidget = widget;
      return false;
    }
    return true;
  });
  final dataContext = scopeWidget?.scopeManager.dataContext;
  if (dataContext == null) return null;

  final isDisabled = _asBool(dataContext.getContextById('isDisabled'));
  if (isDisabled != null) return isDisabled;

  final disabled = _asBool(dataContext.getContextById('disabled'));
  if (disabled != null) return disabled;

  final enabled = _asBool(dataContext.getContextById('enabled'));
  if (enabled != null) return !enabled;
  return null;
}

bool _isPointerIgnoringAncestor(Element element) {
  var ignoring = false;
  element.visitAncestorElements((ancestor) {
    final w = ancestor.widget;
    if (w is IgnorePointer && w.ignoring) {
      ignoring = true;
      return false;
    }
    if (w is AbsorbPointer && w.absorbing) {
      ignoring = true;
      return false;
    }
    return true;
  });
  return ignoring;
}

bool? _semanticsEnabledFlag(Element element) {
  final w = element.widget;
  if (w is Semantics && w.properties.enabled != null) {
    return w.properties.enabled;
  }
  bool? found;
  element.visitAncestorElements((ancestor) {
    final aw = ancestor.widget;
    if (aw is Semantics && aw.properties.enabled != null) {
      found = aw.properties.enabled;
      return false;
    }
    return true;
  });
  return found;
}

/// Enabled state for observed `icon` rows — only when this is an icon button.
///
/// Decorative [Icon]s under a parent InkWell must not report `enabled: true`.
bool? readIconButtonEnabled(Element element) {
  final iconButton = _selfOrAncestor<IconButton>(element);
  if (iconButton != null) return iconButton.onPressed != null;
  if (!_hasIconButtonAncestor(element) &&
      !_isIconButtonWidget(element.widget)) {
    return null;
  }
  return readEnabled(element);
}

/// Enabled for a leaf icon/glyph under compact tappable chrome.
///
/// WifiCard wraps `••••` + eye [AppIcon] in a [Row]/[GestureDetector] with
/// `onTap` — the leaf has no InkWell of its own but is the visual affordance.
/// Stops at card/list-row hosts so decorative chevrons stay non-interactable.
bool? readEnabledFromCompactTapAncestor(Element element) {
  bool? found;
  element.visitAncestorElements((ancestor) {
    final w = ancestor.widget;
    if (!_isGenericTapTarget(w)) return true;
    final bounds = boundsFor(ancestor);
    if (bounds == null) return true;
    if (_looksLikeCardHitTarget(bounds) || _looksLikeListRowHitTarget(bounds)) {
      return false;
    }
    final compact = _looksLikeCompactIconHitTarget(ancestor) ||
        (bounds.width <= 220 && bounds.height <= 56);
    if (!compact) return true;
    found = _genericTapTargetIsEnabled(w);
    return false;
  });
  return found;
}

/// Enabled for observed `card` rows — only when the card itself is tappable.
///
/// FToast wraps banners in [GestureDetector] with `onTap: null` (not a disabled
/// button). Nested close [InkWell]s must not invent an enabled state either.
bool? readCardEnabled(Element element) {
  if (_ensembleAuthoringSuggestsDisabled(element)) return false;
  final widget = element.widget;
  if (widget is InkWell) {
    return widget.onTap != null ? true : null;
  }
  if (widget is InkResponse) {
    return widget.onTap != null ? true : null;
  }
  if (widget is GestureDetector) {
    final tappable = widget.onTap != null ||
        widget.onTapUp != null ||
        widget.onTapDown != null;
    return tappable ? true : null;
  }
  // Material button wrappers used as cards.
  final elevated = _selfOrAncestor<ElevatedButton>(element);
  if (elevated != null) return elevated.onPressed != null;
  final textButton = _selfOrAncestor<TextButton>(element);
  if (textButton != null) return textButton.onPressed != null;
  final outlined = _selfOrAncestor<OutlinedButton>(element);
  if (outlined != null) return outlined.onPressed != null;
  final filled = _selfOrAncestor<FilledButton>(element);
  if (filled != null) return filled.onPressed != null;
  return null;
}

bool _hasScrollableAncestor(Element element) {
  var found = false;
  element.visitAncestorElements((ancestor) {
    if (ancestor.widget is Scrollable) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}
