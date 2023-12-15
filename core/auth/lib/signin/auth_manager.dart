import 'dart:developer';
import 'dart:io';

import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble/framework/stub/auth_context_manager.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_auth/signin/widget/sign_in_with_auth0.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// This abstract out different method of Sign In (local, custom, Firebase, Auth0, ...)
class AuthManager with UserAuthentication {
  static final AuthManager _instance = AuthManager._internal();
  AuthManager._internal();
  factory AuthManager() {
    return _instance;
  }

  FirebaseApp? customFirebaseApp;   // custom Firebase App

  /// Sign in with credentials from providers (e.g. Google, Apple)
  Future<void> signInWithCredential(BuildContext context,
      {required AuthenticatedUser user,
      String? idToken, AuthToken? token}) async {

    if (idToken == null) {
      throw RuntimeError('ID Token is required for Sign In');
    }

    // sign in locally if a SignInProvider is not specified
    if (user.provider == null || user.provider == SignInProvider.local) {
      return _signInLocally(context, user: user);
    } else if (user.provider == SignInProvider.firebase) {
      return _signInWithFirebase(context, user: user, idToken: idToken);
    } else if (user.provider == SignInProvider.auth0) {

    }
    // do nothing if don't know the provider
  }

  Future<void> _signInLocally(BuildContext context,
      {required AuthenticatedUser user, AuthToken? token}) async {

    // update the current user
    await _updateCurrentUser(context, user);


    // TODO: think this through a bit
    // save the access token to storage. This will become
    // the bearer token to any API with serviceId = AuthProvider.id
    // if (token != null) {
    //   const FlutterSecureStorage().write(
    //       key: "${user.provider}_accessToken", value: token.token);
    // }
  }

  Future<void> _signInWithFirebase(BuildContext context,
      {required AuthenticatedUser user,
      required String idToken,
      AuthToken? token}) async {

    // initialize Firebase once
    customFirebaseApp ??= await _initializeFirebaseSignIn();

    final credential = _formatCredential(
        client: user.client,
        idToken: idToken,
        accessToken: token?.token);
    final UserCredential authResult =
        await FirebaseAuth.instanceFor(app: customFirebaseApp!)
            .signInWithCredential(credential);
    final User? firebaseUser = authResult.user;
    if (firebaseUser == null) {
      throw RuntimeError('Unable to Sign In');
    }

    _enrichUserFromFirebase(user: user, firebaseInfo: firebaseUser);
    await _updateCurrentUser(context, user);

  }

  OAuthCredential _formatCredential({SignInClient? client, required String idToken, String? accessToken}) {
    if (client == SignInClient.google) {
      return GoogleAuthProvider.credential(
          idToken: idToken, accessToken: accessToken);
    } else if (client == SignInClient.apple) {
      return OAuthProvider('apple.com').credential(idToken: idToken);
    }
    throw RuntimeError("Invalid Sign In Client");
  }

  Future<FirebaseApp> _initializeFirebaseSignIn() async {
    FirebaseOptions? options;
    if (kIsWeb) {
      options = Ensemble().getAccount()?.firebaseConfig?.webConfig;
    } else if (Platform.isIOS) {
      options = Ensemble().getAccount()?.firebaseConfig?.iOSConfig;
    } else if (Platform.isAndroid) {
      options = Ensemble().getAccount()?.firebaseConfig?.androidConfig;
    }
    if (options == null) {
      throw ConfigError('Firebase is not configured for this platform.');
    }
    return await Firebase.initializeApp(name: 'customFirebase', options: options);
  }

  /// enrich the passed in User with information from Firebase
  void _enrichUserFromFirebase({required AuthenticatedUser user, required User firebaseInfo}) {
    // update basic info if not already there
    user.name ??= firebaseInfo.displayName;
    user.email ??= firebaseInfo.email;
    user.photo ??= firebaseInfo.photoURL;

    // update new info from Firebase
    user.phoneNumber = firebaseInfo.phoneNumber;
    user.emailLVerified = firebaseInfo.emailVerified;
    user.tenantId = firebaseInfo.tenantId;
    user.creationTime = firebaseInfo.metadata.creationTime;
    user.lastSignInTime = firebaseInfo.metadata.lastSignInTime;
  }

