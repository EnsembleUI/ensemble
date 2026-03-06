import 'package:ensemble/framework/device.dart';
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/theme/theme_loader.dart';
import 'package:ensemble/framework/theme/theme_manager.dart';
import 'package:ensemble/framework/tv/tv_focus_order.dart';
import 'package:ensemble/framework/tv/tv_focus_provider.dart';
import 'package:ensemble/framework/tv/tv_focus_theme.dart';
import 'package:ensemble/framework/tv/tv_focus_widget.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/framework/widget/custom_ink_splash.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:flutter/material.dart';

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
      this.ignoresDimension = false});

  final Widget widget;
  final BoxController boxController;

  // child widget may want to control these themselves
  final bool ignoresPadding;
  final bool ignoresMargin;
  final bool ignoresDimension;

  @override
  Widget build(BuildContext context) {
    if (!boxController.requiresBox(
        ignoresMargin: ignoresMargin,
        ignoresPadding: ignoresPadding,
        ignoresDimension: ignoresDimension)) {
      return _getWidget(context);
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
    if (Device().isTV && boxController.tvOptions?.isEnabled == true) {
      // Tappable widgets get full focus handling
      if (boxController is TapEnabledBoxController) {
        final tapController = boxController as TapEnabledBoxController;
        if (tapController.onTap != null || tapController.onLongPress != null) {
          return _TapEnabledWrapper(
            controller: tapController,
            boxController: boxController,
            child: containerWidget,
            wrapEntireWidget: true,
          );
        }
      }
      // Non-tappable widgets (e.g., Button with built-in tap) get focus ordering only
      return _TVFocusOnlyWrapper(
        boxController: boxController,
        child: containerWidget,
      );
    }

    return containerWidget;
  }

  Widget _getWidget(BuildContext context) {
    if (boxController is TapEnabledBoxController &&
        ((boxController as TapEnabledBoxController).onTap != null ||
            (boxController as TapEnabledBoxController).onLongPress != null)) {
      var controller = boxController as TapEnabledBoxController;

      // TV: Wrap with focus handling (build() handles box-level wrapping)
      if (Device().isTV && boxController.tvOptions?.isEnabled == true) {
        if (!boxController.requiresBox(
            ignoresMargin: ignoresMargin,
            ignoresPadding: ignoresPadding,
            ignoresDimension: ignoresDimension)) {
          return _TapEnabledWrapper(
            controller: controller,
            boxController: boxController,
            child: widget,
            wrapEntireWidget: true,
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
              ? () => ScreenController().executeAction(context, controller.onLongPress!)
              : null,
          onTap: controller.onTap != null
              ? () => ScreenController().executeAction(context, controller.onTap!)
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

/// Handles tap/focus for widgets with onTap.
/// - TV: D-pad focus with visible border, auto-scroll on focus
/// - Non-TV: Standard InkWell with splash feedback
class _TapEnabledWrapper extends StatefulWidget {
  const _TapEnabledWrapper({
    required this.child,
    required this.controller,
    required this.boxController,
    this.wrapEntireWidget = false,
  });

  final Widget child;
  final TapEnabledBoxController controller;
  final BoxController boxController;

  /// TV: true = focus border outside widget, false = standard touch behavior
  final bool wrapEntireWidget;

  @override
  State<_TapEnabledWrapper> createState() => _TapEnabledWrapperState();
}

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
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    // TV: Auto-scroll to focused item for D-pad navigation
    if (Device().isTV && _focusNode.hasFocus && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && context.mounted) {
          _scrollToItemIfNotVisible();
        }
      });
    }
  }

  /// Scrolls to center the focused item only if it's off-screen.
  /// Prevents unwanted scroll jerk in Flow/Grid during horizontal navigation.
  void _scrollToItemIfNotVisible() {
    final isVisible = _isItemFullyVisible();
    if (isVisible) return;

    Scrollable.ensureVisible(
      context,
      alignment: 0.5,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  /// Returns true if item is fully visible on screen.
  /// Uses screen coordinates (not scrollable viewport) to handle nested scrollables.
  bool _isItemFullyVisible() {
    final RenderBox? itemBox = context.findRenderObject() as RenderBox?;
    if (itemBox == null || !itemBox.hasSize) {
      return true;
    }

    // Get the screen/window size
    final Size screenSize = MediaQuery.of(context).size;
    final double screenTop = 0;
    final double screenBottom = screenSize.height;
    final double screenLeft = 0;
    final double screenRight = screenSize.width;

    // Get item position in screen coordinates
    final Offset itemScreenPos = itemBox.localToGlobal(Offset.zero);
    final Size itemSize = itemBox.size;

    // Item bounds in screen coordinates
    final double itemTop = itemScreenPos.dy;
    final double itemBottom = itemScreenPos.dy + itemSize.height;
    final double itemLeft = itemScreenPos.dx;
    final double itemRight = itemScreenPos.dx + itemSize.width;

    // Add padding to account for focus border (typically 3-5px) plus small margin
    const double padding = 15.0;

    // Check if item is fully within screen bounds (with padding)
    final bool isFullyVisible =
        itemTop >= (screenTop + padding) &&
        itemBottom <= (screenBottom - padding) &&
        itemLeft >= (screenLeft + padding) &&
        itemRight <= (screenRight - padding);

    return isFullyVisible;
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final boxController = widget.boxController;

    if (Device().isTV && boxController.tvOptions?.isEnabled == true) {
      return _buildTVFocusable(context, controller);
    }
    return _buildInkWell(context, controller);
  }

  /// TV: Focus border + D-pad navigation via TVFocusProvider or built-in TVFocusWidget.
  /// Style priority: tvOptions > Theme > Provider > App primary color
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

    final externalProvider = TVFocusProviderScope.maybeOf(context);
    final effectiveRow = externalProvider != null
        ? tvRow + externalProvider.rowOffset
        : tvRow;
    final effectiveOrder = externalProvider != null
        ? tvOrder + externalProvider.orderOffset
        : tvOrder;

    // Get TV focus theme from Ensemble theme
    final theme = Theme.of(context);
    final themeExtension = theme.extension<EnsembleThemeExtension>();
    final tvFocusTheme = themeExtension?.tvFocusTheme ?? const TVFocusTheme();

    // Resolve focus styling with fallback chain:
    // 1. tvOptions per-widget override (highest priority)
    // 2. Theme configuration
    // 3. Provider values
    // 4. Default fallback (app primary color for color)
    final appPrimaryColor = theme.colorScheme.primary;

    // Focus color: tvOptions > Theme > Provider > App Primary Color
    final Color focusColor;
    if (tvOptions.focusColor != null) {
      focusColor = tvOptions.focusColor!;
    } else {
      focusColor = tvFocusTheme.resolveFocusColor(
          externalProvider?.focusColor, appPrimaryColor);
    }

    // Focus border width: tvOptions > Theme > Provider > Default
    final double focusBorderWidth;
    if (tvOptions.focusBorderWidth != null) {
      focusBorderWidth = tvOptions.focusBorderWidth!;
    } else {
      focusBorderWidth = tvFocusTheme.resolveBorderWidth(externalProvider?.focusBorderWidth);
    }

    // Focus border radius: tvOptions > Widget's borderRadius > Theme > Default
    final double themeFocusBorderRadius = tvFocusTheme.resolveBorderRadius(externalProvider?.focusBorderRadius);
    final focusAnimationDuration = tvFocusTheme.resolveAnimationDuration(externalProvider?.focusAnimationDurationMs);

    final BorderRadius borderRadius;
    if (tvOptions.focusBorderRadius != null) {
      borderRadius = BorderRadius.circular(tvOptions.focusBorderRadius!);
    } else if (boxController.borderRadius != null) {
      borderRadius = boxController.borderRadius!.getValue();
    } else {
      borderRadius = BorderRadius.circular(themeFocusBorderRadius);
    }

    // When wrapEntireWidget is true, don't add internal padding - child is already the complete widget
    // When false (standard behavior), add padding if splash feedback is enabled
    Widget content = widget.wrapEntireWidget
        ? widget.child
        : (controller.enableSplashFeedback && controller.padding != null
            ? Padding(padding: controller.padding!, child: widget.child)
            : widget.child);

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
          ? () => ScreenController().executeAction(context, controller.onLongPress!)
          : null,
      child: Builder(
        builder: (builderContext) {
          final hasFocus = Focus.maybeOf(builderContext)?.hasFocus ?? false;
          return AnimatedContainer(
            duration: focusAnimationDuration,
            decoration: BoxDecoration(
              border: Border.all(
                color: hasFocus ? focusColor : Colors.transparent,
                width: hasFocus ? focusBorderWidth : 0,
              ),
              borderRadius: borderRadius,
            ),
            child: content,
          );
        },
      ),
    );

    final materialChild = Material(color: Colors.transparent, child: inkWell);

    if (externalProvider != null) {
      return externalProvider.wrapFocusable(
        row: effectiveRow,
        order: effectiveOrder,
        isRowEntryPoint: isRowEntryPoint,
        child: materialChild,
      );
    }

    // Otherwise use Ensemble's built-in TVFocusWidget
    return TVFocusWidget(
      focusOrder: TVFocusOrder.withOptions(tvRow, order: tvOrder, isRowEntryPoint: isRowEntryPoint),
      child: materialChild,
    );
  }

  /// Non-TV: Standard InkWell with splash feedback for touch/mouse.
  Widget _buildInkWell(BuildContext context, TapEnabledBoxController controller) {
    Widget inkWellChild = controller.enableSplashFeedback && controller.padding != null
        ? Padding(
            padding: controller.padding!,
            child: widget.child,
          )
        : widget.child;

    Widget inkWell = InkWell(
      focusNode: _focusNode,
      autofocus: widget.boxController.autofocus,
      splashFactory: CustomInkSplashFactory(
        splashDuration: controller.splashDuration,
        splashFadeDuration: controller.splashFadeDuration,
        unconfirmedSplashDuration: controller.unconfirmedSplashDuration,
      ),
      onLongPress: controller.onLongPress != null
          ? () => ScreenController().executeAction(context, controller.onLongPress!)
          : null,
      onTap: controller.onTap != null
          ? () => ScreenController().executeAction(context, controller.onTap!)
          : null,
      splashColor: controller.enableSplashFeedback
          ? controller.splashColor
          : Colors.transparent,
      highlightColor: Colors.transparent,
      focusColor: controller.focusColor,
      hoverColor: controller.hoverColor,
      mouseCursor: controller.mouseCursor,
      child: inkWellChild,
    );

    return Material(color: Colors.transparent, child: inkWell);
  }
}

/// TV: D-pad navigation for widgets with built-in tap handling (e.g., Button).
/// Only adds focus ordering; child handles its own tap and focus visuals.
class _TVFocusOnlyWrapper extends StatelessWidget {
  const _TVFocusOnlyWrapper({
    required this.child,
    required this.boxController,
  });

  final Widget child;
  final BoxController boxController;

  @override
  Widget build(BuildContext context) {
    final tvOptions = boxController.tvOptions!;
    final tvRow = tvOptions.row!;
    final tvOrder = tvOptions.order ?? 0;
    final isRowEntryPoint = tvOptions.isRowEntryPoint;

    final externalProvider = TVFocusProviderScope.maybeOf(context);
    final effectiveRow = externalProvider != null
        ? tvRow + externalProvider.rowOffset
        : tvRow;
    final effectiveOrder = externalProvider != null
        ? tvOrder + externalProvider.orderOffset
        : tvOrder;

    if (externalProvider != null) {
      return externalProvider.wrapFocusable(
        row: effectiveRow,
        order: effectiveOrder,
        isRowEntryPoint: isRowEntryPoint,
        child: child,
      );
    }

    // Standalone mode: use built-in TVFocusWidget
    return TVFocusWidget(
      focusOrder: TVFocusOrder.withOptions(tvRow, order: tvOrder, isRowEntryPoint: isRowEntryPoint),
      child: child,
    );
  }
}
