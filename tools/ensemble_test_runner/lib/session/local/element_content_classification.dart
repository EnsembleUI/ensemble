part of 'element_semantics.dart';

/// True for the element that owns user-facing semantics, excluding the many
/// implementation descendants that resolve to the same merged semantics node.
bool isSemanticLocatorCandidate(Element element) {
  final widget = element.widget;
  if (_isGenericTapTarget(widget) && _hasSpecificControlAncestor(element)) {
    return false;
  }
  if (widget is Semantics || isActionableControl(element)) return true;
  // Non-tappable feedback / settings panels used as `within` scopes.
  return isCardScopeHost(element);
}

/// Material [Card] or bordered visual panel that observes as `card`.
bool isCardScopeHost(Element element) {
  if (element.widget is Card) return true;
  return isVisualCardContainerElement(element);
}

/// Interactive controls suitable as the primary target of a text locator.
/// Excludes bare [Semantics] wrappers that may span multiple controls.
bool isActionableControl(Element element) {
  final widget = element.widget;
  return widget is ElevatedButton ||
      widget is TextButton ||
      widget is OutlinedButton ||
      widget is FilledButton ||
      widget is GestureDetector ||
      widget is InkWell ||
      widget is InkResponse ||
      widget is TextField ||
      widget is CupertinoTextField ||
      widget is EditableText ||
      widget is Checkbox ||
      widget is Switch ||
      widget is CupertinoSwitch ||
      widget is Slider ||
      _isIconButtonWidget(widget) ||
      _isDropdownWidget(widget);
}

/// True when [element]'s widget **is** the logical control (not a descendant).
///
/// Used by observation so one [TextField] yields one `textInput` row
/// instead of every child under it.
bool isPrimaryControlElement(Element element) {
  final widget = element.widget;
  if (_isGenericTapTarget(widget) && _hasSpecificControlAncestor(element)) {
    return false;
  }
  if (widget is EditableText) {
    return element.findAncestorWidgetOfExactType<TextField>() == null &&
        element.findAncestorWidgetOfExactType<CupertinoTextField>() == null;
  }
  return widget is ElevatedButton ||
      widget is TextButton ||
      widget is OutlinedButton ||
      widget is FilledButton ||
      widget is GestureDetector ||
      widget is InkWell ||
      widget is InkResponse ||
      widget is TextField ||
      widget is CupertinoTextField ||
      widget is Checkbox ||
      widget is Switch ||
      widget is CupertinoSwitch ||
      widget is Slider ||
      _isIconButtonWidget(widget) ||
      _isDropdownWidget(widget);
}

/// Non-empty [Text]/[RichText] that is not under a primary control.
bool isStandaloneTextElement(Element element) {
  if (!_isVisibleTextHost(element)) return false;
  return !hasPrimaryControlAncestor(element);
}

/// User-facing text that should remain observable even when it is nested
/// below a control host. The tree builder removes redundant control captions
/// after collection, so filtering nested text here can otherwise hide
/// meaningful status labels (for example, a badge rendered inside a custom
/// row/control).
bool isObservableTextElement(Element element) {
  if (!_isVisibleTextHost(element)) return false;
  if (_selfOrAncestor<EditableText>(element) != null ||
      _selfOrAncestor<TextField>(element) != null ||
      _selfOrAncestor<CupertinoTextField>(element) != null) {
    return false;
  }
  return true;
}

/// Caption / badge [Text] nested under a tappable card, button, or row.
///
/// Without this, status badges ("Bedraad") and other copy inside an InkWell
/// card were dropped while only nested icons were kept.
///
/// Skips captions that only repeat the parent button/card title, and any text
/// under a compact icon host (glyph / merged semantics noise).
bool isNestedContentTextElement(Element element) {
  if (!_isVisibleTextHost(element)) return false;
  if (!hasPrimaryControlAncestor(element)) return false;
  // Field internals — value lives on the textInput row, not a nested text.
  if (_selfOrAncestor<EditableText>(element) != null) return false;
  if (_selfOrAncestor<TextField>(element) != null) return false;
  if (_selfOrAncestor<CupertinoTextField>(element) != null) return false;
  // IconButton / compact InkWell+Icon already is the observe row.
  if (_isUnderCompactIconControl(element)) return false;
  if (_isRedundantCaptionOfNearestPrimary(element)) return false;
  return true;
}

bool _isVisibleTextHost(Element element) {
  final widget = element.widget;
  final String? data;
  if (widget is Text) {
    // Plain [Text] uses `data`; Markdown / [Text.rich] use the TextSpan tree.
    data = _textWidgetCaption(widget);
  } else if (widget is RichText) {
    // [Text] / [Text.rich] build a child [RichText] — keep only the Text host
    // when that host already exposes a caption.
    final ancestorText = element.findAncestorWidgetOfExactType<Text>();
    if (ancestorText != null && _textWidgetCaption(ancestorText) != null) {
      return false;
    }
    // [Icon] / [ImageIcon] also render via RichText — keep the Icon host.
    // Use [is] (not findAncestorWidgetOfExactType): Ensemble Icon subclasses
    // Flutter Icon, and exact runtimeType matching misses that subclass so
    // icon-font glyphs were observed as `text □`.
    if (_hasIconPaintAncestor(element)) return false;
    data = widget.text.toPlainText();
  } else {
    return false;
  }
  // List bullets ("•") and password masks are chrome, not assertable copy.
  if (data == null || data.trim().isEmpty) return false;
  if (isDecorativeGlyphCaption(data)) return false;
  return true;
}

/// True under Flutter [Icon] / [ImageIcon] **or** a subclass (Ensemble Icon).
///
/// [Element.findAncestorWidgetOfExactType] matches `runtimeType == T` and
/// misses `ensemble/framework/widget/icon.dart`'s Icon subclass.
bool _hasIconPaintAncestor(Element element) {
  var found = false;
  element.visitAncestorElements((ancestor) {
    final w = ancestor.widget;
    if (w is Icon || w is ImageIcon) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

/// Visible caption for a [Text] widget, including [Text.rich] / Markdown spans.
String? _textWidgetCaption(Text widget) {
  final data = widget.data?.trim();
  if (data != null && data.isNotEmpty) return data;
  final plain = widget.textSpan?.toPlainText().trim() ?? '';
  return plain.isEmpty ? null : plain;
}

/// Visible image / SVG / GIF / Lottie host (not an inner leaf under Ensemble*).
bool isStandaloneMediaElement(Element element) {
  final type = mediaWidgetType(element.widget);
  if (type == null) return false;
  if (_hasMediaHostAncestor(element)) return false;
  if (hasPrimaryControlAncestor(element)) return false;
  return true;
}

/// Media nested under a tappable card/row (device art, status glyphs, …).
///
/// Not under a compact icon host — that host already observes as `icon`.
bool isNestedContentMediaElement(Element element) {
  final type = mediaWidgetType(element.widget);
  if (type == null) return false;
  if (_hasMediaHostAncestor(element)) return false;
  if (!hasPrimaryControlAncestor(element)) return false;
  if (_isUnderCompactIconControl(element)) return false;
  return true;
}
