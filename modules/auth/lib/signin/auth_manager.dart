import 'dart:developer';
import 'dart:io';

import 'package:ensemble/action/invoke_api_action.dart';
import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/apiproviders/api_provider.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble/framework/stub/auth_context_manager.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_auth/signin/google_auth_manager.dart';
import 'package:ensemble_auth/signin/sign_in_with_server_api_action.dart';
import 'package:ensemble_auth/signin/signin_utils.dart';
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

  FirebaseApp? customFirebaseApp; // custom Firebase App

  /// Sign in with credentials from providers (e.g. Google, Apple) or via Firebase
  Future<String?> signInWithSocialCredential(BuildContext context,
      {required AuthenticatedUser user,
      required String idToken,
      AuthToken? token}) async {
    if (user.provider == null || user.provider == SignInProvider.local) {
      return _signInLocally(context, user: user);
    } else if (user.provider == SignInProvider.firebase) {
      return _signInWithFirebase(context, user: user, idToken: idToken);
    }
    // else if (user.provider == SignInProvider.auth0) {
    //   return _updateCurrentUser(context, user);
    // }
    return null;
  }

  /// After authenticated the user, redirect to a Server API with the idToken
  /// to retrieve Server-specific credentials (bearer, cookies,..). Once completed
  /// we sign the user in, and save the credentials to ${auth.user.data}
  Future<String?> signInWithServerCredential(BuildContext context,
      {required AuthenticatedUser user,
      required String idToken,
      required SignInWithServerAPIAction signInAPI}) async {
    Response? response = await InvokeAPIController().executeWithContext(
        context, signInAPI,
        additionalInputs: {'idToken': idToken, 'user': user});
    if (response != null) {
      // eval the server credentials and save to user object
      if (signInAPI.signInCredentials != null) {
        ScopeManager? scopeManager =
            ScreenController().getScopeManager(context);
        if (scopeManager != null) {
          ScopeManager tempScope =
              scopeManager.createChildScope(ephemeral: true);
          tempScope.dataContext
              .addDataContextById('response', APIResponse(response: response));

          Map credentials = {};
          signInAPI.signInCredentials!.forEach((key, value) {
            credentials[key] = tempScope.dataContext.eval(value);
          });
          user.setServerCredentials(credentials);
        }
      }
      return await _signInLocally(context, user: user);
    }
    return null;
  }

  Future<String?> signInAnonymously(
    BuildContext context,
  ) async {
    try {
      customFirebaseApp ??= await _initializeFirebaseSignIn();
      final _auth = FirebaseAuth.instanceFor(app: customFirebaseApp!);

      UserCredential userCredential = await _auth.signInAnonymously();
      User? user = userCredential.user;
      if (user == null) {
        print('Sign in anonymous failed');
        return null;
      }
      Future<void> updateCurrentUser(BuildContext context, User newUser) async {
        await StorageManager()
            .writeToSystemStorage(UserAuthentication._idKey, newUser.uid);
        await StorageManager()
            .writeToSystemStorage(UserAuthentication._isAnonymous, true);
      }

      updateCurrentUser(context, user);

      return userCredential.credential?.accessToken;
    } catch (e) {
      print(e.toString());
      return null;
    }
  }

  Future<String?> _signInLocally(BuildContext context,
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

    return token?.token;
  }

  Future<String?> _signInWithFirebase(BuildContext context,
      {required AuthenticatedUser user,
      required String idToken,
      AuthToken? token}) async {
    // initialize Firebase once
    customFirebaseApp ??= await _initializeFirebaseSignIn();

    final credential = _formatCredential(
        client: user.client, idToken: idToken, accessToken: token?.token);
    final UserCredential authResult =
        await FirebaseAuth.instanceFor(app: customFirebaseApp!)
            .signInWithCredential(credential);
    final User? firebaseUser = authResult.user;
    if (firebaseUser == null) {
      throw RuntimeError('Unable to Sign In');
    }

    _enrichUserFromFirebase(user: user, firebaseInfo: firebaseUser);
    await _updateCurrentUser(context, user);
    return await firebaseUser.getIdToken();
  }

  OAuthCredential _formatCredential(
      {SignInClient? client, required String idToken, String? accessToken}) {
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
    return await Firebase.initializeApp(
        name: 'customFirebase', options: options);
  }

  /// enrich the passed in User with information from Firebase
  void _enrichUserFromFirebase(
      {required AuthenticatedUser user, required User firebaseInfo}) {
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
      // } else if (user.provider == SignInProvider.auth0) {
      //   await Auth0CredentialsManager().signOut();
      } else {
        // If we don't use the provider, sign out with the signIn clients
        if (user.client == SignInClient.google) {
          // TODO: save the instance of recreate the Google Sign In
          //await GoogleSignIn().signOut();
        } else if (user.client == SignInClient.apple) {
          // there is no sign out for Apple
        } else if (user.client == SignInClient.microsoft) {}
      }

      // then remove user from storage
      await _clearCurrentUser(context);
    }
  }

  /// check if the user is current signed in or not.
  Future<bool> isSignedIn() {
    return getSignedInUser().then((user) => user != null);

    // AuthenticatedUser? user = getCurrentUser();
    // if (user != null) {
    //   // use the Provider to check sign in status
    //   if (user.provider == SignInProvider.firebase) {
    //     if (customFirebaseApp != null) {
    //       return Future.value(
    //           FirebaseAuth.instanceFor(app: customFirebaseApp!).currentUser !=
    //               null);
    //     }
    //   } else if (user.provider == SignInProvider.auth0) {
    //     return Future.value(Auth0CredentialsManager().hasCredentials());
    //   }
    //
    //   // fallback to using the client to check for status
    //   if (user.client == SignInClient.google) {
    //     return GoogleAuthManager().isSignedIn();
    //   } else if (user.client == SignInClient.apple) {
    //     // nothing to do
    //   } else if (user.client == SignInClient.microsoft) {
    //     // TODO
    //   }
    //
    //   // TODO: we have the current user in memory, does that mean signed in still?
    //   return Future.value(true);
    // }
    // return Future.value(false);
  }

  Future<AuthenticatedUser?> getSignedInUser() async {
    AuthenticatedUser? user = getCurrentUser();
    if (user != null) {
      if (user.client == SignInClient.google) {
        return _getSignedInUserFromGoogle(user.provider);
      }
    }
    return user;
  }

  Future<AuthenticatedUser?> _getSignedInUserFromGoogle(
      SignInProvider? provider) async {
    var account = await GoogleAuthManager().getSignedInUser();
    return account != null
        ? SignInUtils.fromGoogleUser(account, provider: provider)
        : null;
  }
}

