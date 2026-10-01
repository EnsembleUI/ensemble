import 'dart:collection';

import 'package:flutter/material.dart';

/// Explicit focus target for a TV focus coordinate.
///
/// This lets widgets that own the real requestable [FocusNode] register it
/// directly instead of forcing navigation code to infer the right node from the
/// focus tree.
class TVFocusTarget {
  const TVFocusTarget({
    required this.focusNode,
    required this.focusOrder,
    required this.row,
    required this.order,
    required this.context,
    this.route,
    this.traversalGroup,
    this.focusGroup,
    this.isRowEntryPoint = false,
    this.lockHorizontalNavigation = false,
    this.delegateHorizontalNavigation = false,
  });

  final FocusNode focusNode;
  final FocusOrder focusOrder;
  final double row;
  final double order;
  final BuildContext context;

  /// The enclosing [ModalRoute] captured at registration time.
  ///
  /// PHASE 3: caching the route here makes [isInRoute] an O(1) comparison
  /// instead of a `ModalRoute.of` ancestor walk on every navigation query (which
  /// ran for every registered target). [ModalRoute] identity is stable across
  /// rebuilds, and the registrar re-registers on dependency changes, so this
  /// stays current.
  final ModalRoute<dynamic>? route;

  /// The enclosing [FocusTraversalGroup] captured at registration time.
  ///
  /// The group widget instance is recreated on rebuild, so it is re-captured by
  /// [TVFocusTargetRegistrar._register] on every rebuild (which is when a new
  /// [TVFocusTarget] is constructed). This makes [isInTraversalGroup] an O(1)
  /// identity comparison instead of a `findAncestorWidgetOfExactType` ancestor
  /// walk that previously ran for every registered target on every D-pad press.
  final FocusTraversalGroup? traversalGroup;

  final String? focusGroup;
  final bool isRowEntryPoint;
  final bool lockHorizontalNavigation;
  final bool delegateHorizontalNavigation;

  BuildContext? get effectiveContext => focusNode.context ?? context;

  bool get isRequestable =>
      focusNode.context != null && focusNode.canRequestFocus;

  bool isInRoute(ModalRoute<dynamic>? route) {
    if (route == null) {
      return true;
    }
    return this.route == route;
  }

  bool isInTraversalGroup(FocusTraversalGroup? traversalGroup) {
    if (traversalGroup == null) {
      return true;
    }
    // Fast path: the group captured at registration is the one being queried.
    if (identical(this.traversalGroup, traversalGroup)) {
      return true;
    }
    // If we captured a (different) live group at registration, the target is
    // known to belong to that other group and cannot be in the queried one.
    // Fall back to a live walk only when registration captured nothing (e.g. a
    // target registered before the group existed in its ancestry).
    if (this.traversalGroup != null) {
      return false;
    }
    final targetContext = effectiveContext;
    return targetContext
            ?.findAncestorWidgetOfExactType<FocusTraversalGroup>() ==
        traversalGroup;
  }
}

/// Route-aware registry of explicit TV focus targets.
///
/// Keeps two views of the same registrations:
/// - [_targets]: flat map keyed by [FocusNode] (used by the legacy
///   [targets] scan, kept for backward compatibility).
/// - [_index]: a route → row → order index built on registration so navigation
///   can resolve a neighbour with direct lookups instead of rebuilding the whole
///   grid from every focus node on each D-pad press.
class TVFocusRegistry {
  TVFocusRegistry._();

  static final Map<FocusNode, TVFocusTarget> _targets =
      <FocusNode, TVFocusTarget>{};

  // routeKey -> row -> order -> target. Rows and orders are SplayTreeMaps so
  // predecessor/successor (LEFT/RIGHT) and nearest-row (UP/DOWN) queries are
  // O(log n) on the relevant row instead of a full scan.
  static final Map<Object, SplayTreeMap<double, SplayTreeMap<double, TVFocusTarget>>>
      _index = {};

