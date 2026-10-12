// Dart 3.8 reports deprecated_member_use at RegExp construction sites even though
// the deprecation is specifically about implementing RegExp. Keep construction compatible
// with this SDK without suppressing diagnostics in unrelated files.
// ignore_for_file: deprecated_member_use
part of 'element_semantics.dart';

/// Non-interactive visual card chrome (bordered / Material [Card] panel).
///
/// FeedbackInput and similar Ensemble boxes look like cards but have no onTap.
/// We still keep them so texts / rating icons nest under a `card` container
/// instead of floating as siblings. Prefer the outermost card-like host.
///
/// Also covers undecorated list-entry Columns (ExtenderItem on Fixed): title +
/// nested "Edit name" action with no border — without this, duplicate Edit
/// name buttons float as root siblings with identical selectors.
///
/// Skip decorative wrappers (e.g. theme `wrapperCard*`) that only chrome an
/// already-keyed / tappable card — those would become card-inside-card.
/// Also skip panels inside a toast banner — the toast host is the container.
bool isVisualCardContainerElement(Element element) {
  if (_isGenericTapTarget(element.widget)) return false;
  if (_isUnderToastOverlay(element)) return false;
  // Never nest inert chrome under a button/icon primary — that inverts
  // NotificationCard into `button > card` when a keyed CTA wraps chrome.
  if (_hasButtonOrIconPrimaryAncestor(element)) return false;

  final decorated = _isCardLikeSurface(element);
  final listEntry = !decorated && _looksLikeUndecoratedListEntry(element);
  if (!decorated && !listEntry) return false;
  if (!_looksLikeCardPanelBounds(boundsFor(element)) && !listEntry) {
    return false;
  }
  if (listEntry && !_looksLikeListEntryPanelBounds(boundsFor(element))) {
    return false;
  }
  if (!_hasObservableCardContent(element)) return false;
  if (_hasNestedCardPrimary(element)) return false;

  var underCard = false;
  element.visitAncestorElements((ancestor) {
    if (_isGroupingCardAncestor(ancestor)) {
      underCard = true;
      return false;
    }
    return true;
  });
  return !underCard;
}

/// Ancestor already groups content as a card / list-entry scope.
bool _isGroupingCardAncestor(Element ancestor) {
  if (_isGenericTapTarget(ancestor.widget)) return false;
  if (_isCardLikeSurface(ancestor) &&
      _looksLikeCardPanelBounds(boundsFor(ancestor))) {
    return true;
  }
  return _looksLikeUndecoratedListEntry(ancestor);
}

/// ExtenderItem-style vertical stack: captions + one nested tap action, no
/// border/fill chrome. Rejects page body / itemTemplate host Columns that
/// stack multiple entries (multiple tap actions).
bool _looksLikeUndecoratedListEntry(Element element) {
  if (!_isVerticalBoxHost(element.widget)) return false;
  if (!_looksLikeListEntryPanelBounds(boundsFor(element))) return false;
  if (!_hasObservableCardContent(element)) return false;
  return _countTopLevelNestedTapActions(element) == 1;
}

bool _isVerticalBoxHost(Widget widget) {
  if (widget is Column) return true;
  if (widget is Flex && widget.direction == Axis.vertical) return true;
  final base = widget.runtimeType.toString().split('<').first;
  return base == 'Column' ||
      base == 'FlexColumn' ||
      base == 'ScrollableColumn' ||
      base == 'FittedColumn';
}

bool _looksLikeListEntryPanelBounds(UiBounds? bounds) {
  if (bounds == null) return false;
  if (bounds.width < 180 || bounds.height < 56) return false;
  // Cap height so page body / multi-item template hosts are not one card.
  if (bounds.height > 220) return false;
  return bounds.width / bounds.height >= 1.15;
}

/// Enabled tap targets that are not nested under another tap target.
int _countTopLevelNestedTapActions(Element element) {
  var count = 0;
  void visit(Element e) {
    if (count > 1) return;
    if (identical(e, element)) {
      e.visitChildren(visit);
      return;
    }
    final w = e.widget;
    if (_isGenericTapTarget(w) && _genericTapTargetIsEnabled(w)) {
      count += 1;
      return;
    }
    e.visitChildren(visit);
  }

  element.visitChildren(visit);
  return count;
}

