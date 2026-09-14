import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/tv/tv_focus_order.dart';
import 'package:ensemble/framework/tv/tv_popover_registry.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/widget/helpers/tooltip_composite.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A TV-only, focusable tooltip popover anchored to its triggering widget.
///
/// Unlike Flutter's [Tooltip], the overlay content is an Ensemble widget tree
/// and participates in the anchor's inherited data scope.
class TVTooltipPopover extends StatefulWidget {
  const TVTooltipPopover({
    super.key,
    required this.child,
    required this.tooltip,
  });

  final Widget child;
  final TooltipData tooltip;

  @override
  State<TVTooltipPopover> createState() => _TVTooltipPopoverState();
}

class _TVTooltipPopoverState extends State<TVTooltipPopover>
    with SingleTickerProviderStateMixin {
  final OverlayPortalController _portalController = OverlayPortalController();
  final FocusScopeNode _anchorAndPopoverScope = FocusScopeNode(
    debugLabel: 'TVTooltipPopoverAnchorScope',
  );
  final FocusScopeNode _popoverScope = FocusScopeNode(
    debugLabel: 'TVTooltipPopoverScope',
  );
  late final AnimationController _animationController;

  bool _isOpen = false;
  bool _closing = false;
  bool _restoreFocusOnClose = false;

  /// Whether the last focus notification saw focus inside the anchor scope.
  /// The popover only opens on a rising edge so programmatically restoring
  /// anchor focus (Back / directional exit) cannot immediately reopen it.
  bool _anchorScopeHadFocus = false;
  FocusNode? _anchorFocusNode;
  ScopeManager? _scopeManager;
  TVPopoverEntry? _popoverEntry;

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
    _unregisterPopover();
    _animationController.dispose();
    FocusManager.instance.removeListener(_onPrimaryFocusChanged);
    _anchorAndPopoverScope.dispose();
    _popoverScope.dispose();
    super.dispose();
  }

  void _unregisterPopover() {
    final entry = _popoverEntry;
    if (entry != null) {
      TVPopoverRegistry.unregister(entry);
      _popoverEntry = null;
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
  /// `ensemble.storage.popoverOpen = event.data.isOpen;`.
  void _notifyTrigger(bool isOpen) {
    final onTriggered = widget.tooltip.onTriggered;
    if (onTriggered == null || !mounted) return;
    ScreenController().executeAction(
      context,
      onTriggered,
      event: EnsembleEvent(null, data: {'isOpen': isOpen}),
    );
  }

  void _onAnchorAndPopoverFocusChanged(bool hasFocus) {
    final gainedFocus = hasFocus && !_anchorScopeHadFocus;
    _anchorScopeHadFocus = hasFocus;

    if (hasFocus) {
      if (gainedFocus && !_isOpen && _isEnabled()) {
        _anchorFocusNode = FocusManager.instance.primaryFocus;
        _popoverEntry = TVPopoverEntry(
          close: () => _close(restoreAnchorFocus: true),
          route: ModalRoute.of(context),
        );
        TVPopoverRegistry.register(_popoverEntry!);
        setState(() => _isOpen = true);
        _portalController.show();
        _notifyTrigger(true);
        _animationController
          ..duration = widget.tooltip.options.animation.duration
          ..forward(from: 0);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_isOpen) return;
          final focusable = _popoverScope.traversalDescendants
              .where((node) => node.canRequestFocus && !node.skipTraversal)
              .firstOrNull;
          // With no focusable content, focus the scope itself so the popover
          // still owns focus and D-pad cannot wander into the background.
          (focusable ?? _popoverScope).requestFocus();
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
    // popover without the anchor control being focused.
    final hasFocus = primaryFocus != null &&
        primaryFocus != _anchorAndPopoverScope &&
        primaryFocus.ancestors.contains(_anchorAndPopoverScope);
    _onAnchorAndPopoverFocusChanged(hasFocus);
  }

  /// Starts closing the popover. Returns true when this call initiated the
  /// close (false if it was already open/closing).
  bool _close({required bool restoreAnchorFocus}) {
    if (!_isOpen || _closing) return false;
    _closing = true;
    _restoreFocusOnClose =
        restoreAnchorFocus && widget.tooltip.options.restoreFocus;

    if (widget.tooltip.options.animation.type ==
            TooltipPopoverAnimationType.none ||
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
    _unregisterPopover();
    _notifyTrigger(false);
    if (_restoreFocusOnClose) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _anchorFocusNode?.canRequestFocus == true) {
          _anchorFocusNode?.requestFocus();
        }
      });
    }
  }

  KeyEventResult _onPopoverKeyEvent(FocusNode _, KeyEvent event) {
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

    // Focus stays inside the popover while it is open: move to the next
    // in-popover target when there is one, otherwise swallow the event at the
    // edge so focus remains where it is. Focus only returns to the anchor when
    // the popover closes (Back or `dismissPopover`).
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

  Widget _buildPopover(BuildContext context) {
    final scopeManager = _scopeManager;
    if (!_isOpen || scopeManager == null || widget.tooltip.widget == null) {
      return const SizedBox.shrink();
    }

    final anchors = _anchors;
    // An OverlayPortal lays its overlay child out with the Overlay's tight
    // constraints, so the CompositedTransformFollower (and therefore its
    // child) would be stretched to the full screen. That breaks both the
    // intrinsic sizing of the popover content and the follower anchor math,
    // which relies on the follower's own size. Keep the follower anchored by
    // its top-left corner and let a CustomSingleChildLayout loosen the
    // constraints and translate the content by the requested follower anchor.
    return CompositedTransformFollower(
      link: _layerLink,
      targetAnchor: anchors.target,
      followerAnchor: Alignment.topLeft,
      offset: widget.tooltip.options.offset,
      child: CustomSingleChildLayout(
        delegate: _PopoverLayoutDelegate(followerAnchor: anchors.follower),
        child: _animatePopover(
          FocusTraversalGroup(
            child: TVFocusScope(
              node: _popoverScope,
              // Parent the overlay scope under the anchor's focus node so the
              // trigger stays an ancestor of the real focus while the popover
              // is open. The trigger keeps `hasFocus` (and its focus styling)
              // without owning the real focus; closing restores it cleanly.
              parentNode: _anchorFocusNode,
              onKeyEvent: _onPopoverKeyEvent,
              lockScope: true,
              // Host focus providers (and the built-in TVFocusWidget) treat an
              // edge callback as handled, so these no-ops keep D-pad focus from
              // traversing out of the popover into the background content.
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

  Widget _animatePopover(Widget child) {
    final animation = CurvedAnimation(
      parent: _animationController,
      curve: widget.tooltip.options.animation.curve,
    );
    switch (widget.tooltip.options.animation.type) {
      case TooltipPopoverAnimationType.fade:
        return FadeTransition(opacity: animation, child: child);
      case TooltipPopoverAnimationType.scale:
        return ScaleTransition(
          scale: Tween<double>(begin: 0.95, end: 1).animate(animation),
          child: child,
        );
      case TooltipPopoverAnimationType.slide:
        return SlideTransition(
          position: Tween<Offset>(
            begin: _slideBeginOffset,
            end: Offset.zero,
          ).animate(animation),
          child: child,
        );
      case TooltipPopoverAnimationType.none:
        return child;
    }
  }

  Offset get _slideBeginOffset {
    switch (widget.tooltip.options.position) {
      case TooltipPopoverPosition.below:
        return const Offset(0, -0.05);
      case TooltipPopoverPosition.above:
        return const Offset(0, 0.05);
      case TooltipPopoverPosition.left:
        return const Offset(0.05, 0);
      case TooltipPopoverPosition.right:
        return const Offset(-0.05, 0);
    }
  }

  ({Alignment target, Alignment follower}) get _anchors {
    final alignment = widget.tooltip.options.alignment;
    switch (widget.tooltip.options.position) {
      case TooltipPopoverPosition.below:
        return (
          target: _horizontalAnchor(alignment, bottom: true),
          follower: _horizontalAnchor(alignment, bottom: false),
        );
      case TooltipPopoverPosition.above:
        return (
          target: _horizontalAnchor(alignment, bottom: false),
          follower: _horizontalAnchor(alignment, bottom: true),
        );
      case TooltipPopoverPosition.left:
        return (
          target: _verticalAnchor(alignment, right: false),
          follower: _verticalAnchor(alignment, right: true),
        );
      case TooltipPopoverPosition.right:
        return (
          target: _verticalAnchor(alignment, right: true),
          follower: _verticalAnchor(alignment, right: false),
        );
    }
  }

  Alignment _horizontalAnchor(TooltipPopoverAlignment alignment,
      {required bool bottom}) {
    switch (alignment) {
      case TooltipPopoverAlignment.start:
        return bottom ? Alignment.bottomLeft : Alignment.topLeft;
      case TooltipPopoverAlignment.center:
        return bottom ? Alignment.bottomCenter : Alignment.topCenter;
      case TooltipPopoverAlignment.end:
        return bottom ? Alignment.bottomRight : Alignment.topRight;
    }
  }

  Alignment _verticalAnchor(TooltipPopoverAlignment alignment,
      {required bool right}) {
    switch (alignment) {
      case TooltipPopoverAlignment.start:
        return right ? Alignment.topRight : Alignment.topLeft;
      case TooltipPopoverAlignment.center:
        return right ? Alignment.centerRight : Alignment.centerLeft;
      case TooltipPopoverAlignment.end:
        return right ? Alignment.bottomRight : Alignment.bottomLeft;
    }
  }

  final LayerLink _layerLink = LayerLink();

  @override
  Widget build(BuildContext context) {
    _scopeManager = DataScopeWidget.getScope(context);
    return FocusScope(
      node: _anchorAndPopoverScope,
      skipTraversal: true,
      child: OverlayPortal(
        controller: _portalController,
        overlayChildBuilder: _buildPopover,
        child: CompositedTransformTarget(
          link: _layerLink,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Positions the intrinsic-sized popover content inside the [OverlayPortal]
/// overlay child.
///
/// The overlay child is laid out with the Overlay's tight constraints, so the
/// delegate loosens them for the content. The enclosing follower anchors its
/// top-left corner to the requested point on the anchor, which means the
/// content must be shifted by the negative of its own follower anchor.
class _PopoverLayoutDelegate extends SingleChildLayoutDelegate {
  const _PopoverLayoutDelegate({required this.followerAnchor});

  final Alignment followerAnchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) =>
      Offset.zero - followerAnchor.alongSize(childSize);

  @override
  bool shouldRelayout(_PopoverLayoutDelegate oldDelegate) =>
      followerAnchor != oldDelegate.followerAnchor;
}
