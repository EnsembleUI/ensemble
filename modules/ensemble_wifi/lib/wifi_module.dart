import 'package:ensemble/framework/stub/wifi_manager.dart';
import 'package:ensemble/module/wifi_module.dart';
import 'package:ensemble_wifi/wifi_manager_impl.dart';
import 'package:get_it/get_it.dart';

class WifiModuleImpl implements WifiModule {
  WifiModuleImpl() {
    GetIt.I.registerSingleton<WifiManager>(WifiManagerImpl());
  }
}
