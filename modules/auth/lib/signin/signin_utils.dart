import 'package:ensemble/framework/stub/auth_context_manager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:yaml/yaml.dart';

class SignInUtils {
  /// convert a Google user account to our User
  static AuthenticatedUser fromGoogleUser(GoogleSignInAccount account,
          {SignInProvider? provider}) =>
      AuthenticatedUser(
          client: SignInClient.google,
          provider: provider,
          id: account.id,
          name: account.displayName,
          email: account.email,
          photo: account.photoUrl);

  static Future<String?> getAppIdFromYaml() async {
    final yamlString = await rootBundle.loadString('ensemble/ensemble-config.yaml');
    final YamlMap yamlMap = loadYaml(yamlString);
    return yamlMap['definitions']?['ensemble']?['appId'];
  }

  static bool areFirebaseOptionsEqual(FirebaseOptions a, FirebaseOptions b) {
    return a.apiKey == b.apiKey &&
      a.appId == b.appId && 
      a.messagingSenderId == b.messagingSenderId &&
      a.projectId == b.projectId;
  }

  /// Decides how custom-token sign-in should bind to Firebase.
  ///
  /// [ensembleAppId] is only a name for a new FirebaseApp. An app that native
  /// startup or Firestore already initialized does not need it.
  static FirebaseSignInPlan planFirebaseSignIn({
    required bool hasPlatformOptions,
    required bool hasMatchingInitializedApp,
    required bool hasAnyInitializedApp,
    required String? ensembleAppId,
  }) {
    if (hasPlatformOptions && hasMatchingInitializedApp) {
      return FirebaseSignInPlan.useExistingApp;
    }
    if (hasPlatformOptions &&
        ensembleAppId != null &&
        ensembleAppId.isNotEmpty) {
      return FirebaseSignInPlan.createNamedApp;
    }
    if (!hasPlatformOptions && hasAnyInitializedApp) {
      return FirebaseSignInPlan.useExistingApp;
    }
    return FirebaseSignInPlan.notConfigured;
  }
}

enum FirebaseSignInPlan {
  useExistingApp,
  createNamedApp,
  notConfigured,
}
