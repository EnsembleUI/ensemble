typedef NetworkInfoSuccessCallback = void Function(NetworkInformation networkInfo);
typedef NetworkInfoErrorCallback = void Function(dynamic);


abstract class NetworkInfoManager {
  void getNetworkInfo(
      NetworkInfoSuccessCallback onSuccess, NetworkInfoErrorCallback onError);
      Future<bool> requestPermission();
}

class NetworkInformation {
  final String? wifiName;
  final String? wifiBSSID;
  final String? wifiIP;
  final String? wifiIPv6;
  final String? wifiSubmask;
  final String? wifiBroadcast;
  final String? wifiGateway;

  NetworkInformation({
    this.wifiName,
    this.wifiBSSID,
    this.wifiIP,
    this.wifiIPv6,
    this.wifiSubmask,
    this.wifiBroadcast,
    this.wifiGateway,
  });

  @override
  String toString() {
    return 'NetworkInformation(wifiName: $wifiName, wifiBSSID: $wifiBSSID, wifiIP: $wifiIP, wifiIPv6: $wifiIPv6, wifiSubmask: $wifiSubmask, wifiBroadcast: $wifiBroadcast, wifiGateway: $wifiGateway)';
  }
}
