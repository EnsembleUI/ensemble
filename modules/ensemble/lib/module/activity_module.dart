import 'package:ensemble/framework/stub/activity_manager.dart';
import 'package:get_it/get_it.dart';

abstract class ActivityModule {}

class ActivityModuleStub implements ActivityModule {
  ActivityModuleStub() {
    GetIt.I.registerSingleton<ActivityManager>(ActivityManagerStub());
  }
}
