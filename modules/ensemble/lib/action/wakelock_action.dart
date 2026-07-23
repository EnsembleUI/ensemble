import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/device.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Action to control device screen wakelock
/// Prevents the screen from turning off automatically when enabled
class WakelockAction extends EnsembleAction {
  /// Creates a [WakelockAction] action.
  WakelockAction({
    super.initiator,
    required this.enable,
    this.onComplete,
    this.onError,
  });

  /// Whether the wakelock should be enabled or disabled.
  final dynamic enable;
  /// Action executed after the operation completes successfully.
  final EnsembleAction? onComplete;
  /// Action executed when the operation fails.
  final EnsembleAction? onError;

  /// Creates a [WakelockAction] from a YAML or map action payload.
  factory WakelockAction.from({Invokable? initiator, Map? payload}) {
    return WakelockAction(
      initiator: initiator,
      enable: payload?['enable'],
      onComplete: EnsembleAction.from(payload?['onComplete']),
      onError: EnsembleAction.from(payload?['onError']),
    );
  }

  /// Runs this action and performs the wakelock operation.
  @override
  Future<void> execute(BuildContext context, ScopeManager scopeManager) async {
    try {
      // Evaluate the enable property (defaults to true if not provided)
      final shouldEnable = Utils.getBool(
        scopeManager.dataContext.eval(enable),
        fallback: true,
      );

      // Toggle wakelock: false disables, anything else enables
      if (shouldEnable == false) {
        await WakelockPlus.disable();
      } else {
        await WakelockPlus.enable();
      }

      // Verify and update the cached status from actual platform state
      await Device().refreshWakelockStatus();

      // Execute onComplete callback if provided
      if (onComplete != null) {
        ScreenController().executeActionWithScope(
          context,
          scopeManager,
          onComplete!,
          event: EnsembleEvent(initiator),
        );
      }
    } catch (e) {
      // Execute onError callback if provided
      if (onError != null) {
        ScreenController().executeActionWithScope(
          context,
          scopeManager,
          onError!,
          event: EnsembleEvent(initiator, error: e.toString()),
        );
      } else {
        throw LanguageError("Error toggling wakelock: $e");
      }
    }
  }
}
