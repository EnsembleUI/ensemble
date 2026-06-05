import 'package:ensemble/framework/device.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Focusable scrollbar widget for TV navigation.
///
/// This widget:
/// - Renders a vertical scrollbar with two visual states (normal/focused)
/// - Handles UP/DOWN key events to manually scroll content
/// - Listens to ScrollController to auto-sync thumb position
/// - Receives focus via TVFocusScope edge handlers when user navigates to boundary
/// - Returns focus to content based on scrollbar position (LEFT for right scrollbar, RIGHT for left scrollbar)
///
/// Visual States:
/// - Normal: Grey color, thin width (e.g., 3px)
/// - Focused: White color, wider width (e.g., 6px)
///
/// Navigation:
/// - Right-positioned scrollbar: RIGHT key at content edge → Scrollbar, LEFT returns to content
/// - Left-positioned scrollbar: LEFT key at content edge → Scrollbar, RIGHT returns to content
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

    debugPrint('[TVScrollbar] initState - position=${widget.options.position}');
  }

  /// Public method to request focus on this scrollbar (called from ListView)
  void requestFocusOnScrollbar() {
    debugPrint('[TVScrollbar] requestFocusOnScrollbar() called');
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
    if (!widget.scrollController.hasClients) {
      debugPrint('[TVScrollbar] _scrollDown - no scroll controller clients');
      return;
    }

    final position = widget.scrollController.position;
    final viewportHeight = position.viewportDimension;
    final scrollStep = viewportHeight * 0.2; // Scroll 20% of viewport

    final currentOffset = position.pixels;
    final newOffset = (currentOffset + scrollStep).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    debugPrint('[TVScrollbar] Scrolling DOWN: $currentOffset → $newOffset');

    widget.scrollController.animateTo(
      newOffset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _scrollUp() {
    if (!widget.scrollController.hasClients) {
      debugPrint('[TVScrollbar] _scrollUp - no scroll controller clients');
      return;
    }

    final position = widget.scrollController.position;
    final viewportHeight = position.viewportDimension;
    final scrollStep = viewportHeight * 0.2; // Scroll 20% of viewport

    final currentOffset = position.pixels;
    final newOffset = (currentOffset - scrollStep).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    debugPrint('[TVScrollbar] Scrolling UP: $currentOffset → $newOffset');

    widget.scrollController.animateTo(
      newOffset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only render on TV
    if (!Device().isTV) {
      return const SizedBox.shrink();
    }

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
              debugPrint('[TVScrollbar] DOWN key - scrolling down');
              _scrollDown();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              debugPrint('[TVScrollbar] UP key - scrolling up');
              _scrollUp();
              return KeyEventResult.handled;
            }

            // Handle LEFT/RIGHT to return focus to content based on scrollbar position
            // When scrollbar is on right, LEFT returns to content
            // When scrollbar is on left, RIGHT returns to content
            if (widget.options.position == 'right' &&
                event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              debugPrint('[TVScrollbar] LEFT key - returning focus to content (scrollbar on right)');
              return KeyEventResult.ignored; // Let focus system handle it
            } else if (widget.options.position == 'left' &&
                       event.logicalKey == LogicalKeyboardKey.arrowRight) {
              debugPrint('[TVScrollbar] RIGHT key - returning focus to content (scrollbar on left)');
              return KeyEventResult.ignored; // Let focus system handle it
            }

            return KeyEventResult.ignored;
          },
          child: InkWell(
            focusNode: _focusNode,
            onTap: () {
              debugPrint('[TVScrollbar] Tapped');
            },
            onFocusChange: (hasFocus) {
              debugPrint('[TVScrollbar] onFocusChange: $hasFocus');
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
