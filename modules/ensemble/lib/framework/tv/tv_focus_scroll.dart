import 'package:flutter/material.dart';

// =============================================================================
// TV Focus - Scroll Into View
// =============================================================================
// Shared scroll-into-view primitives for TV D-pad focus. Both regular
// focusables (box_wrapper.dart) and the focusable scrollbar
// (tv_scrollbar_widget.dart) reveal a newly focused target through the SAME
// axis-restricted rule defined here, so behavior stays consistent and a fix
// only has to be made in one place.

// TV scroll tuning defaults (single home; overridable via tvOptions in YAML).
// Vertical/threshold/duration are used by the shared helpers below; the
// horizontal/edge values are consumed by box_wrapper's horizontal helpers.
const int kTVScrollAnimationDurationMs = 200; // Scroll animation duration
const double kTVVerticalScrollPadding = 50.0; // Vertical visibility padding
const double kTVScrollThreshold = 2.0; // Min delta to trigger scroll
const double kTVHorizontalScrollPadding = 16.0; // Horizontal visibility padding
const double kTVFixedFocusOffset = 48.0; // Netflix-style fixed position
const double kTVEdgePadding = 8.0; // Edge visibility buffer

/// Converts a curve name string to a Flutter [Curve].
/// Supported: easeIn, easeOut, easeInOut, linear, decelerate, ease,
/// fastOutSlowIn, bounceOut, elasticOut. Falls back to [defaultCurve].
Curve curveFromName(String? curveName, {Curve defaultCurve = Curves.easeOut}) {
  switch (curveName?.toLowerCase()) {
    case 'easein':
      return Curves.easeIn;
    case 'easeout':
      return Curves.easeOut;
    case 'easeinout':
      return Curves.easeInOut;
    case 'linear':
      return Curves.linear;
    case 'decelerate':
      return Curves.decelerate;
    case 'ease':
      return Curves.ease;
    case 'fastoutslowin':
      return Curves.fastOutSlowIn;
    case 'bounceout':
      return Curves.bounceOut;
    case 'elasticout':
      return Curves.elasticOut;
    default:
      return defaultCurve;
  }
}

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

/// Finds the outermost vertical scrollable ancestor for route-scoped memory.
ScrollableState? findOutermostVerticalScrollable(BuildContext context) {
  ScrollableState? scrollable;

  context.visitAncestorElements((element) {
    if (element.widget is Scrollable) {
      final state = (element as StatefulElement).state;
      if (state is ScrollableState) {
        final axis = state.axisDirection;
        if (axis == AxisDirection.up || axis == AxisDirection.down) {
          scrollable = state;
        }
      }
    }
    return true;
  });

  return scrollable;
}

