import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/util/ensemble_utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';

/// Ensemble action that closes the active TV tooltip.
///
/// Mirrors `dismissDialog` / `dismissBottomSheet`: a tooltip is not a route, so
/// dismissal is delegated to the shared TV tooltip registry through
/// [EnsembleUtils.dismissTooltip]. Focus is restored to the tooltip's anchor
/// when it closes.
class DismissTooltipAction extends EnsembleAction {
  /// Creates a [DismissTooltipAction] action.
  DismissTooltipAction({super.initiator});

  /// Creates a [DismissTooltipAction] from a YAML or map action payload.
  factory DismissTooltipAction.from({Invokable? initiator, Map? payload}) =>
      DismissTooltipAction(initiator: initiator);

  /// Runs this action and closes the active tooltip.
  @override
  Future<bool> execute(BuildContext context, ScopeManager scopeManager) =>
      EnsembleUtils.dismissTooltip(context);
}
