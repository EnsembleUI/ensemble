import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

// =============================================================================
// TV Focus Order - 2D Grid Coordinate System
// =============================================================================

/// 2D coordinate for TV D-pad navigation. Maps to flutter_pca's PageFocusOrder.
///
/// ## Coordinate System
/// - [row]: Vertical position (0, 1, 2...). Items in same row navigate with LEFT/RIGHT.
/// - [order]: Horizontal position within row. Lower = more left.
///
/// ## Constructors
/// - `TVFocusOrder(row, order)` - Simple positioning, all flags default false.
/// - `TVFocusOrder.withOptions(row, ...)` - Full control over navigation flags.
///
/// ## Example
/// ```dart
/// TVFocusOrder(1, 2)                                    // Row 1, position 2
/// TVFocusOrder.withOptions(0, order: 3, isRowEntryPoint: true)  // Tab bar entry
/// ```
class TVFocusOrder extends FocusOrder {
  /// Creates a focus order with basic positioning.
  ///
  /// Use this for simple cases where you only need row/order coordinates.
  /// For setting [isRowEntryPoint] or navigation options, use [TVFocusOrder.withOptions].
  const TVFocusOrder(
    this.row, [
    this.order = 0,
  ])  : isRowEntryPoint = false,
        lockHorizontalNavigation = false,
        delegateHorizontalNavigation = false,
        section = null;

  /// Creates a focus order with full control over all options.
  ///
  /// Use this when you need to set navigation behavior options like
  /// [isRowEntryPoint], [lockHorizontalNavigation], or [delegateHorizontalNavigation].
  const TVFocusOrder.withOptions(
    this.row, {
    this.order = 0,
    this.isRowEntryPoint = false,
    this.lockHorizontalNavigation = false,
    this.delegateHorizontalNavigation = false,
    this.section,
  });

  final double row;
  final double order;

  /// If true, this item is the preferred entry point when navigating to this row.
  /// Used by TabBar to focus the selected tab when entering the tab row.
  final bool isRowEntryPoint;

  /// If true, prevents horizontal navigation from escaping this row at boundaries.
  /// When at the first item, LEFT won't propagate; when at the last item, RIGHT won't propagate.
  final bool lockHorizontalNavigation;

  /// If true, horizontal navigation (LEFT/RIGHT) is delegated to the parent FocusScope.
  /// Use this for items inside carousels where horizontal keys should switch slides.
  final bool delegateHorizontalNavigation;

  /// Optional navigation section.
  ///
  /// When set, focus movement only considers widgets that share the same section.
  /// This is useful for keeping two nearby UI regions separate while still allowing
  /// explicit edge callbacks to move focus between them.
  final String? section;

  /// Composite value for sorting: row * 10000 + order
  /// This ensures items are sorted by row first, then by order within row
  double get value => row * 10000 + order;

  @override
  int doCompare(TVFocusOrder other) => value.compareTo(other.value);

  /// Create a new TVFocusOrder offset from this one
  TVFocusOrder offset({double rowOffset = 0, double orderOffset = 0}) {
    return TVFocusOrder.withOptions(
      row + rowOffset,
      order: order + orderOffset,
      isRowEntryPoint: isRowEntryPoint,
      lockHorizontalNavigation: lockHorizontalNavigation,
      delegateHorizontalNavigation: delegateHorizontalNavigation,
      section: section,
    );
  }

  /// Request focus on the widget with this order coordinate.
  /// Scoped to current [FocusScope] to prevent stealing focus from other routes.
  void requestFocus(BuildContext context) {
    final scope = FocusScope.of(context);
    final root = FocusManager.instance.rootScope;

    for (final focusNode in root.descendants) {
      if (focusNode.context == null) continue;
      if (!_isInScope(focusNode, scope)) continue;

      final focusTraversalOrder = focusNode.context
          ?.findAncestorWidgetOfExactType<FocusTraversalOrder>();
      if (focusTraversalOrder?.order is TVFocusOrder) {
        final gridFocusOrder = focusTraversalOrder!.order as TVFocusOrder;
        if (gridFocusOrder.value == value) {
          focusNode.requestFocus();
          return;
        }
      }
    }
  }

  /// Request focus on a specific row/order.
  /// Scoped to current [FocusScope] to prevent stealing focus from other routes.
  /// If [order] is omitted, the row's entry point is used when available.
  void requestFocusAt(BuildContext context, double row, [double? order]) {
    final scope = FocusScope.of(context);
    final root = FocusManager.instance.rootScope;
    final rowNodes = <FocusNode>[];

    for (final focusNode in root.descendants) {
      if (focusNode.context == null) continue;
      if (!_isInScope(focusNode, scope)) continue;

      final focusTraversalOrder = focusNode.context
          ?.findAncestorWidgetOfExactType<FocusTraversalOrder>();
      if (focusTraversalOrder?.order is TVFocusOrder) {
        final gridFocusOrder = focusTraversalOrder!.order as TVFocusOrder;
        if (gridFocusOrder.row != row) continue;

        if (order != null) {
          if (gridFocusOrder.order == order) {
            focusNode.requestFocus();
            return;
          }
        } else {
          rowNodes.add(focusNode);
        }
      }
    }

    if (rowNodes.isEmpty) {
      return;
    }

    for (final focusNode in rowNodes) {
      final focusTraversalOrder = focusNode.context
          ?.findAncestorWidgetOfExactType<FocusTraversalOrder>();
      final gridFocusOrder = focusTraversalOrder!.order as TVFocusOrder;
      if (gridFocusOrder.isRowEntryPoint) {
        focusNode.requestFocus();
        return;
      }
    }

    rowNodes.first.requestFocus();
  }

