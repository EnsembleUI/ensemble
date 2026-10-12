part of 'element_semantics.dart';

/// True when [text] is a real control caption (not mask glyphs like ••••).
bool _isSubstantialControlCaption(String? text) {
  final t = text?.trim() ?? '';
  if (t.length <= 2) return false;
  // WifiCard hidden-password row: "•••••••••••••" + eye — glyph chrome, not a
  // button title (otherwise it steals label+role from the parent row).
  if (isDecorativeGlyphCaption(t)) return false;
  return true;
}

/// Bullet / password-mask / icon-font glyphs — not observe text or `text=`.
bool isDecorativeGlyphCaption(String? text) {
  final t = text?.trim() ?? '';
  if (t.isEmpty) return true;
  if (RegExp(r'^[•·\.●○\*‧∙]+$').hasMatch(t)) return true;
  // Custom icon fonts (app-specific LEDs, etc.) paint Private Use Area code points.
  return t.runes.every(_isIconFontOrTofuCodePoint);
}

bool _isIconFontOrTofuCodePoint(int code) {
  if (code == 0xFFFD) return true; // replacement character
  // BMP Private Use Area (Material / custom icon fonts).
  if (code >= 0xE000 && code <= 0xF8FF) return true;
  // Supplementary Private Use Areas.
  if (code >= 0xF0000 && code <= 0xFFFFD) return true;
  if (code >= 0x100000 && code <= 0x10FFFD) return true;
  return false;
}

/// True for Ensemble [ToastController] / fluttertoast FToast overlay banners.
bool _looksLikeToast(
  Element element, {
  required UiBounds? bounds,
  required bool hasNavChevron,
}) {
  if (hasNavChevron) return false;
  if (!_isUnderToastOverlay(element)) return false;
  // Toast banners are wide and relatively short (same band as list rows).
  if (bounds == null) return true;
  if (bounds.width <= 0 || bounds.height <= 0) return true;
  return bounds.height <= 160;
}

/// FToast / Ensemble toast: [Positioned] gravity wrapper or `_ToastStateFul`.
bool _isUnderToastOverlay(Element element) {
  var found = false;
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    final typeName = widget.runtimeType.toString();
    if (typeName.contains('Toast') && typeName.contains('State')) {
      found = true;
      return false;
    }
    if (widget is Positioned) {
      // Ensemble ToastController / FToast gravity builders.
      final topBanner = widget.top != null &&
          widget.left != null &&
          widget.right != null &&
          widget.bottom == null;
      final bottomBanner = widget.bottom != null &&
          widget.left != null &&
          widget.right != null &&
          widget.top == null;
      if (topBanner || bottomBanner) {
        found = true;
        return false;
      }
    }
    return true;
  });
  return found;
}

bool _looksLikeIconSizedMedia(UiBounds? bounds) {
  if (bounds == null) return false;
  if (bounds.width <= 0 || bounds.height <= 0) return false;
  final maxSide = bounds.width > bounds.height ? bounds.width : bounds.height;
  final minSide = bounds.width < bounds.height ? bounds.width : bounds.height;
  if (maxSide > 72) return false;
  return maxSide / minSide <= 1.6;
}

/// True when a nested image/SVG/Lottie fills most of [hitBounds].
///
/// Distinguishes hero illustration CTAs from wide rows that only host a
/// compact AppIcon (WifiCard •••• + eye).
bool _mediaDominatesHitTarget(Element element, UiBounds? hitBounds) {
  if (hitBounds == null || hitBounds.width <= 0 || hitBounds.height <= 0) {
    return false;
  }
  UiBounds? largestMedia;
  void visit(Element e) {
    if (mediaWidgetType(e.widget) != null) {
      final b = boundsFor(e);
      if (b != null && b.width > 0 && b.height > 0) {
        final area = b.width * b.height;
        final best = largestMedia;
        if (best == null || area > best.width * best.height) {
          largestMedia = b;
        }
      }
    }
    e.visitChildren(visit);
  }

  element.visitChildren(visit);
  final media = largestMedia;
  if (media == null) return false;
  final hitArea = hitBounds.width * hitBounds.height;
  if (hitArea <= 0) return false;
  return media.width * media.height >= hitArea * 0.45;
}

/// Compact media used as a control (back arrow, close) rather than decoration.
bool _isCompactActionableMedia(Element element) {
  final bounds = boundsFor(element);
  if (!_looksLikeIconSizedMedia(bounds) &&
      !_looksLikeCompactIconHitTarget(element)) {
    return false;
  }
  final widget = element.widget;
  if (widget is EnsembleImage && widget.controller.onTap != null) return true;
  if (_isGenericTapTarget(widget)) return true;
  var childTap = false;
  element.visitChildren((child) {
    if (_isGenericTapTarget(child.widget)) childTap = true;
  });
  if (childTap) return true;
  return hasPrimaryControlAncestor(element);
}

