import 'package:ensemble/framework/stub/stripe_manager.dart';
import 'package:ensemble/module/stripe_module.dart';
import 'package:get_it/get_it.dart';
import 'stripe_manager.dart';

class StripeModuleImpl implements StripeModule {
  StripeModuleImpl() {
    GetIt.I.registerSingleton<StripeManager>(StripeManagerImpl());
  }
}