/// Scrolls ONLY [scrollable] so that [itemBox] is fully visible vertically.
/// Unlike Scrollable.ensureVisible(), this does NOT affect horizontal scroll.
/// [verticalPadding] controls the threshold from viewport edges (use larger
/// values when there's a top nav bar that items might hide behind).
/// [animationDurationMs] controls the scroll animation duration in milliseconds.
/// [curve] controls the animation curve (defaults to easeInOut).
void scrollVerticalOnly(
  ScrollableState scrollable,
  RenderBox itemBox, {
  double verticalPadding = kTVVerticalScrollPadding,
  int animationDurationMs = kTVScrollAnimationDurationMs,
  Curve curve = Curves.easeInOut,
}) {
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

  // Calculate how much to scroll. Use verticalPadding to position the item
  // nicely within the viewport, not as a trigger threshold.
  double scrollDelta = 0.0;
  if (isAboveScreen) {
    // Item is above visible area - scroll up (decrease scroll position)
    scrollDelta = itemTop - (viewportTop + verticalPadding);
  } else if (isBelowScreen) {
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

/// Convenience wrapper: resolves [widgetContext]'s nearest vertical scrollable
/// ancestor and its render box, then reveals it via [scrollVerticalOnly].
/// Unlike Scrollable.ensureVisible(), this does NOT affect horizontal scroll.
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

  scrollVerticalOnly(
    scrollable,
    itemBox,
    verticalPadding: verticalPadding,
    animationDurationMs: animationDurationMs,
    curve: curve,
  );
}

/// Reveals [widgetContext] in every scrollable ancestor using each scrollable's
/// own [ScrollPosition.ensureVisible] with keep-visible alignment policies.
///
/// Unlike [scrollVerticalOnly], this does NOT derive targets from global
/// coordinates. It therefore respects slivers, pinned/overlay headers, content
/// padding, and nested scrollables, and it moves only the minimum amount
/// required. This is the TV-focus equivalent of Flutter's default traversal
/// reveal ([Scrollable.ensureVisible] with `keepVisibleAtStart`/`End`).
///
/// Both policies are applied per scrollable: `keepVisibleAtEnd` reveals an item
/// past the trailing edge, `keepVisibleAtStart` reveals an item before the
/// leading edge. Each is a no-op when the item is already visible on that side,
/// so at most one actually animates. Axis direction is handled internally by
/// [ScrollPosition.ensureVisible].
///
/// [includeHorizontal]/[includeVertical] let callers skip an axis handled
/// elsewhere (e.g. a host app that manages its own horizontal scrolling).
/// Scrollables on a skipped axis are left untouched but the walk continues to
/// their ancestors.
Future<void> ensureWidgetVisible(
  BuildContext widgetContext, {
  Duration duration = Duration.zero,
  Curve curve = Curves.ease,
  bool includeHorizontal = true,
  bool includeVertical = true,
}) async {
  final renderObject = widgetContext.findRenderObject();
  if (renderObject == null || !renderObject.attached) return;

  // Record the first (innermost) revealed render object so outer scrollables
  // intersect against it, keeping the target's own box as visible as possible
  // when multiple scrollables are nested. See flutter/flutter#65100.
  RenderObject? targetRenderObject;
  var scrollable = Scrollable.maybeOf(widgetContext);

  while (scrollable != null) {
    if (!scrollable.mounted) break;
    final axisDirection = scrollable.axisDirection;
    final isHorizontal = axisDirection == AxisDirection.left ||
        axisDirection == AxisDirection.right;
    final include = isHorizontal ? includeHorizontal : includeVertical;

    if (include) {
      final position = scrollable.position;
      if (position.hasContentDimensions) {
        // Single reveal per scrollable, with the alignment policy chosen from
        // the item's current position (like Flutter's directional traversal).
        // Calling ensureVisible twice in series starts a second 200ms animation
        // after the first settles, which reads as a laggy two-phase scroll.
        final policy =
            _revealPolicyFor(renderObject, scrollable, targetRenderObject);
        if (policy != null) {
          await position.ensureVisible(
            renderObject,
            duration: duration,
            curve: curve,
            alignmentPolicy: policy,
            targetRenderObject: targetRenderObject,
          );
          if (!scrollable.mounted) break;
        }
      }
      targetRenderObject ??= renderObject;
    }

    final scrollableContext = scrollable.context;
    scrollable = Scrollable.maybeOf(scrollableContext);
  }
}

/// Chooses the single [ScrollPositionAlignmentPolicy] that reveals
/// [target] with the least movement given its position in [scrollable].
///
/// Returns `keepVisibleAtEnd` when the item is past the trailing edge,
/// `keepVisibleAtStart` when it is before the leading edge, and `null` when the
/// item is already fully visible on the scrollable's main axis (no scroll
/// needed). Falls back to `keepVisibleAtEnd` if geometry cannot be resolved.
ScrollPositionAlignmentPolicy? _revealPolicyFor(
  RenderObject target,
  ScrollableState scrollable,
  RenderObject? targetRenderObject,
) {
  final targetBox = target as RenderBox?;
  final scrollableBox = scrollable.context.findRenderObject() as RenderBox?;
  if (targetBox == null ||
      scrollableBox == null ||
      !targetBox.hasSize ||
      !scrollableBox.hasSize) {
    return ScrollPositionAlignmentPolicy.keepVisibleAtEnd;
  }

  final horizontal = scrollable.axisDirection == AxisDirection.left ||
      scrollable.axisDirection == AxisDirection.right;

  // Position of the item's leading/trailing edge in the scrollable's viewport
  // coordinate space.
  final Offset itemTopLeft = targetBox.localToGlobal(Offset.zero);
  final Offset viewportTopLeft = scrollableBox.localToGlobal(Offset.zero);
  final double itemStart = horizontal ? itemTopLeft.dx : itemTopLeft.dy;
  final double itemEnd = itemStart +
      (horizontal ? targetBox.size.width : targetBox.size.height);
  final double viewportStart =
      horizontal ? viewportTopLeft.dx : viewportTopLeft.dy;
  final double viewportEnd =
      viewportStart + (horizontal ? scrollableBox.size.width : scrollableBox.size.height);

  if (itemEnd > viewportEnd) {
    return ScrollPositionAlignmentPolicy.keepVisibleAtEnd;
  }
  if (itemStart < viewportStart) {
    return ScrollPositionAlignmentPolicy.keepVisibleAtStart;
  }
  return null;
}


// =============================================================================
// TV Focus - Active Vertical Scrollable Memory (route-scoped)
// =============================================================================

final Map<Object, ScrollableState> _activeVerticalScrollables = {};

Object _activeScrollableRouteKey(Route<dynamic>? route) =>
    route == null ? 'noRoute' : identityHashCode(route);

void rememberActiveVerticalScrollable(
    Route<dynamic>? route, ScrollableState scrollable) {
  _activeVerticalScrollables[_activeScrollableRouteKey(route)] = scrollable;
}

ScrollableState? activeVerticalScrollable(Route<dynamic>? route) =>
    _activeVerticalScrollables[_activeScrollableRouteKey(route)];

void clearActiveVerticalScrollableForRoute(Route<dynamic>? route) {
  _activeVerticalScrollables.remove(_activeScrollableRouteKey(route));
}

/// Resolves [context]'s scrollable ancestry and remembers the outermost
/// vertical scrollable for the current route so `resetScrollOnFocus` can
/// target it. No-op when there is no vertical scrollable ancestor.
void rememberActiveVerticalScrollableForContext(BuildContext context) {
  final nearest = findNearestVerticalScrollable(context);
  if (nearest == null) return;
  rememberActiveVerticalScrollable(
    ModalRoute.of(context),
    findOutermostVerticalScrollable(context) ?? nearest,
  );
}
