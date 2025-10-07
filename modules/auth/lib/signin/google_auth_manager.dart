import 'dart:io';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/error_handling.dart';
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

  bool _isInitialized = false;

  Future<void> registerSignInListener(
      {List<String>? scopes,
      required GoogleSignInAccountCallback onAccountChanged}) async {
    // sign out (authorized scopes are still remembered the next sign in)
    if (_isInitialized) {
      await GoogleSignIn.instance.signOut();
    }

    // create a new instance and listen to account changes
    await GoogleSignIn.instance.initialize(
      clientId: _getClientId(),
      serverClientId: _getServerClientId(),
    );
    _isInitialized = true;

    GoogleSignIn.instance.authenticationEvents.listen((event) {
      if (event is GoogleSignInAuthenticationEventSignIn) {
        onAccountChanged(event.user);
      } else if (event is GoogleSignInAuthenticationEventSignOut) {
        onAccountChanged(null);
      }
    });
  }

  Future<GoogleSignInAccount?> signIn() async {
    if (!_isInitialized) {
      await GoogleSignIn.instance.initialize(
        clientId: _getClientId(),
        serverClientId: _getServerClientId(),
      );
      _isInitialized = true;
    }

    if (kIsWeb) {
      return await GoogleSignIn.instance.attemptLightweightAuthentication();
    } else {
      return await GoogleSignIn.instance.authenticate();
    }
  }

  /// return the account currently signed in
  Future<GoogleSignInAccount?> getSignedInUser() async {
    if (!_isInitialized) {
      await GoogleSignIn.instance.initialize(
        clientId: _getClientId(),
        serverClientId: _getServerClientId(),
      );
      _isInitialized = true;
    }

    // get the current user via lightweight authentication
    try {
      return await GoogleSignIn.instance.attemptLightweightAuthentication();
    } catch (error) {
      return null;
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
