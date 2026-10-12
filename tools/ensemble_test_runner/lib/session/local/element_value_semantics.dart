part of 'element_semantics.dart';

bool? readChecked(Element element) {
  final sw = _selfOrAncestor<Switch>(element);
  if (sw != null) return sw.value;
  final cupertino = _selfOrAncestor<CupertinoSwitch>(element);
  if (cupertino != null) return cupertino.value;
  final cb = _selfOrAncestor<Checkbox>(element);
  if (cb != null) return cb.value;
  return null;
}

/// Reads the selected semantics flag when the element exposes one.
/// Semantics-disabled snapshots leave the value unknown.
bool? readSelected(WidgetTester tester, Element element) {
  final finder =
      find.byElementPredicate((candidate) => identical(candidate, element));
  try {
    final node = tester.getSemantics(finder);
    // `flagsCollection` preserves the tri-state selected value (including
    // unknown). Access it dynamically so the runner also remains compatible
    // with older Flutter SDKs that predate this API.
    final dynamic flags = (node as dynamic).flagsCollection;
    final selected = flags.isSelected.toString().split('.').last;
    return switch (selected) {
      'isTrue' || 'true' => true,
      'isFalse' || 'false' => false,
      _ => null,
    };
  } on NoSuchMethodError {
    // Legacy Flutter exposed only the bit-flag API, which cannot distinguish
    // an explicit false from an unspecified selected state.
    try {
      final node = tester.getSemantics(finder);
      return (node as dynamic).hasFlag(SemanticsFlag.isSelected) as bool;
    } catch (_) {
      return null;
    }
  } catch (_) {
    return null;
  }
}

String? readText(Element element) {
  if (looksSecure(element)) return null;

  // Prefer the live editable value over labels/hints under the same control.
  final field = element.widget is TextField
      ? element.widget as TextField
      : _selfOrAncestor<TextField>(element);
  final cupertino = element.widget is CupertinoTextField
      ? element.widget as CupertinoTextField
      : _selfOrAncestor<CupertinoTextField>(element);
  if (field != null || cupertino != null || element.widget is EditableText) {
    return _readEditableValue(element, field: field, cupertino: cupertino);
  }

  String? editableText;
  final texts = <String>[];
  void visit(Element e) {
    if (!identical(e, element) && looksSecure(e)) return;
    final w = e.widget;
    if (w is EditableText) {
      final value = w.controller.text.trim();
      if (value.isNotEmpty) editableText ??= value;
      return;
    }
    if (w is Text) {
      final caption = _textWidgetCaption(w);
      if (caption != null && !isDecorativeGlyphCaption(caption)) {
        texts.add(caption);
      }
    } else if (w is RichText) {
      // Icon / ImageIcon paint via RichText with a private-use glyph — not copy.
      if (_hasIconPaintAncestor(e)) return;
      final plain = w.text.toPlainText().trim();
      if (plain.isNotEmpty && !isDecorativeGlyphCaption(plain)) {
        texts.add(plain);
      }
    }
    e.visitChildren(visit);
  }

  visit(element);
  if (editableText != null) return editableText;
  if (texts.isEmpty) return null;
  return texts.first;
}

/// Typed value currently in a text field (controller / EditableText only).
String? _readEditableValue(
  Element element, {
  TextField? field,
  CupertinoTextField? cupertino,
}) {
  final fromField = field?.controller?.text;
  if (fromField != null) return fromField;
  final fromCupertino = cupertino?.controller?.text;
  if (fromCupertino != null) return fromCupertino;

  String? editableText;
  var foundEditableText = false;
  void visit(Element e) {
    if (foundEditableText) return;
    if (!identical(e, element) && looksSecure(e)) return;
    final w = e.widget;
    if (w is EditableText) {
      editableText = w.controller.text;
      foundEditableText = true;
      return;
    }
    e.visitChildren(visit);
  }

  visit(element);
  return foundEditableText ? editableText : null;
}

/// InputDecoration / Cupertino placeholder — never used as [readText] value.
String? readHint(Element element) {
  final field = element.widget is TextField
      ? element.widget as TextField
      : _selfOrAncestor<TextField>(element);
  if (field != null) {
    final decoration = field.decoration;
    final hintText = decoration?.hintText?.trim();
    if (hintText != null && hintText.isNotEmpty) return hintText;
    final fromWidget = _plainTextFromWidget(decoration?.hint);
    if (fromWidget != null) return fromWidget;
  }
  final cupertino = element.widget is CupertinoTextField
      ? element.widget as CupertinoTextField
      : _selfOrAncestor<CupertinoTextField>(element);
  final placeholder = cupertino?.placeholder?.trim();
  if (placeholder != null && placeholder.isNotEmpty) return placeholder;
  return null;
}

