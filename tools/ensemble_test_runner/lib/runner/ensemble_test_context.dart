import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:ensemble_test_runner/mocks/test_logger.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/runner/test_runtime_state.dart';
import 'package:flutter/widgets.dart';

class EnsembleTestContext {
  final EnsembleTestCase testCase;
  final EnsembleTestConfig config;
  final TestApiProviderOverlay apiOverlay;
  final TestLogger logger;
  final EnsembleTestSetup setup;

  /// Runtime env overrides applied via [setEnv] steps.
  final Map<String, dynamic> envOverrides = {};

  final TestRuntimeState runtime = TestRuntimeState();

  EnsembleTestContext({
    required this.testCase,
    this.config = const EnsembleTestConfig(),
    required this.apiOverlay,
    required this.logger,
    required this.setup,
  });

  factory EnsembleTestContext.fromTestCase(
    EnsembleTestCase testCase, {
    EnsembleTestConfig config = const EnsembleTestConfig(),
  }) {
    final logger = TestLogger();
    final apiOverlay = TestApiProviderOverlay(
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
      config: config,
      apiOverlay: apiOverlay,
      logger: logger,
      setup: setup,
    );
    ctx.envOverrides.addAll(envMap);
    ctx.runtime.locale = _localeFromEnv(envMap['APP_LOCALE']);
    return ctx;
  }

  static Locale? _localeFromEnv(dynamic value) {
    final locale = value?.toString();
    if (locale == null || locale.isEmpty) return null;
    final normalized = locale.replaceAll('-', '_');
    final parts = normalized.split('_');
    final languageCode = parts.first;
    if (languageCode.isEmpty) return null;
    return Locale(languageCode, parts.length > 1 ? parts[1] : null);
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
}