  Future<void> signOut(BuildContext context) async {
    AuthenticatedUser? user = getCurrentUser();
    if (user != null) {

      // sign out with the Sign In Providers first
      if (user.provider == SignInProvider.firebase) {
        if (customFirebaseApp != null) {
          await FirebaseAuth.instanceFor(app: customFirebaseApp!).signOut();
        }
      } else if (user.provider == SignInProvider.auth0) {
        await Auth0CredentialsManager().signOut();
      } else {
        // If we don't use the provider, sign out with the signIn clients
        if (user.client == SignInClient.google) {
          // TODO: save the instance of recreate the Google Sign In
          //await GoogleSignIn().signOut();
        } else if (user.client == SignInClient.apple) {
          // there is no sign out for Apple
        } else if (user.client == SignInClient.microsoft) {

        }
      }

      // then remove user from storage
      await _clearCurrentUser(context);
    }
  }

  bool isSignedIn() {
    AuthenticatedUser? user = getCurrentUser();
    if (user != null) {

      // use the Provider to check sign in status
      if (user.provider == SignInProvider.firebase) {
        if (customFirebaseApp != null) {
          return FirebaseAuth.instanceFor(app: customFirebaseApp!).currentUser != null;
        }
      } else if (user.provider == SignInProvider.auth0) {
        return Auth0CredentialsManager().hasCredentials();
      }

      // fallback to using the client to check for status
      if (user.client == SignInClient.google) {
        return GoogleSignIn().currentUser != null;
      } else if (user.client == SignInClient.apple) {
        // nothing to do
      } else if (user.client == SignInClient.microsoft) {
        // TODO
      }

      // TODO: we have the current user in memory, does that mean signed in still?
      return true;
    }
    return false;
  }
}

mixin UserAuthentication {
  static const _clientKey = 'user.client';
  static const _providerKey = 'user.provider';
  static const _idKey = 'user.id';
  static const _nameKey = 'user.name';
  static const _emailKey = 'user.email';
  static const _photoKey = 'user.photo';

  static const _phoneNumberKey = 'user.phonenumber';
  static const _emailVerifiedKey = 'user.emailverified';
  static const _tenantIdKey = 'user.tenantId';
  static const _creationTimeKey = 'user.creationTime';
  static const _lastSignInTimeKey = 'user.lastSignInTime';

  bool hasCurrentUser() => StorageManager().hasDataFromSystemStorage(_idKey);

  AuthenticatedUser? getCurrentUser() {
    if (hasCurrentUser()) {
      return AuthenticatedUser(
          client: SignInClient.values.from(
              StorageManager().readFromSystemStorage(_clientKey)),
          provider: SignInProvider.values.from(
              StorageManager().readFromSystemStorage(_providerKey)),
          id: StorageManager().readFromSystemStorage(_idKey),
          name: StorageManager().readFromSystemStorage(_nameKey),
          email: StorageManager().readFromSystemStorage(_emailKey),
          photo: StorageManager().readFromSystemStorage(_photoKey),

          phoneNumber: StorageManager().readFromSystemStorage(_phoneNumberKey),
          emailLVerified: StorageManager().readFromSystemStorage(_emailVerifiedKey),
          tenantId: StorageManager().readFromSystemStorage(_tenantIdKey),
          creationTime: StorageManager().readFromSystemStorage(_creationTimeKey),
          lastSignInTime: StorageManager().readFromSystemStorage(_lastSignInTimeKey),
      );
    }
    return null;
  }


  /// Replace the existing User with a brand new User.
  /// We try to minimize events dispatchers.
  /// TODO: refactor this to dispatch a single User object
  Future<void> _updateCurrentUser(BuildContext context, AuthenticatedUser newUser) async {
    await StorageManager().writeToSystemStorage(_idKey, newUser.id);
    await StorageManager().writeToSystemStorage(_clientKey, newUser.client?.name);
    await StorageManager().writeToSystemStorage(_providerKey, newUser.provider?.name);

    if (newUser.name != null) {
      await StorageManager().writeToSystemStorage(_nameKey, newUser.name);
      _dispatchUserField(context, 'name', newUser.name);
    } else {
      await StorageManager().removeFromSystemStorage(_nameKey);
      _dispatchUserField(context, 'name', null);
    }

    if (newUser.email != null) {
      await StorageManager().writeToSystemStorage(_emailKey, newUser.email);
      _dispatchUserField(context, 'email', newUser.email);
    } else {
      await StorageManager().removeFromSystemStorage(_emailKey);
      _dispatchUserField(context, 'email', null);
    }

    if (newUser.photo != null) {
      await StorageManager().writeToSystemStorage(_photoKey, newUser.photo);
      _dispatchUserField(context, 'photo', newUser.photo);
    } else {
      await StorageManager().removeFromSystemStorage(_photoKey);
      _dispatchUserField(context, 'photo', null);
    }
  }

  Future<void> _clearCurrentUser(BuildContext context) async {
    await StorageManager().removeFromSystemStorage(_idKey);
    await StorageManager().removeFromSystemStorage(_clientKey);
    await StorageManager().removeFromSystemStorage(_providerKey);

    await StorageManager().removeFromSystemStorage(_nameKey);
    _dispatchUserField(context, 'name', null);

    await StorageManager().removeFromSystemStorage(_emailKey);
    _dispatchUserField(context, 'email', null);

    await StorageManager().removeFromSystemStorage(_photoKey);
    _dispatchUserField(context, 'photo', null);
  }

  void _dispatchUserField(BuildContext context, String key, dynamic value) {
    ScreenController().dispatchSystemStorageChanges(context, key, value,
        storagePrefix: 'user');
  }


}