/// True when a button/icon primary already wraps [element].
///
/// Uses light typing only — must not call [inferWidgetType] / visual-card
/// helpers (those re-enter this check).
bool _hasButtonOrIconPrimaryAncestor(Element element) {
  var found = false;
  element.visitAncestorElements((ancestor) {
    if (!isPrimaryControlElement(ancestor)) return true;
    final self = _inferElementWidgetType(ancestor);
    if (self == 'button' || self == 'icon') {
      found = true;
      return false;
    }
    if (!_isGenericTapTarget(ancestor.widget)) return true;
    final bounds = boundsFor(ancestor);
    // Real card/row hosts — nested chrome under those is fine; stop walking.
    if (_looksLikeCardHitTarget(bounds) || _looksLikeListRowHitTarget(bounds)) {
      return false;
    }
    // Compact / CTA-sized tap targets (NotificationCard "Turn on", dismiss).
    found = true;
    return false;
  });
  return found;
}

/// Keyed host is a loose section wrapper, not the CTA / banner itself.
bool _keyedHostIsLooseSectionShell(Element host, Element primary) {
  final hostBounds = boundsFor(host);
  final primaryBounds = boundsFor(primary);
  if (hostBounds == null || primaryBounds == null) return false;
  final hostArea = hostBounds.width * hostBounds.height;
  final primaryArea = primaryBounds.width * primaryBounds.height;
  if (primaryArea <= 0) return false;
  return hostArea > primaryArea * 3;
}

/// Keyed host wraps banner chrome larger than its CTA [primary] InkWell.
///
/// Only when [primary] is the whole-card hit target (Ensemble decoration+onTap
/// on one widget). A small nested CTA inside NotificationCard must not retype
/// a section KeyedSubtree (`Recommendations`) as `card` — that yields card>card.
bool _keyedHostWrapsCardPanelChrome(Element host, Element primary) {
  final primaryBounds = boundsFor(primary);
  if (primaryBounds == null) return false;

  Element? cardChrome;
  primary.visitAncestorElements((ancestor) {
    if (identical(ancestor, host)) return false;
    if (_isCardLikeSurface(ancestor) &&
        _looksLikeCardPanelBounds(boundsFor(ancestor))) {
      cardChrome = ancestor;
      return false;
    }
    return true;
  });
  if (cardChrome == null) return false;

  final chromeBounds = boundsFor(cardChrome!);
  if (chromeBounds == null) return false;
  final primaryArea = primaryBounds.width * primaryBounds.height;
  final chromeArea = chromeBounds.width * chromeBounds.height;
  if (chromeArea <= 0) return false;
  return primaryArea >= chromeArea * 0.45;
}

/// True when a descendant is already the real card (keyed and/or tappable).
bool _hasNestedCardPrimary(Element element) {
  var found = false;
  void visit(Element e) {
    if (found || identical(e, element)) {
      if (!found) e.visitChildren(visit);
      return;
    }
    final keyed = hasCompactValueKey(e) || readOwnedWidgetLocatorId(e) != null;
    if (_isGenericTapTarget(e.widget)) {
      // Material footer CTAs inside a bottom sheet / panel must not disqualify
      // the panel as visual-card chrome (otherwise close icons lose `within`).
      if (_isMaterialButtonWidget(e.widget)) {
        e.visitChildren(visit);
        return;
      }
      final bounds = boundsFor(e);
      if (_looksLikeCardHitTarget(bounds) ||
          _looksLikeListRowHitTarget(bounds)) {
        // Tappable card/row — wrapper is just chrome. Require the tap surface
        // to cover a large share of this panel so short full-width buttons
        // (sheet footer) do not count.
        final parentBounds = boundsFor(element);
        if (parentBounds != null &&
            bounds != null &&
            bounds.width >= parentBounds.width * 0.85 &&
            bounds.height >= parentBounds.height * 0.45) {
          found = true;
          return;
        }
        if (_looksLikeCardHitTarget(bounds) &&
            !_looksLikeListRowHitTarget(bounds)) {
          found = true;
          return;
        }
      }
      // Nested CTA / dismiss InkWells (NotificationCard "Turn on") are not
      // the card primary — only card-sized keyed hosts (device_card).
      if (keyed &&
          bounds != null &&
          (bounds.width > 96 || bounds.height > 72) &&
          !_looksLikeCompactIconHitTarget(e)) {
        found = true;
        return;
      }
    }
    if (keyed && _isCardLikeSurface(e)) {
      found = true;
      return;
    }
    e.visitChildren(visit);
  }

  element.visitChildren(visit);
  return found;
}

