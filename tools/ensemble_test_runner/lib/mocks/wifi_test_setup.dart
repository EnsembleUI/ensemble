import 'package:ensemble/action/get_network_info_action.dart';
import 'package:ensemble/framework/device.dart';
import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble/framework/stub/location_manager.dart';
import 'package:ensemble/framework/stub/network_info.dart';
import 'package:ensemble/framework/stub/wifi_manager.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:get_it/get_it.dart';

WifiTestConfig _activeWifiTestConfig = const WifiTestConfig();

/// Active Wi-Fi test double settings for the current test run.
WifiTestConfig get activeWifiTestConfig => _activeWifiTestConfig;

/// Updates the active Wi-Fi double settings before each test executes.
void applyWifiTestConfig(WifiTestConfig config) {
  _activeWifiTestConfig = config;
}

/// Replaces the app's Wi-Fi managers with deterministic test doubles when the
/// wifi module is enabled (`useWifi`, not [WifiManagerStub]).
void ensureWifiTestDoublesForTest() {
  final getIt = GetIt.I;
  if (!getIt.isRegistered<WifiManager>()) return;
  if (getIt.get<WifiManager>() is WifiManagerStub) return;

  getIt.unregister<WifiManager>();
  if (getIt.isRegistered<NetworkInfoManager>()) {
    getIt.unregister<NetworkInfoManager>();
  }

  getIt.registerSingleton<WifiManager>(_TestWifiManager());
  getIt.registerSingleton<NetworkInfoManager>(_TestNetworkInfoManager());
}

String _wifiTestMode() {
  final value = StorageManager()
      .read(_activeWifiTestConfig.modeStorageKey)
      ?.toString();
  if (value == null || value.isEmpty) return WifiTestConfig.successMode;
  return value;
}

class _TestWifiManager implements WifiManager {
  Future<bool?> _connectResult() async {
    if (_wifiTestMode() == WifiTestConfig.connectFailMode) return false;
    return true;
  }

  @override
  Future<bool?> connect(String ssid, {bool saveNetwork = false}) =>
      _connectResult();

  @override
  Future<bool?> connectByPrefix(String ssidPrefix,
          {bool saveNetwork = false}) =>
      _connectResult();

  @override
  Future<bool?> connectToSecureNetwork(
    String ssid,
    String password, {
    bool isWep = false,
    bool isWpa3 = false,
    bool saveNetwork = false,
    bool isHidden = false,
  }) =>
      _connectResult();

  @override
  Future<bool?> connectToSecureNetworkByPrefix(
    String ssidPrefix,
    String password, {
    bool isWep = false,
    bool isWpa3 = false,
    bool saveNetwork = false,
  }) =>
      _connectResult();

  @override
  Future<bool?> disconnect() async => true;
}

class _TestNetworkInfoManager implements NetworkInfoManager {
  @override
  Future<LocationPermissionStatus> checkPermission() async =>
      LocationPermissionStatus.always;

  @override
  Future<String> getLocationStatus() async => LocationStatus.ready.name;

  @override
  Future<InvokableNetworkInfo> getNetworkInfo() async {
    final reportedSsid =
        _wifiTestMode() == WifiTestConfig.verifyFailMode
            ? _activeWifiTestConfig.verifyFailSsid
            : _activeWifiTestConfig.ssid;
    return InvokableNetworkInfo(
      wifiName: reportedSsid,
      wifiIPv4: '192.168.2.100',
      wifiBSSID: 'AA:BB:CC:DD:EE:FF',
    );
  }
}
