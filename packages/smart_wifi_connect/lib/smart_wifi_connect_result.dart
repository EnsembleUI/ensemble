import 'package:smart_wifi_connect/smart_wifi_connect_status.dart';

class SmartWifiConnectResult {
  final bool success;
  final SmartWifiConnectStatus status;
  final String? message;
  final String? platformCode;

  const SmartWifiConnectResult({
    required this.success,
    required this.status,
    this.message,
    this.platformCode,
  });

  Map<String, dynamic> toMap() => {
        'success': success,
        'status': status.name,
        'message': message,
        'platformCode': platformCode,
      };
}
