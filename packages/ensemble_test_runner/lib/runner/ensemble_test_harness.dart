import 'dart:async';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/ensemble_app.dart';
import 'package:ensemble/framework/apiproviders/http_api_provider.dart';
import 'package:ensemble/framework/definition_providers/local_provider.dart';
import 'package:ensemble/framework/screen_tracker.dart';
import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble_test_runner/mocks/mock_api_provider.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/yaml_test_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Per-test bootstrap data applied before the widget tree mounts.
class EnsembleTestSetup {
  final Map<String, dynamic>? envOverrides;
  final Map<String, dynamic>? initialPublicStorage;

  const EnsembleTestSetup({
    this.envOverrides,
    this.initialPublicStorage,
  });
}

void applyYamlTestBootstrap(EnsembleConfig config, EnsembleTestSetup setup) {
  if (setup.envOverrides != null && setup.envOverrides!.isNotEmpty) {
    config.updateEnvOverrides(setup.envOverrides!);
  }
  setup.initialPublicStorage?.forEach((key, value) {
    StorageManager().write(key, value);
  });
}

/// Boots the real Ensemble runtime for widget tests.
class EnsembleTestHarness {
  static void ensureTestPlugins() {
    TestWidgetsFlutterBinding.ensureInitialized();
    const pathProviderChannel =
        MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      switch (call.method) {
        case 'getApplicationDocumentsDirectory':
        case 'getTemporaryDirectory':
        case 'getApplicationSupportDirectory':
          return '.';
        default:
          return null;
      }
    });

    const packageInfoChannel =
        MethodChannel('dev.fluttercommunity.plus/package_info');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(packageInfoChannel, (call) async {
      if (call.method == 'getAll') {
        return {
          'appName': 'EnsembleTest',
          'packageName': 'com.ensemble.test',
          'version': '1.0.0',
          'buildNumber': '1',
        };
      }
      return null;
    });

    final secureStorage = <String, String>{};
    const secureStorageChannel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
      final args = Map<String, Object?>.from(call.arguments as Map? ?? {});
      final key = args['key']?.toString();
      switch (call.method) {
        case 'write':
          if (key != null) {
            secureStorage[key] = args['value']?.toString() ?? '';
          }
          return null;
        case 'read':
          return key == null ? null : secureStorage[key];
        case 'readAll':
          return Map<String, String>.from(secureStorage);
        case 'delete':
          if (key != null) secureStorage.remove(key);
          return null;
        case 'deleteAll':
          secureStorage.clear();
          return null;
        case 'containsKey':
          return key != null && secureStorage.containsKey(key);
        default:
          return null;
      }
    });

    const deviceInfoChannel =
        MethodChannel('dev.fluttercommunity.plus/device_info');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(deviceInfoChannel, (call) async {
      if (call.method == 'getDeviceInfo') {
        return {
          'computerName': 'Ensemble Test',
          'hostName': 'ensemble-test',
          'arch': 'arm64',
          'model': 'Mac',
          'kernelVersion': 'test',
          'osRelease': 'test',
          'majorVersion': 15,
          'minorVersion': 0,
          'patchVersion': 0,
          'activeCPUs': 8,
          'memorySize': 8589934592,
          'cpuFrequency': 0,
          'systemGUID': 'ensemble-test-device',
        };
      }
      return null;
    });

    const connectivityChannel =
        MethodChannel('dev.fluttercommunity.plus/connectivity');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(connectivityChannel, (call) async {
      if (call.method == 'check') {
        return ['wifi'];
      }
      return null;
    });

    const connectivityStatusChannel =
        MethodChannel('dev.fluttercommunity.plus/connectivity_status');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(connectivityStatusChannel, (call) async {
      switch (call.method) {
        case 'listen':
        case 'cancel':
          return null;
        default:
          return null;
      }
    });

    const appLinksEventsChannel =
        MethodChannel('com.llfbandit.app_links/events');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(appLinksEventsChannel, (call) async {
      switch (call.method) {
        case 'listen':
        case 'cancel':
          return null;
        default:
          return null;
      }
    });

    const workmanagerChannel = MethodChannel(
        'be.tramckrijte.workmanager/foreground_channel_work_manager');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(workmanagerChannel, (call) async {
      switch (call.method) {
        case 'initialize':
          return true;
        default:
          return null;
      }
    });

    YamlTestSession.navigationFlow.startListening();
  }

  final String appPath;
  final String appHome;
  final String? i18nPath;

  EnsembleTestHarness({
    required this.appPath,
    required this.appHome,
    this.i18nPath,
  });

  static String normalizeAppPath(String path) {
    if (path.endsWith('/')) return path;
    return '$path/';
  }

  Future<EnsembleConfig> buildConfig({Locale? forcedLocale}) async {
    final normalized = normalizeAppPath(appPath);
    final i18n = I18nProps(i18nPath ?? '${normalized}translations');

    final provider = await LocalDefinitionProvider(
      normalized,
      appHome,
      i18nProps: i18n,
      initialForcedLocale: forcedLocale,
    ).init();

    final config = EnsembleConfig(definitionProvider: provider);
    final updated = await config.updateAppBundle();
    return updated;
  }

  static void installHttpMockProvider(
    EnsembleConfig config,
    MockAPIProvider mock,
  ) {
    config.apiProviders = {
      ...?config.apiProviders,
      'http': mock,
    };
  }

  Future<EnsembleConfig> bootstrapRuntime(
    EnsembleConfig config,
    EnsembleTestSetup setup, {
    MockAPIProvider? httpMock,
  }) async {
    ensureTestPlugins();

    applyYamlTestBootstrap(config, setup);
    Ensemble().setEnsembleConfig(config);

    if (httpMock != null) {
      installHttpMockProvider(config, httpMock);
    }

    await Ensemble().initManagers();

    config.apiProviders ??= {'http': HTTPAPIProvider()};
    config.apiProviders!.putIfAbsent('http', () => HTTPAPIProvider());

    YamlTestSession.markRuntimeBootstrapped();
    return config;
  }

  Future<EnsembleConfig> loadScreen({
    required WidgetTester tester,
    required EnsembleTestCase testCase,
    EnsembleConfig? existingConfig,
    EnsembleTestContext? context,
  }) async {
    resetTestRuntime();
    ScreenTracker().clearAll();
    YamlTestSession.navigationFlow.clear();

    final ctx = context ?? EnsembleTestContext.fromTestCase(testCase);
    var config = existingConfig ?? await buildConfig();
    final bootstrapped = await tester.runAsync(() async {
      return bootstrapRuntime(
        config,
        ctx.setup,
        httpMock: ctx.mockApiProvider,
      );
    });
    config = bootstrapped!;

    final startScreen = testCase.startScreen;
    if (startScreen == null || startScreen.isEmpty) {
      throw EnsembleTestFailure(
        'loadScreen requires startScreen on test "${testCase.id}"',
      );
    }

    await tester.pumpWidget(
      EnsembleApp(
        ensembleConfig: config,
        screenPayload: ScreenPayload(screenId: startScreen),
      ),
    );

    await waitForInitialWidgets(tester, testCase: testCase);
    return config;
  }

  static Future<void> waitForInitialWidgets(
    WidgetTester tester, {
    EnsembleTestCase? testCase,
  }) async {
    final keysToWait = <String>[];
    if (testCase != null) {
      for (final step in testCase.steps) {
        if (step.type != 'expectVisible' && step.type != 'tap') {
          break;
        }
        final id = step.args['id']?.toString();
        if (id != null && id.isNotEmpty) keysToWait.add(id);
      }
    }

    await tester.pump();
    await _yieldToRealAsyncWork(tester);
    for (var i = 0; i < 80; i++) {
      if (keysToWait.isEmpty ||
          keysToWait.every(
            (id) => find.byKey(ValueKey(id)).evaluate().isNotEmpty,
          )) {
        return;
      }
      await tester.pump(const Duration(milliseconds: 100));
      await _yieldToRealAsyncWork(tester);
    }

    if (keysToWait.isNotEmpty) {
      throw EnsembleTestFailure(
        'Timed out waiting for widgets: ${keysToWait.join(", ")}',
      );
    }
  }

  static Future<void> _yieldToRealAsyncWork(WidgetTester tester) async {
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
  }

  static void applyInPlaceSetup(EnsembleTestContext ctx) {
    final config = Ensemble().getConfig();
    if (config != null) {
      applyYamlTestBootstrap(config, ctx.setup);
    }
    ctx.applyRuntimeEnv();
    for (final entry in ctx.testCase.mocks.apis.entries) {
      ctx.mockApiProvider.setMock(entry.key, entry.value);
    }
    if (config != null) {
      installHttpMockProvider(config, ctx.mockApiProvider);
    }
  }

  static void resetTestRuntime() {
    YamlTestSession.reset();
  }
}
