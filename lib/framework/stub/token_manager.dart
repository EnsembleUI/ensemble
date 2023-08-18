import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/stub/oauth_controller.dart';

abstract class TokenManager {
  Future<OAuthServiceToken?> getServiceTokens(OAuthService serviceName);
  Future<void> updateServiceTokens(OAuthService serviceName, String accessToken,
      {String? refreshToken});
}

class TokenManagerStub implements TokenManager {
  @override
  Future<OAuthServiceToken?> getServiceTokens(OAuthService serviceName) {
    throw ConfigError('Auth module is not enabled.');
  }

  @override
  Future<void> updateServiceTokens(OAuthService serviceName, String accessToken,
      {String? refreshToken}) {
    throw ConfigError('Auth module is not enabled.');
  }
}

class OAuthServiceToken {
  OAuthServiceToken({this.accessToken, this.refreshToken});
  String? accessToken;
  String? refreshToken;
}
