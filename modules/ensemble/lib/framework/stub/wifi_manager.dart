import 'package:ensemble/framework/error_handling.dart';
import 'package:flutter/foundation.dart';

abstract class WifiManager {
  Future<bool?> connect(String ssid, {bool saveNetwork = false});

  Future<bool?> connectByPrefix(String ssidPrefix, {bool saveNetwork = false});

  Future<bool?> connectToSecureNetwork(
    String ssid,
    String password, {
    bool isWep = false,
    bool isWpa3 = false,
    bool saveNetwork = false,
    bool isHidden = false,
  });

  Future<bool?> connectToSecureNetworkByPrefix(
    String ssidPrefix,
    String password, {
    bool isWep = false,
    bool isWpa3 = false,
    bool saveNetwork = false,
  });

  Future<bool?> disconnect();

  Future<void> activateWifi();

  Future<void> deactivateWifi();
}

class WifiManagerStub implements WifiManager {
  WifiManagerStub();

  Never _throwNotEnabled() {
    if (kIsWeb) {
      throw ConfigError(
          "WiFi module is not supported on the web. Please review the Ensemble documentation.");
    }
    throw ConfigError(
        "WiFi module is not enabled. Please review the Ensemble documentation.");
  }

  @override
  Future<bool?> connect(String ssid, {bool saveNetwork = false}) {
    _throwNotEnabled();
  }

  @override
  Future<bool?> connectByPrefix(String ssidPrefix, {bool saveNetwork = false}) {
    _throwNotEnabled();
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
    _throwNotEnabled();
  }

  @override
  Future<bool?> connectToSecureNetworkByPrefix(
    String ssidPrefix,
    String password, {
    bool isWep = false,
    bool isWpa3 = false,
    bool saveNetwork = false,
  }) {
    _throwNotEnabled();
  }

  @override
  Future<bool?> disconnect() {
    _throwNotEnabled();
  }

  @override
  Future<void> activateWifi() {
    _throwNotEnabled();
  }

  @override
  Future<void> deactivateWifi() {
    _throwNotEnabled();
  }
}