  /// Stable map key for a route (or a shared bucket when the route is null).
  static Object _routeKey(ModalRoute<dynamic>? route) =>
      route == null ? 'noRoute' : identityHashCode(route);

  static void register(TVFocusTarget target) {
    // Remove any prior entry for this node (re-registration on rebuild, or a
    // node whose row/order changed) before inserting the fresh target.
    final previous = _targets[target.focusNode];
    if (previous != null && !identical(previous, target)) {
      _removeFromIndex(previous);
    }
    _targets[target.focusNode] = target;
    _insertIntoIndex(target);
  }

  static void unregister(FocusNode focusNode) {
    final removed = _targets.remove(focusNode);
    if (removed != null) {
      _removeFromIndex(removed);
    }
  }

  static void _insertIntoIndex(TVFocusTarget target) {
    final orders = _index
        .putIfAbsent(_routeKey(target.route), () => SplayTreeMap<double,
            SplayTreeMap<double, TVFocusTarget>>())
        .putIfAbsent(
            target.row,
            () => SplayTreeMap<double, TVFocusTarget>());
    orders[target.order] = target;
  }

  static void _removeFromIndex(TVFocusTarget target) {
    final rows = _index[_routeKey(target.route)];
    if (rows == null) return;
    final orders = rows[target.row];
    if (orders == null) return;
    // Only drop the entry if it still points at this exact registration.
    if (identical(orders[target.order], target)) {
      orders.remove(target.order);
    }
    if (orders.isEmpty) {
      rows.remove(target.row);
    }
    if (rows.isEmpty) {
      _index.remove(_routeKey(target.route));
    }
  }

  /// All requestable targets in [row] for the current [route], ordered by
  /// `order`. O(log n) row lookup plus O(k) copy of the row.
  static List<TVFocusTarget> rowTargets({
    required ModalRoute<dynamic>? route,
    required double row,
  }) {
    final rows = _index[_routeKey(route)];
    final orders = rows?[row];
    if (orders == null) return const [];
    return orders.values.where((t) => t.isRequestable).toList(growable: false);
  }

  /// The target at the exact cell [row]/[order], or null. O(1)–O(log n).
  static TVFocusTarget? cellTarget({
    required ModalRoute<dynamic>? route,
    required double row,
    required double order,
  }) {
    final target = _index[_routeKey(route)]?[row]?[order];
    if (target == null || !target.isRequestable) return null;
    return target;
  }

  /// The nearest row value strictly after [row] (down direction), or null.
  static double? nextRow({
    required ModalRoute<dynamic>? route,
    required double row,
  }) {
    final rows = _index[_routeKey(route)];
    return rows?.firstKeyAfter(row);
  }

  /// The nearest row value strictly before [row] (up direction), or null.
  static double? previousRow({
    required ModalRoute<dynamic>? route,
    required double row,
  }) {
    final rows = _index[_routeKey(route)];
    return rows?.lastKeyBefore(row);
  }

  /// Ordered row values present for [route], ascending. O(r) copy.
  static List<double> rowValues({required ModalRoute<dynamic>? route}) {
    final rows = _index[_routeKey(route)];
    if (rows == null) return const [];
    return rows.keys.toList(growable: false);
  }

  /// Whether any requestable target exists at [row]/[order].
  static bool hasCell({
    required ModalRoute<dynamic>? route,
    required double row,
    required double order,
  }) =>
      cellTarget(route: route, row: row, order: order) != null;

  /// Removes every registration for a route (used on route disposal, if ever
  /// needed). Individual targets unregister themselves on dispose.
  static void clearRoute(ModalRoute<dynamic>? route) {
    final targetNodes = _targets.entries
        .where((e) => identical(_routeKey(e.value.route), _routeKey(route)))
        .map((e) => e.key)
        .toList(growable: false);
    for (final node in targetNodes) {
      unregister(node);
    }
    _index.remove(_routeKey(route));
  }

