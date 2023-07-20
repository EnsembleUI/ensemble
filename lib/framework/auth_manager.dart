import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';


class AuthManager {
  static final AuthManager _instance = AuthManager._internal();
  AuthManager._internal();
  factory AuthManager() {
    return _instance;
  }



  Future<void> signIn(BuildContext context, {required AuthenticatedUser user, AuthToken? token}) async {

    // update the user information in storage
    await StorageManager().updateAuthenticatedUser(context, user: user);

    // TODO: think this through a bit
    // save the access token to storage. This will become
    // the bearer token to any API with serviceId = AuthProvider.id
    // if (token != null) {
    //   const FlutterSecureStorage().write(
    //       key: "${user.provider}_accessToken", value: token.token);
    // }


  }

  Future<void> signOut(BuildContext context) async {
    await StorageManager().clearAuthenticatedUser(context);
  }

  bool isSignedIn(BuildContext context) {
    return StorageManager().hasAuthenticatedUser();
  }


}

/// publicly exposed as Context
class AuthContextManager with Invokable {
  final BuildContext _buildContext;
  AuthContextManager(this._buildContext);

  @override
  Map<String, Function> getters() {
    return {
      'user': () => StorageManager().getAuthenticatedUser(),
    };
  }

  @override
  Map<String, Function> methods() {
    return {
      'isSignedIn': () => AuthManager().isSignedIn(_buildContext),
      'signIn': _processSignIn,
      'signOut': () => AuthManager().signOut(_buildContext),
    };
  }

  void _processSignIn(dynamic inputs) {
    Map? inputMap = Utils.getMap(inputs);
    if (inputMap != null) {
      
      // AuthManager().signIn(_buildContext, user: AuthenticatedUser(
      //     provider: AuthProvider.custom,
      //     id: Utils.optionalString(inputMap['id']),
      //     name: Utils.optionalString(inputMap['name']),
      //     email: Utils.optionalString(inputMap['email']),
      //     photo: Utils.optionalString(inputMap['photo'])),
      //   token: AuthToken(tokenType: TokenType.token, token: token)
      //
      // );
    }


    //AuthManager().signIn(_buildContext, user: user)

  }

  @override
  Map<String, Function> setters() {
    return {};
  }

}

/// when a User is authenticated by one of the providers
class AuthenticatedUser with Invokable {
  AuthenticatedUser({required provider, required this.id, this.name, this.email, this.photo}) : _provider = provider;

  final AuthProvider _provider;
  String get provider => _provider.name;

  String? id;
  String? name;
  String? email;
  String? photo;

  @override
  Map<String, Function> getters() {
    return {
      'provider': () => provider,
      'id': () => id,
      'name': () => name,
      'email': () => email,
      'photo': () => photo
    };
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {};
  }
}

enum AuthProvider {
  google, apple, microsoft, custom
}

class AuthToken {
  AuthToken({required this.tokenType, required this.token});
  TokenType tokenType;
  String token;
}

enum TokenType {
  token,          // Authorization: <token>
  bearerToken     // Authorization: Bearer <token>
}