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
  WakelockAction({
    super.initiator,
    required this.enable,
    this.onComplete,
    this.onError,
  });

  final dynamic enable;
  final EnsembleAction? onComplete;
  final EnsembleAction? onError;

  factory WakelockAction.from({Invokable? initiator, Map? payload}) {
    if (payload == null || payload['enable'] == null) {
      throw LanguageError(
          "${ActionType.wakelock.name} requires the 'enable' property (true/false).");
    }

    return WakelockAction(
      initiator: initiator,
      enable: payload['enable'],
      onComplete: EnsembleAction.from(payload['onComplete']),
      onError: EnsembleAction.from(payload['onError']),
    );
  }

  @override
  Future<void> execute(BuildContext context, ScopeManager scopeManager) async {
    try {
      print("WakelockAction: Setting wakelock to $enable");
      // Evaluate the enable property
      final shouldEnable = Utils.getBool(
        scopeManager.dataContext.eval(enable),
        fallback: false,
      );

      // Toggle wakelock based on the enable value
      if (shouldEnable) {
        print("WakelockAction: Enabling wakelock");
        await WakelockPlus.enable();
      } else {
        print("WakelockAction: Disabling wakelock");
        await WakelockPlus.disable();
      }

      // Verify and update the cached status from actual platform state
      await Device().refreshWakelockStatus();
      print("WakelockAction: Actual wakelock status is now: ${await WakelockPlus.enabled}");

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
      print("WakelockAction: Error toggling wakelock: $e");
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
