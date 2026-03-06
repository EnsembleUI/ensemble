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
class TVFocusWidget extends StatelessWidget {
  const TVFocusWidget({
    super.key,
    required this.focusOrder,
    required this.child,
    this.onBackPressed,
  });

  /// The focus coordinate for this widget
  final TVFocusOrder focusOrder;

  /// The child widget (should be focusable, e.g., InkWell)
  final Widget child;

  /// Optional callback when back button is pressed
  final KeyEventResult Function(FocusNode node)? onBackPressed;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalOrder(
      order: focusOrder,
      child: Focus(
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
        // This Focus is for key handling only, not for actual focus
        canRequestFocus: false,
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
    // Find the FocusTraversalGroup this widget belongs to
    final focusTraversalGroup =
        current.context?.findAncestorWidgetOfExactType<FocusTraversalGroup>();

    // Check for scope locking
    final tvFocusScope =
        current.context?.findAncestorWidgetOfExactType<TVFocusScope>();
    final lockScope = tvFocusScope?.lockScope ?? false;

    // Check if trying to exit at top boundary (UP at row 0)
    if (yOffset == -1 && focusOrder.row == 0) {
      // Check if policy blocks escape
      if (focusTraversalGroup?.policy is TVFocusOrderTraversalPolicy) {
        final policy = focusTraversalGroup!.policy as TVFocusOrderTraversalPolicy;
        if (policy.preventOutOfScopeTopTraversal) {
          return true; // Block the event
        }
      }
      // No blocking policy - let event propagate
      return false;
    }

    // Collect all focusable items in the same FocusTraversalGroup
    final root = FocusManager.instance.rootScope;
    final inScope = <TVFocusOrderNode>{};

    for (final focusNode in root.descendants) {
      // Check if this node is mounted and has context
      if (focusNode.context == null) continue;

      // Check if in same FocusTraversalGroup
      final nodeGroup =
          focusNode.context?.findAncestorWidgetOfExactType<FocusTraversalGroup>();
      if (nodeGroup != focusTraversalGroup) continue;

      // Get the TVFocusOrder for this node
      final focusTraversalOrder =
          focusNode.context?.findAncestorWidgetOfExactType<FocusTraversalOrder>();
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
    final y = grid.indexWhere((row) => row.firstOrNull?.order.row == focusOrder.row);
    if (y == -1) {
      return false;
    }

    final x = grid[y].indexWhere((node) => node.order.order == focusOrder.order);
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
      // When moving to a new row, look for an entry point (e.g., selected tab)
      // If no entry point found, go to the first item (order 0)
      newX = _findRowEntryPoint(grid[newY]);
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
      // Handle scope locking
      if (lockScope) {
        // Focus would stay the same, but we're locked - block the event
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
  /// Returns the index of the item marked as entry point, or 0 if none found.
  int _findRowEntryPoint(List<TVFocusOrderNode> row) {
    for (int i = 0; i < row.length; i++) {
      if (row[i].order.isRowEntryPoint) {
        return i;
      }
    }
    // No entry point found, default to first item
    return 0;
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
