import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/image.dart';
import 'package:ensemble/widget/lottie/lottie.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/session/local/media_semantics.dart';
import 'package:ensemble_test_runner/session/local/element_visibility.dart';
import 'package:ensemble_test_runner/session/local/widget_locator_id.dart';
import 'package:ensemble_test_runner/session/local/observed_element_actions.dart';

export 'package:ensemble_test_runner/session/local/element_visibility.dart'
    show
        boundsFor,
        inViewport,
        isElementGeometricallyVisible,
        isUnderOffstageAncestor;
export 'package:ensemble_test_runner/session/local/visible_screen_identifier.dart'
    show visibleScreenIdentifier;
import 'package:ensemble_test_runner/session/observation/ui_element.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

part 'element_shape_classification.dart';
part 'element_content_classification.dart';
part 'element_value_semantics.dart';
part 'element_interaction_state.dart';
part 'element_card_classification.dart';
part 'element_type_classification.dart';

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
  return RunnerBenchmark.sync('observer', 'describeElement', () {
    final type = resolveObservedWidgetType(element, testId: testId);
    final primary = type != 'widget' && testId != null && testId.isNotEmpty
        ? findPrimaryControlDescendant(element)
        : null;
    final semanticsSource = primary ?? element;
    final secure = looksSecure(semanticsSource);
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
    final selected =
        useSemantics ? readSelected(tester, semanticsSource) : null;
    var text = secure ? null : readText(semanticsSource);
    var label = useSemantics
        ? readControlLabel(semanticsSource, tester)
        : readControlLabelWithoutSemantics(semanticsSource);
    final hint = readHint(semanticsSource);
    // Icons rarely have Text; fall back to tooltip / semanticLabel only.
    if (type == 'icon') {
      if ((text == null || text.isEmpty) && (label == null || label.isEmpty)) {
        final iconName = readIconName(semanticsSource);
        if (iconName != null && iconName.isNotEmpty) {
          text = iconName;
        }
      }
      // Nested icons inherit a parent's merged semantics — drop those. Keep
      // labels on compact tappable chrome
      // (CloseAppButton) and on Semantics authored for that chrome.
      final trimmedLabel = label?.trim();
      if (trimmedLabel != null &&
          trimmedLabel.isNotEmpty &&
          (text == null || trimmedLabel != text.trim()) &&
          !_shouldKeepIconSemanticsLabel(semanticsSource, trimmedLabel)) {
        label = null;
      }
    }
    // Standalone text: never keep a merged semantics label (e.g. "Network name Guest_Network"
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
    final actions = actionsFor(
      type,
      secure: secure,
      enabled: enabled,
      testId: testId,
      text: text,
      label: effectiveLabel,
      offscreen: offscreen,
      hasBounds: bounds != null,
      hasScrollableAncestor: _hasScrollableAncestor(element),
    );
    // Interactable = can run a gesture/edit step on this node right now.
    final interactable = visible &&
        !offscreen &&
        enabled != false &&
        actions.any(isInteractionStep);

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
      actions: actions,
    );
  });
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
