import 'package:flutter/services.dart';
import 'package:smart_wifi_connect/smart_wifi_connect_result.dart';
import 'package:smart_wifi_connect/smart_wifi_connect_status.dart';

export 'package:smart_wifi_connect/smart_wifi_connect_result.dart';
export 'package:smart_wifi_connect/smart_wifi_connect_status.dart';

class SmartWifiConnect {
  static const MethodChannel _channel = MethodChannel('smart_wifi_connect');

  static Future<SmartWifiConnectResult> connect({
    required String ssid,
    required String password,
    bool joinOnce = false,
    bool rememberNetwork = true,
  }) async {
    if (ssid.isEmpty) {
      return const SmartWifiConnectResult(
        success: false,
        status: SmartWifiConnectStatus.invalidArguments,
        message: 'SSID cannot be empty',
      );
    }

    try {
      final result = await _channel.invokeMethod<Map>('connect', {
        'ssid': ssid,
        'password': password,
        'joinOnce': joinOnce,
        'rememberNetwork': rememberNetwork,
      });

      if (result == null) {
        return const SmartWifiConnectResult(
          success: false,
          status: SmartWifiConnectStatus.failed,
          message: 'No response from platform',
        );
      }

      final statusStr = result['status'] as String? ?? 'failed';
      final status = SmartWifiConnectStatus.values.firstWhere(
        (e) => e.name == statusStr,
        orElse: () => SmartWifiConnectStatus.failed,
      );

      return SmartWifiConnectResult(
        success: result['success'] as bool? ?? false,
        status: status,
        message: result['message'] as String?,
        platformCode: result['platformCode'] as String?,
      );
    } on PlatformException catch (e) {
      return SmartWifiConnectResult(
        success: false,
        status: SmartWifiConnectStatus.failed,
        message: e.message ?? 'Platform error',
        platformCode: e.code,
      );
    } on MissingPluginException {
      return const SmartWifiConnectResult(
        success: false,
        status: SmartWifiConnectStatus.unsupported,
        message: 'Wi-Fi connect is not supported on this platform',
      );
    }
  }
}
