import 'package:ensemble/framework/error_handling.dart';
import 'package:flutter/foundation.dart';

/// Thrown when device location services are off and Wi-Fi connect cannot proceed.
class WifiLocationDisabledException implements Exception {
  /// Human-readable explanation for the developer / onError fallback.
  final String message;

  /// Creates a [WifiLocationDisabledException].
  WifiLocationDisabledException([
    this.message =
        'Location services are disabled. Enable location to connect to WiFi.',
  ]);

  @override
  String toString() => message;
}

/// Thrown when location permission is denied and Wi-Fi connect cannot proceed.
class WifiPermissionDeniedException implements Exception {
  /// Human-readable explanation for the developer / onError fallback.
  final String message;

  /// Creates a [WifiPermissionDeniedException].
  WifiPermissionDeniedException([
    this.message =
        'Location permission is required to connect to WiFi on this device.',
  ]);

  @override
  String toString() => message;
}

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
}
