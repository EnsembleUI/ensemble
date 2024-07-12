import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/device.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/stub/location_manager.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../framework/stub/network_info.dart';

class GetNetworkInfoAction extends EnsembleAction {
  NetworkInfoManager networkInfo = GetIt.I<NetworkInfoManager>();
  EnsembleAction? onSuccess;
  EnsembleAction? onError;
  EnsembleAction? onDenied;
  EnsembleAction? onLocationDisabled;

  GetNetworkInfoAction({super.initiator,
    super.inputs,
    this.onSuccess,
    this.onError,
    this.onDenied,
    this.onLocationDisabled});

  factory GetNetworkInfoAction.from({Invokable? initiator,dynamic payload}) =>
      GetNetworkInfoAction.fromYaml(initiator: initiator, payload: Utils.getYamlMap(payload));
  factory GetNetworkInfoAction.fromYaml({Invokable? initiator, Map? payload}) {
    return GetNetworkInfoAction(
        initiator: initiator,
        inputs: Utils.getMap(payload?['inputs']),
        onSuccess: EnsembleAction.from(payload?['onSuccess'], initiator: initiator),
        onError: EnsembleAction.from(payload?['onError'], initiator: initiator),
        onDenied: EnsembleAction.from(payload?['onDenied'], initiator: initiator),
        onLocationDisabled: EnsembleAction.from(payload?['onLocationDisabled'], initiator: initiator));
  }

  @override
  Future<dynamic> execute(BuildContext context, ScopeManager scopeManager) {
    if (kIsWeb && onError != null) {
      return ScreenController().executeAction(context, onError!,
          event: EnsembleEvent(initiator,
              error: 'Network info is not supported on the web',
              data: {'status': 'error'}));
    }
    networkInfo.getLocationStatus().then((locationStatus) {
      if ((locationStatus == LocationPermissionStatus.denied.name
          || locationStatus == LocationPermissionStatus.deniedForever.name)
          && onDenied != null) {
        return ScreenController().executeAction(context, onDenied!,
            event: EnsembleEvent(initiator,
                data: {'status': locationStatus}));
      } else if (locationStatus == LocationStatus.disabled.name
          && onLocationDisabled != null) {
        return ScreenController().executeAction(context, onLocationDisabled!,
            event: EnsembleEvent(initiator,
                data: {'status': locationStatus}));
      } else
      if (locationStatus == LocationPermissionStatus.unableToDetermine.name
          && onError != null) {
        return ScreenController().executeAction(context, onError!,
            event: EnsembleEvent(initiator,
                data: {
                  'status': locationStatus
                }));
      } else {
        try {
          networkInfo.getNetworkInfo().then((info) =>
              ScreenController().executeAction(context, onSuccess!,
                  event: EnsembleEvent(initiator,
                      data: {
                        'status': locationStatus,
                        'networkInfo': info,
                      }
                  ))).onError((error, stackTrace) {
            if (onError != null) {
              return ScreenController().executeAction(context, onError!,
                  event: EnsembleEvent(initiator,
                      error: error.toString(),
                      data: {'status': locationStatus}));
            }
          });
        } catch (e) {
          if (onError != null) {
            return ScreenController().executeAction(context, onError!,
                event: EnsembleEvent(initiator,
                    error: e.toString(),
                    data: {'status': locationStatus}));
          }
        }
      }
    }).onError((e, stackTrace) {
      if (onError != null) {
        return ScreenController().executeAction(context, onError!,
            event: EnsembleEvent(initiator,
                error: e.toString(),
                data: {'status': 'error: '+e.toString(), 'networkInfo': null}));
      }
      print('Failed to get location status: $e');
    });
    return Future.value(null);
  }
}
class InvokableNetworkInfo extends Object with Invokable {
  String? wifiName,wifiIPv6,wifiIPv4,wifiGatewayIP,wifiSubmask,wifiBroadcast,wifiBSSID;
  InvokableNetworkInfo({
    this.wifiName,
    this.wifiIPv4,
    this.wifiIPv6,
    this.wifiSubmask,
    this.wifiGatewayIP,
    this.wifiBroadcast,
    this.wifiBSSID,
  });


  @override
  Map<String, Function> getters() {
    return {
      'wifiName': () => wifiName,
      'wifiIPv4': () => wifiIPv4,
      'wifiIPv6': () => wifiIPv6,
      'wifiSubmask': () => wifiSubmask,
      'wifiGatewayIP': () => wifiGatewayIP,
      'wifiBroadcast': () => wifiBroadcast,
      'wifiBSSID': () => wifiBSSID,
    };
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {};
  }
}