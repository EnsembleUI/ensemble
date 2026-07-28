import 'package:ensemble/framework/tv/tv_focus_order.dart';
import 'package:ensemble/framework/tv/tv_focus_registry.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// =============================================================================
// TVFocusWidget - Ensemble's Built-in D-pad Navigation
// =============================================================================

/// Wraps a focusable child with D-pad navigation. Used when no external
/// TVFocusProvider is supplied (standalone Ensemble apps).
///
/// ## How It Works
/// 1. Intercepts arrow key events (UP/DOWN/LEFT/RIGHT)
/// 2. Scans FocusTraversalGroup for all TVFocusOrder widgets
/// 3. Builds 2D grid, moves focus based on row/order coordinates
/// 4. Calls edge handlers when at grid boundaries (for scrollbar navigation)
///
/// ## Key Architecture Note
/// Uses FocusScope (not Focus) so key events bubble up from child.
/// With plain Focus, this node would be a sibling and miss key events.
class TVFocusWidget extends StatelessWidget {
  // ─────────────────────────────────────────────────────────────────────────
  // Row Position Memory (opt-in via tvOptions.rememberRowPosition)
  // ─────────────────────────────────────────────────────────────────────────
  // Remembers the last focused column (order) per row so vertical navigation
  // returns to it. Enabled per-widget by `rememberRowPosition` — NOT by
  // focusGroup. Scoped per screen: the outer map is keyed by the ModalRoute
  // instance, so different screens (and different visits of the same screen)
  // never share memory. Within a route it is keyed by "${focusGroup ?? ''}_$row"
  // so multiple independent regions on one screen stay separate when they set a
  // focusGroup — and it still works with no focusGroup at all.
  // ─────────────────────────────────────────────────────────────────────────
  static final Map<Object, Map<String, double>> _rowOrderMemory = {};

  /// Per-screen namespace (route instance identity). Base [Route] type so the
  /// observer (plain Route on pop) and nav code (ModalRoute) key the same bucket.
  static Object _routeKey(Route<dynamic>? route) =>
      route == null ? 'noRoute' : identityHashCode(route);

  /// Creates a within-route memory key for the given focusGroup and row.
  static String _memoryKey(String? focusGroup, double row) {
    return '${focusGroup ?? ''}_$row';
  }

  /// Saves the current order for a row (called when leaving the row).
  static void _rememberOrder(Route<dynamic>? route, String? focusGroup,
      double row, double order) {
    final bucket = _rowOrderMemory.putIfAbsent(_routeKey(route), () => {});
    bucket[_memoryKey(focusGroup, row)] = order;
  }

  /// Retrieves the remembered order for a row, or null if not remembered.
  static double? _recallOrder(
      Route<dynamic>? route, String? focusGroup, double row) {
    return _rowOrderMemory[_routeKey(route)]?[_memoryKey(focusGroup, row)];
  }

  /// Public save, called on focus-gain so memory stays fresh on all entry paths
  /// (taps, edges, requestFocusAt/ByEdge, carousel), not just D-pad.
  static void rememberOrder(
      Route<dynamic>? route, String? focusGroup, double row, double order) {
    _rememberOrder(route, focusGroup, row, order);
  }

  /// Clears a screen's memory when its route leaves the stack (via
  /// [TVFocusRouteObserver]), so the map doesn't grow unbounded.
  static void clearRowMemoryForRoute(Route<dynamic>? route) {
    _rowOrderMemory.remove(_routeKey(route));
  }

  /// Finds the index of the item with the nearest order value to the target.
  /// Used when the remembered order no longer exists (item was removed).
  static int _findNearestOrderIndex(
    List<TVFocusOrderNode> row,
    double targetOrder,
  ) {
    if (row.isEmpty) return 0;

    int nearestIdx = 0;
    double nearestDiff = (row[0].order.order - targetOrder).abs();

    for (int i = 1; i < row.length; i++) {
      final diff = (row[i].order.order - targetOrder).abs();
      if (diff < nearestDiff) {
        nearestDiff = diff;
        nearestIdx = i;
      }
    }
    return nearestIdx;
  }

