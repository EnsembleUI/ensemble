import 'package:ensemble/framework/stub/wifi_manager.dart';
import 'package:smart_wifi_connect/smart_wifi_connect.dart';

class WifiManagerImpl implements WifiManager {
  @override
  Future<WifiConnectResult> connect({
    required String ssid,
    required String password,
    bool joinOnce = false,
    bool rememberNetwork = true,
  }) async {
    final result = await SmartWifiConnect.connect(
      ssid: ssid,
      password: password,
      joinOnce: joinOnce,
      rememberNetwork: rememberNetwork,
    );

    return WifiConnectResult(
      success: result.success,
      status: result.status.name,
      message: result.message,
      platformCode: result.platformCode,
    );
  }
}
