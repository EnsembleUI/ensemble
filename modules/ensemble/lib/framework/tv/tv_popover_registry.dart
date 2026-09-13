import 'package:flutter/widgets.dart';

/// Handle for a single open TV tooltip popover.
class TVPopoverEntry {
  TVPopoverEntry({required this.close, this.route});

  /// Closes the popover and restores focus to its anchor.
  ///
  /// Returns true when this call initiated the close (false if the popover was
  /// already closing or not open).
  final bool Function() close;

  /// Route the popover's anchor belongs to. Used to scope dismissal so an
  /// action on one screen cannot close a popover belonging to another.
  final Route<dynamic>? route;
}

/// Tracks open TV tooltip popovers so they can be dismissed programmatically.
///
/// A TV tooltip popover is rendered through an [OverlayPortal], not a route, so
/// it cannot be popped like a dialog or bottom sheet. This registry is the
/// popover equivalent of the dialog/bottom-sheet dismiss helpers and gives a
/// `dismissPopover` action a stable target.
class TVPopoverRegistry {
  TVPopoverRegistry._();

  static final List<TVPopoverEntry> _open = <TVPopoverEntry>[];

  static void register(TVPopoverEntry entry) {
    _open.remove(entry);
    _open.add(entry);
  }

  static void unregister(TVPopoverEntry entry) {
    _open.remove(entry);
  }

  /// Closes the popover registered for [route]. When no route is given, the
  /// most recently opened popover is closed. When a route is given but does not
  /// match any popover, a single open popover is still closed (unambiguous),
  /// otherwise no popover is touched. Popovers whose route could not be
  /// resolved are treated as matching any route.
  static bool dismiss({Route<dynamic>? route}) {
    if (_open.isEmpty) {
      return false;
    }
    TVPopoverEntry? target;
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
}
