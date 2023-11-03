import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:flutter/services.dart';

/// managing communication between Ensemble and the host platform (iOS/Android)
class HostPlatformManager extends IsHostPlatformManager
    with _InboundManager, _OutboundManager {
  HostPlatformManager._internal();

  static final HostPlatformManager _instance = HostPlatformManager._internal();

  factory HostPlatformManager() => _instance;

  static const MethodChannel _channel =
      MethodChannel('com.ensembleui.host.platform');

  @override
  MethodChannel getChannel() => _channel;

  void init() {
    _channel.setMethodCallHandler(_receiveData);
  }
}

abstract class IsHostPlatformManager {
  MethodChannel getChannel();
}

/// Handle Inbound methods
mixin _InboundManager on IsHostPlatformManager {
  Future<void> _receiveData(MethodCall call) async {
    Method? method = Method.values.from(call.method);
    switch (method) {
      case Method.updateEnvOverrides:
        _updateEnvOverrides(call.arguments);
        break;
      case Method.fromHostToEnsemble:
        print("Data From HOST: ${call.arguments}");
        break;
      default:
        break;
    }
  }

  /// data coming from hosting platform's envVariable channel
  /// will be added to the environment overrides
  void _updateEnvOverrides(dynamic payload) {
    if (payload is Map && payload.isNotEmpty) {
      Map<String, dynamic> variables = {};
      payload.forEach((key, value) {
        variables[key.toString()] = value;
      });
      Ensemble().getConfig()?.updateEnvOverrides(variables);
    }
  }
}

/// Handle Outbound methods
mixin _OutboundManager on IsHostPlatformManager {
  Future<void> navigateExternalScreen(dynamic payload) async {
    return await getChannel()
        .invokeMethod(Method.navigateExternalScreen.name, payload);
  }

  void sendData(dynamic payload) {
    getChannel().invokeMethod(Method.fromEnsembleToHost.name, payload);
  }

  Future<void> callNativeMethod(String name, dynamic payload) async {
    try {
      await getChannel().invokeMethod(name, payload);
    } catch (_) {
      rethrow;
    }
  }
}

enum Method {
  // for sending environment variables from host to Ensemble
  updateEnvOverrides,

  // navigate to a host platform's screen
  navigateExternalScreen,

  // twp-way communication between host and Ensemble
  fromHostToEnsemble,
  fromEnsembleToHost
}
