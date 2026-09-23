import 'package:ensemble/widget/image.dart';
import 'package:ensemble/widget/lottie/lottie.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/session/local/modal_route_lookup.dart';
import 'package:ensemble_test_runner/session/local/widget_locator_id.dart';
import 'package:ensemble_test_runner/session/observation/ui_element.dart';
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
  // Icons: only report enabled for real icon buttons — do not inherit
  // `onTap` from a parent InkWell that wraps a larger control.
  final enabled = type == 'icon'
      ? readIconButtonEnabled(semanticsSource)
      : type == 'toast'
          ? null
          : type == 'card'
              ? readCardEnabled(semanticsSource)
              : readEnabled(semanticsSource);
  final checked = readChecked(semanticsSource);
  var text = secure ? null : readText(semanticsSource);
  var label = secure
      ? null
      : (useSemantics
          ? readControlLabel(semanticsSource, tester)
          : readControlLabelWithoutSemantics(semanticsSource));
  final hint = secure ? null : readHint(semanticsSource);
  // Icons rarely have Text; fall back to tooltip / semanticLabel.
  if (type == 'icon' &&
      (text == null || text.isEmpty) &&
      (label == null || label.isEmpty)) {
    final iconName = readIconName(semanticsSource);
    if (iconName != null && iconName.isNotEmpty) {
      text = iconName;
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
    if ((text == null || text.isEmpty) && desc != null && desc.isNotEmpty) {
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
  final interactable = visible && !offscreen && enabled != false;

  return UiElement(
    elementId: elementId,
    testId: testId,
    type: type,
    role: inferSemanticRole(semanticsSource, type),
    label: label,
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
      obscured: false,
      checked: checked,
    ),
    bounds: includeBounds ? bounds : null,
    supportedActions: supportedActionsFor(type, secure: secure),
  );
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
        return ownedType;
      }
    }
  }
  if (type != 'widget') return type;
  if (testId == null || testId.isEmpty) return type;
  final primary = findPrimaryControlDescendant(element);
  if (primary != null) {
    return inferWidgetType(primary);
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
  return widget is Semantics || isActionableControl(element);
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
  final widget = element.widget;
  final String? data;
  if (widget is Text) {
    data = widget.data;
  } else if (widget is RichText) {
    // [Text] builds a child [RichText] — keep only the Text host.
    if (element.findAncestorWidgetOfExactType<Text>() != null) return false;
    data = widget.text.toPlainText();
  } else {
    return false;
  }
  if (data == null || data.trim().isEmpty) return false;
  return !hasPrimaryControlAncestor(element);
}

/// Visible image / SVG / GIF / Lottie host (not an inner leaf under Ensemble*).
bool isStandaloneMediaElement(Element element) {
  final type = mediaWidgetType(element.widget);
  if (type == null) return false;
  if (_hasMediaHostAncestor(element)) return false;
  if (hasPrimaryControlAncestor(element)) return false;
  return true;
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
  final substantialText = text != null && text.trim().length > 2;
  final compact = _looksLikeCompactIconHitTarget(element);
  final bounds = boundsFor(element);
  final keyId = readValueKeyLocatorId(element) ?? '';

  // Dropdowns: selected value text + drop-down chevron (not a list-row `>`).
  if (hasDropdownChevron) return 'dropdown';

  // Authoring ids often encode the shape: devices_mini_card, wifi_card, …
  if (RegExp(r'card', caseSensitive: false).hasMatch(keyId)) return 'card';
  if (RegExp(r'toast', caseSensitive: false).hasMatch(keyId)) return 'toast';

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
    // media type (hero image / Lottie with onTap).
    if (compact || _looksLikeIconSizedMedia(bounds)) return 'icon';
    return mediaType;
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
      value = w.data;
    } else if (w is RichText) {
      value = w.text.toPlainText();
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

/// Enabled for observed `card` rows — only when the card itself is tappable.
///
/// FToast wraps banners in [GestureDetector] with `onTap: null` (not a disabled
/// button). Nested close [InkWell]s must not invent an enabled state either.
bool? readCardEnabled(Element element) {
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
    if (w is Text && w.data != null && w.data!.trim().isNotEmpty) {
      texts.add(w.data!.trim());
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
  final semanticsWidget = element.widget is Semantics
      ? element.widget as Semantics
      : _selfOrAncestor<Semantics>(element);
  final direct = semanticsWidget?.properties.label?.trim();
  if (direct != null && direct.isNotEmpty) return direct;
  return null;
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
    final data = widget.data?.trim();
    return (data != null && data.isNotEmpty) ? data : null;
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

List<String> supportedActionsFor(String? type, {required bool secure}) {
  switch (type) {
    case 'textInput':
      return secure
          ? const ['tap', 'enterText', 'clearText', 'focus']
          : const [
              'tap',
              'enterText',
              'clearText',
              'replaceText',
              'submitText',
              'focus',
            ];
    case 'button':
      return const ['tap', 'longPress', 'doubleTap'];
    case 'card':
      return const ['tap', 'longPress'];
    case 'toast':
      return const [];
    case 'icon':
      return const ['tap', 'longPress'];
    case 'dropdown':
      return const ['tap'];
    case 'switch':
    case 'toggle':
    case 'checkbox':
      return const ['tap', 'toggle', 'check', 'uncheck'];
    case 'slider':
      return const ['tap', 'setSlider'];
    case 'text':
      return const ['tap'];
    case 'image':
    case 'svg':
    case 'gif':
    case 'lottie':
      return const ['tap'];
    default:
      return const ['tap'];
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
