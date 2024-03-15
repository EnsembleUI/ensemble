import 'package:ensemble/framework/stub/auth_context_manager.dart';
import 'package:ensemble/framework/stub/oauth_controller.dart';
import 'package:ensemble/framework/stub/token_manager.dart';
import 'package:ensemble/widget/stub_widgets.dart';
import 'package:get_it/get_it.dart';

abstract class AuthModule {}

class AuthModuleStub implements AuthModule {
  AuthModuleStub() {
    GetIt.I
        .registerFactory<SignInWithGoogle>(() => const SignInWithGoogleStub());
    GetIt.I.registerFactory<SignInWithApple>(() => const SignInWithAppleStub());
    GetIt.I.registerFactory<ConnectWithGoogle>(
        () => const ConnectWithGoogleStub());
    GetIt.I.registerFactory<SignInWithAuth0>(() => const SignInWithAuth0Stub());
    GetIt.I.registerSingleton<TokenManager>(TokenManagerStub());
    GetIt.I.registerFactory<OAuthController>(() => OAuthControllerStub());

    // note that we don't inject AuthContextManagerStub(), since its presence
    // will prevent data_context to load
  }
}
