import 'package:ensemble/framework/stub/wifi_manager.dart';
import 'package:get_it/get_it.dart';

abstract class WifiModule {}

class WifiModuleStub implements WifiModule {
  WifiModuleStub() {
    GetIt.I.registerSingleton<WifiManager>(WifiManagerStub());
  }
}