  const TVFocusWidget({
    super.key,
    required this.focusOrder,
    required this.child,
    this.onBackPressed,
    this.onRightEdge,
    this.onLeftEdge,
    this.onTopEdge,
    this.onBottomEdge,
    this.primaryFocusNode,
  });

  /// The focus coordinate for this widget
  final TVFocusOrder focusOrder;

  /// The child widget (should be focusable, e.g., InkWell)
  final Widget child;

  /// Optional callback when back button is pressed
  final KeyEventResult Function(FocusNode node)? onBackPressed;

  /// Optional callback when RIGHT is pressed at the rightmost edge
  /// (when no more items exist in the row). Used for navigating to
  /// widgets outside the grid like scrollbars.
  final VoidCallback? onRightEdge;

  /// Optional callback when LEFT is pressed at the leftmost edge
  final VoidCallback? onLeftEdge;

  /// Optional callback when UP is pressed at the topmost edge
  final VoidCallback? onTopEdge;

  /// Optional callback when DOWN is pressed at the bottommost edge
  final VoidCallback? onBottomEdge;

  /// Explicit requestable node for this coordinate, when the child owns one.
  final FocusNode? primaryFocusNode;

  @override
  Widget build(BuildContext context) {
    final registeredFocusNode = primaryFocusNode;

    // Case 1: the child exposes its own requestable node (e.g. an InkWell's
    // FocusNode passed via primaryFocusNode). Register that node directly and
    // keep the wrapping FocusScope anonymous. (Unchanged legacy behavior.)
    if (registeredFocusNode != null) {
      return TVFocusTargetRegistrar(
        focusNode: registeredFocusNode,
        focusOrder: focusOrder,
        row: focusOrder.row,
        order: focusOrder.order,
        focusGroup: focusOrder.focusGroup,
        isRowEntryPoint: focusOrder.isRowEntryPoint,
        lockHorizontalNavigation: focusOrder.lockHorizontalNavigation,
        delegateHorizontalNavigation: focusOrder.delegateHorizontalNavigation,
        child: FocusTraversalOrder(
          order: focusOrder,
          // Use FocusScope instead of Focus so this node becomes the PARENT of
          // the child's focus node, letting key events bubble up through the
          // handler instead of bypassing a sibling.
          child: FocusScope(
            onKeyEvent: _handleScopeKeyEvent,
            child: child,
          ),
        ),
      );
    }

    // Case 2: the child is a passive wrapper with no requestable node of its own
    // (e.g. bracket tiles/tabs whose real focusable leaf lives deeper in the
    // child). Wrap in an ANONYMOUS FocusScope and do NOT register it: the child's
    // actual leaf is discovered by the live focus-tree scan in
    // TVFocusOrderNode.collectInScope. Registering the scope node instead would
    // make navigation request focus on an empty scope, which focuses the scope
    // itself and shows no ring.
    return FocusTraversalOrder(
      order: focusOrder,
      // FocusScope (not Focus) so this node parents the child's focus node and
      // D-pad key events bubble up to [_handleScopeKeyEvent].
      child: FocusScope(
        onKeyEvent: _handleScopeKeyEvent,
        child: child,
      ),
    );
  }

  /// Handles D-pad key events arriving at the wrapping FocusScope.
  ///
  /// [node] is the enclosing scope node the event bubbled up to; navigation
  /// uses it for ancestor/route lookups while this widget's [focusOrder]
  /// identifies the current grid position.
  KeyEventResult _handleScopeKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      // Handle back button
      if (event.logicalKey == LogicalKeyboardKey.goBack) {
        final result = onBackPressed?.call(node);
        if (result != null) {
          return result;
        }
      }

