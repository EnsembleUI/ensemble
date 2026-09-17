import 'dart:convert';
import 'dart:io';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/ensemble_app.dart';
import 'package:ensemble/framework/apiproviders/api_provider.dart';
import 'package:ensemble/framework/apiproviders/http_api_provider.dart';
import 'package:ensemble/framework/definition_providers/local_provider.dart';
import 'package:ensemble/framework/screen_tracker.dart';
import 'package:ensemble/framework/secrets.dart';
import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble/framework/encrypted_storage_manager.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_device_preview/ensemble_device_preview.dart';
import 'package:ensemble_test_runner/actions/screenshot_device.dart';
import 'package:ensemble_test_runner/actions/test_theme.dart';
import 'package:ensemble_test_runner/mocks/adobe_test_setup.dart';
import 'package:ensemble_test_runner/mocks/firebase_test_setup.dart';
import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/app_session_snapshot.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/live_async_call.dart';
import 'package:ensemble_test_runner/runner/yaml_test_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yaml/yaml.dart';

/// Per-test bootstrap data applied before the widget tree mounts.
class EnsembleTestSetup {
  final Map<String, dynamic>? envOverrides;
  final Map<String, dynamic>? initialPublicStorage;
  final Map<String, dynamic>? initialSecureStorage;
  final Map<String, dynamic>? initialKeychain;

  const EnsembleTestSetup({
    this.envOverrides,
    this.initialPublicStorage,
    this.initialSecureStorage,
    this.initialKeychain,
  });
}

/// Execution-environment behavior used by the shared Ensemble harness.
abstract class EnsembleTestRuntimeAdapter {
  ExecutionMode get mode;
  bool get usesPhysicalDisplay;
  bool get clearsPersistentStateBetweenIndependentTests;
  void initialize();
}

class WidgetTestRuntimeAdapter implements EnsembleTestRuntimeAdapter {
  const WidgetTestRuntimeAdapter();

  @override
  ExecutionMode get mode => ExecutionMode.widget;
  @override
  bool get usesPhysicalDisplay => false;
  @override
  bool get clearsPersistentStateBetweenIndependentTests => false;
  @override
  void initialize() => EnsembleTestHarness.ensureTestPlugins();
}

class IntegrationTestRuntimeAdapter implements EnsembleTestRuntimeAdapter {
  const IntegrationTestRuntimeAdapter();

  @override
  ExecutionMode get mode => ExecutionMode.integration;
  @override
  bool get usesPhysicalDisplay => true;
  @override
  bool get clearsPersistentStateBetweenIndependentTests => true;
  @override
  void initialize() => EnsembleTestHarness.ensureIntegrationRuntime();
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
  final secureEntries = setup.initialSecureStorage?.entries.toList() ??
      const <MapEntry<String, dynamic>>[];
  if (secureEntries.isNotEmpty) {
    await SecretsStore().initialize();
    installTestEncryptionKey();
  }
  for (final entry in secureEntries) {
    EncryptedStorageManager.setSecureStorage({
      'key': entry.key,
      'value': entry.value,
    });
    // The runtime API is synchronous for compatibility with released
    // Ensemble versions, while GetStorage persists asynchronously. Wait for
    // the backend entry to become observable before mounting the app.
    for (var attempt = 0; attempt < 50; attempt++) {
      if (StorageManager().read('enc_${entry.key}') != null) break;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }
  for (final entry in setup.initialKeychain?.entries ??
      const Iterable<MapEntry<String, dynamic>>.empty()) {
    await StorageManager().writeSecurely(key: entry.key, value: entry.value);
  }
}

/// Installs the per-run test encryption key into [SecretsStore] and clears the
/// process-cached key in [EncryptedStorageManager].
///
/// The key comes from `--dart-define=ensembleTestEncryptionKey=...` (generated
/// by the CLI each run). Widget-test fixtures may pass a deterministic value.
void installTestEncryptionKey() {
  const fromDefine = String.fromEnvironment('ensembleTestEncryptionKey');
  final key = fromDefine.isNotEmpty ? fromDefine : _fallbackTestEncryptionKey();
  if (key.length != 32) {
    throw StateError(
      'ensembleTestEncryptionKey must be exactly 32 characters '
      '(got ${key.length}).',
    );
  }
  EncryptedStorageManager.resetCachedKey();
  SecretsStore().secretCache['encryptionKey'] = key;
}

String _fallbackTestEncryptionKey() {
  // Deterministic fallback for unit tests that do not go through the CLI.
  // Never used as a production secret; process-local only.
  return 'EnsembleTestKey00000000000000000';
}

/// Boots the real Ensemble runtime for widget tests.
class EnsembleTestHarness {
  static final String _testStoragePath =
      Directory.systemTemp.createTempSync('ensemble_test_runner_storage_').path;
  static bool _appFontsLoaded = false;
  static bool _sqfliteInitialized = false;
  static final Map<String, String> _secureStorage = {};