mixin UserAuthentication {
  static const _clientKey = 'user.client';
  static const _providerKey = 'user.provider';
  static const _idKey = 'user.id';
  static const _nameKey = 'user.name';
  static const _emailKey = 'user.email';
  static const _photoKey = 'user.photo';
  static const _dataKey = 'user.data';

  static const _phoneNumberKey = 'user.phonenumber';
  static const _emailVerifiedKey = 'user.emailverified';
  static const _tenantIdKey = 'user.tenantId';
  static const _creationTimeKey = 'user.creationTime';
  static const _lastSignInTimeKey = 'user.lastSignInTime';
  static const _isAnonymous = 'user.isAnonymous';

  bool hasCurrentUser() => StorageManager().hasDataFromSystemStorage(_idKey);

  AuthenticatedUser? getCurrentUser() {
    if (hasCurrentUser()) {
      return AuthenticatedUser(
        client: SignInClient.values
            .from(StorageManager().readFromSystemStorage(_clientKey)),
        provider: SignInProvider.values
            .from(StorageManager().readFromSystemStorage(_providerKey)),
        id: StorageManager().readFromSystemStorage(_idKey),
        name: StorageManager().readFromSystemStorage(_nameKey),
        email: StorageManager().readFromSystemStorage(_emailKey),
        photo: StorageManager().readFromSystemStorage(_photoKey),
        data: StorageManager().readFromSystemStorage(_dataKey),
        phoneNumber: StorageManager().readFromSystemStorage(_phoneNumberKey),
        emailLVerified:
            StorageManager().readFromSystemStorage(_emailVerifiedKey),
        tenantId: StorageManager().readFromSystemStorage(_tenantIdKey),
        creationTime: StorageManager().readFromSystemStorage(_creationTimeKey),
        lastSignInTime:
            StorageManager().readFromSystemStorage(_lastSignInTimeKey),
        isAnonymous:
            StorageManager().readFromSystemStorage(_isAnonymous) ?? false,
      );
    }
    return null;
  }

  /// Replace the existing User with a brand new User.
  /// We try to minimize events dispatchers.
  /// TODO: refactor this to dispatch a single User object
  Future<void> _updateCurrentUser(
      BuildContext context, AuthenticatedUser newUser) async {
    await StorageManager().writeToSystemStorage(_idKey, newUser.id);
    await StorageManager()
        .writeToSystemStorage(_clientKey, newUser.client?.name);
    await StorageManager()
        .writeToSystemStorage(_providerKey, newUser.provider?.name);

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

    if (newUser.data != null) {
      await StorageManager().writeToSystemStorage(_dataKey, newUser.data);
      _dispatchUserField(context, 'data', newUser.data);
    } else {
      await StorageManager().removeFromSystemStorage(_dataKey);
      _dispatchUserField(context, 'data', null);
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

    await StorageManager().removeFromSystemStorage(_dataKey);
    _dispatchUserField(context, 'data', null);
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
      // 'isSignedIn': () => AuthManager().isSignedIn(),
      'signIn': _processSignInFromServer,
      'signOut': () => signOut(),
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

  /// this method is exposed to the main module
  @override
  Future<AuthenticatedUser?> getSignedInUser() {
    return AuthManager().getSignedInUser();
  }

  /// this method is exposed to the main module
  @override
  Future<void> signOut() {
    return AuthManager().signOut(Utils.globalAppKey.currentContext!);
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