/// publicly exposed as Context
class AuthContextManagerImpl with Invokable implements AuthContextManager {

  @override
  Map<String, Function> getters() {
    return {
      'user': () => AuthManager().getCurrentUser(),
    };
  }

  @override
  Map<String, Function> methods() {
    return {
      'isSignedIn': () => AuthManager().isSignedIn(),
      'signIn': _processSignInFromServer,
      'signOut': () => AuthManager().signOut(Utils.globalAppKey.currentContext!),
    };
  }

  // this SignIn is using a Server SignInProvider
  void _processSignInFromServer(dynamic inputs) {
    // TODO Think this through, this is doing the Sign in on the server-side.
    // Server should be sending back:
    // 1. a token that we can append to every server call to tell the server
    // who this person is
    // 2. Basic user information so we can display and bind to. (technically
    // we don't need any but it'll be more consistent with other providers)

  }

  @override
  Map<String, Function> setters() {
    return {};
  }
}


class AuthToken {
  AuthToken({required this.tokenType, required this.token});

  TokenType tokenType;
  String token;
}

enum TokenType {
  token, // Authorization: <token>
  bearerToken // Authorization: Bearer <token>
}



/// populate when a user is authenticated by one of the SignIn client.
/// if using Firebase provider, we'll inject more information in.
class AuthenticatedUser with Invokable {
  AuthenticatedUser({this.client, this.provider, required this.id, this.name,
    this.email, this.photo, this.phoneNumber, this.emailLVerified,
    this.tenantId, this.creationTime, this.lastSignInTime});

  final SignInClient? client;
  SignInProvider? provider;

  // basic info provided by the sign in clients
  String? id;
  String? name;
  String? email;
  String? photo;

  // extra info provided if use Firebase
  String? phoneNumber;
  bool? emailLVerified;
  String? tenantId;
  DateTime? creationTime;
  DateTime? lastSignInTime;


  @override
  Map<String, Function> getters() {
    return {
      'client': () => client?.name,
      'provider': () => provider?.name,
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

enum SignInClient {
  google,
  apple,
  microsoft,
  auth0
}

enum SignInProvider {
  local, // store the login state locally on the client
  server, // login on the server. Client will trigger onAuthenticated but not onSignedIn
  firebase,
  auth0
}