  /// Check if [node] is a descendant of [scope] in the focus tree.
  static bool _isInScope(FocusNode node, FocusScopeNode scope) {
    FocusNode? current = node;
    while (current != null) {
      if (identical(current, scope)) return true;
      current = current.parent;
    }
    return false;
  }

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'TVFocusOrder(row: $row, order: $order, section: $section)';
  }
}

/// Request focus for a row/order pair inside the current FocusTraversalGroup.
///
/// This is a convenience wrapper around [TVFocusOrder.requestFocusAt] so
/// callers can jump to a target coordinate without constructing a temporary
/// order object at the call site.
void requestFocusAt(BuildContext context, double row, [double? order]) {
  const TVFocusOrder(0).requestFocusAt(context, row, order);
}

// =============================================================================
// Grid Building Utilities
// =============================================================================

/// Internal wrapper pairing a FocusNode with its TVFocusOrder coordinate.
class TVFocusOrderNode {
  final FocusNode focus;
  final TVFocusOrder order;

  const TVFocusOrderNode(this.focus, this.order);

  @override
  String toString() => 'TVFocusOrderNode(${order.value}, ${focus.hashCode})';

  @override
  bool operator ==(Object other) =>
      other is TVFocusOrderNode &&
      order.value == other.order.value &&
      order.section == other.order.section;

  @override
  int get hashCode => Object.hash(order.value, order.section);

  /// Build a 2D grid from an iterable of focus order nodes.
  /// Items are grouped by row and sorted by order within each row.
  ///
  /// Example result:
  /// ```
  /// [
  ///   [Node(0,0), Node(0,1), Node(0,2)],  // Row 0
  ///   [Node(1,0), Node(1,1)],              // Row 1
  ///   [Node(2,0), Node(2,1), Node(2,2)],  // Row 2
  /// ]
  /// ```
  static List<List<TVFocusOrderNode>> buildGrid(
    Iterable<TVFocusOrderNode> iterable,
  ) {
    // Sort all items by their composite value (row * 10000 + order)
    final sorted = iterable.sorted(
      (a, b) => a.order.value.compareTo(b.order.value),
    );

    // Group items by row
    final grid = <List<TVFocusOrderNode>>[];
    List<TVFocusOrderNode>? currentRow;

    for (final element in sorted) {
      // Start a new row if this element's row differs from current
      if (currentRow == null ||
          currentRow.first.order.row != element.order.row) {
        currentRow = <TVFocusOrderNode>[];
        grid.add(currentRow);
      }
      currentRow.add(element);
    }

    return grid;
  }
}

// =============================================================================
// Focus Traversal Policy & Scope
// =============================================================================

/// Traversal policy that prevents UP navigation from escaping the Ensemble grid.
class TVFocusOrderTraversalPolicy extends ReadingOrderTraversalPolicy {
  /// When true, UP at row 0 is blocked (focus stays in Ensemble content).
  final bool preventOutOfScopeTopTraversal;

  TVFocusOrderTraversalPolicy({
    this.preventOutOfScopeTopTraversal = true,
  });
}

/// Focus scope with edge handlers for scrollbar navigation and focus locking.
///
/// Use cases:
/// - Scrollbar navigation: onRightEdge moves focus from ListView to scrollbar
/// - Modal dialogs: lockScope prevents focus from escaping
///
/// WARNING: Extends FocusScope directly (inheritance anti-pattern).
/// Data is accessed via findAncestorWidgetOfExactType in TVFocusWidget.
/// Future refactor: Use composition with InheritedWidget for data.
class TVFocusScope extends FocusScope {
  /// When true, focus cannot leave this scope (modal behavior).
  final bool lockScope;

  /// Called when RIGHT pressed at rightmost edge. Use for right-side scrollbar.
  final VoidCallback? onRightEdge;

  /// Called when LEFT pressed at leftmost edge. Use for left-side scrollbar.
  final VoidCallback? onLeftEdge;

  /// Called when UP pressed at top edge.
  final VoidCallback? onTopEdge;

  /// Called when DOWN pressed at bottom edge.
  final VoidCallback? onBottomEdge;

  const TVFocusScope({
    super.key,
    required this.lockScope,
    required super.child,
    super.debugLabel,
    this.onRightEdge,
    this.onLeftEdge,
    this.onTopEdge,
    this.onBottomEdge,
  });
}
