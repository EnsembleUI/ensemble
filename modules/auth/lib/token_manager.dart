
import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/stub/oauth_controller.dart';
import 'package:ensemble/framework/stub/token_manager.dart';
import 'package:ensemble/framework/storage_manager.dart';

class TokenManagerImpl implements TokenManager {
  static final TokenManagerImpl _instance = TokenManagerImpl._internal();
  TokenManagerImpl._internal();
  factory TokenManagerImpl() {
    return _instance;
  }

  @override
  Future<void> updateServiceTokens(OAuthService serviceName, String accessToken,
      {String? refreshToken}) async {
    await StorageManager().writeSecurely(
        key: '${serviceName.name}_accessToken', value: accessToken);
    if (refreshToken != null) {
      await StorageManager().writeSecurely(
          key: '${serviceName.name}_refreshToken', value: refreshToken);
    }
  }

  @override
  Future<OAuthServiceToken?> getServiceTokens(OAuthService serviceName) async {
    String? accessToken = await StorageManager().readSecurely('${serviceName.name}_accessToken');
    if (accessToken != null) {
      return OAuthServiceToken(
          accessToken: accessToken,
          refreshToken: await StorageManager().readSecurely(
              '${serviceName.name}_refreshToken'));
    }
    return null;
  }
}