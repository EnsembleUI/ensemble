import 'package:ensemble/framework/placeholder/auth_context_manager.dart';
import 'package:ensemble/framework/placeholder/oauth_controller.dart';
import 'package:ensemble/framework/placeholder/token_manager.dart';
import 'package:ensemble/widget/stub_widgets.dart';
import 'package:get_it/get_it.dart';

abstract class AuthModule {
  void init();
}

class AuthModuleStub implements AuthModule {
  @override
  void init() {
    GetIt.I.registerFactory<AuthContextManagerBase>(() => AuthContextManagerStub());
    GetIt.I.registerFactory<SignInWithGoogleBase>(() => const SignInWithGoogleStub());
    GetIt.I.registerFactory<SignInWithAppleBase>(() => const SignInWithAppleStub());
    GetIt.I.registerSingleton<TokenManagerBase>(TokenManagerStub());
    GetIt.I.registerFactory<OAuthControllerBase>(() => OAuthControllerStub());
  }

}