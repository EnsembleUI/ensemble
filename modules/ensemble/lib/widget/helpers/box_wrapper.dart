import 'package:ensemble/framework/bindings.dart';
import 'package:ensemble/framework/device.dart';
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/theme/theme_loader.dart';
import 'package:ensemble/framework/theme/theme_manager.dart';
import 'package:ensemble/framework/tv/tv_focus_navigation.dart';
import 'package:ensemble/framework/tv/tv_focus_order.dart';
import 'package:ensemble/framework/tv/tv_focus_provider.dart';
import 'package:ensemble/framework/tv/tv_focus_scroll.dart';
import 'package:ensemble/framework/tv/tv_focus_theme.dart';
import 'package:ensemble/framework/tv/tv_focus_widget.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/framework/widget/custom_ink_splash.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:flutter/material.dart';

// TV scroll tuning constants (kTVScrollAnimationDurationMs, kTV*ScrollPadding,
// kTVScrollThreshold, kTVFixedFocusOffset, kTVEdgePadding) live in the shared
// tv_focus_scroll.dart and are available via the import above.

// =============================================================================
// TV Focus - Styling Resolver
// =============================================================================

/// Resolves focus border styling with fallback chain.
///
/// ## Priority (highest to lowest)
/// 1. tvOptions (per-widget YAML)
/// 2. Theme (Tokens.TV in theme.yaml)
/// 3. Provider (host app's TVFocusProvider)
/// 4. Widget (borderColor/borderRadius from styles)
/// 5. Default (primary color, 3px width, 8px radius)
///
/// ## External Pages Warning
/// TVFocusProvider is NOT available on external pages (asExternal: true).
/// For external pages, use Theme (Tokens.TV) for focus styling.
class TVFocusStylingResolver {
  final TVOptionsComposite tvOptions;
  final TVFocusTheme tvFocusTheme;
  final TVFocusProvider? externalProvider;
  final BoxController boxController;
  final Color appPrimaryColor;

  const TVFocusStylingResolver({
    required this.tvOptions,
    required this.tvFocusTheme,
    required this.externalProvider,
    required this.boxController,
    required this.appPrimaryColor,
  });

  /// Focus border color: tvOptions > Theme > Provider > widget.borderColor > primary
  Color get focusBorderColor {
    return tvOptions.focusBorderColor ??
        tvFocusTheme.focusBorderColor ??
        externalProvider?.focusBorderColor ??
        boxController.borderColor ??
        appPrimaryColor;
  }

  /// Focus border width: tvOptions > Theme > Provider > widget.borderWidth > 3.0
  double get focusBorderWidth {
    return tvOptions.focusBorderWidth ??
        tvFocusTheme.focusBorderWidth ??
        externalProvider?.focusBorderWidth ??
        boxController.borderWidth?.toDouble() ??
        TVFocusTheme.defaultBorderWidth;
  }

  /// Focus border radius: tvOptions > Theme > Provider > widget.borderRadius > 8.0
  BorderRadius get focusBorderRadius {
    if (tvOptions.focusBorderRadius != null) {
      return BorderRadius.circular(tvOptions.focusBorderRadius!);
    } else if (tvFocusTheme.focusBorderRadius != null) {
      return BorderRadius.circular(tvFocusTheme.focusBorderRadius!);
    } else if (externalProvider?.focusBorderRadius != null) {
      return BorderRadius.circular(externalProvider!.focusBorderRadius!);
    } else if (boxController.borderRadius != null) {
      return boxController.borderRadius!.getValue();
    } else {
      return BorderRadius.circular(TVFocusTheme.defaultBorderRadius);
    }
  }

  /// Focus animation duration: Theme > Provider > 150ms
  Duration get focusAnimationDuration {
    return tvFocusTheme
        .resolveAnimationDuration(externalProvider?.focusAnimationDurationMs);
  }
}

/// TODO: Legacy - move to EnsembleBoxWrapper
/// wraps around a widget and gives it common box attributes
class BoxWrapper extends StatelessWidget {
  const BoxWrapper(
      {super.key,
      required this.widget,
      required this.boxController,

      // internal widget may want to handle padding itself (e.g. ListView so
      // its scrollbar lays on top of the padding and not the content)
      this.ignoresPadding = false,

      // sometimes our widget may register a gesture. Such gesture should not
      // include the margin. This allows it to handle the margin on its own.
      this.ignoresMargin = false,

      // width/height maybe applied at the child, or not applicable
      this.ignoresDimension = false,

      // some container widgets use tvOptions only to configure an internal TV
      // focus target, such as ListView's scrollbar fallback.
      this.ignoresTVFocus = false});

  final Widget widget;
  final BoxController boxController;

  // child widget may want to control these themselves
  final bool ignoresPadding;
  final bool ignoresMargin;
  final bool ignoresDimension;
  final bool ignoresTVFocus;

