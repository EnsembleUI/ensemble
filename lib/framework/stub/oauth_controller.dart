import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/stub/token_manager.dart';

abstract class OAuthController {
  Future<OAuthServiceToken?> authorize(String serviceId,
      {required String scope, bool forceNewTokens = false});
}

class OAuthControllerStub implements OAuthController {
  @override
  Future<OAuthServiceToken?> authorize(String serviceId,
      {required String scope, bool forceNewTokens = false}) {
    throw ConfigError("Auth module is not enabled.");
  }
}
