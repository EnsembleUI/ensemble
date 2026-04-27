import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

/// Focus coordinate for TV navigation.
/// Based on flutter_pca's PageFocusOrder pattern.
///
/// Each focusable item gets a (row, order) coordinate:
/// - [row] is the vertical position (0, 1, 2, ...)
/// - [isRowEntryPoint] marks this item as the preferred entry when entering this row
/// - [order] is the horizontal position within the row (0, 1, 2, ...)
/// - [page] is for scroll pagination (0 = start, 1 = end)
/// - [pagePixels] is for exact scroll offset
class TVFocusOrder extends FocusOrder {
  /// Creates a focus order with the given coordinates.
  /// [row] describes the vertical position
  /// [order] describes the horizontal position within the row
  /// [page] controls scrolling (0 = start, 1 = end)
  /// [isRowEntryPoint] marks this as the preferred item when entering this row
  const TVFocusOrder(
    this.row, [
    this.order = 0,
    this.page = 0,
    this.pagePixels,
  ])  : isRowEntryPoint = false,
        lockHorizontalNavigation = false,
        delegateHorizontalNavigation = false;

  /// Creates a focus order with named parameters for optional values.
  const TVFocusOrder.withOptions(
    this.row, {
    this.order = 0,
    this.page = 0,
    this.pagePixels,
    this.isRowEntryPoint = false,
    this.lockHorizontalNavigation = false,
    this.delegateHorizontalNavigation = false,
  });

  final double row;
  final double order;
  final int page;
  final double? pagePixels;

  /// If true, this item is the preferred entry point when navigating to this row.
  /// Used by TabBar to focus the selected tab when entering the tab row.
  final bool isRowEntryPoint;

  /// If true, prevents horizontal navigation from escaping this row at boundaries.
  /// When at the first item, LEFT won't propagate; when at the last item, RIGHT won't propagate.
  final bool lockHorizontalNavigation;

  /// If true, horizontal navigation (LEFT/RIGHT) is delegated to the parent FocusScope.
  /// Use this for items inside carousels where horizontal keys should switch slides.
  final bool delegateHorizontalNavigation;

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
      page: page,
      pagePixels: pagePixels,
      isRowEntryPoint: isRowEntryPoint,
      lockHorizontalNavigation: lockHorizontalNavigation,
      delegateHorizontalNavigation: delegateHorizontalNavigation,
    );
  }

  /// Request focus on the widget with this order coordinate
  /// Searches within the same FocusTraversalGroup
  void requestFocus(BuildContext context) {
    final group = context.findAncestorWidgetOfExactType<FocusTraversalGroup>();
    final root = FocusManager.instance.rootScope;

    for (final focusNode in root.descendants) {
      final focusTraversalOrder = focusNode.context
          ?.findAncestorWidgetOfExactType<FocusTraversalOrder>();

      if (focusTraversalOrder?.order is TVFocusOrder) {
        final gridFocusOrder = focusTraversalOrder!.order as TVFocusOrder;
        if (gridFocusOrder.value == value) {
          final thisGroup = focusNode.context
              ?.findAncestorWidgetOfExactType<FocusTraversalGroup>();
          if (thisGroup == group) {
            focusNode.requestFocus();
            return;
          }
        }
      }
    }
  }

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'TVFocusOrder(row: $row, order: $order, page: $page)';
  }
}

/// Node wrapper for grid building
class TVFocusOrderNode {
  final FocusNode focus;
  final TVFocusOrder order;

  const TVFocusOrderNode(this.focus, this.order);

  @override
  String toString() => 'TVFocusOrderNode(${order.value}, ${focus.hashCode})';

  @override
  bool operator ==(Object other) =>
      other is TVFocusOrderNode && order.value == other.order.value;

  @override
  int get hashCode => order.value.hashCode;

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

/// Custom traversal policy for TV focus navigation.
/// Prevents focus from escaping upward when at row 0.
class TVFocusOrderTraversalPolicy extends ReadingOrderTraversalPolicy {
  /// When true, prevents navigating up from row 0
  final bool preventOutOfScopeTopTraversal;

  TVFocusOrderTraversalPolicy({
    this.preventOutOfScopeTopTraversal = true,
  });
}

/// Focus scope that can lock focus within a region.
/// Useful for dialogs or modal content.
class TVFocusScope extends FocusScope {
  /// If true, focus cannot escape this scope
  final bool lockScope;

  const TVFocusScope({
    super.key,
    required this.lockScope,
    required super.child,
    super.debugLabel,
  });
}
