import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/placeholder/token_manager.dart';

abstract class OAuthControllerBase {
  Future<OAuthServiceToken?> authorize(String serviceId,
      {required String scope, bool forceNewTokens = false});
}

class OAuthControllerStub implements OAuthControllerBase {
  @override
  Future<OAuthServiceToken?> authorize(String serviceId, {required String scope, bool forceNewTokens = false}) {
    throw ConfigError("Auth module is not enabled.");
  }

}