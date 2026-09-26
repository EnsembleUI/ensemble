import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/image.dart';
import 'package:ensemble/widget/lottie/lottie.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/session/local/modal_route_lookup.dart';
import 'package:ensemble_test_runner/session/local/widget_locator_id.dart';
import 'package:ensemble_test_runner/session/observation/ui_element.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a semantic [UiElement] snapshot from a live Flutter [Element].
///
/// Shared by [FlutterUiObserver] and live fingerprint revalidation so observe
/// and act agree on observable state.
///
/// When [useSemantics] is false (diagnostic / report snapshots), skips
/// [WidgetTester.getSemantics] label reads. When [registerRouteDependency] is
/// false, visibility uses a dependency-free current-route check so hot-path
/// dumps do not subscribe every element to `_ModalScopeStatus`.
UiElement describeElement({
  required Element element,
  required String elementId,
  required String? testId,
  required AssertionEngine assertions,
  required WidgetTester tester,
  required bool includeBounds,
  bool useSemantics = true,
  bool registerRouteDependency = true,
}) {
  final type = resolveObservedWidgetType(element, testId: testId);
  final primary = type != 'widget' && testId != null && testId.isNotEmpty
      ? findPrimaryControlDescendant(element)
      : null;
  final semanticsSource = primary ?? element;
  final secure = looksSecure(semanticsSource, testId);
  final bounds = boundsFor(element);
  final visible = registerRouteDependency
      ? assertions.isElementVisuallyActionable(element)
      : isElementGeometricallyVisible(element, tester);
  final offscreen = bounds != null && !inViewport(tester, bounds);
  // Icons: only report enabled for real icon buttons / compact chrome —
  // do not inherit `onTap` from a parent card/list-row InkWell.
  // Compact Ensemble Icon(onTap) → InkWell is the host: use readEnabled.
  // Leaf glyph under a compact Row (WifiCard eye-show) inherits that host.
  final bool? enabled;
  if (type == 'icon') {
    final iconEnabled = readIconButtonEnabled(semanticsSource);
    if (iconEnabled != null) {
      enabled = iconEnabled;
    } else if (_isGenericTapTarget(semanticsSource.widget)) {
      enabled = readEnabled(semanticsSource);
    } else {
      enabled = readEnabledFromCompactTapAncestor(semanticsSource);
    }
  } else if (type == 'toast') {
    enabled = null;
  } else if (type == 'card') {
    enabled = readCardEnabled(semanticsSource);
  } else {
    enabled = readEnabled(semanticsSource);
  }
  final checked = readChecked(semanticsSource);
  final selected = useSemantics ? readSelected(tester, semanticsSource) : null;
  var text = secure ? null : readText(semanticsSource);
  var label = secure
      ? null
      : (useSemantics
          ? readControlLabel(semanticsSource, tester)
          : readControlLabelWithoutSemantics(semanticsSource));
  final hint = secure ? null : readHint(semanticsSource);
  // Icons rarely have Text; fall back to tooltip / semanticLabel only.
  if (type == 'icon') {
    if ((text == null || text.isEmpty) && (label == null || label.isEmpty)) {
      final iconName = readIconName(semanticsSource);
      if (iconName != null && iconName.isNotEmpty) {
        text = iconName;
      }
    }
    // Nested icons inherit a parent card's merged semantics ("Guest wifi
    // KPN_Gast") — drop those. Keep labels on compact tappable chrome
    // (CloseAppButton) and on Semantics authored for that chrome.
    final trimmedLabel = label?.trim();
    if (trimmedLabel != null &&
        trimmedLabel.isNotEmpty &&
        (text == null || trimmedLabel != text.trim()) &&
        !_shouldKeepIconSemanticsLabel(semanticsSource, trimmedLabel)) {
      label = null;
    }
  }
  // Standalone text: never keep a merged semantics label (e.g. "Wifi naam KPN"
  // shared by both the label and value Text nodes).
  if (type == 'text') {
    final trimmedText = text?.trim();
    final trimmedLabel = label?.trim();
    if (trimmedLabel != null &&
        trimmedText != null &&
        trimmedLabel != trimmedText) {
      label = null;
    }
  }
  // Images / SVG / GIF / Lottie: surface source basename when there is no
  // semantic label (common for decorative Ensemble Image widgets).
  if (_isMediaObserveType(type)) {
    final desc = readMediaDescription(semanticsSource);
    // Nested AppIcon / SVG under a button inherits the parent row's a11y
    // label (WifiCard embeds `${addSpaces(password)}`). Never publish that
    // as the image title — prefer source basename, else nothing.
    if (hasPrimaryControlAncestor(semanticsSource)) {
      text = (desc != null && desc.isNotEmpty) ? desc : null;
      label = null;
    } else if ((text == null || text.isEmpty) &&
        desc != null &&
        desc.isNotEmpty) {
      text = desc;
    }
  }
  // Switches/checkboxes shouldn't inherit nearby label Text as "value".
  if ((type == 'switch' || type == 'toggle' || type == 'checkbox') &&
      checked != null) {
    text = null;
  }
  // textInput value is editable content only — never hint/label Text.
  if (type == 'textInput' &&
      hint != null &&
      text != null &&
      text.trim() == hint.trim()) {
    text = null;
  }
  final options = type == 'dropdown'
      ? readDropdownOptions(semanticsSource)
      : const <String>[];
  // Buttons / cards: surface the visible caption as [label] when semantics did
  // not provide one — agents author `target: { label, role: button }`.
  final effectiveLabel = _effectiveControlLabel(
    type: type,
    label: label,
    text: text,
  );
  final actions = supportedActionsFor(
    type,
    secure: secure,
    enabled: enabled,
    testId: testId,
    text: text,
    label: effectiveLabel,
  );
  // Interactable = can run a gesture/edit step on this node right now.
  final interactable = visible &&
      !offscreen &&
      enabled != false &&
      actions.any(_isInteractionStep);

  return UiElement(
    elementId: elementId,
    testId: testId,
    type: type,
    role: inferSemanticRole(semanticsSource, type),
    label: effectiveLabel,
    text: text,
    hint: hint,
    options: options,
    state: UiElementState(
      exists: true,
      visible: visible,
      interactable: interactable,
      enabled: enabled,
      secure: secure,
      offscreen: offscreen,
      // Hit testing against overlays is not verified by the observer.
      obscured: null,
      selected: selected,
      checked: checked,
    ),
    bounds: includeBounds ? bounds : null,
    supportedActions: actions,
  );
}