  /// Storage present when the suite started. Independent integration tests
  /// restore this instead of wiping the whole device keychain.
  static AppSessionSnapshot? _preSuiteStorageSnapshot;

  static const bool resetDeviceStorage = bool.fromEnvironment(
    'ensembleTestResetDeviceStorage',
  );

  /// Explicit acknowledgment that integration tests may mutate storage on a
  /// physical device (baseline capture + between-test restores).
  static const bool allowDeviceStorageMutation = bool.fromEnvironment(
    'ensembleTestAllowDeviceStorageMutation',
  );

  /// True when the integration target is a physical device (not emulator/sim).
  static const bool deviceIsPhysical = bool.fromEnvironment(
    'ensembleTestDeviceIsPhysical',
  );

  /// Physical devices require `--allow-device-storage-mutation` or
  /// `--reset-device-storage` before storage is captured or mutated.
  static void requirePhysicalDeviceStorageAcknowledgment() {
    assertPhysicalDeviceStorageAcknowledged(
      deviceIsPhysical: deviceIsPhysical,
      allowMutation: allowDeviceStorageMutation,
      resetStorage: resetDeviceStorage,
    );
  }

  /// Pure gate used by [requirePhysicalDeviceStorageAcknowledgment] and tests.
  static void assertPhysicalDeviceStorageAcknowledged({
    required bool deviceIsPhysical,
    required bool allowMutation,
    required bool resetStorage,
  }) {
    if (!deviceIsPhysical) return;
    if (allowMutation || resetStorage) return;
    throw StateError(
      'Integration tests on a physical device mutate app storage '
      '(capture a pre-suite baseline and restore it between tests). '
      'Pass --allow-device-storage-mutation to acknowledge this, or '
      '--reset-device-storage to wipe storage first on a disposable device.',
    );
  }

