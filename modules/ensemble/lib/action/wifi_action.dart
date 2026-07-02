import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/stub/wifi_manager.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';

/// Wi-Fi operations supported by the connect-to-Wi-Fi action.
enum WifiOperation {
  /// Connects the device to the requested Wi-Fi network.
  connect,
  /// Disconnects the device from the requested Wi-Fi network.
  disconnect
}

Future<dynamic> _handleWifiResult(
  BuildContext context,
  Invokable? initiator,
  EnsembleAction? onSuccess,
  EnsembleAction? onError,
  bool? result,
) {
  if (result == true) {
    if (onSuccess != null) {
      return ScreenController().executeAction(context, onSuccess,
          event: EnsembleEvent(initiator, data: {'connected': true}));
    }
    return Future.value(null);
  }
  if (onError != null) {
    final message = result == null
        ? 'WiFi connection returned no result'
        : 'WiFi connection was denied or could not be verified. '
            'Check SSID/password, tap Connect on the system WiFi dialog (Android), '
            'approve the system join prompt (iOS), and ensure location permission is granted.';
    return ScreenController().executeAction(context, onError,
        event: EnsembleEvent(initiator,
            error: message,
            data: {'connected': result, 'status': 'error'}));
  }
  return Future.value(null);
}

Future<dynamic> _handleWifiError(
  BuildContext context,
  Invokable? initiator,
  EnsembleAction? onError,
  Object error,
) {
  if (onError != null) {
    return ScreenController().executeAction(context, onError,
        event: EnsembleEvent(initiator,
            error: error.toString(), data: {'status': 'error'}));
  }
  return Future.value(null);
}

/// Ensemble action that connects to or disconnects from a Wi-Fi network.
class ConnectToWifiAction extends EnsembleAction {
  /// Platform Wi-Fi manager used to execute the network operation.
  final WifiManager wifiManager = GetIt.I<WifiManager>();
  /// Requested Wi-Fi or provider operation.
  final WifiOperation operation;
  /// Exact Wi-Fi SSID to connect to.
  final String? ssid;
  /// SSID prefix used when the exact network name may vary.
  final String? ssidPrefix;
  /// Password used when joining the Wi-Fi network.
  final String? password;
  /// Whether the Wi-Fi network uses WEP security.
  final bool isWep;
  /// Whether the Wi-Fi network uses WPA3 security.
  final bool isWpa3;
  /// Whether the joined network should be saved by the platform.
  final bool saveNetwork;
  /// Whether the Wi-Fi network is hidden.
  final bool isHidden;
  /// Action executed when the operation succeeds.
  final EnsembleAction? onSuccess;
  /// Action executed when the operation fails.
  final EnsembleAction? onError;

  /// Creates a [ConnectToWifiAction] action.
  ConnectToWifiAction({
    super.initiator,
    super.inputs,
    required this.operation,
    required this.ssid,
    required this.ssidPrefix,
    required this.password,
    required this.isWep,
    required this.isWpa3,
    required this.saveNetwork,
    required this.isHidden,
    this.onSuccess,
    this.onError,
  });

  /// Creates a [ConnectToWifiAction] from a YAML or map action payload.
  factory ConnectToWifiAction.from({Invokable? initiator, dynamic payload}) =>
      ConnectToWifiAction.fromYaml(
          initiator: initiator, payload: Utils.getYamlMap(payload));

  /// Creates a [ConnectToWifiAction] from a YAML or map action payload.
  factory ConnectToWifiAction.fromYaml({Invokable? initiator, Map? payload}) {
    final operationName =
        Utils.optionalString(payload?['operation']) ?? 'connect';
    final operation = WifiOperation.values.firstWhere(
      (value) => value.name == operationName,
      orElse: () => WifiOperation.connect,
    );

    return ConnectToWifiAction(
      initiator: initiator,
      inputs: Utils.getMap(payload?['inputs']),
      operation: operation,
      ssid: Utils.optionalString(payload?['ssid']),
      ssidPrefix: Utils.optionalString(payload?['ssidPrefix']),
      password: Utils.optionalString(payload?['password']),
      isWep: Utils.getBool(payload?['isWep'], fallback: false),
      isWpa3: Utils.getBool(payload?['isWpa3'], fallback: false),
      saveNetwork: Utils.getBool(payload?['saveNetwork'], fallback: false),
      isHidden: Utils.getBool(payload?['isHidden'], fallback: false),
      onSuccess:
          EnsembleAction.from(payload?['onSuccess'], initiator: initiator),
      onError: EnsembleAction.from(payload?['onError'], initiator: initiator),
    );
  }

  /// Runs this action and performs the configured Wi-Fi operation.
  @override
  Future<dynamic> execute(
      BuildContext context, ScopeManager scopeManager) async {
    if (kIsWeb) {
      return _handleWifiError(context, initiator, onError,
          'WiFi is not supported on the web');
    }

    try {
      switch (operation) {
        case WifiOperation.disconnect:
          final result = await wifiManager.disconnect();
          return _handleWifiResult(
              context, initiator, onSuccess, onError, result);
        case WifiOperation.connect:
          return _connect(context, scopeManager);
      }
    } on PlatformException catch (e) {
      final message = e.message?.isNotEmpty == true ? e.message! : e.code;
      return _handleWifiError(
        context,
        initiator,
        onError,
        message,
      );
    } catch (e) {
      final message = e is StateError ? e.message : e.toString();
      return _handleWifiError(context, initiator, onError, message);
    }
  }

  Future<dynamic> _connect(
      BuildContext context, ScopeManager scopeManager) async {
    final evaluatedSsid = ssid != null ? scopeManager.dataContext.eval(ssid) : null;
    final evaluatedPrefix = ssidPrefix != null
        ? scopeManager.dataContext.eval(ssidPrefix)
        : null;
    final evaluatedPassword =
        password != null ? scopeManager.dataContext.eval(password) : null;

    final hasPassword =
        evaluatedPassword != null && evaluatedPassword.toString().isNotEmpty;
    final hasSsid =
        evaluatedSsid != null && evaluatedSsid.toString().isNotEmpty;
    final hasPrefix =
        evaluatedPrefix != null && evaluatedPrefix.toString().isNotEmpty;

    if (!hasSsid && !hasPrefix) {
      return _handleWifiError(context, initiator, onError,
          'ssid or ssidPrefix is required for connect operation');
    }

    bool? result;
    if (hasPrefix) {
      if (hasPassword) {
        result = await wifiManager.connectToSecureNetworkByPrefix(
          evaluatedPrefix.toString(),
          evaluatedPassword.toString(),
          isWep: isWep,
          isWpa3: isWpa3,
          saveNetwork: saveNetwork,
        );
      } else {
        result = await wifiManager.connectByPrefix(
          evaluatedPrefix.toString(),
          saveNetwork: saveNetwork,
        );
      }
    } else if (hasPassword) {
      result = await wifiManager.connectToSecureNetwork(
        evaluatedSsid.toString(),
        evaluatedPassword.toString(),
        isWep: isWep,
        isWpa3: isWpa3,
        saveNetwork: saveNetwork,
        isHidden: isHidden,
      );
    } else {
      result = await wifiManager.connect(
        evaluatedSsid.toString(),
        saveNetwork: saveNetwork,
      );
    }

    return _handleWifiResult(context, initiator, onSuccess, onError, result);
  }
}