/// Label for a control: InputDecoration label, then semantics (not the hint).
String? readControlLabel(Element element, WidgetTester tester) {
  final fromWidgets = readControlLabelWithoutSemantics(element);
  if (fromWidgets != null) return fromWidgets;
  final semantic = readSemanticsLabel(tester, element)?.trim();
  if (semantic == null || semantic.isEmpty) return null;
  final hint = readHint(element)?.trim();
  if (hint != null && hint.isNotEmpty) {
    if (semantic == hint) return null;
    // Flutter often merges "Label" + hint into one semantics string.
    if (semantic.endsWith(hint)) {
      final stripped =
          semantic.substring(0, semantic.length - hint.length).trim();
      return stripped.isEmpty ? null : stripped;
    }
  }
  return semantic;
}

/// Widget-field label only — never calls [WidgetTester.getSemantics].
String? readControlLabelWithoutSemantics(Element element) {
  final field = element.widget is TextField
      ? element.widget as TextField
      : _selfOrAncestor<TextField>(element);
  if (field != null) {
    final decoration = field.decoration;
    final labelText = decoration?.labelText?.trim();
    if (labelText != null && labelText.isNotEmpty) return labelText;
    final fromWidget = _plainTextFromWidget(decoration?.label);
    if (fromWidget != null) return fromWidget;
  }
  // Walk past empty Semantics nodes (Material / InkWell often insert one)
  // so CloseAppButton's `semantics.label` on the Column is still found.
  return _nearestNonEmptySemanticsLabel(element);
}

/// First non-empty [Semantics.properties.label] on [element] or an ancestor.
String? _nearestNonEmptySemanticsLabel(Element element) {
  String? from(Widget widget) {
    if (widget is! Semantics) return null;
    final label = widget.properties.label?.trim();
    return (label != null && label.isNotEmpty) ? label : null;
  }

  final self = from(element.widget);
  if (self != null) return self;
  String? found;
  element.visitAncestorElements((ancestor) {
    final label = from(ancestor.widget);
    if (label != null) {
      found = label;
      return false;
    }
    return true;
  });
  return found;
}

String? _plainTextFromWidget(Widget? widget) {
  if (widget == null) return null;
  if (widget is Text) {
    return _textWidgetCaption(widget);
  }
  if (widget is RichText) {
    final data = widget.text.toPlainText().trim();
    return data.isEmpty ? null : data;
  }
  return null;
}

/// Walks a widget *configuration* (not the element tree) for visible label text.
String? _plainTextFromWidgetDeep(Widget? widget) {
  if (widget == null) return null;
  final direct = _plainTextFromWidget(widget);
  if (direct != null) return direct;

  if (widget is Padding) return _plainTextFromWidgetDeep(widget.child);
  if (widget is Center) return _plainTextFromWidgetDeep(widget.child);
  if (widget is Align) return _plainTextFromWidgetDeep(widget.child);
  if (widget is SizedBox) return _plainTextFromWidgetDeep(widget.child);
  if (widget is DecoratedBox) return _plainTextFromWidgetDeep(widget.child);
  if (widget is ColoredBox) return _plainTextFromWidgetDeep(widget.child);
  if (widget is Material) return _plainTextFromWidgetDeep(widget.child);
  if (widget is InkWell) return _plainTextFromWidgetDeep(widget.child);
  if (widget is GestureDetector) {
    return _plainTextFromWidgetDeep(widget.child);
  }
  if (widget is SingleChildRenderObjectWidget) {
    return _plainTextFromWidgetDeep(widget.child);
  }
  if (widget is Flexible) return _plainTextFromWidgetDeep(widget.child);
  if (widget is Expanded) return _plainTextFromWidgetDeep(widget.child);

  List<Widget>? children;
  if (widget is Row || widget is Column || widget is Flex || widget is Wrap) {
    children = (widget as dynamic).children as List<Widget>?;
  } else if (widget is Stack) {
    children = widget.children;
  }
  if (children != null) {
    for (final child in children) {
      final text = _plainTextFromWidgetDeep(child);
      if (text != null) return text;
    }
  }
  return null;
}

/// Dropdown option labels from widget `items` / menu entries.
///
/// Available while the menu is closed — Flutter keeps the item list on the
/// button widget. Custom InkWell-only dropdowns have no items to read.
List<String> readDropdownOptions(Element element) {
  final options = <String>[];
  var found = false;

  void consider(Widget widget) {
    if (found && options.isNotEmpty) return;
    if (widget is DropdownButton) {
      _collectDropdownMenuItemLabels(widget.items, options);
      found = true;
      return;
    }
    if (widget is DropdownMenu) {
      for (final entry in widget.dropdownMenuEntries) {
        final label = entry.label.trim();
        if (label.isNotEmpty) options.add(label);
      }
      found = true;
      return;
    }
    if (_isDropdownWidget(widget) &&
        widget is! DropdownButton &&
        widget is! DropdownMenu) {
      // EnsembleDropdown / DropdownButtonFormField2 / DropdownButton2 expose
      // `items` but are not part of material.dart — read dynamically.
      final items = _dynamicItemsList(widget);
      if (items != null) {
        _collectDropdownMenuItemLabels(items, options);
        found = true;
      }
    }
  }

  consider(element.widget);
  if (!found || options.isEmpty) {
    void visit(Element e) {
      if (found && options.isNotEmpty) return;
      consider(e.widget);
      e.visitChildren(visit);
    }

    element.visitChildren(visit);
  }
  if (!found || options.isEmpty) {
    element.visitAncestorElements((ancestor) {
      consider(ancestor.widget);
      return !(found && options.isNotEmpty);
    });
  }
  return List<String>.unmodifiable(options);
}

