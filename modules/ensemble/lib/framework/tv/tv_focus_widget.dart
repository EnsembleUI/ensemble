import 'package:ensemble/framework/tv/tv_focus_order.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Widget that wraps a focusable child with TV D-pad navigation support.
/// Based on flutter_pca's PageFocusWidget pattern.
///
/// This widget:
/// - Intercepts arrow key events (UP/DOWN/LEFT/RIGHT)
/// - Builds a 2D grid of focusable items in the same FocusTraversalGroup
/// - Navigates between items using row/order coordinates
/// - Handles auto-scrolling when focus changes
/// - Supports edge handlers for navigating to widgets outside the grid (e.g., scrollbars)
///
/// IMPORTANT: The inner Focus widget uses `skipTraversal: true` (not `canRequestFocus: false`)
/// so that it still receives key events but doesn't participate in tab navigation.
/// Using `canRequestFocus: false` would cause Flutter to skip this widget entirely
/// in the key event routing chain, breaking D-pad navigation.
class TVFocusWidget extends StatelessWidget {
  const TVFocusWidget({
    super.key,
    required this.focusOrder,
    required this.child,
    this.onBackPressed,
    this.onRightEdge,
    this.onLeftEdge,
    this.onTopEdge,
    this.onBottomEdge,
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

  @override
  Widget build(BuildContext context) {
    return FocusTraversalOrder(
      order: focusOrder,
      // Use FocusScope instead of Focus so that this node becomes the PARENT
      // of the child's focus node in the focus tree. This allows key events
      // from the child to bubble up through this handler.
      // With a plain Focus widget, this node would be a SIBLING to the child's
      // focus node, and key events would bypass it entirely.
      child: FocusScope(
        onKeyEvent: (FocusNode node, KeyEvent event) {
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
              if (_moveFocus(context, node, yOffset: 1)) {
                return KeyEventResult.handled;
              }
            } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              if (_moveFocus(context, node, yOffset: -1)) {
                return KeyEventResult.handled;
              }
            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              if (_moveFocus(context, node, xOffset: 1)) {
                return KeyEventResult.handled;
              }
            } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              if (_moveFocus(context, node, xOffset: -1)) {
                return KeyEventResult.handled;
              }
            }
          }
          return KeyEventResult.ignored;
        },
        child: child,
      ),
    );
  }

  /// Move focus in the specified direction.
  /// Returns true if focus was moved, false if at boundary.
  bool _moveFocus(
    BuildContext context,
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

    // Collect all focusable items in the same FocusTraversalGroup
    final root = FocusManager.instance.rootScope;
    final inScope = <TVFocusOrderNode>{};

    for (final focusNode in root.descendants) {
      // Check if this node is mounted and has context
      if (focusNode.context == null) continue;

      // Check if in same FocusTraversalGroup
      final nodeGroup = focusNode.context
          ?.findAncestorWidgetOfExactType<FocusTraversalGroup>();
      if (nodeGroup != focusTraversalGroup) continue;

      // Get the TVFocusOrder for this node
      final focusTraversalOrder = focusNode.context
          ?.findAncestorWidgetOfExactType<FocusTraversalOrder>();
      if (focusTraversalOrder?.order is TVFocusOrder) {
        final order = focusTraversalOrder!.order as TVFocusOrder;
        inScope.add(TVFocusOrderNode(focusNode, order));
      }
    }

    if (inScope.isEmpty) {
      return false;
    }

    // Build 2D grid from collected items
    final grid = TVFocusOrderNode.buildGrid(inScope);
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
      // Priority: preserve current column (order) > entry point > clamp
      // Try to find the same order value in the new row first
      final sameOrderIndex = grid[newY]
          .indexWhere((node) => node.order.order == focusOrder.order);
      if (sameOrderIndex != -1) {
        // Same order found in target row - stay in same column
        newX = sameOrderIndex;
      } else {
        // Same order not in target row - try entry point as fallback
        final entryPointIndex = _findRowEntryPoint(grid[newY]);
        if (entryPointIndex != -1) {
          newX = entryPointIndex;
        } else {
          // No entry point either, clamp to available range
          newX = x.clamp(0, grid[newY].length - 1);
        }
      }
    } else {
      // Horizontal movement: try to find target order in same row first
      newY = y;
      final targetOrder = focusOrder.order + xOffset;
      final nX = grid[y].indexWhere((node) => node.order.order == targetOrder);
      if (nX != -1) {
        // Found target order in same row
        newX = nX;
      } else {
        // Target order not in current row - find nearest row that has it
        // This handles cases like 8th Finals row 5 → Quarter Finals (which only has rows 1-4)
        int? nearestRowWithTarget;
        int nearestDistance = 999999;

        for (int rowIdx = 0; rowIdx < grid.length; rowIdx++) {
          final hasTargetOrder = grid[rowIdx].any((node) => node.order.order == targetOrder);
          if (hasTargetOrder) {
            final distance = (rowIdx - y).abs();
            if (distance < nearestDistance) {
              nearestDistance = distance;
              nearestRowWithTarget = rowIdx;
            }
          }
        }

        if (nearestRowWithTarget != null) {
          // Found a row with the target order - jump to it
          newY = nearestRowWithTarget;
          newX = grid[newY].indexWhere((node) => node.order.order == targetOrder);
        } else {
          // No row has the target order - clamp to current row boundaries
          newX = (x + xOffset).clamp(0, grid[y].length - 1);
        }
      }
    }

    final oldTarget = grid[y][x].focus;
    final target = grid[newY][newX].focus;

    // Check if we're at a boundary (focus wouldn't move)
    if (oldTarget == target) {
      // Handle scope locking
      if (lockScope) {
        // Focus would stay the same, but we're locked - block the event
        return true;
      }

      // Handle horizontal boundary locking (prevents escaping row at left/right edges)
      if (xOffset != 0 && focusOrder.lockHorizontalNavigation) {
        // At horizontal boundary with lockHorizontalNavigation enabled - block the event
        return true;
      }

      // Check for edge handlers before letting event propagate
      // This allows navigation to widgets outside the grid (e.g., scrollbars)
      // Priority: widget-level handlers > scope-level handlers
      final rightEdgeHandler = onRightEdge ?? tvFocusScope?.onRightEdge;
      final leftEdgeHandler = onLeftEdge ?? tvFocusScope?.onLeftEdge;
      final bottomEdgeHandler = onBottomEdge ?? tvFocusScope?.onBottomEdge;
      final topEdgeHandler = onTopEdge ?? tvFocusScope?.onTopEdge;

      if (xOffset > 0 && rightEdgeHandler != null) {
        rightEdgeHandler();
        return true;
      } else if (xOffset < 0 && leftEdgeHandler != null) {
        leftEdgeHandler();
        return true;
      } else if (yOffset > 0 && bottomEdgeHandler != null) {
        bottomEdgeHandler();
        return true;
      } else if (yOffset < 0 && topEdgeHandler != null) {
        topEdgeHandler();
        return true;
      }

      // At boundary - let event propagate to parent
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
