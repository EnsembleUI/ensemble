import 'dart:io';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/ensemble_app.dart';
import 'package:ensemble/framework/apiproviders/api_provider.dart';
import 'package:ensemble/framework/apiproviders/http_api_provider.dart';
import 'package:ensemble/framework/definition_providers/local_provider.dart';
import 'package:ensemble/framework/screen_tracker.dart';
import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble_test_runner/mocks/adobe_test_setup.dart';
import 'package:ensemble_test_runner/mocks/firebase_test_setup.dart';
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
  final Map<String, dynamic>? initialKeychain;

  const EnsembleTestSetup({
    this.envOverrides,
    this.initialPublicStorage,
    this.initialKeychain,
  });
}

/// Applies YAML test environment and storage bootstrap data to [config].
Future<void> applyYamlTestBootstrap(
    EnsembleConfig config, EnsembleTestSetup setup) async {
  if (setup.envOverrides != null && setup.envOverrides!.isNotEmpty) {
    config.updateEnvOverrides(setup.envOverrides!);
  }
  await applyYamlTestStorageBootstrap(setup);
}

Future<void> applyYamlTestStorageBootstrap(EnsembleTestSetup setup) async {
  for (final entry in setup.initialPublicStorage?.entries ??
      const Iterable<MapEntry<String, dynamic>>.empty()) {
    await StorageManager().write(entry.key, entry.value);
  }
  for (final entry in setup.initialKeychain?.entries ??
      const Iterable<MapEntry<String, dynamic>>.empty()) {
    await StorageManager().writeSecurely(key: entry.key, value: entry.value);
  }
}

/// Boots the real Ensemble runtime for widget tests.
class EnsembleTestHarness {
  static final String _testStoragePath =
      Directory.systemTemp.createTempSync('ensemble_test_runner_storage_').path;

