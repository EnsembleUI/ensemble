import 'dart:io';
import 'package:ensemble/action/get_network_info_action.dart';
import 'package:ensemble/framework/device.dart';
import 'package:ensemble/framework/stub/location_manager.dart';
import 'package:ensemble/framework/stub/network_info.dart'
    as ensembleNetWorkInfo;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:network_info_plus/network_info_plus.dart';

class NetworkInfoImpl implements ensembleNetWorkInfo.NetworkInfoManager {
  final NetworkInfo _networkInfo = NetworkInfo();
  @override
  Future<String?> getWifiBSSID() async {
    if (kIsWeb) {
      return Future.value(null); //not supported on the web
    }
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        if (await getLocationStatus() == LocationStatus.ready) {
          return await _networkInfo.getWifiBSSID();
        }
        return await _networkInfo.getWifiBSSID();
      }
    } on PlatformException catch (e) {
      throw PlatformException(
          code: 'Failed to get Wifi BSSID',
          message: e.message,
          details: e.details);
      print('Failed to get Wifi BSSID');
    }
  }

  @override
  Future<String?> getWifiBroadcast() async {
    try {
      return await _networkInfo.getWifiBroadcast();
    } on PlatformException catch (e) {
      throw PlatformException(
          code: 'Failed to get Wifi Broadcast address',
          message: e.message,
          details: e.details);
    }
  }

  @override
  Future<String?> getWifiGatewayIP() async {
    try {
      return await _networkInfo.getWifiGatewayIP();
    } on PlatformException catch (e) {
      throw PlatformException(
          code: 'Failed to get Wifi Gateway ip address',
          message: e.message,
          details: e.details);
    }
  }

  @override
  Future<String?> getWifiIPv4() async {
    try {
      return await _networkInfo.getWifiIP();
    } on PlatformException catch (e) {
      throw PlatformException(
          code: 'Failed to get Wifi IPv4 address',
          message: e.message,
          details: e.details);
    }
  }

  @override
  Future<String?> getWifiIPv6() async {
    try {
      return await _networkInfo.getWifiIPv6();
    } on PlatformException catch (e) {
      throw PlatformException(
          code: 'Failed to get Wifi IPv6 address',
          message: e.message,
          details: e.details);
    }
  }

  @override
  Future<String?> getWifiName() async {
    if (kIsWeb) {
      return Future.value(null); //not supported on the web
    }
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        String? wifiName;
        if (await getLocationStatus() == LocationStatus.ready) {
          wifiName = await _networkInfo.getWifiName();
        } else {
          wifiName = await _networkInfo.getWifiName();
        }
        if (Platform.isAndroid && wifiName != null) {
          //android can put double quotes around wifiname, we need to remove them
          if (wifiName.startsWith('"') && wifiName.endsWith('"')) {
            wifiName = wifiName.substring(1, wifiName.length - 1);
          }
        }
        return wifiName;
      }
    } on PlatformException catch (e) {
      throw PlatformException(
          code: 'Failed to get Wifi name',
          message: e.message,
          details: e.details);
      print('Failed to get Wifi BSSID');
    }
  }

  @override
  Future<String?> getWifiSubmask() async {
    try {
      return await _networkInfo.getWifiSubmask();
    } on PlatformException catch (e) {
      throw PlatformException(
          code: 'Failed to get Wifi Submask',
          message: e.message,
          details: e.details);
    }
  }

  Future<LocationPermissionStatus> checkPermission() async {
    final permission = await Geolocator.checkPermission();
    return LocationPermissionStatus.values
        .firstWhere((element) => element.name == permission.name);
  }

  @override
  Future<String> getLocationStatus() async {
    if (await Geolocator.isLocationServiceEnabled()) {
      LocationPermission permission = await Geolocator.checkPermission();
      // ask for permission if not already
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return permission.name;
    }
    return LocationStatus.disabled.name;
  }

  @override
  Future<InvokableNetworkInfo> getNetworkInfo() async {
    return InvokableNetworkInfo(
      wifiName: await getWifiName(),
      wifiBSSID: await getWifiBSSID(),
      wifiIPv4: await getWifiIPv4(),
      wifiIPv6: await getWifiIPv6(),
      wifiGatewayIP: await getWifiGatewayIP(),
      wifiBroadcast: await getWifiBroadcast(),
      wifiSubmask: await getWifiSubmask(),
    );
  }
}
