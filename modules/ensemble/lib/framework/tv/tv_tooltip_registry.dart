import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Handle for a single open TV tooltip.
class TVTooltipEntry {
  TVTooltipEntry({
    required this.close,
    this.route,
    required this.dismissOnBack,
  });

  /// Closes the tooltip and restores focus to its anchor.
  ///
  /// Returns true when this call initiated the close (false if the tooltip was
  /// already closing or not open).
  final bool Function() close;

  /// Route the tooltip's anchor belongs to. Used to scope dismissal so an
  /// action on one screen cannot close a tooltip belonging to another.
  final Route<dynamic>? route;

  /// Mirrors `options.dismissOnBack`; read by [TVTooltipRegistry.handleBack].
  final bool dismissOnBack;
}

/// Tracks open TV tooltips so they can be dismissed programmatically.
///
/// A TV tooltip is rendered through an [OverlayPortal], not a route, so
/// it cannot be popped like a dialog or bottom sheet. This registry is the
/// tooltip equivalent of the dialog/bottom-sheet dismiss helpers and gives a
/// `dismissTooltip` action a stable target.
class TVTooltipRegistry {
  TVTooltipRegistry._();

  static final List<TVTooltipEntry> _open = <TVTooltipEntry>[];

  static void register(TVTooltipEntry entry) {
    _open.remove(entry);
    _open.add(entry);
  }

  static void unregister(TVTooltipEntry entry) {
    _open.remove(entry);
  }

  /// Closes the tooltip registered for [route]. When no route is given, the
  /// most recently opened tooltip is closed. When a route is given but does not
  /// match any tooltip, a single open tooltip is still closed (unambiguous),
  /// otherwise no tooltip is touched. Tooltips whose route could not be
  /// resolved are treated as matching any route.
  static bool dismiss({Route<dynamic>? route}) {
    if (_open.isEmpty) {
      return false;
    }
    TVTooltipEntry? target;
    if (route == null) {
      target = _open.last;
    } else {
      for (final entry in _open.reversed) {
        if (entry.route == null || entry.route == route) {
          target = entry;
          break;
        }
      }
      if (target == null && _open.length == 1) {
        target = _open.single;
      }
    }
    if (target == null) {
      return false;
    }
    return target.close();
  }

  /// Set when a tooltip closed on a Back key-down; cleared by the next
  /// key-down (a new press) or by [handleBack].
  static bool _backPressConsumed = false;

  /// Called by a tooltip that closed on a Back key-down. On Android 13+ the
  /// same press then also arrives as a route pop, which [handleBack] consumes.
  static void markBackPressConsumed() {
    if (_backPressConsumed) return;
    _backPressConsumed = true;
    // Added mid-dispatch, so it first sees the next key event.
    HardwareKeyboard.instance.addHandler(_clearOnNextPress);
  }

  static bool _clearOnNextPress(KeyEvent event) {
    if (event is KeyDownEvent) _clearBackPressConsumed();
    return false;
  }

  static void _clearBackPressConsumed() {
    _backPressConsumed = false;
    HardwareKeyboard.instance.removeHandler(_clearOnNextPress);
  }

  /// Back handler for hosts that receive Back as a route pop (Android 13+
  /// with `enableOnBackInvokedCallback`). Call it before running normal Back.
  ///
  /// Returns true (consume the Back) when the press already closed a tooltip
  /// through its key handler, or when it closes the most recently opened
  /// tooltip that has `dismissOnBack` and whose route is current. Returns
  /// false (nothing touched) otherwise, so normal Back runs.
  static bool handleBack() {
    if (_backPressConsumed) {
      _clearBackPressConsumed();
      return true;
    }
    final entry = _open.lastOrNull;
    if (entry == null ||
        !entry.dismissOnBack ||
        entry.route?.isCurrent == false) {
      return false;
    }
    // Consume even if already closing, so a Back during the close animation
    // cannot also navigate.
    entry.close();
    return true;
  }
}
