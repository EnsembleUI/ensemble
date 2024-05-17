import 'dart:developer';
import 'dart:io';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/stub/auth_context_manager.dart';
import 'package:ensemble/framework/stub/oauth_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

typedef GoogleSignInAccountCallback = void Function(
    GoogleSignInAccount? account);

/// Managing Google Sign in
class GoogleAuthManager {
  static final GoogleAuthManager _instance = GoogleAuthManager._internal();

  GoogleAuthManager._internal();

  factory GoogleAuthManager() {
    return _instance;
  }

  GoogleSignIn? _googleSignIn;

  Future<void> registerSignInListener(
      {List<String>? scopes,
      required GoogleSignInAccountCallback onAccountChanged}) async {
    // sign out (authorized scopes are still remembered the next sign in)
    if (_googleSignIn != null) {
      await _googleSignIn?.signOut();
    }

    // create a new instance and listen to account changes
    _googleSignIn = GoogleSignIn(
        clientId: _getClientId(),
        serverClientId: _getServerClientId(),
        scopes: scopes ?? []);
    _googleSignIn?.onCurrentUserChanged
        .listen((account) => onAccountChanged(account));
  }

  Future<GoogleSignInAccount?> signIn() async {
    if (kIsWeb) {
      return await _googleSignIn?.signInSilently();
    } else {
      return await _googleSignIn?.signIn();
    }
  }

  Future<bool>? canAccessScopes(List<String> scopes) =>
      _googleSignIn?.canAccessScopes(scopes);

  /// return the account currently signed in
  Future<GoogleSignInAccount?> getSignedInUser() {
    if (_googleSignIn != null) {
      return Future.value(_googleSignIn!.currentUser);
    }
    // the app starts up we don't have _googleSignIn yet, so attempt to silently
    // sign in if the underlying platform still remember the last sign in
    try {
      return GoogleSignIn()
          .signInSilently(suppressErrors: true)
          .then((account) => account);
    } catch (error) {
      return Future.value(null);
    }
  }

  /// retrieve the clientId from configuration
  String _getClientId() {
    SignInCredential? credential =
        Ensemble().getSignInServices()?.signInCredentials?[OAuthService.google];
    String? clientId;
    if (kIsWeb) {
      clientId = credential?.webClientId;
    } else if (Platform.isAndroid) {
      clientId = credential?.androidClientId;
    } else if (Platform.isIOS) {
      clientId = credential?.iOSClientId;
    }
    if (clientId != null) {
      return clientId;
    }
    throw LanguageError("Google SignIn provider is required.",
        recovery: "Please check your configuration.");
  }

  /// serverClientId is not supported on Web
  String? _getServerClientId() => kIsWeb
      ? null
      : Ensemble()
          .getSignInServices()
          ?.signInCredentials?[OAuthService.google]
          ?.serverClientId;
}