      // Handle arrow keys
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        if (_moveFocus(node, yOffset: 1)) return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (_moveFocus(node, yOffset: -1)) return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        if (_moveFocus(node, xOffset: 1)) return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        if (_moveFocus(node, xOffset: -1)) return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  /// Move focus in the specified direction.
  /// Returns true if focus was moved, false if at boundary.
  bool _moveFocus(
    FocusNode current, {
    int yOffset = 0,
    int xOffset = 0,
  }) {
    // If delegateHorizontalNavigation is true, let parent handle horizontal keys
    // (e.g., for carousel slide switching)
    if (xOffset != 0 && focusOrder.delegateHorizontalNavigation) {
      return false;
    }

    // Find the FocusTraversalGroup this widget belongs to
    final focusTraversalGroup =
        current.context?.findAncestorWidgetOfExactType<FocusTraversalGroup>();

    // Check for scope locking
    final tvFocusScope =
        current.context?.findAncestorWidgetOfExactType<TVFocusScope>();
    final lockScope = tvFocusScope?.lockScope ?? false;
    final rightEdgeHandler = onRightEdge ?? tvFocusScope?.onRightEdge;
    final leftEdgeHandler = onLeftEdge ?? tvFocusScope?.onLeftEdge;
    final bottomEdgeHandler = onBottomEdge ?? tvFocusScope?.onBottomEdge;
    final topEdgeHandler = onTopEdge ?? tvFocusScope?.onTopEdge;
    final currentFocusGroup = focusOrder.focusGroup;
    final route =
        current.context != null ? ModalRoute.of(current.context!) : null;
    // PHASE 1: unified collection (was registry + descendants scan inlined here).
    final inScopeByOrder = TVFocusOrderNode.collectInScope(
      route: route,
      traversalGroup: focusTraversalGroup,
      focusGroup: currentFocusGroup,
    );

    if (inScopeByOrder.isEmpty) {
      return false;
    }

    // Build 2D grid from collected items
    final grid = TVFocusOrderNode.buildGrid(inScopeByOrder.values);
    if (grid.isEmpty) {
      return false;
    }

    // Find current position in grid
    final y =
        grid.indexWhere((row) => row.firstOrNull?.order.row == focusOrder.row);
    if (y == -1) {
      return false;
    }

    // Check if trying to exit at top boundary (UP and at first row in grid)
    // Let the event propagate to native focus handling (e.g., sport tab)
    // so users can navigate back to native content from Ensemble content
    if (yOffset == -1 && y == 0) {
      if (topEdgeHandler != null) {
        topEdgeHandler();
        return true;
      }
      return false;
    }

    final x =
        grid[y].indexWhere((node) => node.order.order == focusOrder.order);
    if (x == -1) {
      return false;
    }

    // Calculate target position
    int newY;
    int newX;

    // For vertical movement, find the nearest row in that direction by actual tvRow value
    // For horizontal movement, find the nearest order in that direction
    if (yOffset != 0) {
      // Vertical movement: find nearest row
      newY = _findNearestRow(grid, y, focusOrder.row, yOffset);

      // Get the target row's actual row value
      final targetRowValue = grid[newY].first.order.row;

      // Save keyed on the SOURCE row; restore keyed on the TARGET row (its own
      // rememberRowPosition + focusGroup) — so entering a remembering row from
      // an ungrouped/other row (e.g. a TabBar) still restores its column.
      if (focusOrder.rememberRowPosition) {
        _rememberOrder(
            route, currentFocusGroup, focusOrder.row, focusOrder.order);
      }

      final targetOrderMeta = grid[newY].first.order;
      if (targetOrderMeta.rememberRowPosition) {
        final rememberedOrder =
            _recallOrder(route, targetOrderMeta.focusGroup, targetRowValue);
        if (rememberedOrder != null) {
          // Try to find item with remembered order
          final rememberedIndex = grid[newY].indexWhere(
            (node) => node.order.order == rememberedOrder,
          );
          if (rememberedIndex != -1) {
            // Found the remembered item
            newX = rememberedIndex;
          } else {
            // Remembered order no longer exists, find nearest order
            newX = _findNearestOrderIndex(grid[newY], rememberedOrder);
          }
        } else {
          // No memory for this row - use entry point or first item
          final entryPointIndex = _findRowEntryPoint(grid[newY]);
          newX = entryPointIndex != -1 ? entryPointIndex : 0;
        }
      } else {
        // Default (grid) behavior: entry point → preserve current column → clamp.
        final entryPointIndex = _findRowEntryPoint(grid[newY]);
        if (entryPointIndex != -1) {
          // Entry point found, use it
          newX = entryPointIndex;
        } else {
          // No entry point: preserve current column position (order)
          // Try to find the same order value in the new row
          final sameOrderIndex = grid[newY]
              .indexWhere((node) => node.order.order == focusOrder.order);
          if (sameOrderIndex != -1) {
            newX = sameOrderIndex;
          } else {
            // Same order not found, clamp to available range
            newX = x.clamp(0, grid[newY].length - 1);
          }
        }
      }
    } else {
      // Horizontal movement: stay on same row, find nearest order
      newY = y;
      final targetOrder = focusOrder.order + xOffset;
      final nX = grid[y].indexWhere((node) => node.order.order == targetOrder);
      if (nX != -1) {
        newX = nX;
      } else {
        // Clamp to row boundaries
        newX = (x + xOffset).clamp(0, grid[y].length - 1);
      }
    }

    final oldTarget = grid[y][x].focus;
    final target = grid[newY][newX].focus;

    // Check if we're at a boundary (focus wouldn't move)
    if (oldTarget == target) {
      // Check for edge handlers before letting event propagate
      // This allows navigation to widgets outside the grid (e.g., scrollbars)
      // Priority: widget-level handlers > scope-level handlers
      if (xOffset > 0 && rightEdgeHandler != null) {
        // At right edge and have handler
        if (kDebugMode) {
          debugPrint(
              '[TVFocusWidget] At right edge - calling onRightEdge handler');
        }
        rightEdgeHandler();
        return true;
      } else if (xOffset < 0 && leftEdgeHandler != null) {
        // At left edge and have handler
        if (kDebugMode) {
          debugPrint(
              '[TVFocusWidget] At left edge - calling onLeftEdge handler');
        }
        leftEdgeHandler();
        return true;
      } else if (yOffset > 0 && bottomEdgeHandler != null) {
        // At bottom edge and have handler
        if (kDebugMode) {
          debugPrint(
              '[TVFocusWidget] At bottom edge - calling onBottomEdge handler');
        }
        bottomEdgeHandler();
        return true;
      } else if (yOffset < 0 && topEdgeHandler != null) {
        // At top edge and have handler
        if (kDebugMode) {
          debugPrint('[TVFocusWidget] At top edge - calling onTopEdge handler');
        }
        topEdgeHandler();
        return true;
      }

      // At boundary - let event propagate to parent, unless locked
      if (lockScope) {
        return true;
      }
      if (xOffset != 0 && focusOrder.lockHorizontalNavigation) {
        return true;
      }
      return false;
    }

    // Request focus on target
    // Note: Scrolling is handled by box_wrapper.dart's _onFocusChange() listener
    target.requestFocus();

    // Return true if position changed
    return x != newX || y != newY;
  }