  @override
  Widget build(BuildContext context) {
    if (!boxController.requiresBox(
        ignoresMargin: ignoresMargin,
        ignoresPadding: ignoresPadding,
        ignoresDimension: ignoresDimension)) {
      return wrapWithTVFocusContext(
        context: context,
        tvOptions: boxController.tvOptions,
        child: _getWidget(context),
      );
    }
    // when we have a border radius, we need to clip the decoration.
    // Note that this clip only apply to the background decoration.
    // Some children (i.e. Images) might need an additional ClipRRect
    Clip clip = Clip.none;
    if (boxController.borderRadius != null &&
        boxController.hasBoxDecoration()) {
      clip = Clip.hardEdge;
    }
    ScopeManager? scopeManager = DataScopeWidget.getScope(context);
    final Widget? backgroundImage =
        boxController.backgroundImage?.getImageAsWidget(scopeManager);

    // we will exclude padding here if told, or if we have a tap enabled box as
    // we have to apply the padding inside the Material ink
    bool excludePadding = ignoresPadding ||
        (boxController is TapEnabledBoxController &&
            (boxController as TapEnabledBoxController).onTap != null &&
            (boxController as TapEnabledBoxController).enableSplashFeedback);

    final childWidget = backgroundImage != null
        ? Stack(
            children: [
              Positioned.fill(child: backgroundImage),
              _getClippedWidget(context),
            ],
          )
        : _getClippedWidget(context);

    final boxDecoration = !boxController.hasBoxDecoration()
        ? null
        : BoxDecoration(
            color: boxController.backgroundColor,
            gradient: boxController.backgroundGradient,
            border: !boxController.hasBorder()
                ? null
                : boxController.borderGradient != null
                    ? GradientBoxBorder(
                        gradient: boxController.borderGradient!,
                        width: boxController.borderWidth?.toDouble() ??
                            ThemeManager().getBorderThickness(context))
                    : Border.all(
                        color: boxController.borderColor ??
                            ThemeManager().getBorderColor(context),
                        width: boxController.borderWidth?.toDouble() ??
                            ThemeManager().getBorderThickness(context)),
            borderRadius: boxController.borderRadius?.getValue(),
            boxShadow: !boxController.hasBoxShadow()
                ? null
                : <BoxShadow>[
                    boxController.boxShadow?.getValue(context) ??
                        BoxShadow(
                            color: boxController.shadowColor ??
                                ThemeManager().getShadowColor(context),
                            blurRadius:
                                boxController.shadowRadius?.toDouble() ??
                                    ThemeManager().getShadowRadius(context),
                            offset: boxController.shadowOffset ??
                                ThemeManager().getShadowOffset(context),
                            blurStyle: boxController.shadowStyle ??
                                ThemeManager().getShadowStyle(context))
                  ],
          );

    // if animation is enabled, we need a starting non-empty transform to animate
    final transform = boxController.transform ??
        (boxController.animation?.enabled == true ? Matrix4.identity() : null);

    Widget containerWidget = boxController.animation?.enabled == true
        ? AnimatedContainer(
            duration: boxController.animation!.duration,
            curve: boxController.animation?.curve ?? Curves.linear,
            width: ignoresDimension ? null : boxController.width?.toDouble(),
            height: ignoresDimension ? null : boxController.height?.toDouble(),
            margin: ignoresMargin ? null : boxController.margin,
            padding: excludePadding ? null : boxController.padding,
            clipBehavior: clip,
            decoration: boxDecoration,
            transform: transform,
            child: childWidget)
        : Container(
            width: ignoresDimension ? null : boxController.width?.toDouble(),
            height: ignoresDimension ? null : boxController.height?.toDouble(),
            margin: ignoresMargin ? null : boxController.margin,
            padding: excludePadding ? null : boxController.padding,
            clipBehavior: clip,
            decoration: boxDecoration,
            transform: transform,
            child: childWidget);

    // TV: Wrap widgets for D-pad navigation
    if (!ignoresTVFocus &&
        Device().isTV &&
        boxController.tvOptions?.isEnabled == true) {
      // Tappable widgets get full focus handling
      if (boxController is TapEnabledBoxController) {
        final tapController = boxController as TapEnabledBoxController;
        if (tapController.onTap != null || tapController.onLongPress != null) {
          return wrapWithTVFocusContext(
            context: context,
            tvOptions: boxController.tvOptions,
            child: _TapEnabledWrapper(
              controller: tapController,
              boxController: boxController,
              child: containerWidget,
            ),
          );
        }
      }
      // Non-tappable widgets (e.g., Button with built-in tap) get focus ordering only
      return wrapWithTVFocusContext(
        context: context,
        tvOptions: boxController.tvOptions,
        child: _TVFocusOnlyWrapper(
          boxController: boxController,
          child: containerWidget,
        ),
      );
    }

    return wrapWithTVFocusContext(
      context: context,
      tvOptions: boxController.tvOptions,
      child: containerWidget,
    );
  }

  Widget _getWidget(BuildContext context) {
    if (boxController is TapEnabledBoxController &&
        ((boxController as TapEnabledBoxController).onTap != null ||
            (boxController as TapEnabledBoxController).onLongPress != null)) {
      var controller = boxController as TapEnabledBoxController;

      // TV: Wrap with focus handling (build() handles box-level wrapping)
      if (!ignoresTVFocus &&
          Device().isTV &&
          boxController.tvOptions?.isEnabled == true) {
        if (!boxController.requiresBox(
            ignoresMargin: ignoresMargin,
            ignoresPadding: ignoresPadding,
            ignoresDimension: ignoresDimension)) {
          return _TapEnabledWrapper(
            controller: controller,
            boxController: boxController,
            child: widget,
          );
        }
        return widget; // build() will wrap the container
      }

      // Non-TV: Original Material/InkWell pattern for touch/mouse
      return Material(
        color: Colors.transparent,
        child: InkWell(
          splashFactory: CustomInkSplashFactory(
            splashDuration: controller.splashDuration,
            splashFadeDuration: controller.splashFadeDuration,
            unconfirmedSplashDuration: controller.unconfirmedSplashDuration,
          ),
          onLongPress: controller.onLongPress != null
              ? () => ScreenController()
                  .executeAction(context, controller.onLongPress!)
              : null,
          onTap: controller.onTap != null
              ? () =>
                  ScreenController().executeAction(context, controller.onTap!)
              : null,
          splashColor: controller.enableSplashFeedback
              ? controller.splashColor
              : Colors.transparent,
          highlightColor: Colors.transparent,
          focusColor: controller.focusColor,
          hoverColor: controller.hoverColor,
          mouseCursor: controller.mouseCursor,
          child: controller.enableSplashFeedback && controller.padding != null
              ? Padding(padding: controller.padding!, child: widget)
              : widget,
        ),
      );
    }
    return widget;
  }

  /// The child widget need to clip separately from the Container's decoration
  Widget _getClippedWidget(BuildContext context) {
    // some widget (i.e. Image) will not respect the Container's boundary
    // even if clipBehavior is enabled. In these case we need to apply
    // an explicit ClipRRect around it. Note also that apply it around
    // another Container may cause clipping at the borderRadius's corners.
    // Also note that clipping is not necessary unless borderRadius is set
    return boxController.borderRadius != null &&
            boxController.clipContent == true
        ? ClipRRect(
            borderRadius: boxController.borderRadius!.getValue(),
            clipBehavior: Clip.hardEdge,
            child: _getWidget(context))
        : _getWidget(context);
  }
}