bool _isMaterialButtonWidget(Widget widget) {
  return widget is ElevatedButton ||
      widget is TextButton ||
      widget is OutlinedButton ||
      widget is FilledButton;
}

bool _isCardLikeSurface(Element element) {
  final widget = element.widget;
  if (widget is Card) return true;
  if (_decorationLooksLikeCard(_boxDecorationOf(widget))) return true;
  if (_ensembleBoxLooksLikeCard(widget)) return true;
  return false;
}

bool _ensembleBoxLooksLikeCard(Widget widget) {
  if (widget is! HasController) return false;
  final controller = widget.controller;
  if (controller is! BoxController) return false;
  if (controller.hasBorder() && controller.borderRadius != null) return true;
  // Soft tiles: radius + fill (e.g. theme `.wrapperCard*`) without a stroke.
  if (controller.borderRadius != null &&
      (controller.backgroundColor != null || controller.hasBoxShadow())) {
    return true;
  }
  if (widget is Invokable) {
    final className =
        _invokableProperty(widget as Invokable, 'className')?.toString() ?? '';
    if (RegExp(r'card', caseSensitive: false).hasMatch(className)) {
      return true;
    }
  }
  return false;
}

BoxDecoration? _boxDecorationOf(Widget widget) {
  if (widget is Container && widget.decoration is BoxDecoration) {
    return widget.decoration as BoxDecoration;
  }
  if (widget is DecoratedBox && widget.decoration is BoxDecoration) {
    return widget.decoration as BoxDecoration;
  }
  if (widget is Material) {
    final shape = widget.shape;
    if (shape is RoundedRectangleBorder &&
        (widget.color != null || shape.side.width > 0)) {
      return BoxDecoration(
        color: widget.color,
        borderRadius: shape.borderRadius,
        border: shape.side.width > 0 ? Border.fromBorderSide(shape.side) : null,
      );
    }
  }
  return null;
}

bool _decorationLooksLikeCard(BoxDecoration? decoration) {
  if (decoration == null) return false;
  final hasRadius = decoration.borderRadius != null;
  final hasBorder = decoration.border != null;
  final hasFill = decoration.color != null ||
      decoration.gradient != null ||
      (decoration.boxShadow != null && decoration.boxShadow!.isNotEmpty);
  // FeedbackInput: stroke + radius. Soft cards: fill/shadow + radius.
  if (hasRadius && hasBorder) return true;
  if (hasRadius && hasFill) return true;
  return false;
}

bool _looksLikeCardPanelBounds(UiBounds? bounds) {
  if (bounds == null) return false;
  if (bounds.width <= 0 || bounds.height <= 0) return false;
  // Wide panels (page feedback) and mini tiles.
  return bounds.width >= 140 && bounds.height >= 64;
}

bool _hasObservableCardContent(Element element) {
  var texts = 0;
  var actions = 0;
  void visit(Element e) {
    if (texts >= 1 && actions >= 1) return;
    final w = e.widget;
    if (w is Text && _textWidgetCaption(w) != null) {
      texts += 1;
    } else if (w is RichText && w.text.toPlainText().trim().isNotEmpty) {
      texts += 1;
    }
    if (_isGenericTapTarget(w) ||
        _isIconButtonWidget(w) ||
        w is Icon ||
        w is ImageIcon) {
      actions += 1;
    }
    e.visitChildren(visit);
  }

  element.visitChildren(visit);
  // A card needs grouping value: caption + chrome, or several captions.
  return (texts >= 1 && actions >= 1) || texts >= 2;
}
