import 'package:ensemble_auth/signin/signin_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reuses a Firebase app that already matches platform options', () {
    expect(
      SignInUtils.planFirebaseSignIn(
        hasPlatformOptions: true,
        hasMatchingInitializedApp: true,
        hasAnyInitializedApp: true,
        ensembleAppId: null,
      ),
      FirebaseSignInPlan.useExistingApp,
    );
  });

  test('reuses an already initialized app when account options are missing',
      () {
    expect(
      SignInUtils.planFirebaseSignIn(
        hasPlatformOptions: false,
        hasMatchingInitializedApp: false,
        hasAnyInitializedApp: true,
        ensembleAppId: '089MF0tt1eMCu4U4Fa0u',
      ),
      FirebaseSignInPlan.useExistingApp,
    );
  });

  test('creates a named app only when nothing initialized matches', () {
    expect(
      SignInUtils.planFirebaseSignIn(
        hasPlatformOptions: true,
        hasMatchingInitializedApp: false,
        hasAnyInitializedApp: false,
        ensembleAppId: '089MF0tt1eMCu4U4Fa0u',
      ),
      FirebaseSignInPlan.createNamedApp,
    );
  });

  test('stays unconfigured when there is no app and no platform options', () {
    expect(
      SignInUtils.planFirebaseSignIn(
        hasPlatformOptions: false,
        hasMatchingInitializedApp: false,
        hasAnyInitializedApp: false,
        ensembleAppId: null,
      ),
      FirebaseSignInPlan.notConfigured,
    );
  });
}
