/// Network metadata provider for Ensemble apps.
library network_info;

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

/// Provides Wi-Fi and network metadata through `network_info_plus`.
class NetworkInfoImpl implements ensembleNetWorkInfo.NetworkInfoManager {
  /// Creates a network-info manager backed by the platform implementation.
  NetworkInfoImpl();

  final NetworkInfo _networkInfo = NetworkInfo();

  /// Returns the current Wi-Fi BSSID when the platform exposes it.
  Future<String?> getWifiBSSID() async {
    if (kIsWeb) {
      return Future.value(null); //not supported on the web
    }
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        if (await getLocationStatus() == LocationStatus.ready.name) {
          return await _networkInfo.getWifiBSSID();
        }
        return await _networkInfo.getWifiBSSID();
      }
    } on PlatformException catch (e) {
      throw PlatformException(
          code: 'Failed to get Wifi BSSID',
          message: e.message,
          details: e.details);
    }
    return null;
  }

  /// Returns the current Wi-Fi broadcast address.
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

  /// Returns the current Wi-Fi gateway IP address.
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

  /// Returns the current Wi-Fi IPv4 address.
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

  /// Returns the current Wi-Fi IPv6 address.
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

  /// Returns the current Wi-Fi network name.
  Future<String?> getWifiName() async {
    if (kIsWeb) {
      return Future.value(null); //not supported on the web
    }
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        String? wifiName;
        if (await getLocationStatus() == LocationStatus.ready.name) {
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
    }
    return null;
  }

  /// Returns the current Wi-Fi subnet mask.
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

  /// Returns the raw location permission status reported by the platform.
  @override
  Future<LocationPermissionStatus> checkPermission() async {
    final permission = await Geolocator.checkPermission();
    return LocationPermissionStatus.values
        .firstWhere((element) => element.name == permission.name);
  }

  /// Returns whether location services are ready, disabled, or denied.
  @override
  Future<String> getLocationStatus() async {
    if (await Geolocator.isLocationServiceEnabled()) {
      LocationPermission permission = await Geolocator.checkPermission();
      // ask for permission if not already
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever ||
          permission == LocationPermission.unableToDetermine) {
        return permission.name;
      }
      return LocationStatus.ready.name;
    }
    return LocationStatus.disabled.name;
  }

  /// Returns the available Wi-Fi metadata as an invokable Ensemble payload.
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