bool _looksLikeCardHitTarget(UiBounds? bounds) {
  if (bounds == null) return false;
  if (bounds.width <= 0 || bounds.height <= 0) return false;
  // Mini cards (Devices / Speedtest): roughly square-ish or tall tiles.
  if (bounds.height >= 72 && bounds.width >= 96) return true;
  final ratio = bounds.width / bounds.height;
  return bounds.width >= 110 &&
      bounds.height >= 56 &&
      ratio >= 0.7 &&
      ratio <= 2.4;
}

bool _looksLikeListRowHitTarget(UiBounds? bounds) {
  if (bounds == null) return false;
  if (bounds.width <= 0 || bounds.height <= 0) return false;
  // Full-width settings rows: wide and relatively short.
  final ratio = bounds.width / bounds.height;
  return bounds.width >= 180 &&
      bounds.height >= 36 &&
      bounds.height <= 96 &&
      ratio >= 2.4;
}

bool _hasNavigationChevronDescendant(Element element) {
  var found = false;
  void visit(Element e) {
    if (found) return;
    final w = e.widget;
    if (w is Icon && _isNavigationChevronIcon(w.icon)) {
      found = true;
      return;
    }
    e.visitChildren(visit);
  }

  element.visitChildren(visit);
  return found;
}

bool _isNavigationChevronIcon(IconData? data) {
  if (data == null) return false;
  return data == Icons.chevron_right ||
      data == Icons.chevron_right_rounded ||
      data == Icons.chevron_right_outlined ||
      data == Icons.arrow_forward ||
      data == Icons.arrow_forward_ios ||
      data == Icons.arrow_forward_rounded ||
      data == Icons.arrow_right ||
      data == Icons.arrow_right_alt ||
      data == Icons.keyboard_arrow_right ||
      data == Icons.keyboard_arrow_right_rounded ||
      data == Icons.navigate_next ||
      data == Icons.navigate_next_rounded;
}

bool _looksLikeCompactIconHitTarget(Element element) {
  final bounds = boundsFor(element);
  if (bounds == null) return false;
  if (bounds.width <= 0 || bounds.height <= 0) return false;
  final maxSide = bounds.width > bounds.height ? bounds.width : bounds.height;
  final minSide = bounds.width < bounds.height ? bounds.width : bounds.height;
  if (maxSide > 72) return false;
  return maxSide / minSide <= 1.6;
}

bool _hasIconDescendant(Element element) {
  var found = false;
  void visit(Element e) {
    if (found) return;
    final w = e.widget;
    if (w is Icon || w is ImageIcon) {
      found = true;
      return;
    }
    e.visitChildren(visit);
  }

  element.visitChildren(visit);
  return found;
}

bool _hasDropdownChevronDescendant(Element element) {
  var found = false;
  void visit(Element e) {
    if (found) return;
    final w = e.widget;
    if (w is Icon && _isDropdownChevronIcon(w.icon)) {
      found = true;
      return;
    }
    e.visitChildren(visit);
  }

  element.visitChildren(visit);
  return found;
}

bool _isDropdownChevronIcon(IconData? data) {
  if (data == null) return false;
  return data == Icons.arrow_drop_down ||
      data == Icons.arrow_drop_down_rounded ||
      data == Icons.arrow_drop_down_circle ||
      data == Icons.arrow_drop_down_circle_outlined ||
      data == Icons.keyboard_arrow_down ||
      data == Icons.keyboard_arrow_down_rounded ||
      data == Icons.expand_more ||
      data == Icons.expand_more_rounded ||
      data == Icons.arrow_downward ||
      data == Icons.arrow_downward_rounded;
}

String? _longestTextDescendant(
  Element element, {
  bool substantialOnly = false,
}) {
  String? longest;
  void visit(Element e) {
    final w = e.widget;
    String? value;
    if (w is Text) {
      value = _textWidgetCaption(w);
    } else if (w is RichText) {
      if (_hasIconPaintAncestor(e)) {
        value = null;
      } else {
        value = w.text.toPlainText();
      }
    }
    if (value != null &&
        value.trim().isNotEmpty &&
        (!substantialOnly || _isSubstantialControlCaption(value))) {
      if (longest == null || value.length > longest!.length) {
        longest = value;
      }
    }
    e.visitChildren(visit);
  }

  element.visitChildren(visit);
  return longest;
}
