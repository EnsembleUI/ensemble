import 'package:ensemble/framework/tv/tv_focus_order.dart';
import 'package:ensemble/framework/tv/tv_focus_provider.dart';
import 'package:ensemble/framework/tv/tv_focus_scroll.dart';
import 'package:ensemble/framework/tv/tv_focus_widget.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// =============================================================================
// TVScrollbarWidget - Focusable Scrollbar for D-pad Navigation
// =============================================================================

/// Focusable scrollbar for TV. Syncs with ListView's ScrollController.
///
/// ## Visibility
/// - **Hidden** when content fits in viewport (no scrolling needed)
/// - **Visible** when content overflows (scrolling available)
///
/// ## Visual States (when visible)
/// - Unfocused: Grey, thin (3px default) - always visible if scrollable
/// - Focused: White, wider (6px default)
///
/// ## Navigation Flow
/// 1. User presses RIGHT at content edge → onRightEdge triggers → scrollbar gains focus
/// 2. User presses UP/DOWN → scrolls content 20% per press
/// 3. User presses LEFT → returns focus to content
///
/// ## YAML Configuration
/// ```yaml
/// styles:
///   tvOptions:
///     scrollbarOptions:
///       position: right     # 'left' or 'right'
///       color: 0xFF666666   # unfocused color (visible when scrollable)
///       focusedColor: 0xFFFFFFFF
/// ```
class TVScrollbarFallbackFocusConfig {
  const TVScrollbarFallbackFocusConfig({
    required this.row,
    required this.order,
    this.focusGroup,
    this.isRowEntryPoint = false,
  });

  final double row;
  final double order;
  final String? focusGroup;
  final bool isRowEntryPoint;
}

class TVScrollbarWidget extends StatefulWidget {
  const TVScrollbarWidget({
    super.key,
    required this.scrollController,
    required this.options,
    this.fallbackFocus,
  });

  /// ScrollController from the scrollable content (ListView/Column)
  final ScrollController scrollController;

  /// Scrollbar styling options from YAML
  final TVScrollbarOptionsComposite options;

  /// Optional focus coordinate used when the owning ListView has no focusable
  /// descendants. When omitted, focus reaches the scrollbar only via edge
  /// handoff from a focused content item.
  final TVScrollbarFallbackFocusConfig? fallbackFocus;

  @override
  State<TVScrollbarWidget> createState() => TVScrollbarWidgetState();
}

class TVScrollbarWidgetState extends State<TVScrollbarWidget> {
  late final FocusNode _focusNode;
  bool _isFocused = false;
  double _thumbOffset = 0.0;
  double _thumbHeight = 0.0;
  bool _isScrollable = false;
  bool _isInitialized = false;

