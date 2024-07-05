
import 'network_info_manager.dart';
import 'package:network_info_plus/network_info_plus.dart';

class NetworkInfoImpl extends NetworkInfoManager {

  @override
  Future<void> getNetworkInfo(
      NetworkInfoSuccessCallback onSuccess, NetworkInfoErrorCallback onError) async {
    if (await requestPermission()) {
      try {
        final info = NetworkInfo();

        final wifiName = await info.getWifiName(); // "FooNetwork"
        final wifiBSSID = await info.getWifiBSSID(); // 11:22:33:44:55:66
        final wifiIP = await info.getWifiIP(); // 192.168.1.43
        final wifiIPv6 = await info.getWifiIPv6(); // 2001:0db8:85a3:0000:0000:8a2e:0370:7334
        final wifiSubmask = await info.getWifiSubmask(); // 255.255.255.0
        final wifiBroadcast = await info.getWifiBroadcast(); // 192.168.1.255
        final wifiGateway = await info.getWifiGatewayIP(); // 192.168.1.1

        var networkInfo = NetworkInformation(
            wifiName: wifiName,
            wifiBSSID: wifiBSSID,
            wifiIP: wifiIP,
            wifiIPv6: wifiIPv6,
            wifiSubmask: wifiSubmask,
            wifiBroadcast: wifiBroadcast,
            wifiGateway: wifiGateway
        );
        onSuccess(networkInfo);
        return;
      } catch (e) {
        onError('Failed to get NetworkInfo');
      }
    } else {
      onError('Permission denied');
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      final status =
          await fcontacts.FlutterContacts.requestPermission(readonly: true);
      return status;
    } catch (_) {
      return false;
    }
  }
}
