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
  /// stays current. (The enclosing FocusTraversalGroup is deliberately NOT
  /// cached — its widget instance is recreated on rebuild, so [isInTraversalGroup]
  /// must resolve it live.)
  final ModalRoute<dynamic>? route;

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
    final targetContext = effectiveContext;
    return targetContext
            ?.findAncestorWidgetOfExactType<FocusTraversalGroup>() ==
        traversalGroup;
  }
}

/// Route-aware registry of explicit TV focus targets.
class TVFocusRegistry {
  TVFocusRegistry._();

  static final Map<FocusNode, TVFocusTarget> _targets =
      <FocusNode, TVFocusTarget>{};

  static void register(TVFocusTarget target) {
    _targets[target.focusNode] = target;
  }

  static void unregister(FocusNode focusNode) {
    _targets.remove(focusNode);
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
