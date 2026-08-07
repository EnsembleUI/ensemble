import 'package:flutter/material.dart';

// =============================================================================
// TV Focus - Scroll Into View
// =============================================================================
// Scroll-into-view logic used by TVScrollbarWidget so a focused scrollbar is
// always revealed by its nearest vertical scrollable ancestor. (Regular
// focusable widgets implement the same rule in box_wrapper.dart.)

const int kTVScrollAnimationDurationMs = 200; // Scroll animation duration
const double kTVVerticalScrollPadding = 50.0; // Vertical visibility padding
const double kTVScrollThreshold = 2.0; // Min delta to trigger scroll

/// Finds the nearest vertical scrollable ancestor.
ScrollableState? findNearestVerticalScrollable(BuildContext context) {
  ScrollableState? scrollable;

  context.visitAncestorElements((element) {
    if (element.widget is Scrollable) {
      final state = (element as StatefulElement).state;
      if (state is ScrollableState) {
        final axis = state.axisDirection;
        if (axis == AxisDirection.up || axis == AxisDirection.down) {
          scrollable = state;
          return false; // Stop searching
        }
      }
    }
    return true; // Continue searching
  });

  return scrollable;
}

/// Scrolls ONLY the nearest vertical scrollable ancestor so that
/// [widgetContext]'s render box is fully visible within the viewport.
/// Unlike Scrollable.ensureVisible(), this does NOT affect horizontal scroll.
/// [verticalPadding] controls the threshold from viewport edges (use larger
/// values when there's a top nav bar that items might hide behind).
/// [animationDurationMs] controls the scroll animation duration in milliseconds.
/// [curve] controls the animation curve (defaults to easeInOut).
void scrollWidgetIntoView(
  BuildContext widgetContext, {
  double verticalPadding = kTVVerticalScrollPadding,
  int animationDurationMs = kTVScrollAnimationDurationMs,
  Curve curve = Curves.easeInOut,
}) {
  final scrollable = findNearestVerticalScrollable(widgetContext);
  if (scrollable == null) return;

  final itemBox = widgetContext.findRenderObject() as RenderBox?;
  if (itemBox == null || !itemBox.hasSize) return;

  final scrollableBox = scrollable.context.findRenderObject() as RenderBox?;
  if (scrollableBox == null || !scrollableBox.hasSize) return;

  final position = scrollable.position;

  // Get scrollable viewport position relative to screen
  final Offset scrollableScreenPos = scrollableBox.localToGlobal(Offset.zero);
  final double viewportTop = scrollableScreenPos.dy;
  final double viewportBottom = viewportTop + scrollableBox.size.height;

  // Get item position relative to screen
  final Offset itemScreenPos = itemBox.localToGlobal(Offset.zero);
  final double itemTop = itemScreenPos.dy;
  final double itemBottom = itemTop + itemBox.size.height;

  final bool isAboveScreen = itemTop < viewportTop;
  final bool isBelowScreen = itemBottom > viewportBottom;

  // If fully visible vertically, no need to scroll
  if (!isAboveScreen && !isBelowScreen) {
    return;
  }

  // Calculate how much to scroll
  // Use verticalPadding to position the item nicely within the viewport,
  // not as a trigger threshold - so horizontal navigation doesn't jitter.
  double scrollDelta = 0.0;
  if (isAboveScreen) {
    // Item is above visible area - scroll up (decrease scroll position)
    scrollDelta = itemTop - (viewportTop + verticalPadding);
  } else if (isBelowScreen) {
    // Item is below visible area - scroll down (increase scroll position)
    scrollDelta = itemBottom - (viewportBottom - verticalPadding);
  }

  final double targetScroll =
      (position.pixels + scrollDelta).clamp(0.0, position.maxScrollExtent);

  // Only scroll if delta is significant (avoid micro-scrolls)
  if ((targetScroll - position.pixels).abs() > kTVScrollThreshold) {
    position.animateTo(
      targetScroll,
      duration: Duration(milliseconds: animationDurationMs),
      curve: curve,
    );
  }
}