  static Iterable<TVFocusTarget> targets<T extends FocusOrder>({
    ModalRoute<dynamic>? route,
    FocusTraversalGroup? traversalGroup,
    String? focusGroup,
  }) {
    return _targets.values.where((target) {
      if (target.focusOrder is! T) {
        return false;
      }
      if (!target.isRequestable) {
        return false;
      }
      if (!target.isInRoute(route)) {
        return false;
      }
      if (!target.isInTraversalGroup(traversalGroup)) {
        return false;
      }
      if (focusGroup != null && target.focusGroup != focusGroup) {
        return false;
      }
      return true;
    });
  }
}

/// Marks a decorative subtree (e.g. a page background) as excluded from TV
/// focus. Any [TVFocusTargetRegistrar] inside it is kept out of
/// [TVFocusRegistry], so D-pad navigation never targets it.
///
/// This is needed because the host navigates via [TVFocusRegistry] rather than
/// the Flutter focus tree, so [ExcludeFocus] alone is not sufficient.
class TVFocusExclusion extends InheritedWidget {
  const TVFocusExclusion({super.key, required super.child});

  static bool isExcluded(BuildContext context) =>
      context.getElementForInheritedWidgetOfExactType<TVFocusExclusion>() !=
      null;

  @override
  bool updateShouldNotify(TVFocusExclusion oldWidget) => false;
}

/// Registers a focus target while its widget subtree is mounted.
class TVFocusTargetRegistrar extends StatefulWidget {
  const TVFocusTargetRegistrar({
    super.key,
    required this.focusNode,
    required this.focusOrder,
    required this.row,
    required this.order,
    required this.child,
    this.focusGroup,
    this.isRowEntryPoint = false,
    this.lockHorizontalNavigation = false,
    this.delegateHorizontalNavigation = false,
  });

  final FocusNode focusNode;
  final FocusOrder focusOrder;
  final double row;
  final double order;
  final String? focusGroup;
  final bool isRowEntryPoint;
  final bool lockHorizontalNavigation;
  final bool delegateHorizontalNavigation;
  final Widget child;

  @override
  State<TVFocusTargetRegistrar> createState() => _TVFocusTargetRegistrarState();
}

class _TVFocusTargetRegistrarState extends State<TVFocusTargetRegistrar> {
  // PHASE 3: captured here (not in _register) so the ModalRoute dependency is
  // only established in didChangeDependencies, which also re-fires — and
  // refreshes this — whenever the enclosing route changes.
  ModalRoute<dynamic>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    _register();
  }

  @override
  void didUpdateWidget(TVFocusTargetRegistrar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      TVFocusRegistry.unregister(oldWidget.focusNode);
    }
    _register();
  }

  @override
  void dispose() {
    TVFocusRegistry.unregister(widget.focusNode);
    super.dispose();
  }

  void _register() {
    // Decorative subtrees (e.g. page backgrounds) opt out of the TV focus grid.
    if (TVFocusExclusion.isExcluded(context)) {
      TVFocusRegistry.unregister(widget.focusNode);
      return;
    }
    TVFocusRegistry.register(
      TVFocusTarget(
        focusNode: widget.focusNode,
        focusOrder: widget.focusOrder,
        row: widget.row,
        order: widget.order,
        focusGroup: widget.focusGroup,
        isRowEntryPoint: widget.isRowEntryPoint,
        lockHorizontalNavigation: widget.lockHorizontalNavigation,
        delegateHorizontalNavigation: widget.delegateHorizontalNavigation,
        context: context,
        route: _route,
        // Resolve once at registration so navigation queries are O(1). The
        // group widget is recreated on rebuild, but this registrar re-registers
        // (constructing a new target) on every rebuild, so the captured group
        // stays in sync.
        traversalGroup: context.findAncestorWidgetOfExactType<FocusTraversalGroup>(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
