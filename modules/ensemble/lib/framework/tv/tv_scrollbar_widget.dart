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
class TVScrollbarWidget extends StatefulWidget {
  const TVScrollbarWidget({
    super.key,
    required this.scrollController,
    required this.options,
    this.focusNode,
    this.autofocus = false,
    this.disableHorizontalNavigation = false,
    this.restorePreviousFocusOnTop = false,
    this.onFocusOrigin,
    this.onTopBoundary,
  });

  /// ScrollController from the scrollable content (ListView/Column)
  final ScrollController scrollController;

  /// Scrollbar styling options from YAML
  final TVScrollbarOptionsComposite options;

  /// Optional owner-supplied focus node. This lets ListView make a scrollbar
  /// the fallback target when its content has no TV-focusable children.
  final FocusNode? focusNode;

  /// Requests focus once the scrollbar is visible and scrollable.
  final bool autofocus;

  /// Keeps horizontal navigation on the scrollbar when it is the ListView's
  /// only TV-focusable target.
  final bool disableHorizontalNavigation;

  /// Restores the exact focus target that entered this scrollbar when UP is
  /// pressed at the top. Used only for a ListView fallback scrollbar.
  final bool restorePreviousFocusOnTop;

  /// Reports the focus node that entered this scrollbar.
  final ValueChanged<FocusNode>? onFocusOrigin;

  /// Called instead of the generic focus-origin restoration when UP is pressed
  /// at the top boundary.
  final VoidCallback? onTopBoundary;

  @override
  State<TVScrollbarWidget> createState() => _TVScrollbarWidgetState();
}

class _TVScrollbarWidgetState extends State<TVScrollbarWidget> {
  late final FocusNode _focusNode;
  bool _isFocused = false;
  double _thumbOffset = 0.0;
  double _thumbHeight = 0.0;
  bool _isScrollable = false;
  bool _isInitialized = false;
  bool _didAutofocus = false;
  late final bool _ownsFocusNode;
  FocusNode? _lastPrimaryFocus;
  FocusNode? _focusBeforeScrollbar;

  @override
  void initState() {
    super.initState();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode(debugLabel: 'TVScrollbar');
    _lastPrimaryFocus = FocusManager.instance.primaryFocus;
    FocusManager.instance.addListener(_trackFocusOrigin);
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

  @override
  void didUpdateWidget(TVScrollbarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.autofocus && widget.autofocus) {
      _requestAutofocusIfPossible();
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_trackFocusOrigin);
    widget.scrollController.removeListener(_onScrollChange);
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _trackFocusOrigin() {
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == _focusNode) {
      final previousFocus = _lastPrimaryFocus;
      if (previousFocus != null &&
          previousFocus != _focusNode &&
          previousFocus.context != null &&
          previousFocus.canRequestFocus) {
        _focusBeforeScrollbar = previousFocus;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _focusBeforeScrollbar == previousFocus) {
            widget.onFocusOrigin?.call(previousFocus);
          }
        });
      }
    }
    _lastPrimaryFocus = primaryFocus;
  }

  bool _restorePreviousFocus() {
    final previousFocus = _focusBeforeScrollbar;
    if (previousFocus == null ||
        previousFocus.context == null ||
        !previousFocus.canRequestFocus) {
      return false;
    }
    previousFocus.requestFocus();
    return true;
  }

  void _onScrollChange() {
    if (mounted && widget.scrollController.hasClients) {
      setState(() {
        _updateThumbPosition();
      });
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
    _requestAutofocusIfPossible();
  }

  void _requestAutofocusIfPossible() {
    if (!widget.autofocus || !_isScrollable || _didAutofocus || !mounted) {
      return;
    }
    _didAutofocus = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isScrollable) {
        _focusNode.requestFocus();
      }
    });
  }

  bool _scrollDown() {
    if (!widget.scrollController.hasClients) return false;

    final position = widget.scrollController.position;
    final viewportHeight = position.viewportDimension;
    final scrollStep = viewportHeight * 0.2; // Scroll 20% of viewport

    final newOffset = (position.pixels + scrollStep).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (newOffset == position.pixels) return false;

    widget.scrollController.animateTo(
      newOffset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
    return true;
  }

  bool _scrollUp() {
    if (!widget.scrollController.hasClients) return false;

    final position = widget.scrollController.position;
    final viewportHeight = position.viewportDimension;
    final scrollStep = viewportHeight * 0.2; // Scroll 20% of viewport

    final newOffset = (position.pixels - scrollStep).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (newOffset == position.pixels) return false;

    widget.scrollController.animateTo(
      newOffset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // Hide scrollbar completely if content is not scrollable
    if (!_isScrollable) {
      return const SizedBox.shrink();
    }

    // Focus is requested via TVFocusScope edge handlers when user navigates to content boundary
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackHeight = constraints.maxHeight;

        // Use Focus widget with onKeyEvent for UP/DOWN scrolling
        // InkWell provides focusability and integrates with directional focus
        return Focus(
          onKeyEvent: (node, event) {
            // Only handle when we have focus
            if (!_isFocused || event is! KeyDownEvent)
              return KeyEventResult.ignored;

            if (widget.disableHorizontalNavigation &&
                (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                    event.logicalKey == LogicalKeyboardKey.arrowRight)) {
              return KeyEventResult.handled;
            }

            // Handle UP/DOWN for manual scrolling
            if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              return _scrollDown()
                  ? KeyEventResult.handled
                  : KeyEventResult.ignored;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              if (_scrollUp()) return KeyEventResult.handled;
              if (widget.onTopBoundary != null) {
                widget.onTopBoundary!();
                return KeyEventResult.handled;
              }
              if (widget.restorePreviousFocusOnTop && _restorePreviousFocus()) {
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            }

            // Handle LEFT/RIGHT to return focus to content based on scrollbar position
            // When scrollbar is on right, LEFT returns to content
            // When scrollbar is on left, RIGHT returns to content
            if (widget.options.position == 'right' &&
                event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              return KeyEventResult.ignored; // Let focus system handle it
            } else if (widget.options.position == 'left' &&
                event.logicalKey == LogicalKeyboardKey.arrowRight) {
              return KeyEventResult.ignored; // Let focus system handle it
            }

            return KeyEventResult.ignored;
          },
          child: InkWell(
            focusNode: _focusNode,
            // Focus is requested after the scrollbar has established that the
            // content overflows. An invisible scrollbar must not own focus.
            autofocus: false,
            onTap: () {},
            onFocusChange: (hasFocus) {
              if (mounted) {
                setState(() {
                  _isFocused = hasFocus;
                });
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: _isFocused
                  ? widget.options.focusedWidth
                  : widget.options.width,
              height: trackHeight,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(widget.options.radius),
              ),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 150),
                    left: 0,
                    top: _thumbOffset,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: _isFocused
                          ? widget.options.focusedWidth
                          : widget.options.width,
                      height: _thumbHeight,
                      decoration: BoxDecoration(
                        color: _isFocused
                            ? widget.options.focusedColor
                            : widget.options.color,
                        borderRadius:
                            BorderRadius.circular(widget.options.radius),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
