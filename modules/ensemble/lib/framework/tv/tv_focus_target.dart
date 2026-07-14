import 'package:flutter/material.dart';

import 'tv_focus_order.dart';
import 'tv_focus_provider.dart';

/// Declarative destination for explicit TV focus jumps.
///
/// A target addresses a widget by [focusGroup]/[row]/[order] coordinate.
/// [order] is optional; when omitted the target row entry point is preferred.
class TVFocusTarget {
  const TVFocusTarget({
    this.focusGroup,
    this.row,
    this.order,
  });

  final String? focusGroup;
  final double? row;
  final double? order;

  bool get isValid => row != null;

  TVFocusTarget offset({
    double rowOffset = 0,
    double orderOffset = 0,
  }) {
    return TVFocusTarget(
      focusGroup: focusGroup,
      row: row != null ? row! + rowOffset : null,
      order: order != null ? order! + orderOffset : null,
    );
  }
}

VoidCallback? buildTVFocusTargetCallback(
  BuildContext context,
  TVFocusProvider? provider,
  TVFocusTarget? target,
) {
  if (target?.isValid != true) {
    return null;
  }

  final effectiveTarget = provider != null
      ? target!.offset(
          rowOffset: provider.rowOffset,
          orderOffset: provider.orderOffset,
        )
      : target!;

  if (provider != null) {
    final p = provider;
    return () => p.requestFocusAt(
          context,
          effectiveTarget.row!,
          effectiveTarget.order,
          effectiveTarget.focusGroup,
        );
  }

  return () => requestFocusAt(
        context,
        effectiveTarget.row!,
        effectiveTarget.order,
        effectiveTarget.focusGroup,
      );
}