  static void ensureTestPlugins() {
    TestWidgetsFlutterBinding.ensureInitialized();
    ensureFirebaseCoreMocksForTest();
    ensureAdobeAnalyticsMocksForTest();
    HttpOverrides.global = _YamlTestHttpOverrides();
    const pathProviderChannel =
        MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      switch (call.method) {
        case 'getApplicationDocumentsDirectory':
        case 'getTemporaryDirectory':
        case 'getApplicationSupportDirectory':
          return _testStoragePath;
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
  final Map<String, Function>? externalMethods;

  EnsembleTestHarness({
    required this.appPath,
    required this.appHome,
    this.i18nPath,
    this.externalMethods,
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

  static Future<void> initializeRealApiProviders(EnsembleConfig config) async {
    await Ensemble.initializeAPIProviders(config);
    config.apiProviders ??= {};
    config.apiProviders!.putIfAbsent('http', () => HTTPAPIProvider());

    final firebase = config.apiProviders!['firebase'];
    if (firebase != null) {
      config.apiProviders!['firebaseFunction'] = firebase;
    }
  }

  /// Wraps real providers with [mock] for call recording and optional overrides.
  static void installApiMockOverrides(
    EnsembleConfig config,
    MockAPIProvider mock,
  ) {
    final realProviders = Map<String, APIProvider>.from(
      config.apiProviders ?? const {},
    );

    final installed = <String, APIProvider>{};
    for (final entry in realProviders.entries) {
      if (entry.key == 'http') {
        mock.bindHttpDelegate(entry.value as HTTPAPIProvider);
        installed['http'] = mock;
        continue;
      }
      installed[entry.key] = ApiMockOverlay(mock, entry.value);
    }

    if (!installed.containsKey('http')) {
      mock.bindHttpDelegate(HTTPAPIProvider());
      installed['http'] = mock;
    }

    final firebase = realProviders['firebase'];
    if (firebase != null && !installed.containsKey('firebaseFunction')) {
      installed['firebaseFunction'] =
          installed['firebase'] ?? ApiMockOverlay(mock, firebase);
    }

    config.apiProviders = installed;
  }

  Future<EnsembleConfig> bootstrapRuntime(
    EnsembleConfig config,
    EnsembleTestSetup setup, {
    MockAPIProvider? apiMockOverlay,
  }) async {
    ensureTestPlugins();

    final env = Map<String, dynamic>.from(config.envOverrides ?? {});
    env['firebase_app_check'] = 'false';
    if (setup.envOverrides != null && setup.envOverrides!.isNotEmpty) {
      env.addAll(setup.envOverrides!);
    }
    config.updateEnvOverrides(env);
    Ensemble().setEnsembleConfig(config);
    if (externalMethods != null && externalMethods!.isNotEmpty) {
      Ensemble().setExternalMethods(externalMethods!);
    }

    await Ensemble().initManagers();
    await initializeRealApiProviders(config);

    if (apiMockOverlay != null) {
      installApiMockOverrides(config, apiMockOverlay);
    }
    await applyYamlTestStorageBootstrap(setup);

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
    await _ensureDefaultViewport(tester, ctx);
    var config = existingConfig ?? await buildConfig();
    final bootstrapped = await tester.runAsync(() async {
      return bootstrapRuntime(
        config,
        ctx.setup,
        apiMockOverlay: ctx.mockApiProvider,
      );
    });
    config = bootstrapped!;

    final startScreen = testCase.startScreen;
    if (startScreen == null || startScreen.isEmpty) {
      throw EnsembleTestFailure(
        'loadScreen requires startScreen on test "${testCase.id}"',
      );
    }

    // Skip re-initializing providers in EnsembleApp.initApp; bootstrapRuntime
    // already installed real providers and mock overlays.
    config.appBundle = null;
    await tester.pumpWidget(
      EnsembleApp(
        ensembleConfig: config,
        screenPayload: ScreenPayload(screenId: startScreen),
      ),
    );

    await waitForInitialWidgets(tester, testCase: testCase);
    return config;
  }

  static Future<void> _ensureDefaultViewport(
    WidgetTester tester,
    EnsembleTestContext context,
  ) async {
    if (context.runtime.deviceSize != null) return;
    const size = Size(800, 844);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    context.runtime.deviceSize = size;
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

  static Future<void> applyInPlaceSetup(EnsembleTestContext ctx) async {
    final config = Ensemble().getConfig();
    if (config != null) {
      await applyYamlTestBootstrap(config, ctx.setup);
    }
    ctx.applyRuntimeEnv();
    for (final entry in ctx.testCase.mocks.apis.entries) {
      ctx.mockApiProvider.setMock(entry.key, entry.value);
    }
    if (config != null && config.apiProviders?['http'] is! MockAPIProvider) {
      installApiMockOverrides(config, ctx.mockApiProvider);
    }
  }

  static void resetTestRuntime() {
    YamlTestSession.reset();
  }
}

class _YamlTestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.connectionFactory = (
      Uri uri,
      String? proxyHost,
      int? proxyPort,
    ) {
      // HTTP to local gateways (e.g. instellen.local) uses filtered DNS so mDNS
      // does not prefer loopback. All HTTPS uses the platform connector so TLS
      // handshakes (cloud APIs and local gateway cert capture) work normally.
      if (uri.scheme == 'https') {
        return _platformDefaultConnection(uri, proxyHost, proxyPort);
      }
      return _connectWithoutStaggeredLookup(uri, proxyHost, proxyPort);
    };
    return client;
  }

  static Future<ConnectionTask<Socket>> _platformDefaultConnection(
    Uri uri,
    String? proxyHost,
    int? proxyPort,
  ) async {
    final savedOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    try {
      return Socket.startConnect(proxyHost ?? uri.host, proxyPort ?? uri.port);
    } finally {
      HttpOverrides.global = savedOverrides;
    }
  }

  static Future<ConnectionTask<Socket>> _connectWithoutStaggeredLookup(
    Uri uri,
    String? proxyHost,
    int? proxyPort,
  ) async {
    final host = proxyHost ?? uri.host;
    final port = proxyPort ?? uri.port;
    final addresses = _usableAddresses(
      host,
      await InternetAddress.lookup(host),
    );
    if (addresses.isEmpty) {
      throw const SocketException('No addresses resolved');
    }
    var cancelled = false;
    final socket = _connectToFirstAvailableAddress(
      addresses,
      port,
      isCancelled: () => cancelled,
    );
    return ConnectionTask.fromSocket(
      socket,
      () {
        cancelled = true;
      },
    );
  }

  /// Dart's [InternetAddress.lookup] can return loopback before LAN IPs for
  /// mDNS names like `instellen.local`, causing slow connection-refused retries.
  static List<InternetAddress> _usableAddresses(
    String host,
    List<InternetAddress> addresses,
  ) {
    if (host == 'localhost' || host == '127.0.0.1' || host == '::1') {
      return addresses;
    }
    final filtered =
        addresses.where((address) => !address.isLoopback).toList();
    return filtered.isEmpty ? addresses : filtered;
  }

  static Future<Socket> _connectToFirstAvailableAddress(
    List<InternetAddress> addresses,
    int port, {
    required bool Function() isCancelled,
  }) async {
    Object? lastError;
    StackTrace? lastStackTrace;
    for (final address in addresses) {
      if (isCancelled()) {
        throw const SocketException('Connection attempt cancelled');
      }
      try {
        return await Socket.connect(address, port);
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
      }
    }
    Error.throwWithStackTrace(
      lastError ?? const SocketException('Connection failed'),
      lastStackTrace ?? StackTrace.current,
    );
  }
}
