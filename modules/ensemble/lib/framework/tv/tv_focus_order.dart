import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

// =============================================================================
// TV Focus Order - 2D Grid Coordinate System
// =============================================================================

enum TVFocusDirection {
  left,
  right,
  top,
  bottom,
}

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
        focusGroup = null;

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
    this.focusGroup,
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

  /// Optional focus group.
  ///
  /// When set, focus movement only considers widgets that share the same group.
  /// This is useful for keeping two nearby UI regions separate while still allowing
  /// explicit edge callbacks to move focus between them.
  final String? focusGroup;

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
      focusGroup: focusGroup,
    );
  }

  /// Request focus on the widget with this order coordinate.
  /// Scoped to current route to prevent stealing focus from other screens.
  void requestFocus(BuildContext context) {
    final route = ModalRoute.of(context);
    final root = FocusManager.instance.rootScope;
    TVFocusOrderNode? targetNode;

    for (final focusNode in root.descendants) {
      if (focusNode.context == null) continue;
      if (!focusNode.canRequestFocus) continue;
      if (!_isInRoute(focusNode.context!, route)) continue;

      final focusTraversalOrder = focusNode.context
          ?.findAncestorWidgetOfExactType<FocusTraversalOrder>();
      if (focusTraversalOrder?.order is TVFocusOrder) {
        final gridFocusOrder = focusTraversalOrder!.order as TVFocusOrder;
        if (gridFocusOrder.value == value &&
            gridFocusOrder.focusGroup == focusGroup) {
          final candidate = TVFocusOrderNode(focusNode, gridFocusOrder);
          if (targetNode == null ||
              TVFocusOrderNode.isBetterFocusCandidate(
                  candidate.focus, targetNode.focus)) {
            targetNode = candidate;
          }
        }
      }
    }

    targetNode?.focus.requestFocus();
  }

  /// Request focus on a specific row/order.
  /// Scoped to current route to prevent stealing focus from other screens.
  /// If [order] is omitted, the row's entry point is used when available.
  void requestFocusAt(BuildContext context, double row,
      [double? order, String? focusGroup]) {
    final route = ModalRoute.of(context);
    final root = FocusManager.instance.rootScope;
    final candidatesByOrder = <TVFocusOrderNode, TVFocusOrderNode>{};
    final rowNodesByOrder = <TVFocusOrderNode, TVFocusOrderNode>{};

    for (final focusNode in root.descendants) {
      if (focusNode.context == null) continue;
      if (!focusNode.canRequestFocus) continue;
      if (!_isInRoute(focusNode.context!, route)) continue;

      final focusTraversalOrder = focusNode.context
          ?.findAncestorWidgetOfExactType<FocusTraversalOrder>();
      if (focusTraversalOrder?.order is TVFocusOrder) {
        final gridFocusOrder = focusTraversalOrder!.order as TVFocusOrder;
        if (focusGroup != null && gridFocusOrder.focusGroup != focusGroup) {
          continue;
        }
        final node = TVFocusOrderNode(focusNode, gridFocusOrder);
        TVFocusOrderNode.addPreferredCandidate(candidatesByOrder, node);
        if (gridFocusOrder.row != row) continue;
        TVFocusOrderNode.addPreferredCandidate(rowNodesByOrder, node);
      }
    }

    final candidates = candidatesByOrder.values.toList();
    final rowNodes = rowNodesByOrder.values.toList();

    if (order != null) {
      TVFocusOrderNode? exactNode;
      for (final node in rowNodes) {
        if (node.order.order == order) {
          exactNode = node;
          break;
        }
      }
      if (exactNode != null) {
        exactNode.focus.requestFocus();
        return;
      }
    }

    if (order != null && rowNodes.isNotEmpty) {
      _requestBestNodeInRow(rowNodes, order);
      return;
    }

    if (rowNodes.isEmpty) {
      final nearestRow = _findNearestRow(candidates, row);
      if (nearestRow == null) {
        return;
      }
      _requestBestNodeInRow(nearestRow, order);
      return;
    }

    _requestBestNodeInRow(rowNodes, order);
  }

  /// Request focus from an edge into another focus group.
  ///
  /// Unlike [requestFocusAt], [targetRow] and [targetOrder] are optional hints.
  /// When they are omitted, the target is selected deterministically from the
  /// requested group based on the direction of travel.
  void requestFocusByEdge(
    BuildContext context, {
    required TVFocusDirection direction,
    String? targetFocusGroup,
    double? targetRow,
    double? targetOrder,
    double? currentRow,
    double? currentOrder,
  }) {
    final route = ModalRoute.of(context);
    final root = FocusManager.instance.rootScope;
    final candidatesByOrder = <TVFocusOrderNode, TVFocusOrderNode>{};

    for (final focusNode in root.descendants) {
      if (focusNode.context == null) continue;
      if (!focusNode.canRequestFocus) continue;
      if (!_isInRoute(focusNode.context!, route)) continue;

      final focusTraversalOrder = focusNode.context
          ?.findAncestorWidgetOfExactType<FocusTraversalOrder>();
      if (focusTraversalOrder?.order is TVFocusOrder) {
        final gridFocusOrder = focusTraversalOrder!.order as TVFocusOrder;
        if (targetFocusGroup != null &&
            gridFocusOrder.focusGroup != targetFocusGroup) {
          continue;
        }
        TVFocusOrderNode.addPreferredCandidate(
          candidatesByOrder,
          TVFocusOrderNode(focusNode, gridFocusOrder),
        );
      }
    }

    final candidates = candidatesByOrder.values.toList();
    if (candidates.isEmpty) {
      return;
    }

    final grid = TVFocusOrderNode.buildGrid(candidates);
    if (grid.isEmpty) {
      return;
    }

    final targetRowNodes = _selectRowForEdge(
      grid,
      direction: direction,
      targetRow: targetRow,
      currentRow: currentRow,
    );
    if (targetRowNodes == null || targetRowNodes.isEmpty) {
      return;
    }

    final targetNode = _selectNodeForEdge(
      targetRowNodes,
      direction: direction,
      targetOrder: targetOrder,
      currentOrder: currentOrder,
    );
    targetNode?.focus.requestFocus();
  }

  static List<TVFocusOrderNode>? _selectRowForEdge(
    List<List<TVFocusOrderNode>> grid, {
    required TVFocusDirection direction,
    double? targetRow,
    double? currentRow,
  }) {
    if (targetRow != null) {
      List<TVFocusOrderNode>? nearest;
      var nearestDiff = double.infinity;
      for (final rowNodes in grid) {
        final diff = (rowNodes.first.order.row - targetRow).abs();
        if (diff < nearestDiff) {
          nearest = rowNodes;
          nearestDiff = diff;
        }
      }
      return nearest;
    }

    switch (direction) {
      case TVFocusDirection.right:
      case TVFocusDirection.left:
        if (currentRow == null) {
          return grid.first;
        }
        return _findNearestRow(
          grid.expand((row) => row).toList(),
          currentRow,
        );
      case TVFocusDirection.bottom:
        return grid.first;
      case TVFocusDirection.top:
        return grid.last;
    }
  }

  static TVFocusOrderNode? _selectNodeForEdge(
    List<TVFocusOrderNode> rowNodes, {
    required TVFocusDirection direction,
    double? targetOrder,
    double? currentOrder,
  }) {
    if (rowNodes.isEmpty) {
      return null;
    }

    if (targetOrder != null) {
      return _nearestNodeByOrder(rowNodes, targetOrder);
    }

    switch (direction) {
      case TVFocusDirection.right:
        return rowNodes.first;
      case TVFocusDirection.left:
        return rowNodes.last;
      case TVFocusDirection.top:
      case TVFocusDirection.bottom:
        for (final node in rowNodes) {
          if (node.order.isRowEntryPoint) {
            return node;
          }
        }
        if (currentOrder != null) {
          return _nearestNodeByOrder(rowNodes, currentOrder);
        }
        return rowNodes.first;
    }
  }

  static TVFocusOrderNode? _nearestNodeByOrder(
    List<TVFocusOrderNode> rowNodes,
    double targetOrder,
  ) {
    TVFocusOrderNode? nearest;
    var nearestDiff = double.infinity;
    for (final node in rowNodes) {
      final diff = (node.order.order - targetOrder).abs();
      if (diff < nearestDiff) {
        nearest = node;
        nearestDiff = diff;
      }
    }
    return nearest;
  }

  static List<TVFocusOrderNode>? _findNearestRow(
    List<TVFocusOrderNode> candidates,
    double targetRow,
  ) {
    if (candidates.isEmpty) {
      return null;
    }

    final grid = TVFocusOrderNode.buildGrid(candidates);
    if (grid.isEmpty) {
      return null;
    }

    List<TVFocusOrderNode>? nearest;
    var nearestDiff = double.infinity;
    for (final rowNodes in grid) {
      final diff = (rowNodes.first.order.row - targetRow).abs();
      if (diff < nearestDiff) {
        nearest = rowNodes;
        nearestDiff = diff;
      }
    }
    return nearest;
  }

  static void _requestBestNodeInRow(
    Iterable<TVFocusOrderNode> rowNodes, [
    double? targetOrder,
  ]) {
    final nodes = rowNodes.toList();
    if (nodes.isEmpty) {
      return;
    }

    if (targetOrder != null) {
      TVFocusOrderNode? nearest;
      var nearestDiff = double.infinity;
      for (final node in nodes) {
        final diff = (node.order.order - targetOrder).abs();
        if (diff < nearestDiff) {
          nearest = node;
          nearestDiff = diff;
        }
      }
      nearest?.focus.requestFocus();
      return;
    }

    for (final node in rowNodes) {
      if (node.order.isRowEntryPoint) {
        node.focus.requestFocus();
        return;
      }
    }

    nodes.first.focus.requestFocus();
  }

  static bool _isInRoute(BuildContext context, ModalRoute<dynamic>? route) {
    if (route == null) {
      return true;
    }
    return ModalRoute.of(context) == route;
  }

  static bool isInRoute(BuildContext context, ModalRoute<dynamic>? route) {
    return _isInRoute(context, route);
  }

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'TVFocusOrder(row: $row, order: $order, focusGroup: $focusGroup)';
  }
}