/// Accessible name for controls that lack a semantics label (Ensemble tabs).
String? _effectiveControlLabel({
  required String type,
  required String? label,
  required String? text,
}) {
  final trimmedLabel = label?.trim();
  if (trimmedLabel != null && trimmedLabel.isNotEmpty) return trimmedLabel;
  final t = type.toLowerCase();
  if (t != 'button' && t != 'card' && t != 'icon') return label;
  final trimmedText = text?.trim();
  if (trimmedText == null || trimmedText.isEmpty) return label;
  return trimmedText;
}

/// Nearest primary-control descendant, if any.
///
/// Prefers specific controls (switch, dropdown, icon, …) over generic
/// [GestureDetector]/[InkWell] wrappers that often wrap them.
Element? findPrimaryControlDescendant(Element element) {
  Element? specific;
  Element? generic;
  void visit(Element e) {
    if (isPrimaryControlElement(e)) {
      if (_isGenericTapTarget(e.widget)) {
        generic ??= e;
      } else {
        specific ??= e;
      }
      return;
    }
    e.visitChildren(visit);
  }

  element.visitChildren(visit);
  return specific ?? generic;
}

/// When a keyed Ensemble wrapper is typed generically, prefer the logical
/// control it owns (Checkbox → checkbox, TextField → textInput, …).
///
/// Also refines ancestor-derived `card`/`button` when the keyed host wraps a
/// specific control — so `testId` on a Checkbox inside a tappable FlexRow is
/// not reported as a list-row card. The FlexRow itself stays a separate `card`
/// observe row when it is also kept.
String resolveObservedWidgetType(Element element, {required String? testId}) {
  final type = inferWidgetType(element);
  if (!_isGenericTapTarget(element.widget)) {
    final ownedSpecific = _specificPrimaryControlDescendant(element);
    if (ownedSpecific != null) {
      final ownedType = _inferElementWidgetType(ownedSpecific);
      if (ownedType != null &&
          (type == 'widget' || type == 'card' || type == 'button')) {
        // Bottom sheets / feedback panels are visual cards that contain footer
        // CTAs — do not retype the panel as that button (loses card `within`
        // for nested dismiss icons).
        if (type == 'card' && (ownedType == 'button' || ownedType == 'icon')) {
          return type;
        }
        return ownedType;
      }
    }
  }
  if (type != 'widget') return type;
  if (testId == null || testId.isEmpty) return type;
  final primary = findPrimaryControlDescendant(element);
  if (primary != null) {
    final primaryType = inferWidgetType(primary);
    // KeyedSubtree(testId) outside a small CTA InkWell that still wraps
    // banner chrome (Ensemble decoration+onTap+testId on one host) must not
    // observe as `button` parenting an inner `card`.
    if (primaryType == 'button' &&
        _keyedHostWrapsCardPanelChrome(element, primary)) {
      return 'card';
    }
    // Section shells (Recommendations) are much larger than their nested CTA —
    // do not promote the shell to `button` (avoids button > card nesting).
    if (_keyedHostIsLooseSectionShell(element, primary)) {
      return 'widget';
    }
    return primaryType;
  }
  String? nestedType;
  void visitNested(Element e) {
    if (nestedType != null) return;
    if (isStandaloneTextElement(e)) {
      nestedType = 'text';
      return;
    }
    if (isStandaloneMediaElement(e)) {
      nestedType = mediaWidgetType(e.widget) ?? 'image';
      return;
    }
    e.visitChildren(visitNested);
  }

  element.visitChildren(visitNested);
  return nestedType ?? type;
}

String inferSemanticRole(Element element, String type) {
  final widget = element.widget;
  if (widget is Semantics) {
    final properties = widget.properties;
    if (properties.button == true) return 'button';
    if (properties.textField == true) return 'textField';
    if (properties.slider == true) return 'slider';
    if (properties.checked != null) return 'checkbox';
  }
  if (_selfOrAncestor<Checkbox>(element) != null) return 'checkbox';
  if (_selfOrAncestor<Switch>(element) != null ||
      _selfOrAncestor<CupertinoSwitch>(element) != null) {
    return 'switch';
  }
  if (_selfOrAncestor<Slider>(element) != null) return 'slider';
  if (type == 'textInput') return 'textField';
  return type;
}

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
/// Used by observe / inspect-ui so one [TextField] yields one `textInput` row
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
      // the card primary — only card-sized keyed hosts (gateway_card).
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

