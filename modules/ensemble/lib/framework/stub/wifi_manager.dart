import 'package:ensemble/framework/error_handling.dart';

abstract class WifiManager {
  Future<WifiConnectResult> connect({
    required String ssid,
    required String password,
    bool joinOnce = false,
    bool rememberNetwork = true,
  });
}

class WifiManagerStub implements WifiManager {
  @override
  Future<WifiConnectResult> connect({
    required String ssid,
    required String password,
    bool joinOnce = false,
    bool rememberNetwork = true,
  }) {
    throw ConfigError(
        "Wi-Fi module is not enabled. Please review the Ensemble documentation.");
  }
}

class WifiConnectResult {
  final bool success;
  final String status;
  final String? message;
  final String? platformCode;

  const WifiConnectResult({
    required this.success,
    required this.status,
    this.message,
    this.platformCode,
  });
}