/// Request focus for a row/order pair inside the current FocusTraversalGroup.
///
/// This is a convenience wrapper around [TVFocusOrder.requestFocusAt] so
/// callers can jump to a target coordinate without constructing a temporary
/// order object at the call site.
void requestFocusAt(BuildContext context, double row,
    [double? order, String? focusGroup]) {
  const TVFocusOrder(0).requestFocusAt(context, row, order, focusGroup);
}

void requestFocusByEdge(
  BuildContext context, {
  required TVFocusDirection direction,
  String? targetFocusGroup,
  double? targetRow,
  double? targetOrder,
  double? currentRow,
  double? currentOrder,
}) {
  const TVFocusOrder(0).requestFocusByEdge(
    context,
    direction: direction,
    targetFocusGroup: targetFocusGroup,
    targetRow: targetRow,
    targetOrder: targetOrder,
    currentRow: currentRow,
    currentOrder: currentOrder,
  );
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
      order.focusGroup == other.order.focusGroup;

  @override
  int get hashCode => Object.hash(order.value, order.focusGroup);

  static void addPreferredCandidate(
    Map<TVFocusOrderNode, TVFocusOrderNode> candidates,
    TVFocusOrderNode candidate,
  ) {
    final existing = candidates[candidate];
    if (existing == null ||
        isBetterFocusCandidate(candidate.focus, existing.focus)) {
      candidates[candidate] = candidate;
    }
  }

  static bool isBetterFocusCandidate(FocusNode candidate, FocusNode existing) {
    if (candidate.hasPrimaryFocus != existing.hasPrimaryFocus) {
      return candidate.hasPrimaryFocus;
    }
    if (candidate.hasFocus != existing.hasFocus) {
      return candidate.hasFocus;
    }

    final candidateLabel = candidate.debugLabel ?? '';
    final existingLabel = existing.debugLabel ?? '';
    final candidateIsEnsembleTapNode =
        candidateLabel.startsWith('TapEnabledWrapper_');
    final existingIsEnsembleTapNode =
        existingLabel.startsWith('TapEnabledWrapper_');
    if (candidateIsEnsembleTapNode != existingIsEnsembleTapNode) {
      return candidateIsEnsembleTapNode;
    }

    return _focusNodeDepth(candidate) > _focusNodeDepth(existing);
  }

  static int _focusNodeDepth(FocusNode focusNode) {
    var depth = 0;
    focusNode.context?.visitAncestorElements((_) {
      depth++;
      return true;
    });
    return depth;
  }

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