/// Nested actionable / chrome controls kept under a tappable card/row ancestor.
///
/// Without this, anything under a FlexRow/GestureDetector primary was dropped —
/// so agents never saw info icons, nested IconButtons, or unkeyed checkboxes
/// inside settings rows. Excludes structural wrappers and leaves under a more
/// specific host (Icon under IconButton, etc.). Nav chevrons are kept so the
/// observe tree mirrors what is on screen.
bool isNestedActionableElement(Element element) {
  if (!hasPrimaryControlAncestor(element)) return false;

  final widget = element.widget;

  // Specific interactive hosts nested in a row/card.
  if (_isSpecificNestedActionHost(widget)) {
    // KeyedSubtree(testId) → Checkbox: the keyed host is already kept as this
    // control. Keeping the leaf too duplicates id/type in the tree + overlay.
    if (_isRedundantLeafUnderKeyedControlWrapper(element)) return false;
    return true;
  }
  if (widget is EditableText) return false;

  if (_isGenericTapTarget(widget)) {
    // Inside Checkbox/TextField/IconButton — the host is the action, not this.
    if (_hasSpecificControlAncestor(element)) return false;
    // Nested under another nested action host — keep outermost only.
    if (_hasNestedActionTapWrapperAncestor(element)) return false;
    // KeyedSubtree(back_button) → InkWell: shell already observes as icon.
    if (isRedundantLeafUnderKeyedIconShell(element)) return false;
    if (!_genericTapTargetIsEnabled(widget)) return false;

    final bounds = boundsFor(element);
    if (bounds == null) return false;
    // Full-row / card-sized wrappers are the parent primary, not a nested action.
    if (_looksLikeCardHitTarget(bounds) || _looksLikeListRowHitTarget(bounds)) {
      return false;
    }

    final text = _longestTextDescendant(element);
    final substantialText = text != null && text.trim().length > 2;

    // Compact icon / glyph chrome (info, overflow, close, chevron, …).
    if (_looksLikeCompactIconHitTarget(element)) {
      if (substantialText) return false;
      return _hasIconDescendant(element) ||
          _mediaTypeFromDescendant(element) != null ||
          (text != null && text.trim().isNotEmpty);
    }

    // Smaller nested CTA / link inside a card (not the whole row).
    if (substantialText && bounds.width <= 220 && bounds.height <= 56) {
      return true;
    }
    return false;
  }

  // Plain Icon / ImageIcon chrome on a settings row (may or may not be wrapped).
  // Icon-only compact hosts already exclude leaves via `_isUnderCompactIconControl`.
  // Caption+icon Rows (WifiCard eye) keep the leaf so agents can tap the glyph.
  if (widget is Icon) {
    if (_isUnderCompactIconControl(element)) return false;
    if (_hasSpecificControlAncestor(element)) return false;
    if (_hasIconButtonAncestor(element)) return false;
    if (!_looksLikeCompactIconHitTarget(element)) return false;
    return true;
  }
  if (widget is ImageIcon) {
    if (_isUnderCompactIconControl(element)) return false;
    if (_hasSpecificControlAncestor(element)) return false;
    if (_hasIconButtonAncestor(element)) return false;
    if (!_looksLikeCompactIconHitTarget(element)) return false;
    return true;
  }
  return false;
}

/// Leaf text/media under a keyed compact icon shell (back button, etc.).
///
/// The keyed host already observes as `icon` — keeping the leaf duplicates the
/// row (and overlays) with the same id.
bool isRedundantLeafUnderKeyedIconShell(Element element) {
  Element? keyed;
  element.visitAncestorElements((ancestor) {
    if (hasCompactValueKey(ancestor) ||
        readOwnedWidgetLocatorId(ancestor) != null) {
      keyed = ancestor;
      return false;
    }
    return true;
  });
  if (keyed == null) return false;

  final hostBounds = boundsFor(keyed!);
  if (hostBounds != null &&
      (_looksLikeCardHitTarget(hostBounds) ||
          _looksLikeListRowHitTarget(hostBounds))) {
    return false;
  }
  if (_looksLikeCompactIconHitTarget(keyed!)) return true;
  if (hostBounds != null && hostBounds.width <= 72 && hostBounds.height <= 72) {
    return true;
  }
  // KeyedSubtree → IconButton / compact InkWell.
  final primary = findPrimaryControlDescendant(keyed!);
  if (primary == null) return false;
  if (_isIconButtonWidget(primary.widget)) return true;
  if (_isGenericTapTarget(primary.widget) &&
      _looksLikeCompactIconHitTarget(primary)) {
    return true;
  }
  return false;
}

/// True when a compact icon control (IconButton / glyph InkWell) already wraps
/// [element] — leaf Icon/Image/text under that host is redundant.
bool _isUnderCompactIconControl(Element element) {
  var found = false;
  element.visitAncestorElements((ancestor) {
    final w = ancestor.widget;
    if (_isIconButtonWidget(w)) {
      found = true;
      return false;
    }
    if (!_isGenericTapTarget(w) || !_genericTapTargetIsEnabled(w)) {
      return true;
    }
    final bounds = boundsFor(ancestor);
    if (bounds == null) return true;
    // Card / settings row — stop; nested icons/text under those are intentional.
    if (_looksLikeCardHitTarget(bounds) || _looksLikeListRowHitTarget(bounds)) {
      return false;
    }
    if (_looksLikeCompactIconHitTarget(ancestor)) {
      found = true;
      return false;
    }
    // Compact tappable chrome (≤72) without a real caption.
    if (bounds.width <= 72 && bounds.height <= 72) {
      final text = _longestTextDescendant(ancestor);
      if (text == null || text.trim().length <= 1) {
        found = true;
        return false;
      }
    }
    return true;
  });
  return found;
}