  // Thumb offset/height are pushed here on scroll so only the thumb rebuilds
  // (via ValueListenableBuilder) instead of the whole scrollbar subtree.
  final ValueNotifier<({double offset, double height})> _thumbVN =
      ValueNotifier((offset: 0.0, height: 0.0));

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'TVScrollbar');
    widget.scrollController.addListener(_onScrollChange);

    // Initialize thumb position once controller is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeIfReady();
    });
  }

  void _initializeIfReady() {
    if (_isInitialized || !mounted) return;

    if (widget.scrollController.hasClients) {
      _isInitialized = true;
      _updateThumbPosition();
      setState(() {});
    } else {
      // Controller not ready yet, try again next frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeIfReady();
      });
    }
  }

  /// Public method to request focus on this scrollbar (called from ListView)
  void requestFocusOnScrollbar() {
    _focusNode.requestFocus();
  }

  bool get _isFallbackFocusTarget => widget.fallbackFocus != null;

  bool get _canScrollUp {
    if (!widget.scrollController.hasClients) return false;
    final position = widget.scrollController.position;
    return position.pixels > position.minScrollExtent;
  }

  bool get _canScrollDown {
    if (!widget.scrollController.hasClients) return false;
    final position = widget.scrollController.position;
    return position.pixels < position.maxScrollExtent;
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScrollChange);
    _focusNode.dispose();
    _thumbVN.dispose();
    super.dispose();
  }

  void _onScrollChange() {
    if (!mounted || !widget.scrollController.hasClients) return;
    final wasScrollable = _isScrollable;
    _updateThumbPosition(); // updates _thumbVN + _isScrollable (no setState)
    // Full rebuild only when visibility toggles; thumb moves are handled by the
    // ValueListenableBuilder around the thumb.
    if (_isScrollable != wasScrollable) {
      setState(() {});
    }
  }

  void _updateThumbPosition() {
    if (!widget.scrollController.hasClients) return;

    final position = widget.scrollController.position;
    final viewportHeight = position.viewportDimension;
    final contentHeight = position.maxScrollExtent + viewportHeight;
    final scrollOffset = position.pixels;

    // Check if content is scrollable (content exceeds viewport)
    _isScrollable = position.maxScrollExtent > 0;

    if (!_isScrollable) {
      // No scrollable content, hide the thumb
      _thumbHeight = 0.0;
      _thumbOffset = 0.0;
      _thumbVN.value = (offset: 0.0, height: 0.0);
      return;
    }

    // Calculate thumb height (proportional to viewport/content ratio)
    final thumbRatio = viewportHeight / contentHeight;
    _thumbHeight = (viewportHeight * thumbRatio).clamp(
      widget.options.thumbHeight,
      viewportHeight,
    );

    // Calculate thumb offset based on scroll position
    final maxThumbOffset = viewportHeight - _thumbHeight;
    final scrollRatio = contentHeight > viewportHeight
        ? scrollOffset / (contentHeight - viewportHeight)
        : 0.0;
    _thumbOffset = (maxThumbOffset * scrollRatio).clamp(0.0, maxThumbOffset);
    _thumbVN.value = (offset: _thumbOffset, height: _thumbHeight);
  }

  void _scrollDown() {
    if (!widget.scrollController.hasClients) return;

    final position = widget.scrollController.position;
    final viewportHeight = position.viewportDimension;
    final scrollStep = viewportHeight * 0.2; // Scroll 20% of viewport

    final newOffset = (position.pixels + scrollStep).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    widget.scrollController.animateTo(
      newOffset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _scrollUp() {
    if (!widget.scrollController.hasClients) return;

    final position = widget.scrollController.position;
    final viewportHeight = position.viewportDimension;
    final scrollStep = viewportHeight * 0.2; // Scroll 20% of viewport

    final newOffset = (position.pixels - scrollStep).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    widget.scrollController.animateTo(
      newOffset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Hide scrollbar completely if content is not scrollable
    if (!_isScrollable) {
      return const SizedBox.shrink();
    }

    // Focus is requested via TVFocusScope edge handlers when user navigates to content boundary
    final scrollbar = LayoutBuilder(
      builder: (context, constraints) {
        final trackHeight = constraints.maxHeight;

        // Use Focus widget with onKeyEvent for UP/DOWN scrolling
        // InkWell provides focusability and integrates with directional focus
        return Focus(
          onKeyEvent: (node, event) {
            // Only handle when we have focus
            if (!_isFocused || (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
              return KeyEventResult.ignored;
            }

            // Handle UP/DOWN for manual scrolling
            if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              if (_isFallbackFocusTarget && !_canScrollDown) {
                return KeyEventResult.ignored;
              }
              _scrollDown();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              if (_isFallbackFocusTarget && !_canScrollUp) {
                return KeyEventResult.ignored;
              }
              _scrollUp();
              return KeyEventResult.handled;
            }

            if (_isFallbackFocusTarget &&
                (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                    event.logicalKey == LogicalKeyboardKey.arrowRight)) {
              return KeyEventResult.handled;
            }

            // LEFT/RIGHT are intentionally not consumed: leaving them unhandled
            // lets the focus system move focus back to the content (the
            // scrollbar sits beside the list, so horizontal nav naturally exits
            // it). UP/DOWN above are the only keys this scrollbar handles.
            return KeyEventResult.ignored;
          },
          child: InkWell(
            focusNode: _focusNode,
            autofocus: widget.options.autofocus,
            onTap: () {},
            onFocusChange: (hasFocus) {
              if (mounted) {
                setState(() {
                  _isFocused = hasFocus;
                });
                // Reveal the scrollbar in its enclosing scrollable when it
                // gains focus (same scroll-into-view rule as other focusables).
                // Re-check `_isFocused` at callback time in case focus has
                // already moved away before the frame completes.
                if (hasFocus) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && context.mounted && _isFocused) {
                      scrollWidgetIntoView(context);
                    }
                  });
                }
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: _isFocused ? widget.options.focusedWidth : widget.options.width,
              height: trackHeight,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(widget.options.radius),
              ),
              child: Stack(
                children: [
                  // Only the thumb rebuilds on scroll (not the whole subtree).
                  ValueListenableBuilder<({double offset, double height})>(
                    valueListenable: _thumbVN,
                    builder: (context, thumb, _) {
                      return AnimatedPositioned(
                        duration: const Duration(milliseconds: 150),
                        left: 0,
                        top: thumb.offset,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: _isFocused
                              ? widget.options.focusedWidth
                              : widget.options.width,
                          height: thumb.height,
                          decoration: BoxDecoration(
                            color: _isFocused
                                ? widget.options.focusedColor
                                : widget.options.color,
                            borderRadius:
                                BorderRadius.circular(widget.options.radius),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    final fallbackFocus = widget.fallbackFocus;
    if (fallbackFocus == null) {
      return scrollbar;
    }

    final externalProvider = TVFocusProviderScope.maybeOf(context);
    if (externalProvider != null) {
      return externalProvider.wrapFocusable(
        row: fallbackFocus.row + externalProvider.rowOffset,
        order: fallbackFocus.order + externalProvider.orderOffset,
        isRowEntryPoint: fallbackFocus.isRowEntryPoint,
        lockHorizontalNavigation: true,
        focusGroup: fallbackFocus.focusGroup,
        primaryFocusNode: _focusNode,
        child: scrollbar,
      );
    }

    return TVFocusWidget(
      focusOrder: TVFocusOrder.withOptions(
        fallbackFocus.row,
        order: fallbackFocus.order,
        isRowEntryPoint: fallbackFocus.isRowEntryPoint,
        lockHorizontalNavigation: true,
        focusGroup: fallbackFocus.focusGroup,
      ),
      primaryFocusNode: _focusNode,
      child: scrollbar,
    );
  }
}
