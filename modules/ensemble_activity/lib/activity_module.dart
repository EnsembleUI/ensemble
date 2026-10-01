import 'package:ensemble/framework/stub/activity_manager.dart';
import 'package:ensemble/module/activity_module.dart';
import 'package:get_it/get_it.dart';
import 'activity_manager.dart';

class ActivityModuleImpl implements ActivityModule {
  ActivityModuleImpl() {
    GetIt.I.registerSingleton<ActivityManager>(ActivityManagerImpl());
  }
}

