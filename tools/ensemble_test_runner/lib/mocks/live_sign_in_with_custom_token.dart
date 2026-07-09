import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/apiproviders/firebase_functions/firebase_functions_api_provider.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble/framework/stub/auth_context_manager.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/widget/stub_widgets.dart';
import 'package:ensemble_test_runner/mocks/firebase_auth_test_setup.dart';
import 'package:ensemble_test_runner/mocks/live_firebase_auth_http.dart';
import 'package:ensemble_test_runner/runner/live_async_call.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

/// Signs in with a Firebase custom token via the real Identity Toolkit REST API.
///
/// HTTP runs through [LiveAsyncCallSupport] (same [WidgetTester.runAsync] queue
/// as live [invokeAPI] calls) because direct sockets from action callbacks fail
/// under [flutter test].
class LiveSignInWithCustomToken implements SignInWithCustomToken {
  @override
  Future<void> signInWithCustomToken(
    BuildContext context, {
    required SignInWithCustomTokenAction action,
  }) async {
    try {
      final token = _evaluatedToken(context, action.jwtToken);
      if (token.isEmpty) {
        throw LanguageError(
          "signInWithCustomToken requires jwtToken as 'token' parameter.",
          recovery:
              "Fix: pass valid jwtToken as 'token' under signInWithCustomToken",
        );
      }

      final appName = _resolveAppName();
      final apiKey = _resolveApiKey();
      final authBody = await _signInOverHttp(token: token, apiKey: apiKey);

      final idToken = authBody['idToken']?.toString();
      final refreshToken = authBody['refreshToken']?.toString();
      final localId = uidFromFirebaseAuthResponse(authBody);
      if (idToken == null || localId == null || refreshToken == null) {
        throw StateError(
          'Firebase signInWithCustomToken response missing tokens '
          '(keys: ${authBody.keys.toList()}).',
        );
      }

      final expiresInSec =
          int.tryParse(authBody['expiresIn']?.toString() ?? '') ?? 3600;
      recordLiveAuthSession(
        appName: appName,
        idToken: idToken,
        refreshToken: refreshToken,
        uid: localId,
        expiresAtMs: DateTime.now()
            .add(Duration(seconds: expiresInSec))
            .millisecondsSinceEpoch,
        email: authBody['email']?.toString(),
        isEmailVerified: authBody['emailVerified'] == true,
      );

      await StorageManager().writeToSystemStorage('user.id', localId);
      await StorageManager().writeToSystemStorage('user.isAnonymous', false);

      if (action.onAuthenticated != null) {
        final user = AuthenticatedUser(
          provider: SignInProvider.firebase,
          id: localId,
        );
        ScreenController().executeAction(
          context,
          action.onAuthenticated!,
          event: EnsembleEvent(
            null,
            data: {'user': user, 'idToken': idToken},
          ),
        );
      }
    } catch (error) {
      if (action.onError != null) {
        ScreenController().executeAction(
          context,
          action.onError!,
          event: EnsembleEvent(
            null,
            error: {'error': _redactSecrets(error.toString())},
          ),
        );
      }
    }
  }

  /// Avoid dumping JWTs / refresh tokens into test logs via onError.
  static String _redactSecrets(String message) {
    return message
        .replaceAllMapped(
          RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'),
          (_) => '[redacted-jwt]',
        )
        .replaceAllMapped(
          RegExp(r'(refreshToken|idToken|accessToken|token)["\s:=]+[^\s,"}]+',
              caseSensitive: false),
          (match) => '${match.group(1)}=[redacted]',
        );
  }

  Future<Map<String, dynamic>> _signInOverHttp({
    required String token,
    required String apiKey,
  }) async {
    final result = await LiveAsyncCallSupport.run(
      () => postIdentityToolkitSignInWithCustomToken(
        customToken: token,
        apiKey: apiKey,
      ),
    );
    if (result == null) {
      throw StateError(
        'Firebase signInWithCustomToken did not complete under runAsync.',
      );
    }
    return result;
  }

  String _evaluatedToken(BuildContext context, String? jwtToken) {
    var token = jwtToken ?? '';
    final scopeManager = ScreenController().getScopeManager(context);
    if (scopeManager != null) {
      token = scopeManager.dataContext.eval(token)?.toString() ?? token;
    }
    return token;
  }

  String _resolveApiKey() {
    final apiKey = _resolveFirebaseApp().options.apiKey;
    if (apiKey.isEmpty) {
      throw ConfigError('Firebase apiKey is missing for live auth sign-in.');
    }
    return apiKey;
  }

  String _resolveAppName() {
    try {
      return _resolveFirebaseApp().name;
    } catch (_) {
      return defaultFirebaseAppName;
    }
  }

  FirebaseApp _resolveFirebaseApp() {
    final functionsApp = FirebaseFunctionsAPIProvider.getFirebaseAppContext();
    if (functionsApp != null) {
      return functionsApp;
    }
    if (Firebase.apps.isNotEmpty) {
      return Firebase.apps.first;
    }
    throw ConfigError(
      'No Firebase app is initialized for live auth sign-in.',
    );
  }
}

/// Registers [LiveSignInWithCustomToken] so YAML `signInWithCustomToken`
/// actions use the real Identity Toolkit API during tests.
void ensureLiveSignInWithCustomTokenForTest() {
  if (!GetIt.I.isRegistered<SignInWithCustomToken>()) {
    GetIt.I.registerFactory<SignInWithCustomToken>(
      () => LiveSignInWithCustomToken(),
    );
    return;
  }
  GetIt.I.unregister<SignInWithCustomToken>();
  GetIt.I.registerFactory<SignInWithCustomToken>(
    () => LiveSignInWithCustomToken(),
  );
}