/// Caption [Text] that only repeats the nearest button/card/dropdown title.
bool _isRedundantCaptionOfNearestPrimary(Element element) {
  final own = _visibleTextOf(element);
  if (own == null) return false;

  Element? primary;
  element.visitAncestorElements((ancestor) {
    if (isPrimaryControlElement(ancestor)) {
      primary = ancestor;
      return false;
    }
    return true;
  });
  if (primary == null) return false;

  final primaryType = inferWidgetType(primary!);
  // Only collapse under buttons / dropdowns — tappable cards still drop the
  // matching title in [dropRedundantNestedObserveLeaves] when interactable.
  if (primaryType != 'button' && primaryType != 'dropdown') {
    return false;
  }

  final primaryText = _longestTextDescendant(primary!)?.trim();
  if (primaryText == null || primaryText.isEmpty) return false;
  if (own == primaryText) return true;
  final firstLine = primaryText.split('\n').first.trim();
  return firstLine == own;
}

String? _visibleTextOf(Element element) {
  final w = element.widget;
  if (w is Text) {
    return _textWidgetCaption(w);
  }
  if (w is RichText) {
    final data = w.text.toPlainText().trim();
    return data.isNotEmpty ? data : null;
  }
  return null;
}

bool _isSpecificNestedActionHost(Widget widget) {
  return widget is Checkbox ||
      widget is Switch ||
      widget is CupertinoSwitch ||
      widget is Slider ||
      widget is TextField ||
      widget is CupertinoTextField ||
      widget is ElevatedButton ||
      widget is TextButton ||
      widget is OutlinedButton ||
      widget is FilledButton ||
      _isIconButtonWidget(widget) ||
      _isDropdownWidget(widget);
}

/// True when the nearest compact-keyed ancestor already observes as [element]
/// (e.g. [KeyedSubtree] with ValueKey wrapping a [Checkbox]).
///
/// Large keyed shells (page / card rows) are excluded so an unkeyed checkbox
/// under a keyed page still surfaces as its own nested action.
bool _isRedundantLeafUnderKeyedControlWrapper(Element element) {
  Element? keyed;
  element.visitAncestorElements((ancestor) {
    if (hasCompactValueKey(ancestor)) {
      keyed = ancestor;
      return false;
    }
    return true;
  });
  if (keyed == null) return false;
  // Row/card GestureDetector with a key is the parent surface, not a
  // checkbox host — keep the nested specific control.
  if (_isGenericTapTarget(keyed!.widget)) return false;

  final owned = _specificPrimaryControlDescendant(keyed!);
  if (!identical(owned, element)) return false;

  final hostBounds = boundsFor(keyed!);
  if (hostBounds != null &&
      (_looksLikeCardHitTarget(hostBounds) ||
          _looksLikeListRowHitTarget(hostBounds))) {
    return false;
  }
  // Viewport-sized keyed shells (page roots) — leaf must stay.
  if (hostBounds != null &&
      (hostBounds.width >= 280 && hostBounds.height >= 280)) {
    return false;
  }
  return true;
}

bool _genericTapTargetIsEnabled(Widget widget) {
  if (widget is InkWell) return widget.onTap != null;
  if (widget is InkResponse) return widget.onTap != null;
  if (widget is GestureDetector) {
    return widget.onTap != null ||
        widget.onTapUp != null ||
        widget.onTapDown != null;
  }
  return false;
}

bool _hasNestedActionTapWrapperAncestor(Element element) {
  var found = false;
  element.visitAncestorElements((ancestor) {
    final w = ancestor.widget;
    if (!_isGenericTapTarget(w)) return true;
    final bounds = boundsFor(ancestor);
    if (bounds == null) return true;
    // Large card/row — stop; nested actions live under this.
    if (_looksLikeCardHitTarget(bounds) || _looksLikeListRowHitTarget(bounds)) {
      return false;
    }
    if (_looksLikeCompactIconHitTarget(ancestor) ||
        (bounds.width <= 220 && bounds.height <= 56)) {
      if (_genericTapTargetIsEnabled(w)) {
        found = true;
        return false;
      }
    }
    return true;
  });
  return found;
}

/// Observed type for [widget] when it is image/svg/gif/lottie media.
String? mediaWidgetType(Widget widget) {
  if (widget is EnsembleImage) {
    return _mediaTypeForSource(widget.controller.source, fallback: 'image');
  }
  if (widget is EnsembleLottie) return 'lottie';
  if (widget is Image || widget is RawImage) {
    return _mediaTypeForImageProvider(
      widget is Image ? widget.image : null,
      fallback: 'image',
    );
  }
  final base = widget.runtimeType.toString().split('<').first;
  switch (base) {
    case 'SvgPicture':
      return 'svg';
    case 'CachedNetworkImage':
    case 'FadeInImage':
      return 'image';
    case 'Lottie':
    case 'LottieBuilder':
      return 'lottie';
    default:
      return null;
  }
}

