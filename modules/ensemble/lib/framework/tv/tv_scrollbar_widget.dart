import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// =============================================================================
// TVScrollbarWidget - Focusable Scrollbar for D-pad Navigation
// =============================================================================

/// Focusable scrollbar for TV. Syncs with ListView's ScrollController.
///
/// ## Visual States
/// - Unfocused: Grey, thin (3px default)
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
///       color: 0xFF666666   # unfocused color
///       focusedColor: 0xFFFFFFFF
/// ```
class TVScrollbarWidget extends StatefulWidget {
  const TVScrollbarWidget({
    super.key,
    required this.scrollController,
    required this.options,
  });

  /// ScrollController from the scrollable content (ListView/Column)
  final ScrollController scrollController;

  /// Scrollbar styling options from YAML
  final TVScrollbarOptionsComposite options;

  @override
  State<TVScrollbarWidget> createState() => _TVScrollbarWidgetState();
}

class _TVScrollbarWidgetState extends State<TVScrollbarWidget> {
  late final FocusNode _focusNode;
  bool _isFocused = false;
  double _thumbOffset = 0.0;
  double _thumbHeight = 0.0;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'TVScrollbar');
    widget.scrollController.addListener(_onScrollChange);
  }

  /// Public method to request focus on this scrollbar (called from ListView)
  void requestFocusOnScrollbar() {
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScrollChange);
    _focusNode.dispose();
    super.dispose();
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

    // Removed excessive logging - thumb updates constantly during scroll
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
    // Calculate current thumb position for first render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.scrollController.hasClients) {
        _updateThumbPosition();
      }
    });

    // Focus is requested via TVFocusScope edge handlers when user navigates to content boundary
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackHeight = constraints.maxHeight;

        // Use Focus widget with onKeyEvent for UP/DOWN scrolling
        // InkWell provides focusability and integrates with directional focus
        return Focus(
          onKeyEvent: (node, event) {
            // Only handle when we have focus
            if (!_isFocused || event is! KeyDownEvent) return KeyEventResult.ignored;

            // Handle UP/DOWN for manual scrolling
            if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              _scrollDown();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              _scrollUp();
              return KeyEventResult.handled;
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
            autofocus: widget.options.autofocus,
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
              width: _isFocused ? widget.options.focusedWidth : widget.options.width,
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
                      width: _isFocused ? widget.options.focusedWidth : widget.options.width,
                      height: _thumbHeight,
                      decoration: BoxDecoration(
                        color: _isFocused ? widget.options.focusedColor : widget.options.color,
                        borderRadius: BorderRadius.circular(widget.options.radius),
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