  /// Find the entry point index in a row.
  /// Returns the index of the item marked as entry point, or -1 if none found.
  int _findRowEntryPoint(List<TVFocusOrderNode> row) {
    for (int i = 0; i < row.length; i++) {
      if (row[i].order.isRowEntryPoint) {
        return i;
      }
    }
    // No entry point found
    return -1;
  }

  /// Find the nearest row in the specified direction.
  /// Uses actual tvRow values, not array indices.
  int _findNearestRow(
    List<List<TVFocusOrderNode>> grid,
    int currentY,
    double currentRow,
    int direction,
  ) {
    if (direction > 0) {
      // Moving down: find first row with tvRow > currentRow
      for (int i = currentY + 1; i < grid.length; i++) {
        final rowValue = grid[i].firstOrNull?.order.row;
        if (rowValue != null && rowValue > currentRow) {
          return i;
        }
      }
      // No row found below, stay at current
      return currentY;
    } else {
      // Moving up: find last row with tvRow < currentRow
      for (int i = currentY - 1; i >= 0; i--) {
        final rowValue = grid[i].firstOrNull?.order.row;
        if (rowValue != null && rowValue < currentRow) {
          return i;
        }
      }
      // No row found above, stay at current
      return currentY;
    }
  }
}

/// Frees [TVFocusWidget]'s per-route row-position memory when a screen leaves
/// the stack. Cleared at the route level (not per widget) so item-template
/// rebuilds don't wipe live memory. Registered in [EnsembleRouteObserver].
class TVFocusRouteObserver extends NavigatorObserver {
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    TVFocusWidget.clearRowMemoryForRoute(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    TVFocusWidget.clearRowMemoryForRoute(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (oldRoute != null) {
      TVFocusWidget.clearRowMemoryForRoute(oldRoute);
    }
  }
}
