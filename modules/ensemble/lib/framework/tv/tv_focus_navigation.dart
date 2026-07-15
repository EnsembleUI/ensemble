import 'package:ensemble/framework/tv/tv_focus_context.dart';
import 'package:ensemble/framework/tv/tv_focus_order.dart';
import 'package:ensemble/framework/tv/tv_focus_provider.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:flutter/widgets.dart';

String? resolveTVFocusGroup(
  BuildContext context,
  TVOptionsComposite tvOptions,
) {
  return tvOptions.focusGroup ?? TVFocusContext.maybeOf(context)?.focusGroup;
}

TVFocusEdgeTargetComposite? resolveTVFocusEdgeTarget(
  BuildContext context,
  TVOptionsComposite tvOptions,
  TVFocusDirection direction,
) {
  final inheritedContext = TVFocusContext.maybeOf(context);
  switch (direction) {
    case TVFocusDirection.right:
      return tvOptions.edges?.right ?? inheritedContext?.rightEdge;
    case TVFocusDirection.left:
      return tvOptions.edges?.left ?? inheritedContext?.leftEdge;
    case TVFocusDirection.top:
      return tvOptions.edges?.top ?? inheritedContext?.topEdge;
    case TVFocusDirection.bottom:
      return tvOptions.edges?.bottom ?? inheritedContext?.bottomEdge;
  }
}

VoidCallback? buildTVEdgeNavigationCallback({
  required BuildContext context,
  required TVFocusProvider? provider,
  required TVFocusDirection direction,
  required TVFocusEdgeTargetComposite? target,
  required double currentRow,
  required double currentOrder,
}) {
  if (target == null) {
    return null;
  }
  if (target.targetRow == null && target.targetFocusGroup == null) {
    return null;
  }

  final rowOffset = provider?.rowOffset ?? 0;
  final orderOffset = provider?.orderOffset ?? 0;
  final effectiveTargetRow =
      target.targetRow != null ? target.targetRow! + rowOffset : null;
  final effectiveTargetOrder =
      target.targetOrder != null ? target.targetOrder! + orderOffset : null;

  if (provider != null) {
    final p = provider;
    return () => p.requestFocusByEdge(
          context,
          direction: direction,
          targetFocusGroup: target.targetFocusGroup,
          targetRow: effectiveTargetRow,
          targetOrder: effectiveTargetOrder,
          currentRow: currentRow,
          currentOrder: currentOrder,
        );
  }

  return () => requestFocusByEdge(
        context,
        direction: direction,
        targetFocusGroup: target.targetFocusGroup,
        targetRow: effectiveTargetRow,
        targetOrder: effectiveTargetOrder,
        currentRow: currentRow,
        currentOrder: currentOrder,
      );
}

Widget wrapWithTVFocusContext({
  required BuildContext context,
  required Widget child,
  required TVOptionsComposite? tvOptions,
}) {
  if (tvOptions?.focusGroup == null && tvOptions?.edges == null) {
    return child;
  }

  final inheritedContext = TVFocusContext.maybeOf(context);
  return TVFocusContext(
    focusGroup: tvOptions?.focusGroup ?? inheritedContext?.focusGroup,
    rightEdge: tvOptions?.edges?.right ?? inheritedContext?.rightEdge,
    leftEdge: tvOptions?.edges?.left ?? inheritedContext?.leftEdge,
    topEdge: tvOptions?.edges?.top ?? inheritedContext?.topEdge,
    bottomEdge: tvOptions?.edges?.bottom ?? inheritedContext?.bottomEdge,
    child: child,
  );
}
