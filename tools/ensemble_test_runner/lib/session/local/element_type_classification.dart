// Dart 3.8 reports deprecated_member_use at RegExp construction sites even though
// the deprecation is specifically about implementing RegExp. Keep construction compatible
// with this SDK without suppressing diagnostics in unrelated files.
// ignore_for_file: deprecated_member_use
part of 'element_semantics.dart';

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
  final nestedTypes = <String>[];
  void visitNested(Element e) {
    if (isStandaloneTextElement(e)) {
      nestedTypes.add('text');
      return;
    }
    if (isStandaloneMediaElement(e)) {
      nestedTypes.add(mediaWidgetType(e.widget) ?? 'image');
      return;
    }
    e.visitChildren(visitNested);
  }

  element.visitChildren(visitNested);
  // A keyed host may wrap a whole section (for example DeviceHeader with a
  // title, illustration, and subtitle). Do not type that structural host as
  // whichever text/media descendant happened to appear first. It is only a
  // leaf alias when it owns one observable content node; otherwise preserve
  // the generic `widget` type so its real children remain clear in the tree.
  return nestedTypes.length == 1 ? nestedTypes.single : type;
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
  final substantialText =
      _longestTextDescendant(element, substantialOnly: true) != null;
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