void _collectDropdownMenuItemLabels(List<dynamic>? items, List<String> out) {
  if (items == null) return;
  for (final item in items) {
    if (item is! DropdownMenuItem) continue;
    final fromChild = _plainTextFromWidgetDeep(item.child)?.trim();
    if (fromChild != null && fromChild.isNotEmpty) {
      out.add(fromChild);
      continue;
    }
    final value = item.value;
    if (value == null) continue;
    final asString = value.toString().trim();
    if (asString.isNotEmpty) out.add(asString);
  }
}

List<dynamic>? _dynamicItemsList(Widget widget) {
  try {
    final items = (widget as dynamic).items;
    if (items is List) return items;
  } catch (_) {}
  return null;
}

String? readSemanticsLabel(WidgetTester tester, Element element) {
  final widget = element.widget;
  if (widget is Semantics) {
    final direct = widget.properties.label;
    if (direct != null && direct.isNotEmpty) return direct;
  }
  try {
    final node = tester.getSemantics(
      find.byElementPredicate((e) => identical(e, element)),
    );
    final label = node.label;
    return label.isEmpty ? null : label;
  } catch (_) {
    return null;
  }
}

/// True when [label] should stay on an icon observe row.
///
/// Compact back/close hosts keep their a11y caption. Nested glyphs under a
/// card/list-row drop merged parent labels (use `within` + `role=icon` instead).
bool _shouldKeepIconSemanticsLabel(Element element, String label) {
  if (_isCompactIconTapHost(element)) return true;
  if (_iconOwnsAuthoredSemanticsLabel(element, label)) return true;
  return false;
}

/// InkWell / IconButton / compact glyph host that is itself the observe target.
bool _isCompactIconTapHost(Element element) {
  if (_isIconButtonWidget(element.widget)) return true;
  if (_isGenericTapTarget(element.widget) &&
      _genericTapTargetIsEnabled(element.widget)) {
    final bounds = boundsFor(element);
    if (bounds != null &&
        bounds.width <= 72 &&
        bounds.height <= 72 &&
        !_looksLikeCardHitTarget(bounds) &&
        !_looksLikeListRowHitTarget(bounds)) {
      return true;
    }
    if (_looksLikeCompactIconHitTarget(element)) return true;
  }
  return false;
}

/// True when [label] is authored on compact icon chrome around [element], not
/// merged from a larger card/list-row ancestor (WifiCard / Guest wifi).
bool _iconOwnsAuthoredSemanticsLabel(Element element, String label) {
  var owned = false;
  void consider(Element e) {
    final w = e.widget;
    if (w is! Semantics) return;
    final l = w.properties.label?.trim();
    if (l == null || l != label) return;
    final bounds = boundsFor(e);
    if (bounds != null &&
        (_looksLikeCardHitTarget(bounds) ||
            _looksLikeListRowHitTarget(bounds))) {
      return;
    }
    // CloseAppButton / IconButton chrome is compact; card MergeSemantics is not.
    if (bounds != null && (bounds.width > 96 || bounds.height > 96)) {
      return;
    }
    owned = true;
  }

  consider(element);
  if (owned) return true;
  element.visitAncestorElements((ancestor) {
    final bounds = boundsFor(ancestor);
    if (bounds != null &&
        (_looksLikeCardHitTarget(bounds) ||
            _looksLikeListRowHitTarget(bounds))) {
      return false;
    }
    consider(ancestor);
    return !owned;
  });
  return owned;
}

/// User-provided name for an icon (id is separate). Never invents Material names.
String? readIconName(Element element) {
  Icon? icon;
  void findIcon(Element e) {
    if (icon != null) return;
    if (e.widget is Icon) {
      icon = e.widget as Icon;
      return;
    }
    e.visitChildren(findIcon);
  }

  if (element.widget is Icon) {
    icon = element.widget as Icon;
  } else {
    element.visitChildren(findIcon);
  }

  final semantic = icon?.semanticLabel?.trim();
  if (semantic != null && semantic.isNotEmpty) return semantic;

  final iconButton = _selfOrAncestor<IconButton>(element);
  final buttonTooltip = iconButton?.tooltip?.trim();
  if (buttonTooltip != null && buttonTooltip.isNotEmpty) return buttonTooltip;

  final tooltip = _selfOrAncestor<Tooltip>(element);
  final tooltipMessage = tooltip?.message?.trim();
  if (tooltipMessage != null && tooltipMessage.isNotEmpty) {
    return tooltipMessage;
  }

  // Text-glyph icons (e.g. language "A") — only if the app literally rendered it.
  final glyph = readText(element)?.trim();
  if (glyph != null && glyph.isNotEmpty && glyph.length <= 2) return glyph;

  return null;
}
