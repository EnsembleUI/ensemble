import 'dart:io';

import 'package:ensemble/framework/stub/wifi_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:plugin_wifi_connect/plugin_wifi_connect.dart';

class WifiManagerImpl implements WifiManager {
  Future<void> _ensureLocationPermission() async {
    if (kIsWeb || (!Platform.isIOS && !Platform.isAndroid)) {
      return;
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError(
          'Location services are disabled. Enable location to connect to WiFi.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError(
          'Location permission is required to connect to WiFi on this device.');
    }
  }

  Future<bool?> _connect(Future<bool?> Function() connect) async {
    await _ensureLocationPermission();
    return connect();
  }

  @override
  Future<bool?> connect(String ssid, {bool saveNetwork = false}) {
    return _connect(
        () => PluginWifiConnect.connect(ssid, saveNetwork: saveNetwork));
  }

  @override
  Future<bool?> connectByPrefix(String ssidPrefix, {bool saveNetwork = false}) {
    return _connect(() => PluginWifiConnect.connectByPrefix(ssidPrefix,
        saveNetwork: saveNetwork));
  }

  @override
  Future<bool?> connectToSecureNetwork(
    String ssid,
    String password, {
    bool isWep = false,
    bool isWpa3 = false,
    bool saveNetwork = false,
    bool isHidden = false,
  }) {
    return _connect(() => PluginWifiConnect.connectToSecureNetwork(
          ssid,
          password,
          isWep: isWep,
          isWpa3: isWpa3,
          saveNetwork: saveNetwork,
          isHidden: isHidden,
        ));
  }

  @override
  Future<bool?> connectToSecureNetworkByPrefix(
    String ssidPrefix,
    String password, {
    bool isWep = false,
    bool isWpa3 = false,
    bool saveNetwork = false,
  }) {
    return _connect(() => PluginWifiConnect.connectToSecureNetworkByPrefix(
          ssidPrefix,
          password,
          isWep: isWep,
          isWpa3: isWpa3,
          saveNetwork: saveNetwork,
        ));
  }

  @override
  Future<bool?> disconnect() {
    return PluginWifiConnect.disconnect();
  }

  @override
  Future<void> activateWifi() {
    return PluginWifiConnect.activateWifi();
  }

  @override
  Future<void> deactivateWifi() {
    return PluginWifiConnect.deactivateWifi();
  }
}
