import 'package:ensemble/framework/stub/stripe_manager.dart';
import 'package:get_it/get_it.dart';

abstract class StripeModule {}

class StripeModuleStub implements StripeModule {
  StripeModuleStub() {
    GetIt.I.registerSingleton<StripeManager>(StripeManagerStub());
  }
}