  static void ensureTestPlugins() {
    TestWidgetsFlutterBinding.ensureInitialized();
    if (!_sqfliteInitialized) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      _sqfliteInitialized = true;
    }
    ensureFirebaseCoreMocksForTest();
    ensureAdobeAnalyticsMocksForTest();
    HttpOverrides.global = _RealNetworkHttpOverrides();
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
        return _resolvePackageInfo(Directory.current);
      }
      return null;
    });

    const secureStorageChannel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
      final args = Map<String, Object?>.from(call.arguments as Map? ?? {});
      final key = args['key']?.toString();
      switch (call.method) {
        case 'write':
          if (key != null) {
            _secureStorage[key] = args['value']?.toString() ?? '';
          }
          return null;
        case 'read':
          return key == null ? null : _secureStorage[key];
        case 'readAll':
          return Map<String, String>.from(_secureStorage);
        case 'delete':
          if (key != null) _secureStorage.remove(key);
          return null;
        case 'deleteAll':
          _secureStorage.clear();
          return null;
        case 'containsKey':
          return key != null && _secureStorage.containsKey(key);
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

  /// Initializes only runner-owned Dart listeners for a real application.
  /// Native plugin channels remain registered by the Android/iOS host app.
  static void ensureIntegrationRuntime() {
    TestWidgetsFlutterBinding.ensureInitialized();
    YamlTestSession.navigationFlow.startListening();
  }

  final String appPath;
  final String appHome;
  final String? i18nPath;
  final Map<String, Function>? externalMethods;
  final ExecutionMode executionMode;
  late final EnsembleTestRuntimeAdapter runtimeAdapter =
      executionMode == ExecutionMode.integration
          ? const IntegrationTestRuntimeAdapter()
          : const WidgetTestRuntimeAdapter();

  EnsembleTestHarness({
    required this.appPath,
    required this.appHome,
    this.i18nPath,
    this.externalMethods,
    this.executionMode = ExecutionMode.widget,
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
  static void installTestApiOverlay(
    EnsembleConfig config,
    TestApiProviderOverlay mock,
  ) {
    final realProviders = Map<String, APIProvider>.from(
      config.apiProviders ?? const {},
    );

    final installed = <String, APIProvider>{};
    for (final entry in realProviders.entries) {
      var delegate = entry.value;
      if (delegate is TestApiProviderOverlay) {
        delegate = delegate.delegate;
      } else if (delegate is TestApiOverlay) {
        delegate = delegate.delegate;
      }

      if (entry.key == 'http') {
        mock.bindHttpDelegate(delegate as HTTPAPIProvider);
        installed['http'] = mock;
        continue;
      }
      installed[entry.key] = TestApiOverlay(mock, delegate);
    }

    if (!installed.containsKey('http')) {
      mock.bindHttpDelegate(HTTPAPIProvider());
      installed['http'] = mock;
    }

    final firebase = realProviders['firebase'];
    if (firebase != null && !installed.containsKey('firebaseFunction')) {
      installed['firebaseFunction'] =
          installed['firebase'] ?? TestApiOverlay(mock, firebase);
    }

    config.apiProviders = installed;
  }

  Future<EnsembleConfig> bootstrapRuntime(
    EnsembleConfig config,
    EnsembleTestSetup setup, {
    TestApiProviderOverlay? apiOverlay,
    bool clearPersistentState = false,
  }) async {
    runtimeAdapter.initialize();
    await ensureAppFontsLoaded();

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
    if (clearPersistentState) {
      await _clearPersistentTestState();
    }
    await initializeRealApiProviders(config);

    if (apiOverlay != null) {
      installTestApiOverlay(config, apiOverlay);
    }
    await applyYamlTestStorageBootstrap(setup);

    YamlTestSession.markRuntimeBootstrapped();
    return config;
  }

  static Future<void> ensureAppFontsLoaded() async {
    if (_appFontsLoaded) return;
    _appFontsLoaded = true;

    List<dynamic> manifest;
    try {
      final rawManifest = await rootBundle.loadString('FontManifest.json');
      manifest = jsonDecode(rawManifest) as List<dynamic>;
    } catch (_) {
      return;
    }

    for (final familyEntry in manifest.whereType<Map>()) {
      final family = familyEntry['family']?.toString();
      final fonts = familyEntry['fonts'];
      if (family == null || fonts is! List) continue;

      for (final alias in _fontFamilyAliases(family)) {
        await _loadFontFamily(alias, fonts);
      }
    }
  }

  static List<String> fontFamilyAliasesForTest(String family) =>
      _fontFamilyAliases(family);

  static List<String> fontAssetCandidatesForTest(String asset) =>
      _fontAssetCandidates(asset);

  static Map<String, String> packageInfoForTest(String appDir) =>
      _resolvePackageInfo(Directory(appDir));

  static Map<String, String> _resolvePackageInfo(Directory appDir) {
    final pubspec = _readPubspec(appDir);
    final properties = _readProperties(
      File('${appDir.path}/ensemble/ensemble.properties'),
    );

    final packageName =
        properties['appId'] ?? pubspec['name'] ?? 'com.ensemble.test';
    final appName = properties['appName'] ??
        _titleFromPackageName(pubspec['name']) ??
        'EnsembleTest';
    final versionParts = _splitVersion(pubspec['version']);

    return {
      'appName': appName,
      'packageName': packageName,
      'version': versionParts.version,
      'buildNumber': versionParts.buildNumber,
    };
  }

  static Map<String, String> _readPubspec(Directory appDir) {
    final file = File('${appDir.path}/pubspec.yaml');
    if (!file.existsSync()) return const {};

    try {
      final yaml = loadYaml(file.readAsStringSync());
      if (yaml is! YamlMap) return const {};
      return {
        for (final entry in yaml.entries)
          if (entry.value != null) entry.key.toString(): entry.value.toString(),
      };
    } catch (_) {
      return const {};
    }
  }

  static Map<String, String> _readProperties(File file) {
    if (!file.existsSync()) return const {};

    final values = <String, String>{};
    for (final rawLine in file.readAsLinesSync()) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final separator = line.indexOf('=');
      if (separator <= 0) continue;
      values[line.substring(0, separator).trim()] =
          line.substring(separator + 1).trim();
    }
    return values;
  }

  static ({String version, String buildNumber}) _splitVersion(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return (version: '1.0.0', buildNumber: '1');
    }
    final parts = raw.trim().split('+');
    final version = parts.first.trim();
    final buildNumber = parts.length > 1 ? parts.sublist(1).join('+') : '1';
    return (
      version: version.isEmpty ? '1.0.0' : version,
      buildNumber: buildNumber.trim().isEmpty ? '1' : buildNumber.trim(),
    );
  }

  static String? _titleFromPackageName(String? name) {
    if (name == null || name.trim().isEmpty) return null;
    return name
        .trim()
        .split(RegExp(r'[_\s]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  static List<String> _fontFamilyAliases(String family) {
    final aliases = <String>{family, family.toLowerCase()};

    const packagePrefix = 'packages/';
    if (family.startsWith(packagePrefix)) {
      final slashIndex = family.lastIndexOf('/');
      if (slashIndex != -1 && slashIndex < family.length - 1) {
        final unqualifiedFamily = family.substring(slashIndex + 1);
        aliases.add(unqualifiedFamily);
        aliases.add(unqualifiedFamily.toLowerCase());
      }
    }

    return aliases.toList(growable: false);
  }

  static List<String> _fontAssetCandidates(String asset) {
    final candidates = <String>{asset};
    if (asset.contains('%')) {
      try {
        candidates.add(Uri.decodeFull(asset));
      } catch (_) {
        // Keep the manifest-provided asset key if decoding is not valid URI
        // escaping.
      }
    }
    return candidates.toList(growable: false);
  }

  static Future<void> _loadFontFamily(
    String family,
    List<dynamic> fontEntries,
  ) async {
    final loader = FontLoader(family);
    var hasFonts = false;

    for (final fontEntry in fontEntries.whereType<Map>()) {
      final asset = fontEntry['asset']?.toString();
      if (asset == null || asset.isEmpty) continue;

      for (final assetKey in _fontAssetCandidates(asset)) {
        try {
          final fontData = await rootBundle.load(assetKey);
          loader.addFont(Future.value(fontData));
          hasFonts = true;
          break;
        } catch (_) {
          // Ignore missing assets so a bad font entry does not fail unrelated
          // behavioral tests.
        }
      }
    }

    if (hasFonts) {
      await loader.load();
    }
  }

  Future<EnsembleConfig> loadScreen({
    required WidgetTester tester,
    required EnsembleTestCase testCase,
    EnsembleConfig? existingConfig,
    EnsembleTestContext? context,
    EnsembleTestConfig suiteConfig = const EnsembleTestConfig(),
    Future<void> Function()? beforeBootstrap,
    Locale? forcedLocale,
  }) async {
    // Independent tests need a new EnsembleApp state. Pumping another
    // EnsembleApp of the same type would otherwise reuse the prior route.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    resetTestRuntime();
    ScreenTracker().clearAll();
    YamlTestSession.navigationFlow.clear();
    await beforeBootstrap?.call();

    final ctx = context ??
        EnsembleTestContext.fromTestCase(
          testCase,
          config: suiteConfig,
        );
    await applyViewport(
      tester,
      ctx,
      screenshotDevice: screenshotDeviceForTestCase(testCase, ctx.config),
    );
    var config = existingConfig ?? await buildConfig();
    final bootstrapped = await tester.runAsync(() async {
      return bootstrapRuntime(
        config,
        ctx.setup,
        apiOverlay: ctx.apiOverlay,
        clearPersistentState:
            runtimeAdapter.clearsPersistentStateBetweenIndependentTests &&
                testCase.session == null,
      );
    });
    if (bootstrapped == null) {
      final bootstrapError = tester.takeException();
      if (bootstrapError != null) throw bootstrapError;
      if (ctx.runtime.flutterErrors.isNotEmpty) {
        throw EnsembleTestFailure(ctx.runtime.flutterErrors.last);
      }
      throw EnsembleTestFailure(
        'Ensemble runtime bootstrap completed without a configuration.',
      );
    }
    config = bootstrapped;

    final startScreen = testCase.startScreen;
    if (startScreen == null || startScreen.isEmpty) {
      throw EnsembleTestFailure(
        'loadScreen requires startScreen on test "${testCase.id}"',
      );
    }

    final deviceTheme = testCase.deviceTarget?.theme;
    await tester.runAsync(() => seedEnsembleTestTheme(deviceTheme));

    // Skip re-initializing providers in EnsembleApp.initApp; bootstrapRuntime
    // already installed real providers and mock overlays.
    config.appBundle = null;
    await tester.pumpWidget(
      EnsembleApp(
        ensembleConfig: config,
        screenPayload: ScreenPayload(
          screenId: startScreen,
          screenName: startScreen,
          arguments: testCase.startScreenInputs,
        ),
        forcedLocale: forcedLocale,
      ),
    );

    await waitForInitialWidgets(tester, testCase: testCase);
    final appliedTheme = applyDeviceThemeForTestCase(testCase);
    if (appliedTheme != null) {
      ctx.runtime.themeMode = appliedTheme;
      await tester.pump();
    }
    return config;
  }

  static Future<void> openSessionScreen(
    WidgetTester tester,
    EnsembleTestCase testCase,
  ) async {
    final startScreen = testCase.startScreen;
    if (startScreen == null || startScreen.isEmpty) {
      throw EnsembleTestFailure(
        'Session test "${testCase.id}" requires startScreen',
      );
    }
    final context = Utils.globalAppKey.currentContext;
    if (context == null) {
      throw EnsembleTestFailure(
        'Cannot open "$startScreen" because the saved app session is not mounted',
      );
    }

    ScreenTracker().clearAll();
    YamlTestSession.navigationFlow.clear();
    ScreenController().navigateToScreen(
      context,
      screenId: startScreen,
      screenName: startScreen,
      pageArgs: testCase.startScreenInputs,
      routeOption: RouteOption.clearAllScreens,
    );
    await tester.pump();
    await waitForInitialWidgets(tester, testCase: testCase);
  }

  /// Widget tests may emulate a screenshot device. Integration tests keep the
  /// real simulator/emulator view so hit-testing and layout stay aligned.
  Future<void> applyViewport(
    WidgetTester tester,
    EnsembleTestContext context, {
    DeviceInfo? screenshotDevice,
  }) async {
    if (runtimeAdapter.usesPhysicalDisplay) {
      _recordPhysicalDisplaySize(tester, context);
      return;
    }
    if (screenshotDevice != null) {
      await _setViewportForDevice(tester, context, screenshotDevice);
    }
    await _ensureDefaultViewport(tester, context);
  }

  static void _recordPhysicalDisplaySize(
    WidgetTester tester,
    EnsembleTestContext context,
  ) {
    final pixelRatio = tester.view.devicePixelRatio;
    final physicalSize = tester.view.physicalSize;
    context.runtime.deviceSize = Size(
      physicalSize.width / pixelRatio,
      physicalSize.height / pixelRatio,
    );
  }

  static Future<void> _ensureDefaultViewport(
    WidgetTester tester,
    EnsembleTestContext context,
  ) async {
    if (context.runtime.deviceSize != null) return;
    const size = Size(800, 844);
    await tester.binding.setSurfaceSize(size);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    _setViewPadding(tester, EdgeInsets.zero);
    context.runtime.deviceSize = size;
  }

  static Future<void> _setViewportForDevice(
    WidgetTester tester,
    EnsembleTestContext context,
    DeviceInfo device,
  ) async {
    await tester.binding.setSurfaceSize(device.screenSize);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = device.screenSize;
    _setViewPadding(tester, device.safeAreas);
    context.runtime.deviceSize = device.screenSize;
  }

  static void _setViewPadding(WidgetTester tester, EdgeInsets padding) {
    final viewPadding = FakeViewPadding(
      left: padding.left,
      top: padding.top,
      right: padding.right,
      bottom: padding.bottom,
    );
    tester.view.padding = viewPadding;
    tester.view.viewPadding = viewPadding;
  }

  static Future<void> waitForInitialWidgets(
    WidgetTester tester, {
    EnsembleTestCase? testCase,
  }) async {
    final keysToWait = <String>[];
    if (testCase != null) {
      for (final step in testCase.steps) {
        if (step.type != 'expectVisible') {
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
    Future<void> yieldOnce() async {
      await Future<void>.delayed(Duration.zero);
    }

    if (LiveAsyncCallSupport.runner != null) {
      await LiveAsyncCallSupport.run<void>(yieldOnce);
    } else {
      await tester.runAsync(yieldOnce);
    }
  }

  static Future<void> applyInPlaceSetup(EnsembleTestContext ctx) async {
    final config = Ensemble().getConfig();
    if (config != null) {
      await applyYamlTestBootstrap(config, ctx.setup);
    }
    ctx.applyRuntimeEnv();
    for (final entry in ctx.testCase.mocks.apis.entries) {
      ctx.apiOverlay.setMock(entry.key, entry.value);
    }
    if (config != null) {
      installTestApiOverlay(config, ctx.apiOverlay);
    }
  }

  /// Wipes all public / encrypted / keychain storage. Destructive — only used
  /// when [resetDeviceStorage] is set or when capturing an empty baseline.
  static Future<void> wipeAllPersistentStorage() async {
    final storage = StorageManager();
    await storage.clearPublicStorage();
    for (final key
        in storage.getKeys().where((key) => key.startsWith('enc_')).toList()) {
      await storage.remove(key);
    }
    final keychain = await storage.getAllFromKeychain();
    for (final key in keychain.keys) {
      await storage.removeSecurely(key);
    }
  }

  /// Captures the pre-suite storage baseline once. When
  /// [resetDeviceStorage] is true, wipes first so the baseline is empty.
  static Future<void> ensurePreSuiteStorageSnapshot() async {
    if (_preSuiteStorageSnapshot != null) return;
    requirePhysicalDeviceStorageAcknowledgment();
    if (resetDeviceStorage) {
      await wipeAllPersistentStorage();
    }
    _preSuiteStorageSnapshot = await AppSessionSnapshot.capture();
  }

  /// Restores device storage to the pre-suite baseline so independent tests
  /// do not inherit keys written by earlier tests, while preserving whatever
  /// already existed on the device before the suite started.
  static Future<void> _clearPersistentTestState() async {
    await restorePreSuiteStorage();
  }

  /// Restores the cached pre-suite storage baseline (capturing it first if needed).
  static Future<void> restorePreSuiteStorage() async {
    await ensurePreSuiteStorageSnapshot();
    await _preSuiteStorageSnapshot!.restore();
  }

  /// Restores the pre-suite baseline at suite teardown (including after
  /// failures) so the device returns to its pre-run storage state.
  ///
  /// Invoked from the suite entry `finally` and again from package `tearDown`
  /// so both Dart exception exits and flutter_test teardown paths restore.
  /// Safe to call repeatedly; no-ops when no baseline was captured.
  static Future<void> restorePreSuiteStorageAtSuiteEnd() async {
    if (_preSuiteStorageSnapshot == null) return;
    await _preSuiteStorageSnapshot!.restore();
  }

  /// Test hook: drop the cached baseline between unit tests.
  static void resetPreSuiteStorageSnapshotForTest() {
    _preSuiteStorageSnapshot = null;
  }

  /// Test hook exposing [restorePreSuiteStorage].
  static Future<void> restorePreSuiteStorageForTest() =>
      restorePreSuiteStorage();

  static void resetTestRuntime() {
    YamlTestSession.reset();
  }
}

class _RealNetworkHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context);
  }
}
