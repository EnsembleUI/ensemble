import 'package:ensemble_test_runner/mocks/firebase_auth_test_setup.dart';
import 'package:ensemble_test_runner/mocks/firebase_firestore_test_setup.dart';
import 'package:ensemble_test_runner/mocks/firebase_functions_test_setup.dart';
import 'package:ensemble_test_runner/mocks/live_sign_in_with_custom_token.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';

bool _firebaseCoreMocksInstalled = false;

final Map<String, String> firebaseProjectIdsByApp = {};

/// Preserves [CoreFirebaseOptions] from [Firebase.initializeApp] instead of
/// the stock mock that always returns projectId `123`.
class _PreservingFirebaseCoreHostApi implements TestFirebaseCoreHostApi {
  @override
  Future<CoreInitializeResponse> initializeApp(
    String appName,
    CoreFirebaseOptions initializeAppRequest,
  ) async {
    firebaseProjectIdsByApp[appName] = initializeAppRequest.projectId;
    return CoreInitializeResponse(
      name: appName,
      options: initializeAppRequest,
      pluginConstants: {},
    );
  }

  @override
  Future<List<CoreInitializeResponse>> initializeCore() async {
    return [
      CoreInitializeResponse(
        name: defaultFirebaseAppName,
        options: CoreFirebaseOptions(
          apiKey: 'test-api-key',
          projectId: 'test-project',
          appId: 'test-app-id',
          messagingSenderId: 'test-sender',
        ),
        pluginConstants: {},
      ),
    ];
  }

  @override
  Future<CoreFirebaseOptions> optionsFromResource() async {
    return CoreFirebaseOptions(
      apiKey: 'test-api-key',
      projectId: 'test-project',
      appId: 'test-app-id',
      messagingSenderId: 'test-sender',
    );
  }
}

/// Installs Firebase Core platform mocks so [Firebase.initializeApp] works under
/// [flutter test] (no native Firebase host). Required before app bootstrap.
void ensureFirebaseCoreMocksForTest() {
  if (_firebaseCoreMocksInstalled) return;
  TestFirebaseCoreHostApi.setUp(_PreservingFirebaseCoreHostApi());
  ensureLiveCloudFunctionsForTest();
  ensureLiveFirebaseAuthForTest();
  ensureLiveFirestoreForTest();
  _firebaseCoreMocksInstalled = true;
}

/// Call after app module bootstrap so [signInWithCustomToken] uses live Firebase.
void ensureLiveAuthActionsForTest() {
  ensureLiveSignInWithCustomTokenForTest();
}
