import 'package:ensemble_test_runner/mocks/firebase_auth_test_setup.dart';
import 'package:ensemble_test_runner/mocks/firebase_firestore_test_setup.dart';
import 'package:ensemble_test_runner/mocks/firebase_functions_test_setup.dart';
import 'package:ensemble_test_runner/mocks/firebase_remote_config_test_setup.dart';
import 'package:ensemble_test_runner/mocks/live_sign_in_with_custom_token.dart';
import 'package:ensemble/framework/logging/log_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:get_it/get_it.dart';

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

/// Installs Firebase Core platform mocks so `Firebase.initializeApp` works under
/// `flutter test` (no native Firebase host). Required before app bootstrap.
void ensureFirebaseCoreMocksForTest() {
  if (_firebaseCoreMocksInstalled) return;
  TestFirebaseCoreHostApi.setUp(_PreservingFirebaseCoreHostApi());
  ensureLiveCloudFunctionsForTest();
  ensureLiveFirebaseAuthForTest();
  ensureLiveFirestoreForTest();
  ensureRemoteConfigForTest();
  _firebaseCoreMocksInstalled = true;
}

/// Call after app module bootstrap so `signInWithCustomToken` uses live Firebase.
void ensureLiveAuthActionsForTest() {
  ensureLiveSignInWithCustomTokenForTest();
}

/// Replaces the application's analytics provider with a no-op widget-test
/// provider after app module bootstrap and before test screens are launched.
void ensureTestAnalyticsProvider() {
  // App module bootstraps register their production analytics provider before
  // this hook. Widget tests have no native analytics host and use simulated
  // Firebase app IDs, so replace it at the runner boundary before the app is
  // launched. This keeps test-only analytics configuration out of app code.
  if (GetIt.I.isRegistered<LogProvider>()) {
    GetIt.I.unregister<LogProvider>();
  }
  GetIt.I.registerSingleton<LogProvider>(_TestLogProvider());
}

class _TestLogProvider extends LogProvider {
  @override
  Future<void> init({
    Map? options,
    String? ensembleAppId,
    bool shouldAwait = false,
  }) async {}

  @override
  Future<void> log(Map<String, dynamic> config) async {}
}