String? _mediaTypeFromDescendant(Element element) {
  String? found;
  void visit(Element e) {
    if (found != null) return;
    found = mediaWidgetType(e.widget);
    if (found != null) return;
    e.visitChildren(visit);
  }

  element.visitChildren(visit);
  return found;
}

bool _hasMediaHostAncestor(Element element) {
  var found = false;
  element.visitAncestorElements((ancestor) {
    final w = ancestor.widget;
    if (w is EnsembleImage || w is EnsembleLottie) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

String _mediaTypeForSource(Object? source, {required String fallback}) {
  final raw = source?.toString().trim().toLowerCase() ?? '';
  if (raw.endsWith('.svg') || raw.contains('.svg?')) return 'svg';
  if (raw.endsWith('.gif') ||
      raw.contains('.gif?') ||
      raw.contains('image/gif')) {
    return 'gif';
  }
  if (raw.endsWith('.json') ||
      raw.contains('.json?') ||
      raw.contains('lottie')) {
    return 'lottie';
  }
  return fallback;
}

String _mediaTypeForImageProvider(
  ImageProvider? provider, {
  required String fallback,
}) {
  if (provider == null) return fallback;
  final desc = provider.toString().toLowerCase();
  if (desc.contains('.gif') || desc.contains('image/gif')) return 'gif';
  if (desc.contains('.svg')) return 'svg';
  return fallback;
}

/// Basename / short label for media source (observe Title column).
String? readMediaDescription(Element element) {
  final widget = element.widget;
  if (widget is EnsembleImage) {
    return _mediaSourceLabel(widget.controller.source);
  }
  if (widget is EnsembleLottie) {
    return _mediaSourceLabel(widget.controller.source);
  }
  if (widget is Image) {
    return _mediaSourceLabel(widget.image);
  }
  return null;
}

String? _mediaSourceLabel(Object? source) {
  if (source == null) return null;
  if (source is List) return 'memory';
  var raw = source.toString().trim();
  if (raw.isEmpty) return null;
  // ImageProvider debug strings — keep short.
  final assetMatch = RegExp(r'AssetImage\(name:\s*"([^"]+)"\)').firstMatch(raw);
  if (assetMatch != null) raw = assetMatch.group(1)!;
  final networkMatch = RegExp(r'NetworkImage\("([^"]+)"').firstMatch(raw);
  if (networkMatch != null) raw = networkMatch.group(1)!;
  final uri = Uri.tryParse(raw);
  final path = (uri != null && uri.path.isNotEmpty) ? uri.path : raw;
  final segments = path.split('/');
  final base = segments.isNotEmpty ? segments.last : path;
  final cleaned = base.split('?').first.trim();
  return cleaned.isEmpty ? null : cleaned;
}

/// True when a primary control already wraps [element] (nested InkWell, etc.).
bool hasPrimaryControlAncestor(Element element) {
  var found = false;
  element.visitAncestorElements((ancestor) {
    if (isPrimaryControlElement(ancestor)) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

bool isTextLocatorCandidate(Element element) {
  final widget = element.widget;
  return widget is Text ||
      widget is RichText ||
      widget is EditableText ||
      isSemanticLocatorCandidate(element);
}

T? _selfOrAncestor<T extends Widget>(Element element) {
  final w = element.widget;
  if (w is T) return w;
  return element.findAncestorWidgetOfExactType<T>();
}

bool _isGenericTapTarget(Widget widget) =>
    widget is GestureDetector || widget is InkWell || widget is InkResponse;

bool _isDropdownWidget(Widget widget) {
  if (widget is DropdownButton ||
      widget is DropdownButtonFormField ||
      widget is DropdownMenu ||
      widget is PopupMenuButton) {
    return true;
  }
  // Ensemble (and dropdown_button2) use these — not Flutter's DropdownButton.
  final base = widget.runtimeType.toString().split('<').first;
  return base == 'DropdownButtonFormField2' ||
      base == 'EnsembleDropdown' ||
      base == 'DropdownButton2';
}

bool _isIconButtonWidget(Widget widget) {
  if (widget is IconButton) return true;
  // Ensemble IconButton renders FrameworkIconButton → Material + InkWell.
  final base = widget.runtimeType.toString().split('<').first;
  return base == 'FrameworkIconButton' || base == 'EnsembleIconButton';
}

bool _hasSpecificControlAncestor(Element element) {
  var found = false;
  element.visitAncestorElements((ancestor) {
    final w = ancestor.widget;
    if (w is ElevatedButton ||
        w is TextButton ||
        w is OutlinedButton ||
        w is FilledButton ||
        w is Switch ||
        w is CupertinoSwitch ||
        w is Checkbox ||
        w is Slider ||
        w is TextField ||
        w is CupertinoTextField ||
        _isIconButtonWidget(w) ||
        _isDropdownWidget(w)) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

String inferWidgetType(Element element) {
  // Prefer the element's own widget so keyed Text under a button stays `text`.
  final self = _inferElementWidgetType(element);
  if (self != null) return self;

  // Specific controls before generic tap targets — InkWell wraps switches,
  // dropdowns, and icon buttons and would otherwise inflate to `button`.
  if (_selfOrAncestor<EditableText>(element) != null ||
      _selfOrAncestor<TextField>(element) != null ||
      _selfOrAncestor<CupertinoTextField>(element) != null) {
    return 'textInput';
  }
  if (_selfOrAncestor<Switch>(element) != null ||
      _selfOrAncestor<CupertinoSwitch>(element) != null) {
    return 'switch';
  }
  if (_selfOrAncestor<Checkbox>(element) != null) {
    return 'checkbox';
  }
  if (_selfOrAncestor<Slider>(element) != null) {
    return 'slider';
  }
  if (_hasDropdownAncestor(element)) return 'dropdown';
  if (_hasIconButtonAncestor(element)) return 'icon';

  // Keyed Ensemble wrappers (KeyedSubtree + testId) sit *above* the real
  // Checkbox/Switch/TextField. Prefer that owned control over climbing to an
  // ancestor InkWell (e.g. FlexRow onTap) which would mis-type the box as a
  // list-row `card`.
  //
  // Do NOT apply this when [element] is itself a GestureDetector/InkWell —
  // those are the row/card surfaces and must keep card/button typing even if
  // they contain a checkbox (observe both: row as card, keyed box as checkbox).
  if (!_isGenericTapTarget(element.widget)) {
    final ownedSpecific = _specificPrimaryControlDescendant(element);
    if (ownedSpecific != null) {
      final ownedType = _inferElementWidgetType(ownedSpecific);
      if (ownedType != null) return ownedType;
    }
  }

  // Classify the nearest generic tap target by contents — do not stamp every
  // InkWell/GestureDetector as `button` (cards / list rows are common).
  Element? tapTarget;
  if (_isGenericTapTarget(element.widget)) {
    tapTarget = element;
  } else {
    element.visitAncestorElements((ancestor) {
      if (_isGenericTapTarget(ancestor.widget)) {
        tapTarget = ancestor;
        return false;
      }
      return true;
    });
  }
  if (tapTarget != null) return _inferGenericTapTargetType(tapTarget!);
  if (_selfOrAncestor<ElevatedButton>(element) != null ||
      _selfOrAncestor<TextButton>(element) != null ||
      _selfOrAncestor<OutlinedButton>(element) != null ||
      _selfOrAncestor<FilledButton>(element) != null) {
    return 'button';
  }
  return 'widget';
}

/// Nearest non-generic primary control under [element] (Checkbox, Switch, …).
Element? _specificPrimaryControlDescendant(Element element) {
  final primary = findPrimaryControlDescendant(element);
  if (primary == null) return null;
  if (_isGenericTapTarget(primary.widget)) return null;
  return primary;
}

bool _hasDropdownAncestor(Element element) {
  if (_isDropdownWidget(element.widget)) return true;
  var found = false;
  element.visitAncestorElements((ancestor) {
    if (_isDropdownWidget(ancestor.widget)) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

bool _hasIconButtonAncestor(Element element) {
  if (_isIconButtonWidget(element.widget)) return true;
  var found = false;
  element.visitAncestorElements((ancestor) {
    if (_isIconButtonWidget(ancestor.widget)) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

/// Type for [element] based on its own widget (and light child heuristics).
String? _inferElementWidgetType(Element element) {
  final widget = element.widget;
  if (widget is EditableText ||
      widget is TextField ||
      widget is CupertinoTextField) {
    return 'textInput';
  }
  if (widget is Switch || widget is CupertinoSwitch) return 'switch';
  if (widget is Checkbox) return 'checkbox';
  if (widget is Slider) return 'slider';
  if (_isDropdownWidget(widget)) return 'dropdown';
  if (_isIconButtonWidget(widget)) return 'icon';
  if (widget is Icon || widget is ImageIcon) return 'icon';
  final mediaType = mediaWidgetType(widget);
  if (mediaType != null) {
    // Compact Image/SVG used as back/close chrome should observe as `icon`,
    // not decorative `image` — especially Ensemble Image with onTap.
    if (_isCompactActionableMedia(element)) return 'icon';
    return mediaType;
  }
  if (widget is ElevatedButton ||
      widget is TextButton ||
      widget is OutlinedButton ||
      widget is FilledButton) {
    return 'button';
  }
  if (_isGenericTapTarget(widget)) {
    // Prefer specific Ensemble/host wrappers over bare InkWell typing.
    if (_hasDropdownAncestor(element)) return 'dropdown';
    if (_hasIconButtonAncestor(element)) return 'icon';
    return _inferGenericTapTargetType(element);
  }
  // Non-tappable bordered / Material cards (e.g. FeedbackInput panel).
  if (isVisualCardContainerElement(element) ||
      (widget is Card && _looksLikeCardPanelBounds(boundsFor(element)))) {
    return 'card';
  }
  if (widget is Text || widget is RichText) return 'text';
  return null;
}

/// Classify InkWell / GestureDetector by contents (Ensemble + host patterns).
///
/// Tappable ≠ button. Prefer:
/// - [toast] for FToast / Ensemble showToast banners
/// - [dropdown] for value+drop-down chevron
/// - [card] for tiles and settings rows (Devices / Speedtest / Guest wifi)
/// - [button] for Material buttons and compact text CTAs ("Get started →")
String _inferGenericTapTargetType(Element element) {
  final hasDropdownChevron = _hasDropdownChevronDescendant(element);
  final hasNavChevron = _hasNavigationChevronDescendant(element);
  final text = _longestTextDescendant(element);
  final hasIcon = _hasIconDescendant(element);
  // Prefer real captions over longer mask glyphs (WifiCard "••••" vs
  // "Wachtwoord") so the outer edit row is not mistyped as icon chrome.
  final substantialText = _longestSubstantialTextDescendant(element) != null;
  final compact = _looksLikeCompactIconHitTarget(element);
  final bounds = boundsFor(element);
  final keyId = readValueKeyLocatorId(element) ?? '';

  // Dropdowns: selected value text + drop-down chevron (not a list-row `>`).
  if (hasDropdownChevron) return 'dropdown';

  // Authoring ids that encode shape: `devices_mini_card`, `error_toast` —
  // require a toast/card token, not a camelCase substring (`tipsToast` is CSS).
  if (_authoringIdEncodesShape(keyId, 'card')) return 'card';
  if (_authoringIdEncodesShape(keyId, 'toast')) return 'toast';

  // Ensemble / fluttertoast overlays — before card heuristics (banner bounds
  // otherwise look like list-row cards, and FToast uses onTap: null → enabled=false).
  if (_looksLikeToast(element, bounds: bounds, hasNavChevron: hasNavChevron)) {
    return 'toast';
  }

  // Icon buttons: Flutter Icon, or compact glyph-only targets (language "A").
  // Also compact tappable images (back arrow / close X rendered as SVG/PNG) —
  // those are actionable controls, not decorative `image` rows.
  if (hasIcon && !substantialText) return 'icon';
  if (compact && (hasIcon || text == null || text.trim().length <= 1)) {
    return 'icon';
  }

  // Tappable illustration without a text label.
  final mediaType = _mediaTypeFromDescendant(element);
  if (mediaType != null && !substantialText) {
    // Small hit targets stay `icon` (nav / chrome). Larger surfaces keep the
    // media type only when the media dominates the hit target (hero / Lottie).
    // WifiCard show-password Row is wide with a 24px AppIcon SVG — that is
    // chrome, not a decorative `image` surface.
    if (compact || _looksLikeIconSizedMedia(bounds)) return 'icon';
    if (_mediaDominatesHitTarget(element, bounds)) return mediaType;
    return 'icon';
  }

  // Tile / mini-card / settings row — all observe as `card` for now.
  if (substantialText &&
      (_looksLikeCardHitTarget(bounds) ||
          _looksLikeListRowHitTarget(bounds) ||
          hasNavChevron)) {
    return 'card';
  }

  // Compact text CTAs and Material-style actions.
  return 'button';
}

/// True when [id] contains [token] as a snake/kebab/path segment or whole id.
///
/// `error_toast` / `toast` match; CSS-ish camelCase `tipsToast` does not.
bool _authoringIdEncodesShape(String id, String token) {
  final t = token.trim().toLowerCase();
  if (t.isEmpty || id.trim().isEmpty) return false;
  final parts = id
      .trim()
      .split(RegExp(r'[-_./]+'))
      .map((p) => p.trim().toLowerCase())
      .where((p) => p.isNotEmpty);
  return parts.any((p) => p == t);
}

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
  // Custom icon fonts (kpnUI LEDs, etc.) paint Private Use Area code points.
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

/// Longest descendant text that counts as a real caption (skips •••• masks).
String? _longestSubstantialTextDescendant(Element element) {
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
    if (value != null && _isSubstantialControlCaption(value)) {
      if (longest == null || value.length > longest!.length) {
        longest = value;
      }
    }
    e.visitChildren(visit);
  }

  element.visitChildren(visit);
  return longest;
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

String? _longestTextDescendant(Element element) {
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
    if (value != null && value.trim().isNotEmpty) {
      if (longest == null || value.length > longest!.length) {
        longest = value;
      }
    }
    e.visitChildren(visit);
  }

  element.visitChildren(visit);
  return longest;
}

bool looksSecure(Element element, String? testId) {
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
        gesture.onTapDown != null;
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
  try {
    final node = tester.getSemantics(
      find.byElementPredicate((candidate) => identical(candidate, element)),
    );
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
      final node = tester.getSemantics(
        find.byElementPredicate((candidate) => identical(candidate, element)),
      );
      return (node as dynamic).hasFlag(SemanticsFlag.isSelected) as bool;
    } catch (_) {
      return null;
    }
  } catch (_) {
    return null;
  }
}

String? readText(Element element) {
  if (looksSecure(element, null)) return null;

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
    if (!identical(e, element) && looksSecure(e, null)) return;
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
  final fromField = field?.controller?.text.trim();
  if (fromField != null && fromField.isNotEmpty) return fromField;
  final fromCupertino = cupertino?.controller?.text.trim();
  if (fromCupertino != null && fromCupertino.isNotEmpty) return fromCupertino;

  String? editableText;
  void visit(Element e) {
    if (editableText != null) return;
    if (!identical(e, element) && looksSecure(e, null)) return;
    final w = e.widget;
    if (w is EditableText) {
      final value = w.controller.text.trim();
      if (value.isNotEmpty) editableText = value;
      return;
    }
    e.visitChildren(visit);
  }

  visit(element);
  return editableText;
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

/// Geometry / opacity / current-route visibility without InheritedWidget deps.
bool isElementGeometricallyVisible(Element element, WidgetTester tester) {
  if (!isUnderCurrentModalRoute(element)) return false;
  if (_isUnderOffstageAncestor(element)) return false;
  final renderObject = element.renderObject;
  if (renderObject is! RenderBox ||
      !renderObject.hasSize ||
      renderObject.size.isEmpty) {
    return false;
  }
  if (_effectiveOpacity(element) <= 0.01) return false;
  final topLeft = renderObject.localToGlobal(Offset.zero);
  final rect = topLeft & renderObject.size;
  if (!rect.isFinite || rect.isEmpty) return false;
  final viewport = tester.binding.renderViews.first.paintBounds;
  final visibleRect = rect.intersect(viewport);
  return visibleRect != Rect.zero &&
      visibleRect.width > 0 &&
      visibleRect.height > 0;
}

bool _isUnderOffstageAncestor(Element element) {
  var isOffstage = false;
  element.visitAncestorElements((ancestor) {
    final renderObject = ancestor.renderObject;
    if (renderObject is RenderOffstage && renderObject.offstage) {
      isOffstage = true;
      return false;
    }
    return true;
  });
  return isOffstage;
}

double _effectiveOpacity(Element element) {
  var opacity = 1.0;
  element.visitAncestorElements((ancestor) {
    final renderObject = ancestor.renderObject;
    if (renderObject is RenderOpacity) {
      opacity *= renderObject.opacity;
    } else if (renderObject != null &&
        renderObject.runtimeType.toString() == 'RenderAnimatedOpacity') {
      try {
        final animatedOpacity = (renderObject as dynamic).opacity;
        if (animatedOpacity is Animation<double>) {
          opacity *= animatedOpacity.value;
        } else if (animatedOpacity is double) {
          opacity *= animatedOpacity;
        }
      } catch (_) {}
    }
    return opacity > 0.01;
  });
  return opacity;
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

UiBounds? boundsFor(Element element) {
  final renderObject = element.renderObject;
  if (renderObject is! RenderBox ||
      !renderObject.hasSize ||
      renderObject.size.isEmpty) {
    return null;
  }
  final topLeft = renderObject.localToGlobal(Offset.zero);
  final rect = topLeft & renderObject.size;
  if (!rect.isFinite || rect.isEmpty) return null;
  return UiBounds(
    left: rect.left,
    top: rect.top,
    width: rect.width,
    height: rect.height,
  );
}

bool inViewport(WidgetTester tester, UiBounds bounds) {
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  final rect =
      Rect.fromLTWH(bounds.left, bounds.top, bounds.width, bounds.height);
  return (Offset.zero & size).overlaps(rect);
}

/// YAML step names an agent/crawler can run **against this observed node**.
///
/// Only lists steps that are actually targetable with the locators this node
/// exposes (`testId` → id-based steps; visible label/text → structured
/// `target: { label|text, role }` taps / text waits). Unkeyed tappable cards
/// without a caption still get no interaction steps — act on a keyed child.
///
/// Wait/assert steps (`waitFor`, `expectVisible`, …) are included alongside
/// gesture/edit steps so the list matches the test-step vocabulary.
List<String> supportedActionsFor(
  String? type, {
  required bool secure,
  bool? enabled,
  String? testId,
  String? text,
  String? label,
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
      'scrollUntilVisible',
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

  switch (t) {
    case 'text':
      addTextWaitAssert();
      if (hasId) {
        addIdWaitAssert();
      }
      // Plain text is not a gesture target.
      break;
    case 'toast':
    case 'widget':
    case 'image':
    case 'svg':
    case 'gif':
    case 'lottie':
      addIdWaitAssert();
      break;
    case 'textinput':
    case 'textfield':
      addIdWaitAssert();
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
      addIdWaitAssert();
      // Unkeyed Ensemble tabs / CTAs: tap via label+role (or text+role).
      if (canGesture && (hasId || hasCaption)) {
        if (hasId) addEnabledAsserts();
        actions.addAll(const ['tap', 'longPress', 'doubleTap']);
      }
      break;
    case 'card':
      // Tap when the row is positively enabled (InkWell onTap) and either
      // keyed or has a caption agents can target via label+role.
      addIdWaitAssert();
      if (enabled == true && (hasId || hasCaption)) {
        if (hasId) addEnabledAsserts();
        actions.addAll(const ['tap', 'longPress']);
      }
      break;
    case 'icon':
      addIdWaitAssert();
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
      addIdWaitAssert();
      if (canGesture && (hasId || hasCaption)) {
        if (hasId) addEnabledAsserts();
        actions.addAll(const ['tap', 'select', 'selectIndex']);
      }
      break;
    case 'switch':
    case 'toggle':
    case 'checkbox':
      addIdWaitAssert();
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
      addIdWaitAssert();
      if (canGesture && (hasId || hasCaption || enabled == true)) {
        if (hasId) addEnabledAsserts();
        actions.addAll(const ['tap', 'setSlider']);
      }
      break;
    default:
      addIdWaitAssert();
      break;
  }

  // Stable order, unique.
  final seen = <String>{};
  return [
    for (final step in actions)
      if (seen.add(step)) step,
  ];
}

/// Recompute [UiElement.supportedActions] / interactable after label absorb.
UiElement refreshObserveActions(UiElement element) {
  final secure = element.state.secure == true;
  final actions = supportedActionsFor(
    element.type,
    secure: secure,
    enabled: element.state.enabled,
    testId: element.testId,
    text: element.text,
    label: element.label,
  );
  final visible = element.state.visible != false;
  final offscreen = element.state.offscreen == true;
  final interactable = visible &&
      !offscreen &&
      element.state.enabled != false &&
      actions.any(_isInteractionStep);
  final prev = element.state;
  return element.copyWith(
    supportedActions: actions,
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

bool _isInteractionStep(String step) {
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

bool _isMediaObserveType(String type) {
  switch (type) {
    case 'image':
    case 'svg':
    case 'gif':
    case 'lottie':
      return true;
    default:
      return false;
  }
}
