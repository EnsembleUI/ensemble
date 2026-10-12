import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Returns the option family exposed by the currently open selector.
///
/// Material dropdowns expose [DropdownMenuItem], while application-owned
/// selectors commonly render [ListTile]. Keeping the fallback in one helper
/// makes raw and structured execution select the same option by index.
Finder selectIndexOptions() {
  final dropdownItems = find.byType(DropdownMenuItem);
  if (dropdownItems.evaluate().isNotEmpty) return dropdownItems;
  return find.byType(ListTile);
}
