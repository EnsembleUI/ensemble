
import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/error_handling.dart';

abstract class TokenManagerBase {
  Future<OAuthServiceToken?> getServiceTokens(ServiceName serviceName);
  Future<void> updateServiceTokens(ServiceName serviceName, String accessToken,
      {String? refreshToken});
}

class TokenManagerStub implements TokenManagerBase {
  @override
  Future<OAuthServiceToken?> getServiceTokens(ServiceName serviceName) {
    throw ConfigError('Auth module is not enabled.');
  }
  @override
  Future<void> updateServiceTokens(ServiceName serviceName, String accessToken, {String? refreshToken}) {
    throw ConfigError('Auth module is not enabled.');
  }
}

class OAuthServiceToken {
  OAuthServiceToken({required this.accessToken, this.refreshToken});
  String accessToken;
  String? refreshToken;
}
