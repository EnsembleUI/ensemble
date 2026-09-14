import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/tv/tv_focus_order.dart';
import 'package:ensemble/framework/tv/tv_tooltip_registry.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/widget/helpers/tooltip_composite.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A TV-only, focusable tooltip anchored to its triggering widget.
///
/// Unlike Flutter's [Tooltip], the overlay content is an Ensemble widget tree
/// and participates in the anchor's inherited data scope.
class TVTooltip extends StatefulWidget {
  const TVTooltip({
    super.key,
    required this.child,
    required this.tooltip,
  });

  final Widget child;
  final TooltipData tooltip;

  @override
  State<TVTooltip> createState() => _TVTooltipState();
}

class _TVTooltipState extends State<TVTooltip>
    with SingleTickerProviderStateMixin {
  final OverlayPortalController _portalController = OverlayPortalController();
  final FocusScopeNode _anchorAndTooltipScope = FocusScopeNode(
    debugLabel: 'TVTooltipAnchorScope',
  );
  final FocusScopeNode _tooltipScope = FocusScopeNode(
    debugLabel: 'TVTooltipScope',
  );
  late final AnimationController _animationController;

  bool _isOpen = false;
  bool _closing = false;
  bool _restoreFocusOnClose = false;

  /// Whether the last focus notification saw focus inside the anchor scope.
  /// The tooltip only opens on a rising edge so programmatically restoring
  /// anchor focus (Back / directional exit) cannot immediately reopen it.
  bool _anchorScopeHadFocus = false;
  FocusNode? _anchorFocusNode;
  ScopeManager? _scopeManager;
  TVTooltipEntry? _tooltipEntry;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.dismissed && _closing) {
          _completeClose();
        }
      });
    FocusManager.instance.addListener(_onPrimaryFocusChanged);
  }

  @override
  void dispose() {
    // Disposal intentionally does not emit the close notification: running an
    // action from teardown is unsafe with a deactivated context. Definitions
    // that mirror `event.data.isOpen` into a flag should treat a torn-down
    // anchor (screen replaced / conditionally removed while open) as a reset.
    _unregisterTooltip();
    _animationController.dispose();
    FocusManager.instance.removeListener(_onPrimaryFocusChanged);
    _anchorAndTooltipScope.dispose();
    _tooltipScope.dispose();
    super.dispose();
  }

  void _unregisterTooltip() {
    final entry = _tooltipEntry;
    if (entry != null) {
      TVTooltipRegistry.unregister(entry);
      _tooltipEntry = null;
    }
  }

  /// Resolves `options.enabled`, which may be a literal bool or a binding
  /// expression, against the anchor's data scope. Defaults to enabled when the
  /// expression cannot be resolved.
  bool _isEnabled() {
    final raw = widget.tooltip.options.enabled;
    if (raw is bool) return raw;
    final resolved = _scopeManager?.dataContext.eval(raw);
    return resolved is bool ? resolved : true;
  }

  /// Runs the tooltip's `onTriggered` action with the current open state so a
  /// definition can mirror it into a flag, e.g.
  /// `ensemble.storage.tooltipOpen = event.data.isOpen;`.
  void _notifyTrigger(bool isOpen) {
    final onTriggered = widget.tooltip.onTriggered;
    if (onTriggered == null || !mounted) return;
    ScreenController().executeAction(
      context,
      onTriggered,
      event: EnsembleEvent(null, data: {'isOpen': isOpen}),
    );
  }

  void _onAnchorAndTooltipFocusChanged(bool hasFocus) {
    final gainedFocus = hasFocus && !_anchorScopeHadFocus;
    _anchorScopeHadFocus = hasFocus;

    if (hasFocus) {
      if (gainedFocus && !_isOpen && _isEnabled()) {
        _anchorFocusNode = FocusManager.instance.primaryFocus;
        _tooltipEntry = TVTooltipEntry(
          close: () => _close(restoreAnchorFocus: true),
          route: ModalRoute.of(context),
        );
        TVTooltipRegistry.register(_tooltipEntry!);
        setState(() => _isOpen = true);
        _portalController.show();
        _notifyTrigger(true);
        _animationController
          ..duration = widget.tooltip.options.animation.duration
          ..forward(from: 0);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_isOpen) return;
          final focusable = _tooltipScope.traversalDescendants
              .where((node) => node.canRequestFocus && !node.skipTraversal)
              .firstOrNull;
          // With no focusable content, focus the scope itself so the tooltip
          // still owns focus and D-pad cannot wander into the background.
          (focusable ?? _tooltipScope).requestFocus();
        });
      }
      return;
    }

    if (_isOpen && !_closing && widget.tooltip.options.dismissOnFocusLoss) {
      _close(restoreAnchorFocus: false);
    }
  }

  void _onPrimaryFocusChanged() {
    final primaryFocus = FocusManager.instance.primaryFocus;
    // Only count focus on a real descendant of the anchor scope. The scope
    // node itself is requestable, and Flutter can land focus on it when a
    // focused child is removed; treating that as anchor focus would open the
    // tooltip without the anchor control being focused.
    final hasFocus = primaryFocus != null &&
        primaryFocus != _anchorAndTooltipScope &&
        primaryFocus.ancestors.contains(_anchorAndTooltipScope);
    _onAnchorAndTooltipFocusChanged(hasFocus);
  }

  /// Starts closing the tooltip. Returns true when this call initiated the
  /// close (false if it was already open/closing).
  bool _close({required bool restoreAnchorFocus}) {
    if (!_isOpen || _closing) return false;
    _closing = true;
    _restoreFocusOnClose =
        restoreAnchorFocus && widget.tooltip.options.restoreFocus;

    if (widget.tooltip.options.animation.type ==
            TooltipAnimationType.none ||
        widget.tooltip.options.animation.duration == Duration.zero ||
        _animationController.value == 0) {
      _completeClose();
      return true;
    }

    _animationController.reverse();
    return true;
  }

  void _completeClose() {
    if (!mounted || !_closing) return;
    _portalController.hide();
    setState(() => _isOpen = false);
    _closing = false;
    _unregisterTooltip();
    _notifyTrigger(false);
    if (_restoreFocusOnClose) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _anchorFocusNode?.canRequestFocus == true) {
          _anchorFocusNode?.requestFocus();
        }
      });
    }
  }

  KeyEventResult _onTooltipKeyEvent(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.goBack) {
      if (widget.tooltip.options.dismissOnBack) {
        _close(restoreAnchorFocus: true);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    final direction = _arrowDirection(event.logicalKey);
    if (direction == null) {
      return KeyEventResult.ignored;
    }

    // Focus stays inside the tooltip while it is open: move to the next
    // in-tooltip target when there is one, otherwise swallow the event at the
    // edge so focus remains where it is. Focus only returns to the anchor when
    // the tooltip closes (Back or `dismissTooltip`).
    FocusManager.instance.primaryFocus?.focusInDirection(direction);
    return KeyEventResult.handled;
  }

  static void _keepFocus() {}

  static TraversalDirection? _arrowDirection(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowUp) return TraversalDirection.up;
    if (key == LogicalKeyboardKey.arrowDown) return TraversalDirection.down;
    if (key == LogicalKeyboardKey.arrowLeft) return TraversalDirection.left;
    if (key == LogicalKeyboardKey.arrowRight) return TraversalDirection.right;
    return null;
  }

  Widget _buildTooltip(BuildContext context) {
    final scopeManager = _scopeManager;
    if (!_isOpen || scopeManager == null || widget.tooltip.widget == null) {
      return const SizedBox.shrink();
    }

    final anchors = _anchors;
    // An OverlayPortal lays its overlay child out with the Overlay's tight
    // constraints, so the CompositedTransformFollower (and therefore its
    // child) would be stretched to the full screen. That breaks both the
    // intrinsic sizing of the tooltip content and the follower anchor math,
    // which relies on the follower's own size. Keep the follower anchored by
    // its top-left corner and let a CustomSingleChildLayout loosen the
    // constraints and translate the content by the requested follower anchor.
    return CompositedTransformFollower(
      link: _layerLink,
      targetAnchor: anchors.target,
      followerAnchor: Alignment.topLeft,
      offset: widget.tooltip.options.offset,
      child: CustomSingleChildLayout(
        delegate: _TooltipLayoutDelegate(followerAnchor: anchors.follower),
        child: _animateTooltip(
          FocusTraversalGroup(
            child: TVFocusScope(
              node: _tooltipScope,
              // Parent the overlay scope under the anchor's focus node so the
              // trigger stays an ancestor of the real focus while the tooltip
              // is open. The trigger keeps `hasFocus` (and its focus styling)
              // without owning the real focus; closing restores it cleanly.
              parentNode: _anchorFocusNode,
              onKeyEvent: _onTooltipKeyEvent,
              lockScope: true,
              // Host focus providers (and the built-in TVFocusWidget) treat an
              // edge callback as handled, so these no-ops keep D-pad focus from
              // traversing out of the tooltip into the background content.
              onLeftEdge: _keepFocus,
              onRightEdge: _keepFocus,
              onTopEdge: _keepFocus,
              onBottomEdge: _keepFocus,
              child: scopeManager
                  .buildWidgetWithScopeFromDefinition(widget.tooltip.widget),
            ),
          ),
        ),
      ),
    );
  }

  Widget _animateTooltip(Widget child) {
    final animation = CurvedAnimation(
      parent: _animationController,
      curve: widget.tooltip.options.animation.curve,
    );
    switch (widget.tooltip.options.animation.type) {
      case TooltipAnimationType.fade:
        return FadeTransition(opacity: animation, child: child);
      case TooltipAnimationType.scale:
        return ScaleTransition(
          scale: Tween<double>(begin: 0.95, end: 1).animate(animation),
          child: child,
        );
      case TooltipAnimationType.slide:
        return SlideTransition(
          position: Tween<Offset>(
            begin: _slideBeginOffset,
            end: Offset.zero,
          ).animate(animation),
          child: child,
        );
      case TooltipAnimationType.none:
        return child;
    }
  }

  Offset get _slideBeginOffset {
    switch (widget.tooltip.options.position) {
      case TooltipPosition.below:
        return const Offset(0, -0.05);
      case TooltipPosition.above:
        return const Offset(0, 0.05);
      case TooltipPosition.left:
        return const Offset(0.05, 0);
      case TooltipPosition.right:
        return const Offset(-0.05, 0);
    }
  }

  ({Alignment target, Alignment follower}) get _anchors {
    final alignment = widget.tooltip.options.alignment;
    switch (widget.tooltip.options.position) {
      case TooltipPosition.below:
        return (
          target: _horizontalAnchor(alignment, bottom: true),
          follower: _horizontalAnchor(alignment, bottom: false),
        );
      case TooltipPosition.above:
        return (
          target: _horizontalAnchor(alignment, bottom: false),
          follower: _horizontalAnchor(alignment, bottom: true),
        );
      case TooltipPosition.left:
        return (
          target: _verticalAnchor(alignment, right: false),
          follower: _verticalAnchor(alignment, right: true),
        );
      case TooltipPosition.right:
        return (
          target: _verticalAnchor(alignment, right: true),
          follower: _verticalAnchor(alignment, right: false),
        );
    }
  }

  Alignment _horizontalAnchor(TooltipAlignment alignment,
      {required bool bottom}) {
    switch (alignment) {
      case TooltipAlignment.start:
        return bottom ? Alignment.bottomLeft : Alignment.topLeft;
      case TooltipAlignment.center:
        return bottom ? Alignment.bottomCenter : Alignment.topCenter;
      case TooltipAlignment.end:
        return bottom ? Alignment.bottomRight : Alignment.topRight;
    }
  }

  Alignment _verticalAnchor(TooltipAlignment alignment,
      {required bool right}) {
    switch (alignment) {
      case TooltipAlignment.start:
        return right ? Alignment.topRight : Alignment.topLeft;
      case TooltipAlignment.center:
        return right ? Alignment.centerRight : Alignment.centerLeft;
      case TooltipAlignment.end:
        return right ? Alignment.bottomRight : Alignment.bottomLeft;
    }
  }

  final LayerLink _layerLink = LayerLink();

  @override
  Widget build(BuildContext context) {
    _scopeManager = DataScopeWidget.getScope(context);
    return FocusScope(
      node: _anchorAndTooltipScope,
      skipTraversal: true,
      child: OverlayPortal(
        controller: _portalController,
        overlayChildBuilder: _buildTooltip,
        child: CompositedTransformTarget(
          link: _layerLink,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Positions the intrinsic-sized tooltip content inside the [OverlayPortal]
/// overlay child.
///
/// The overlay child is laid out with the Overlay's tight constraints, so the
/// delegate loosens them for the content. The enclosing follower anchors its
/// top-left corner to the requested point on the anchor, which means the
/// content must be shifted by the negative of its own follower anchor.
class _TooltipLayoutDelegate extends SingleChildLayoutDelegate {
  const _TooltipLayoutDelegate({required this.followerAnchor});

  final Alignment followerAnchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) =>
      Offset.zero - followerAnchor.alongSize(childSize);

  @override
  bool shouldRelayout(_TooltipLayoutDelegate oldDelegate) =>
      followerAnchor != oldDelegate.followerAnchor;
}
