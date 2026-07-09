import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:ensemble_test_runner/mocks/test_logger.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/runner/test_runtime_state.dart';

class EnsembleTestContext {
  final EnsembleTestCase testCase;
  final TestApiProviderOverlay apiOverlay;
  final TestLogger logger;
  final EnsembleTestSetup setup;

  /// Runtime env overrides applied via [setEnv] steps.
  final Map<String, dynamic> envOverrides = {};

  final TestRuntimeState runtime = TestRuntimeState();

  EnsembleTestContext({
    required this.testCase,
    required this.apiOverlay,
    required this.logger,
    required this.setup,
  });

  factory EnsembleTestContext.fromTestCase(EnsembleTestCase testCase) {
    final logger = TestLogger();
    final mockApi = TestApiProviderOverlay(
      mocks: Map<String, MockAPIResponse>.from(testCase.mocks.apis),
    );

    final storage = testCase.initialState['storage'];
    final keychain = testCase.initialState['keychain'];
    final env = testCase.initialState['env'];

    final envMap =
        env is Map ? Map<String, dynamic>.from(env) : <String, dynamic>{};

    final setup = EnsembleTestSetup(
      envOverrides: envMap.isEmpty ? null : envMap,
      initialPublicStorage:
          storage is Map ? Map<String, dynamic>.from(storage) : null,
      initialKeychain:
          keychain is Map ? Map<String, dynamic>.from(keychain) : null,
    );

    final ctx = EnsembleTestContext(
      testCase: testCase,
      apiOverlay: mockApi,
      logger: logger,
      setup: setup,
    );
    ctx.envOverrides.addAll(envMap);
    return ctx;
  }

  void applyRuntimeEnv() {
    if (envOverrides.isEmpty) return;
    Ensemble().getConfig()?.updateEnvOverrides(envOverrides);
  }

  void setEnv(String key, dynamic value) {
    envOverrides[key] = value;
    applyRuntimeEnv();
  }

  void setStorage(String key, dynamic value) {
    StorageManager().write(key, value);
  }

  void removeStorage(String key) {
    StorageManager().remove(key);
  }

  Future<void> clearStorage() async {
    await StorageManager().clearPublicStorage();
  }

  MockAPIResponse mockFromStepArgs(Map<String, dynamic> args) {
    final response = args['response'];
    if (response is! Map) {
      throw EnsembleTestFailure('mockApi requires a "response" map');
    }
    return MockAPIResponse(
      statusCode: response['statusCode'] as int? ?? 200,
      body: response['body'],
      headers: response['headers'] is Map
          ? Map<String, dynamic>.from(response['headers'] as Map)
          : null,
      delayMs: args['delayMs'] as int?,
    );
  }
}