/// Wrap around a widget to give it box property.
class EnsembleBoxWrapper extends StatelessWidget {
  const EnsembleBoxWrapper(
      {super.key,
      required this.widget,
      required this.boxController,

      // internal widget may want to handle padding itself (e.g. ListView so
      // its scrollbar lays on top of the padding and not the content)
      this.ignoresPadding = false,

      // sometimes our widget may register a gesture. Such gesture should not
      // include the margin. This allows it to handle the margin on its own.
      this.ignoresMargin = false,

      // width/height maybe applied at the child, or not applicable
      this.ignoresDimension = false,
      this.fallbackWidth,
      this.fallbackHeight,
      this.fallbackBorderRadius});

  final Widget widget;
  final EnsembleBoxController boxController;

  // child widget may want to control these themselves
  final bool ignoresPadding;
  final bool ignoresMargin;
  final bool ignoresDimension;
  final double? fallbackWidth;
  final double? fallbackHeight;
  final EBorderRadius? fallbackBorderRadius;

  bool _requiresBox() =>
      boxController.requiresBox(
          ignoresMargin: ignoresMargin,
          ignoresPadding: ignoresPadding,
          ignoresDimension: ignoresDimension) ||
      (!ignoresDimension &&
          (fallbackWidth != null || fallbackHeight != null)) ||
      fallbackBorderRadius != null;

  bool _hasBoxDecoration() =>
      boxController.hasBoxDecoration() || fallbackBorderRadius != null;

  EBorderRadius? get _borderRadius =>
      boxController.borderRadius ?? fallbackBorderRadius;

  @override
  Widget build(BuildContext context) {
    if (!_requiresBox()) {
      return widget;
    }
    // when we have a border radius, we need to clip the decoration.
    // Note that this clip only apply to the background decoration.
    // Some children (i.e. Images) might need an additional ClipRRect
    Clip clip = Clip.none;
    if (_hasBoxDecoration()) {
      clip = Clip.hardEdge;
    }
    ScopeManager? scopeManager = DataScopeWidget.getScope(context);
    final Widget? backgroundImage =
        boxController.backgroundImage?.getImageAsWidget(scopeManager);

    return Container(
      width: ignoresDimension
          ? null
          : boxController.width?.toDouble() ?? fallbackWidth,
      height: ignoresDimension
          ? null
          : boxController.height?.toDouble() ?? fallbackHeight,
      margin: ignoresMargin ? null : boxController.margin,
      padding: ignoresPadding ? null : boxController.padding,
      clipBehavior: clip,
      decoration: !_hasBoxDecoration()
          ? null
          : BoxDecoration(
              color: boxController.backgroundColor,
              gradient: boxController.backgroundGradient,
              border: !boxController.hasBorder()
                  ? null
                  : boxController.borderGradient != null
                      ? GradientBoxBorder(
                          gradient: boxController.borderGradient!,
                          width: boxController.borderWidth?.toDouble() ??
                              ThemeManager().getBorderThickness(context))
                      : Border.all(
                          color: boxController.borderColor ??
                              ThemeManager().getBorderColor(context),
                          width: boxController.borderWidth?.toDouble() ??
                              ThemeManager().getBorderThickness(context)),
              borderRadius: _borderRadius?.getValue(),
              boxShadow: boxController.boxShadow == null
                  ? null
                  : <BoxShadow>[boxController.boxShadow!.getValue(context)],
            ),
      child: backgroundImage != null
          ? Stack(
              children: [
                Positioned.fill(child: backgroundImage),
                _getWidget(),
              ],
            )
          : _getWidget(),
    );
  }

  /// The child widget need to clip separately from the Container's decoration
  Widget _getWidget() {
    // some widget (i.e. Image) will not respect the Container's boundary
    // even if clipBehavior is enabled. In these case we need to apply
    // an explicit ClipRRect around it. Note also that apply it around
    // another Container may cause clipping at the borderRadius's corners.
    // Also note that clipping is not necessary unless borderRadius is set
    return _borderRadius != null && boxController.clipContent == true
        ? ClipRRect(
            borderRadius: _borderRadius!.getValue(),
            clipBehavior: Clip.hardEdge,
            child: widget)
        : widget;
  }
}

/// Handles tap/focus for tappable widgets (onTap/onLongPress) on TV.
///
/// Only ever constructed when `Device().isTV && tvOptions.isEnabled` is true, so
/// it always renders the D-pad-focusable variant (visible focus border +
/// auto-scroll on focus). Non-TV taps are handled inline by the Material/InkWell
/// in `_getWidget`.
class _TapEnabledWrapper extends StatefulWidget {
  const _TapEnabledWrapper({
    required this.child,
    required this.controller,
    required this.boxController,
  });

  final Widget child;
  final TapEnabledBoxController controller;
  final BoxController boxController;

  @override
  State<_TapEnabledWrapper> createState() => _TapEnabledWrapperState();
}

/// Refresh `rememberRowPosition` memory on focus-gain (covers taps, edges,
/// requestFocusAt/ByEdge, carousel — all land focus here), routing to the host
/// provider or the built-in grid. Passes relative row/order; host adds offsets.
void _saveTVRowPositionOnFocus(
    BuildContext context, BoxController boxController) {
  final tvOptions = boxController.tvOptions;
  if (tvOptions == null || tvOptions.row == null) return;
  if (!resolveTVRememberRowPosition(context, tvOptions)) return;

  final route = ModalRoute.of(context);
  final focusGroup = resolveTVFocusGroup(context, tvOptions);
  final row = tvOptions.row!;
  final order = tvOptions.order ?? 0;

  final provider = TVFocusProviderScope.maybeOf(context);
  if (provider != null) {
    provider.saveRowPosition(
        route: route, row: row, order: order, focusGroup: focusGroup);
  } else {
    TVFocusWidget.rememberOrder(route, focusGroup, row, order);
  }
}

