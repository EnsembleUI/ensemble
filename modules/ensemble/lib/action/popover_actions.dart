import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/util/ensemble_utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';

/// Ensemble action that closes the active TV tooltip popover.
///
/// Mirrors `dismissDialog` / `dismissBottomSheet`: a popover is not a route, so
/// dismissal is delegated to the shared TV popover registry through
/// [EnsembleUtils.dismissPopover]. Focus is restored to the popover's anchor
/// when it closes.
class DismissPopoverAction extends EnsembleAction {
  /// Creates a [DismissPopoverAction] action.
  DismissPopoverAction({super.initiator});

  /// Creates a [DismissPopoverAction] from a YAML or map action payload.
  factory DismissPopoverAction.from({Invokable? initiator, Map? payload}) =>
      DismissPopoverAction(initiator: initiator);

  /// Runs this action and closes the active popover.
  @override
  Future<bool> execute(BuildContext context, ScopeManager scopeManager) =>
      EnsembleUtils.dismissPopover(context);
}
