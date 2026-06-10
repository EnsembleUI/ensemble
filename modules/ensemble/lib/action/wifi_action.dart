import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/stub/wifi_manager.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

class ConnectToWifiAction extends EnsembleAction {
  ConnectToWifiAction({
    super.initiator,
    required this.ssid,
    required this.password,
    this.joinOnce,
    this.rememberNetwork,
    this.onSuccess,
    this.onError,
  });

  final dynamic ssid;
  final dynamic password;
  final dynamic joinOnce;
  final dynamic rememberNetwork;
  final EnsembleAction? onSuccess;
  final EnsembleAction? onError;

  factory ConnectToWifiAction.fromYaml({Invokable? initiator, Map? payload}) {
    if (payload == null || payload['ssid'] == null) {
      throw Exception("connectToWifi requires 'ssid' parameter.");
    }

    return ConnectToWifiAction(
      initiator: initiator,
      ssid: payload['ssid'],
      password: payload['password'] ?? '',
      joinOnce: payload['joinOnce'],
      rememberNetwork: payload['rememberNetwork'],
      onSuccess:
          EnsembleAction.from(payload['onSuccess'], initiator: initiator),
      onError: EnsembleAction.from(payload['onError'], initiator: initiator),
    );
  }

  @override
  Future<void> execute(BuildContext context, ScopeManager scopeManager) async {
    try {
      final wifiManager = GetIt.I<WifiManager>();

      final evaluatedSsid =
          Utils.getString(scopeManager.dataContext.eval(ssid), fallback: '');
      final evaluatedPassword =
          Utils.getString(scopeManager.dataContext.eval(password), fallback: '');
      final evaluatedJoinOnce =
          Utils.optionalBool(scopeManager.dataContext.eval(joinOnce)) ?? false;
      final evaluatedRememberNetwork =
          Utils.optionalBool(scopeManager.dataContext.eval(rememberNetwork)) ??
              true;

      final result = await wifiManager.connect(
        ssid: evaluatedSsid,
        password: evaluatedPassword,
        joinOnce: evaluatedJoinOnce,
        rememberNetwork: evaluatedRememberNetwork,
      );

      if (result.success && onSuccess != null) {
        await ScreenController().executeAction(
          context,
          onSuccess!,
          event: EnsembleEvent(initiator, data: {
            'status': result.status,
            'message': result.message,
          }),
        );
      } else if (!result.success && onError != null) {
        await ScreenController().executeAction(
          context,
          onError!,
          event: EnsembleEvent(initiator, error: result.message, data: {
            'status': result.status,
            'platformCode': result.platformCode,
          }),
        );
      }
    } catch (e) {
      if (onError != null) {
        await ScreenController().executeAction(
          context,
          onError!,
          event: EnsembleEvent(initiator, error: e.toString()),
        );
      }
    }
  }
}
