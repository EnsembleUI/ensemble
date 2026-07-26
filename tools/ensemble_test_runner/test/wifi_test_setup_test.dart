import 'package:ensemble/action/get_network_info_action.dart';
import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble/framework/stub/network_info.dart';
import 'package:ensemble/framework/stub/wifi_manager.dart';
import 'package:ensemble_test_runner/mocks/wifi_test_setup.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

void main() {
  setUp(() async {
    EnsembleTestHarness.ensureTestPlugins();
    await StorageManager().init();
    await StorageManager().clearPublicStorage();
    applyWifiTestConfig(const WifiTestConfig(
      ssid: 'KPN_Test_WiFi',
      modeStorageKey: 'wifiTestMode',
    ));
  });

  test('wifi doubles are skipped when wifi module is a stub', () {
    final getIt = GetIt.I;
    if (getIt.isRegistered<WifiManager>()) {
      getIt.unregister<WifiManager>();
    }
    getIt.registerSingleton<WifiManager>(WifiManagerStub());
    ensureWifiTestDoublesForTest();
    expect(getIt.get<WifiManager>(), isA<WifiManagerStub>());
  });

  test('wifi doubles succeed by default', () async {
    _installWifiDoubles();

    expect(
      await GetIt.I<WifiManager>().connectToSecureNetwork('KPN_Test_WiFi', 'pw'),
      isTrue,
    );
    final info = await GetIt.I<NetworkInfoManager>().getNetworkInfo();
    expect(info.wifiName, 'KPN_Test_WiFi');
  });

  test('wifi doubles honor connect_fail mode from storage', () async {
    await StorageManager().write('wifiTestMode', 'connect_fail');
    _installWifiDoubles();

    expect(
      await GetIt.I<WifiManager>().connectToSecureNetwork('KPN_Test_WiFi', 'pw'),
      isFalse,
    );
  });

  test('wifi doubles honor verify_fail mode from storage', () async {
    await StorageManager().write('wifiTestMode', 'verify_fail');
    _installWifiDoubles();

    expect(
      await GetIt.I<WifiManager>().connectToSecureNetwork('KPN_Test_WiFi', 'pw'),
      isTrue,
    );
    final info = await GetIt.I<NetworkInfoManager>().getNetworkInfo();
    expect(info.wifiName, 'Wrong_Network');
  });
}

/// Registers a non-stub [WifiManager] so [ensureWifiTestDoublesForTest] installs.
void _installWifiDoubles() {
  final getIt = GetIt.I;
  if (getIt.isRegistered<WifiManager>()) {
    getIt.unregister<WifiManager>();
  }
  if (getIt.isRegistered<NetworkInfoManager>()) {
    getIt.unregister<NetworkInfoManager>();
  }
  // Pretend the wifi module is enabled (not WifiManagerStub).
  getIt.registerSingleton<WifiManager>(_EnabledWifiMarker());
  ensureWifiTestDoublesForTest();
}

class _EnabledWifiMarker implements WifiManager {
  @override
  Future<bool?> connect(String ssid, {bool saveNetwork = false}) async => true;

  @override
  Future<bool?> connectByPrefix(String ssidPrefix,
          {bool saveNetwork = false}) async =>
      true;

  @override
  Future<bool?> connectToSecureNetwork(
    String ssid,
    String password, {
    bool isWep = false,
    bool isWpa3 = false,
    bool saveNetwork = false,
    bool isHidden = false,
  }) async =>
      true;

  @override
  Future<bool?> connectToSecureNetworkByPrefix(
    String ssidPrefix,
    String password, {
    bool isWep = false,
    bool isWpa3 = false,
    bool saveNetwork = false,
  }) async =>
      true;

  @override
  Future<bool?> disconnect() async => true;
}