/// Maps a curve name (from `tvOptions.scrollAnimationCurve`) to a [Curve].
/// Supported: easeIn, easeOut, easeInOut, linear, decelerate, ease,
/// fastOutSlowIn, bounceOut, elasticOut.
// Curve-name resolution lives in tv_focus_scroll.dart (shared with the
// focusable scrollbar); this thin alias keeps the existing internal call sites.
Curve _curveFromName(String? curveName, {Curve defaultCurve = Curves.easeOut}) =>
    curveFromName(curveName, defaultCurve: defaultCurve);

class _TapEnabledWrapperState extends State<_TapEnabledWrapper> {
  late final FocusNode _focusNode;
  static int _instanceCounter = 0;
  late final int _instanceId;

  @override
  void initState() {
    super.initState();
    _instanceId = ++_instanceCounter;
    _focusNode = FocusNode(debugLabel: 'TapEnabledWrapper_$_instanceId');
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    // If disposed while focused, no focus-loss event fires — reset the shared
    // controller's hasFocus so a reused controller / the ${id.hasFocus} binding
    // don't keep a stale `true`. (No dispatch: the context is being torn down.)
    if (widget.boxController.hasFocus) {
      widget.boxController.hasFocus = false;
    }
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    final hasFocus = _focusNode.hasFocus;

    // Update controller's hasFocus state and dispatch binding event
    if (widget.boxController.hasFocus != hasFocus) {
      widget.boxController.hasFocus = hasFocus;

      // Dispatch focus change for expression bindings like ${myWidget.hasFocus}
      final widgetId = widget.boxController.id;
      if (widgetId != null) {
        final scopeManager = DataScopeWidget.getScope(context);
        scopeManager?.dispatch(
          ModelChangeEvent(
            WidgetBindingSource(widgetId, property: 'hasFocus'),
            hasFocus,
            bindingScope: scopeManager,
          ),
        );
      }
    }

    // Auto-scroll to keep focused item visible during D-pad navigation
    if (Device().isTV && hasFocus && mounted) {
      // Keep row-position memory fresh on any focus-gain.
      _saveTVRowPositionOnFocus(context, widget.boxController);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && context.mounted) {
          _handleFocusScroll();
        }
      });
    }
  }

  /// Converts a curve name string to a Flutter Curve object.
  /// Supported values: easeIn, easeOut, easeInOut, linear, decelerate, ease.
  Curve _getCurveFromName(String? curveName,
          {Curve defaultCurve = Curves.easeOut}) =>
      _curveFromName(curveName, defaultCurve: defaultCurve);

  /// Handles scrolling when focus changes.
  /// Uses Netflix-style fixed position for horizontal scrolling when enabled.
  void _handleFocusScroll() {
    final RenderBox? itemBox = context.findRenderObject() as RenderBox?;
    if (itemBox == null || !itemBox.hasSize) return;

    final tvOptions = widget.boxController.tvOptions;
    final useFixedFocusScroll = tvOptions?.fixedFocusScroll ?? false;

    // Get configurable scroll properties with defaults
    final scrollAnimationDuration =
        tvOptions?.scrollAnimationDuration ?? kTVScrollAnimationDurationMs;
    final horizontalScrollPadding =
        tvOptions?.horizontalScrollPadding ?? kTVHorizontalScrollPadding;
    final scrollCurveName = tvOptions?.scrollAnimationCurve;

    // Check if external provider handles horizontal scrolling
    final externalProvider = TVFocusProviderScope.maybeOf(context);
    final hostHandlesScroll =
        externalProvider?.handlesHorizontalScroll ?? false;

    // Handle vertical scrolling to ensure focused item is visible
    final verticalScrollable = findNearestVerticalScrollable(context);
    if (verticalScrollable != null) {
      final verticalPadding =
          tvOptions?.verticalScrollPadding ?? kTVVerticalScrollPadding;
      final verticalCurve =
          _getCurveFromName(scrollCurveName, defaultCurve: Curves.easeInOut);
      scrollVerticalOnly(verticalScrollable, itemBox,
          verticalPadding: verticalPadding,
          animationDurationMs: scrollAnimationDuration,
          curve: verticalCurve);
    }

    // Handle horizontal scrolling
    // Skip only if host app explicitly handles horizontal scroll
    if (hostHandlesScroll) {
      return;
    }

    final horizontalScrollable = _findHorizontalScrollable();

    if (horizontalScrollable != null) {
      final horizontalCurve =
          _getCurveFromName(scrollCurveName, defaultCurve: Curves.easeOut);
      if (useFixedFocusScroll) {
        // Netflix-style: focus stays at fixed left position
        final fixedOffset = tvOptions?.fixedFocusOffset ?? kTVFixedFocusOffset;
        _scrollHorizontalWithFixedPosition(
            horizontalScrollable, itemBox, fixedOffset,
            animationDuration: scrollAnimationDuration, curve: horizontalCurve);
      } else {
        // Default: ensure item is visible (centered when scrolling needed)
        _scrollHorizontalIfNotVisible(horizontalScrollable, itemBox,
            padding: horizontalScrollPadding,
            animationDuration: scrollAnimationDuration,
            curve: horizontalCurve);
      }
    }
  }

  /// Finds the nearest horizontal scrollable ancestor.
  ScrollableState? _findHorizontalScrollable() {
    ScrollableState? scrollable;

    context.visitAncestorElements((element) {
      if (element.widget is Scrollable) {
        final state = (element as StatefulElement).state;
        if (state is ScrollableState) {
          final axis = state.axisDirection;
          if (axis == AxisDirection.left || axis == AxisDirection.right) {
            scrollable = state;
            return false; // Stop searching
          }
        }
      }
      return true; // Continue searching
    });

    return scrollable;
  }

  /// Default horizontal scrolling: ensure item is visible, scroll only if needed.
  /// [padding] controls the horizontal padding for visibility checks.
  /// [animationDuration] controls the scroll animation duration in milliseconds.
  /// [curve] controls the animation curve (defaults to easeOut).
  void _scrollHorizontalIfNotVisible(
    ScrollableState scrollable,
    RenderBox itemBox, {
    double padding = kTVHorizontalScrollPadding,
    int animationDuration = kTVScrollAnimationDurationMs,
    Curve curve = Curves.easeOut,
  }) {
    final scrollableBox = scrollable.context.findRenderObject() as RenderBox?;
    if (scrollableBox == null || !scrollableBox.hasSize) return;

    // Get item position relative to screen
    final Offset itemScreenPos = itemBox.localToGlobal(Offset.zero);
    final double itemWidth = itemBox.size.width;
    final double itemLeft = itemScreenPos.dx;
    final double itemRight = itemLeft + itemWidth;

    // Get scrollable position relative to screen
    final Offset scrollableScreenPos = scrollableBox.localToGlobal(Offset.zero);
    final double scrollableLeft = scrollableScreenPos.dx;
    final double scrollableRight = scrollableLeft + scrollableBox.size.width;

    // Check if item is fully visible
    final bool isFullyVisible = itemLeft >= (scrollableLeft + padding) &&
        itemRight <= (scrollableRight - padding);

    if (isFullyVisible) return;

    // Center the item horizontally. This mirrors Scrollable.ensureVisible(
    // alignment: 0.5) but scrolls ONLY this horizontal scrollable. The old
    // ensureVisible(context) was not axis-restricted — it also scrolled every
    // enclosing vertical scrollable, undoing the padding-aware
    // scrollVerticalOnly done moments earlier and causing a vertical jerk.
    final position = scrollable.position;
    final double itemCenter = itemLeft + itemWidth / 2;
    final double viewportCenter = scrollableLeft + scrollableBox.size.width / 2;
    final double targetScroll = (position.pixels + (itemCenter - viewportCenter))
        .clamp(0.0, position.maxScrollExtent);

    if ((targetScroll - position.pixels).abs() > kTVScrollThreshold) {
      position.animateTo(
        targetScroll,
        duration: Duration(milliseconds: animationDuration),
        curve: curve,
      );
    }
  }

  /// Netflix-style horizontal scrolling: focus stays at fixed left position,
  /// content scrolls underneath. At boundaries, focus moves through visible items.
  /// [animationDuration] controls the scroll animation duration in milliseconds.
  /// [curve] controls the animation curve (defaults to easeOut).
  void _scrollHorizontalWithFixedPosition(
    ScrollableState scrollable,
    RenderBox itemBox,
    double fixedOffset, {
    int animationDuration = kTVScrollAnimationDurationMs,
    Curve curve = Curves.easeOut,
  }) {
    final scrollableBox = scrollable.context.findRenderObject() as RenderBox?;
    if (scrollableBox == null || !scrollableBox.hasSize) return;

    final position = scrollable.position;

    // Get item position relative to screen
    final Offset itemScreenPos = itemBox.localToGlobal(Offset.zero);
    final double itemWidth = itemBox.size.width;
    final double itemLeft = itemScreenPos.dx;
    final double itemRight = itemLeft + itemWidth;

    // Get scrollable position relative to screen
    final Offset scrollableScreenPos = scrollableBox.localToGlobal(Offset.zero);
    final double scrollableLeft = scrollableScreenPos.dx;
    final double scrollableRight = scrollableLeft + scrollableBox.size.width;

    // Padding for visibility checks
    const double edgePadding = kTVEdgePadding;

    // Check if item's LEFT edge is visible (for START boundary)
    final bool isLeftEdgeVisible = itemLeft >= scrollableLeft;

    // Check if item's RIGHT edge is visible (for END boundary)
    final bool isRightEdgeVisible = itemRight <= scrollableRight;

    // Item is reasonably visible if both edges are on screen
    final bool isItemReasonablyVisible =
        isLeftEdgeVisible && isRightEdgeVisible;

    // Check if we're currently at boundaries
    final bool isAtStart = position.pixels <= kTVScrollThreshold;
    final bool isAtEnd =
        position.pixels >= position.maxScrollExtent - kTVScrollThreshold;

    // Calculate item's position relative to viewport
    final double itemLeftInViewport = itemLeft - scrollableLeft;

    // Calculate item's position in content coordinate system
    final double itemContentPosition = position.pixels + itemLeftInViewport;

    // Calculate target scroll position BEFORE clamping (for boundary detection)
    final double rawTargetScroll = itemContentPosition - fixedOffset;

    // Check if target would hit start boundary
    final bool wouldHitStart = rawTargetScroll <= 0;

    // START BOUNDARY: Skip scroll if item is visible and at/before fixedOffset
    if ((isAtStart || wouldHitStart) &&
        isLeftEdgeVisible &&
        itemLeftInViewport <= fixedOffset + edgePadding) {
      return;
    }

    // END BOUNDARY: Only skip scroll when we're ACTUALLY at maxScrollExtent
    // and the item is already visible. This ensures we scroll all the way to
    // the end before letting focus move through the remaining visible items.
    if (isAtEnd && isItemReasonablyVisible) {
      return;
    }

    // Clamp to valid scroll range - this will scroll to maxScrollExtent when
    // rawTargetScroll exceeds it, ensuring content scrolls fully before
    // focus position shifts
    double targetScroll = rawTargetScroll.clamp(0.0, position.maxScrollExtent);

    // Animate if there's a meaningful change
    if ((targetScroll - position.pixels).abs() > kTVScrollThreshold) {
      position.animateTo(
        targetScroll,
        duration: Duration(milliseconds: animationDuration),
        curve: curve,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // _TapEnabledWrapper is only constructed on TV with tvOptions enabled (see
    // the guards in box_wrapper build()/_getWidget), so it always renders the
    // TV-focusable variant. Non-TV taps are handled inline in _getWidget.
    return _buildTVFocusable(context, widget.controller);
  }

  /// Builds TV-focusable widget with D-pad navigation and focus border.
  ///
  /// Uses TVFocusProvider (if available) or falls back to built-in TVFocusWidget.
  /// Focus styling resolved via TVFocusStylingResolver (see priority chain above).
  Widget _buildTVFocusable(
    BuildContext context,
    TapEnabledBoxController controller,
  ) {
    final boxController = widget.boxController;
    final tvOptions = boxController.tvOptions!;
    final tvRow = tvOptions.row!;
    final tvOrder = tvOptions.order ?? 0;
    final isRowEntryPoint = tvOptions.isRowEntryPoint;
    final autofocus = widget.boxController.autofocus;
    final focusGroup = resolveTVFocusGroup(context, tvOptions);
    final rememberRowPosition =
        resolveTVRememberRowPosition(context, tvOptions);

    final externalProvider = TVFocusProviderScope.maybeOf(context);
    final effectiveRow =
        externalProvider != null ? tvRow + externalProvider.rowOffset : tvRow;
    final effectiveOrder = externalProvider != null
        ? tvOrder + externalProvider.orderOffset
        : tvOrder;

    // Get TV focus theme from Ensemble theme
    final theme = Theme.of(context);
    final themeExtension = theme.extension<EnsembleThemeExtension>();
    final tvFocusTheme = themeExtension?.tvFocusTheme ?? const TVFocusTheme();

    // Use resolver for focus styling (eliminates duplication)
    final stylingResolver = TVFocusStylingResolver(
      tvOptions: tvOptions,
      tvFocusTheme: tvFocusTheme,
      externalProvider: externalProvider,
      boxController: boxController,
      appPrimaryColor: theme.colorScheme.primary,
    );
    final focusBorderColor = stylingResolver.focusBorderColor;
    final focusBorderWidth = stylingResolver.focusBorderWidth;
    final borderRadius = stylingResolver.focusBorderRadius;
    final focusAnimationDuration = stylingResolver.focusAnimationDuration;

    // The child is already the complete widget; no internal padding is added.
    Widget content = widget.child;

    Widget inkWell = InkWell(
      focusNode: _focusNode,
      autofocus: autofocus,
      splashColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      highlightColor: Colors.transparent,
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      splashFactory: NoSplash.splashFactory,
      onTap: controller.onTap != null
          ? () => ScreenController().executeAction(context, controller.onTap!)
          : null,
      onLongPress: controller.onLongPress != null
          ? () =>
              ScreenController().executeAction(context, controller.onLongPress!)
          : null,
      child: Builder(
        builder: (builderContext) {
          final hasFocus = Focus.maybeOf(builderContext)?.hasFocus ?? false;

          // Build the content with focus indicator border
          Widget focusedContent = AnimatedContainer(
            duration: focusAnimationDuration,
            decoration: BoxDecoration(
              border: Border.all(
                color: hasFocus ? focusBorderColor : Colors.transparent,
                width: focusBorderWidth,
              ),
              borderRadius: borderRadius,
            ),
            child: content,
          );

          // Apply focused state styles from tvOptions
          if (tvOptions.hasFocusedStyles) {
            // Apply scale animation
            if (tvOptions.scale != null) {
              focusedContent = AnimatedScale(
                scale: hasFocus ? tvOptions.scale! : 1.0,
                duration: focusAnimationDuration,
                child: focusedContent,
              );
            }

            // Apply opacity animation
            // Use tvOptions.opacity when focused, boxController.opacity when unfocused
            if (tvOptions.opacity != null) {
              focusedContent = AnimatedOpacity(
                opacity: hasFocus
                    ? tvOptions.opacity!
                    : (boxController.opacity ?? 1.0),
                duration: focusAnimationDuration,
                child: focusedContent,
              );
            }

            // Apply elevation
            if (tvOptions.elevation != null) {
              focusedContent = AnimatedPhysicalModel(
                duration: focusAnimationDuration,
                shape: BoxShape.rectangle,
                elevation: hasFocus ? tvOptions.elevation!.toDouble() : 0,
                color: Colors.transparent,
                shadowColor: Colors.black54,
                borderRadius: borderRadius,
                child: focusedContent,
              );
            }
          }

          return focusedContent;
        },
      ),
    );

    final materialChild = Material(color: Colors.transparent, child: inkWell);
    final tvFocusScope = context.findAncestorWidgetOfExactType<TVFocusScope>();
    final rightEdgeHandler = buildTVEdgeNavigationCallback(
          context: context,
          provider: externalProvider,
          direction: TVFocusDirection.right,
          target: resolveTVFocusEdgeTarget(
              context, tvOptions, TVFocusDirection.right),
          currentRow: effectiveRow,
          currentOrder: effectiveOrder,
        ) ??
        tvFocusScope?.onRightEdge;
    final leftEdgeHandler = buildTVEdgeNavigationCallback(
          context: context,
          provider: externalProvider,
          direction: TVFocusDirection.left,
          target: resolveTVFocusEdgeTarget(
              context, tvOptions, TVFocusDirection.left),
          currentRow: effectiveRow,
          currentOrder: effectiveOrder,
        ) ??
        tvFocusScope?.onLeftEdge;
    final topEdgeHandler = buildTVEdgeNavigationCallback(
          context: context,
          provider: externalProvider,
          direction: TVFocusDirection.top,
          target: resolveTVFocusEdgeTarget(
              context, tvOptions, TVFocusDirection.top),
          currentRow: effectiveRow,
          currentOrder: effectiveOrder,
        ) ??
        tvFocusScope?.onTopEdge;
    final bottomEdgeHandler = buildTVEdgeNavigationCallback(
          context: context,
          provider: externalProvider,
          direction: TVFocusDirection.bottom,
          target: resolveTVFocusEdgeTarget(
              context, tvOptions, TVFocusDirection.bottom),
          currentRow: effectiveRow,
          currentOrder: effectiveOrder,
        ) ??
        tvFocusScope?.onBottomEdge;

    if (externalProvider != null) {
      return externalProvider.wrapFocusable(
        row: effectiveRow,
        order: effectiveOrder,
        isRowEntryPoint: isRowEntryPoint,
        lockHorizontalNavigation: tvOptions.lockHorizontalNavigation,
        delegateHorizontalNavigation: tvOptions.delegateHorizontalNavigation,
        focusGroup: focusGroup,
        rememberRowPosition: rememberRowPosition,
        primaryFocusNode: _focusNode,
        onRightEdge: rightEdgeHandler,
        onLeftEdge: leftEdgeHandler,
        onTopEdge: topEdgeHandler,
        onBottomEdge: bottomEdgeHandler,
        child: materialChild,
      );
    }

    // Otherwise use Ensemble's built-in TVFocusWidget
    return TVFocusWidget(
      focusOrder: TVFocusOrder.withOptions(
        tvRow,
        order: tvOrder,
        isRowEntryPoint: isRowEntryPoint,
        lockHorizontalNavigation: tvOptions.lockHorizontalNavigation,
        delegateHorizontalNavigation: tvOptions.delegateHorizontalNavigation,
        focusGroup: focusGroup,
        rememberRowPosition: rememberRowPosition,
      ),
      onRightEdge: rightEdgeHandler,
      onLeftEdge: leftEdgeHandler,
      onTopEdge: topEdgeHandler,
      onBottomEdge: bottomEdgeHandler,
      primaryFocusNode: _focusNode,
      child: materialChild,
    );
  }

}

// =============================================================================
// _TVFocusOnlyWrapper - Focus Wrapper for Self-Focusable Widgets
// =============================================================================

/// Wraps widgets that handle their own tap/focus (e.g., Button, Switch).
///
/// Unlike _TapHandlerState which provides full InkWell, this wrapper only adds:
/// - TVFocusOrder for grid navigation (row/order positioning)
/// - Scroll-on-focus behavior (auto-scroll when focused)
/// - Focus border decoration (visual focus indicator)
///
/// The child widget retains its own tap handling and focus node.
class _TVFocusOnlyWrapper extends StatefulWidget {
  const _TVFocusOnlyWrapper({
    required this.child,
    required this.boxController,
  });

  final Widget child;
  final BoxController boxController;

  @override
  State<_TVFocusOnlyWrapper> createState() => _TVFocusOnlyWrapperState();
}

class _TVFocusOnlyWrapperState extends State<_TVFocusOnlyWrapper> {
  bool _hasFocus = false;

  // This widget's TV focus target: the SAME node that backs the onFocusChange
  // FocusScope below is also the one registered (via primaryFocusNode →
  // TVFocusWidget Case 1). That identity is the point — focusing it drives
  // _hasFocus and boxController.hasFocus (the focus ring + ${id.hasFocus}
  // bindings), and as a scope it delegates focus to the first focusable
  // descendant (e.g. a Button's inner FilledButton).
  //
  // Regression fix: Case 2's _RegisteredFocusScope registered a SEPARATE scope
  // node, so navigation focused a node that didn't track hasFocus — enabled
  // Buttons then showed no focus ring or highlight.
  final FocusScopeNode _scopeNode =
      FocusScopeNode(debugLabel: 'TVFocusOnlyWrapper');

  @override
  void dispose() {
    // Reset stale focus state if disposed while focused (see _TapEnabledWrapper).
    if (widget.boxController.hasFocus) {
      widget.boxController.hasFocus = false;
    }
    _scopeNode.dispose();
    super.dispose();
  }

  /// Handles vertical scrolling when this widget's subtree gains focus.
  void _handleFocusScroll(BuildContext childContext) {
    final RenderBox? itemBox = childContext.findRenderObject() as RenderBox?;
    if (itemBox == null || !itemBox.hasSize) return;

    final tvOptions = widget.boxController.tvOptions;
    final scrollAnimationDuration =
        tvOptions?.scrollAnimationDuration ?? kTVScrollAnimationDurationMs;
    final verticalPadding =
        tvOptions?.verticalScrollPadding ?? kTVVerticalScrollPadding;
    // Honor the configurable scrollAnimationCurve (previously hardcoded here).
    final curve = _curveFromName(tvOptions?.scrollAnimationCurve,
        defaultCurve: Curves.easeInOut);

    // Handle vertical scrolling to ensure focused item is visible
    final verticalScrollable = findNearestVerticalScrollable(context);
    if (verticalScrollable != null) {
      scrollVerticalOnly(verticalScrollable, itemBox,
          verticalPadding: verticalPadding,
          animationDurationMs: scrollAnimationDuration,
          curve: curve);
    }
  }

  @override
  Widget build(BuildContext context) {
    final boxController = widget.boxController;
    final tvOptions = boxController.tvOptions!;
    final tvRow = tvOptions.row!;
    final tvOrder = tvOptions.order ?? 0;
    final isRowEntryPoint = tvOptions.isRowEntryPoint;
    final focusGroup = resolveTVFocusGroup(context, tvOptions);
    final rememberRowPosition =
        resolveTVRememberRowPosition(context, tvOptions);

    final externalProvider = TVFocusProviderScope.maybeOf(context);
    final effectiveRow =
        externalProvider != null ? tvRow + externalProvider.rowOffset : tvRow;
    final effectiveOrder = externalProvider != null
        ? tvOrder + externalProvider.orderOffset
        : tvOrder;

    // Get TV focus theme from Ensemble theme
    final theme = Theme.of(context);
    final themeExtension = theme.extension<EnsembleThemeExtension>();
    final tvFocusTheme = themeExtension?.tvFocusTheme ?? const TVFocusTheme();

    // Use resolver for focus styling (eliminates duplication)
    final stylingResolver = TVFocusStylingResolver(
      tvOptions: tvOptions,
      tvFocusTheme: tvFocusTheme,
      externalProvider: externalProvider,
      boxController: boxController,
      appPrimaryColor: theme.colorScheme.primary,
    );
    final focusBorderColor = stylingResolver.focusBorderColor;
    final focusBorderWidth = stylingResolver.focusBorderWidth;
    final borderRadius = stylingResolver.focusBorderRadius;
    final focusAnimationDuration = stylingResolver.focusAnimationDuration;

    // Build focus indicator content
    Widget focusIndicatorContent = AnimatedContainer(
      duration: focusAnimationDuration,
      decoration: BoxDecoration(
        border: Border.all(
          color: _hasFocus ? focusBorderColor : Colors.transparent,
          width: focusBorderWidth,
        ),
        borderRadius: borderRadius,
      ),
      child: widget.child,
    );

    // Apply focused state styles from tvOptions
    if (tvOptions.hasFocusedStyles) {
      // Apply scale animation
      if (tvOptions.scale != null) {
        focusIndicatorContent = AnimatedScale(
          scale: _hasFocus ? tvOptions.scale! : 1.0,
          duration: focusAnimationDuration,
          child: focusIndicatorContent,
        );
      }

      // Apply opacity animation
      // Use tvOptions.opacity when focused, boxController.opacity when unfocused
      if (tvOptions.opacity != null) {
        focusIndicatorContent = AnimatedOpacity(
          opacity:
              _hasFocus ? tvOptions.opacity! : (boxController.opacity ?? 1.0),
          duration: focusAnimationDuration,
          child: focusIndicatorContent,
        );
      }

      // Apply elevation
      if (tvOptions.elevation != null) {
        focusIndicatorContent = AnimatedPhysicalModel(
          duration: focusAnimationDuration,
          shape: BoxShape.rectangle,
          elevation: _hasFocus ? tvOptions.elevation!.toDouble() : 0,
          color: Colors.transparent,
          shadowColor: Colors.black54,
          borderRadius: borderRadius,
          child: focusIndicatorContent,
        );
      }
    }

    // Wrap child with FocusScope to detect when any descendant gains focus
    // and render focus border
    final wrappedChild = FocusScope(
      // Explicit node so it can be registered as the TV focus target below.
      node: _scopeNode,
      onFocusChange: (hasFocus) {
        if (mounted) {
          setState(() {
            _hasFocus = hasFocus;
          });

          // Update controller's hasFocus state and dispatch binding event
          if (widget.boxController.hasFocus != hasFocus) {
            widget.boxController.hasFocus = hasFocus;

            // Dispatch focus change for expression bindings like ${myWidget.hasFocus}
            final widgetId = widget.boxController.id;
            if (widgetId != null) {
              final scopeManager = DataScopeWidget.getScope(context);
              scopeManager?.dispatch(
                ModelChangeEvent(
                  WidgetBindingSource(widgetId, property: 'hasFocus'),
                  hasFocus,
                  bindingScope: scopeManager,
                ),
              );
            }
          }

          if (hasFocus) {
            // Keep row-position memory fresh on any focus-gain.
            _saveTVRowPositionOnFocus(context, widget.boxController);

            // Delegate primary focus to the child so Select/Enter can activate
            // it. A FocusScopeNode with no previously-focused child takes primary
            // focus *itself* instead of a descendant (FocusScopeNode
            // ._doRequestFocus: focusedChild == null → focuses the scope). Under
            // pure D-pad navigation focusedChild is always null, so without this
            // the child Button looks focused (scope.hasFocus includes the scope)
            // but isn't actually focused — Select then reaches no button and
            // bubbles to the app root unhandled. Redirect to the first focusable
            // descendant (the Button's own node) to restore activation.
            // Disabled children expose no focusable descendant, so the scope
            // keeps focus: ring shows, nothing to activate — correct for a
            // disabled control.
            if (_scopeNode.hasPrimaryFocus) {
              final childFocus = _scopeNode.traversalDescendants.isEmpty
                  ? null
                  : _scopeNode.traversalDescendants.first;
              childFocus?.requestFocus();
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && context.mounted) {
                _handleFocusScroll(context);
              }
            });
          }
        }
      },
      child: focusIndicatorContent,
    );

    final tvFocusScope = context.findAncestorWidgetOfExactType<TVFocusScope>();
    final rightEdgeHandler = buildTVEdgeNavigationCallback(
          context: context,
          provider: externalProvider,
          direction: TVFocusDirection.right,
          target: resolveTVFocusEdgeTarget(
              context, tvOptions, TVFocusDirection.right),
          currentRow: effectiveRow,
          currentOrder: effectiveOrder,
        ) ??
        tvFocusScope?.onRightEdge;
    final leftEdgeHandler = buildTVEdgeNavigationCallback(
          context: context,
          provider: externalProvider,
          direction: TVFocusDirection.left,
          target: resolveTVFocusEdgeTarget(
              context, tvOptions, TVFocusDirection.left),
          currentRow: effectiveRow,
          currentOrder: effectiveOrder,
        ) ??
        tvFocusScope?.onLeftEdge;
    final topEdgeHandler = buildTVEdgeNavigationCallback(
          context: context,
          provider: externalProvider,
          direction: TVFocusDirection.top,
          target: resolveTVFocusEdgeTarget(
              context, tvOptions, TVFocusDirection.top),
          currentRow: effectiveRow,
          currentOrder: effectiveOrder,
        ) ??
        tvFocusScope?.onTopEdge;
    final bottomEdgeHandler = buildTVEdgeNavigationCallback(
          context: context,
          provider: externalProvider,
          direction: TVFocusDirection.bottom,
          target: resolveTVFocusEdgeTarget(
              context, tvOptions, TVFocusDirection.bottom),
          currentRow: effectiveRow,
          currentOrder: effectiveOrder,
        ) ??
        tvFocusScope?.onBottomEdge;

    if (externalProvider != null) {
      return externalProvider.wrapFocusable(
        row: effectiveRow,
        order: effectiveOrder,
        isRowEntryPoint: isRowEntryPoint,
        lockHorizontalNavigation: tvOptions.lockHorizontalNavigation,
        delegateHorizontalNavigation: tvOptions.delegateHorizontalNavigation,
        focusGroup: focusGroup,
        rememberRowPosition: rememberRowPosition,
        // Register the hasFocus-tracking node itself (Case 1); see _scopeNode.
        primaryFocusNode: _scopeNode,
        onRightEdge: rightEdgeHandler,
        onLeftEdge: leftEdgeHandler,
        onTopEdge: topEdgeHandler,
        onBottomEdge: bottomEdgeHandler,
        child: wrappedChild,
      );
    }

    // Standalone mode: use built-in TVFocusWidget
    return TVFocusWidget(
      focusOrder: TVFocusOrder.withOptions(
        tvRow,
        order: tvOrder,
        isRowEntryPoint: isRowEntryPoint,
        lockHorizontalNavigation: tvOptions.lockHorizontalNavigation,
        delegateHorizontalNavigation: tvOptions.delegateHorizontalNavigation,
        focusGroup: focusGroup,
        rememberRowPosition: rememberRowPosition,
      ),
      onRightEdge: rightEdgeHandler,
      onLeftEdge: leftEdgeHandler,
      onTopEdge: topEdgeHandler,
      onBottomEdge: bottomEdgeHandler,
      // Register the hasFocus-tracking node itself (Case 1); see _scopeNode.
      primaryFocusNode: _scopeNode,
      child: wrappedChild,
    );
  }
}
