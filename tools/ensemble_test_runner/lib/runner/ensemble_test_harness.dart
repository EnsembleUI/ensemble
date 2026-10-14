import 'package:ensemble_test_runner/src/benchmark_measurement.dart';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/ensemble_app.dart';
import 'package:ensemble/framework/screen_tracker.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/framework/apiproviders/api_provider.dart';
import 'package:ensemble/framework/apiproviders/http_api_provider.dart';
import 'package:ensemble/framework/definition_providers/local_provider.dart';
import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble_test_runner/actions/screenshot_device.dart';
import 'package:ensemble_test_runner/actions/test_theme.dart';
import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:ensemble_test_runner/mocks/wifi_test_setup.dart';
import 'package:ensemble_test_runner/src/integrations/test_integration_registration.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/app_session_snapshot.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/event_driven_settler.dart';
import 'package:ensemble_test_runner/runner/test_font_loader.dart';
import 'package:ensemble_test_runner/runner/live_async_call.dart';
import 'package:ensemble_test_runner/runner/test_app_metadata.dart';
import 'package:ensemble_test_runner/runner/test_session.dart';
import 'package:ensemble_test_runner/runner/test_bootstrap.dart';
import 'package:ensemble_test_runner/runner/test_harness_host_runtime.dart';
import 'package:ensemble_test_runner/src/integrations/device_preview/device_preview_adapter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

export 'test_bootstrap.dart';

/// Execution-environment behavior used by the shared Ensemble harness.
abstract class EnsembleTestRuntimeAdapter {
  ExecutionMode get mode;
  bool get usesPhysicalDisplay;
  bool get clearsPersistentStateBetweenIndependentTests;
  void initialize();
  void afterBootstrap();
  Future<void> applyViewport(
    WidgetTester tester,
    EnsembleTestContext context,
    DeviceInfo? screenshotDevice, {
    bool ensureDefaultViewport = true,
    bool reportLogicalDisplaySize = true,
  });
  Future<void> resetViewport(WidgetTester tester);
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

  @override
  void afterBootstrap() {
    ensureWifiTestDoublesForTest();
    EnsembleTestHarness.afterTestPluginBootstrap();
  }

  @override
  Future<void> applyViewport(
    WidgetTester tester,
    EnsembleTestContext context,
    DeviceInfo? screenshotDevice, {
    bool ensureDefaultViewport = true,
    bool reportLogicalDisplaySize = true,
  }) async {
    if (screenshotDevice != null) {
      await EnsembleTestHarness.setViewportForDevice(
        tester,
        context,
        screenshotDevice,
      );
    }
    if (ensureDefaultViewport) {
      await EnsembleTestHarness.ensureDefaultViewport(tester, context);
    }
  }

  @override
  Future<void> resetViewport(WidgetTester tester) =>
      EnsembleTestHarness.resetViewport(tester);
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

  @override
  void afterBootstrap() {}

  @override
  Future<void> applyViewport(
    WidgetTester tester,
    EnsembleTestContext context,
    DeviceInfo? screenshotDevice, {
    bool ensureDefaultViewport = true,
    bool reportLogicalDisplaySize = true,
  }) async {
    if (reportLogicalDisplaySize) {
      EnsembleTestHarness.recordPhysicalDisplaySize(tester, context);
    } else {
      context.runtime.deviceSize = tester.view.physicalSize;
    }
  }

  @override
  Future<void> resetViewport(WidgetTester tester) async {
    // Integration mode reports and uses the physical display. Its viewport is
    // owned by the native host and must not be reset between attempts.
  }
}

/// Boots the real Ensemble runtime for widget tests.
class EnsembleTestHarness {
  /// Storage present when the suite started. Independent integration tests
  /// restore this instead of wiping the whole device keychain.
  static AppSessionSnapshot? _preSuiteStorageSnapshot;
  static Future<AppSessionSnapshot>? _preSuiteStorageSnapshotCapture;

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

  /// Exposes initialization state for the startup-boundary regression test.
  @visibleForTesting
  static bool get testStoragePathCreatedForTest =>
      TestHarnessHostRuntime.testStoragePathCreatedForTest;

  static void disposeTestStorage() =>
      TestHarnessHostRuntime.disposeTestStorage();

  static void ensureTestPlugins() => TestHarnessHostRuntime.ensureTestPlugins();

  static void configureTestIntegrations(
    Iterable<TestIntegrationRegistration> registrations,
  ) =>
      TestHarnessHostRuntime.configureTestIntegrations(registrations);

  static void afterTestPluginBootstrap() =>
      TestHarnessHostRuntime.afterTestPluginBootstrap();

  static void ensureIntegrationRuntime() =>
      TestHarnessHostRuntime.ensureIntegrationRuntime();

  @visibleForTesting
  static Map<String, Object?> deviceInfoMockForTest() =>
      TestHarnessHostRuntime.deviceInfoMockForTest();

  final String appPath;
  final String appHome;
  final String? i18nPath;
  final Map<String, Function>? externalMethods;
  final ExecutionMode executionMode;
  late final EnsembleTestRuntimeAdapter runtimeAdapter =
      runtimeAdapterFor(executionMode);

  EnsembleTestHarness({
    required this.appPath,
    required this.appHome,
    this.i18nPath,
    this.externalMethods,
    this.executionMode = ExecutionMode.widget,
  });

  static EnsembleTestRuntimeAdapter runtimeAdapterFor(ExecutionMode mode) =>
      mode == ExecutionMode.integration
          ? const IntegrationTestRuntimeAdapter()
          : const WidgetTestRuntimeAdapter();

  static String normalizeAppPath(String path) {
    if (path.endsWith('/')) return path;
    return '$path/';
  }

  Future<EnsembleConfig> buildConfig({Locale? forcedLocale}) async {
    return await RunnerBenchmark.async('lifecycle', 'buildConfig', () async {
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
    });
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
    return await RunnerBenchmark.async('lifecycle', 'bootstrapRuntime',
        () async {
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
      await applyTestStorageBootstrap(setup);

      return config;
    });
  }

  static Future<void> ensureAppFontsLoaded() => TestFontLoader.ensureLoaded();

  static List<String> fontFamilyAliasesForTest(String family) =>
      TestFontLoader.familyAliases(family);

  static List<String> fontAssetCandidatesForTest(String asset) =>
      TestFontLoader.assetCandidates(asset);

  static Map<String, String> packageInfoForTest(String appDir) =>
      TestAppMetadata.packageInfo(appDir);

  Future<EnsembleConfig> loadScreen({
    required WidgetTester tester,
    required EnsembleTestCase testCase,
    required EnsembleTestContext context,
    EnsembleConfig? existingConfig,
    EnsembleTestConfig suiteConfig = const EnsembleTestConfig(),
    Future<void> Function()? beforeBootstrap,
    Locale? forcedLocale,
  }) async {
    return await RunnerBenchmark.async('lifecycle', 'loadScreen', () async {
      final ctx = context;
      // Independent tests need a new EnsembleApp state. Pumping another
      // EnsembleApp of the same type would otherwise reuse the prior route.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      resetTestRuntime(navigationFlow: ctx.navigationFlow);
      ScreenTracker().clearAll();
      await beforeBootstrap?.call();

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
        while (tester.takeException() != null) {}
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
    });
  }

  static Future<void> openSessionScreen(
      WidgetTester tester, EnsembleTestCase testCase,
      {required NavigationFlowRecorder navigationFlow}) async {
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
    navigationFlow.clear();
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
    bool ensureDefaultViewport = true,
    bool reportLogicalDisplaySize = true,
  }) async {
    return await RunnerBenchmark.async('lifecycle', 'applyViewport', () async {
      await runtimeAdapter.applyViewport(
        tester,
        context,
        screenshotDevice,
        ensureDefaultViewport: ensureDefaultViewport,
        reportLogicalDisplaySize: reportLogicalDisplaySize,
      );
    });
  }

  static void recordPhysicalDisplaySize(
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

  static Future<void> ensureDefaultViewport(
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

  /// Restores the widget-test view after a report screenshot viewport override.
  static Future<void> resetViewport(WidgetTester tester) async {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetPadding();
    tester.view.resetViewPadding();
    await tester.binding.setSurfaceSize(null);
  }

  static Future<void> setViewportForDevice(
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

    if (keysToWait.isEmpty) {
      await tester.pump();
      await _yieldToRealAsyncWork(tester);
      return;
    }

    try {
      await EventDrivenSettler(
        tester: tester,
        onPump: () => _yieldToRealAsyncWork(tester),
      ).waitFor(
        condition: () => keysToWait.every(
          (id) => find.byKey(ValueKey(id)).evaluate().isNotEmpty,
        ),
        timeout: const Duration(seconds: 8),
      );
    } on FlutterError {
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
    return await RunnerBenchmark.async('lifecycle', 'applyInPlaceSetup',
        () async {
      final config = Ensemble().getConfig();
      if (config != null) {
        await applyTestBootstrap(config, ctx.setup);
      }
      ctx.applyRuntimeEnv();
      for (final entry in ctx.testCase.mocks.apis.entries) {
        ctx.apiOverlay.setMock(entry.key, entry.value);
      }
      if (config != null) {
        installTestApiOverlay(config, ctx.apiOverlay);
      }
    });
  }

  /// Wipes all public / encrypted / keychain storage. Destructive — only used
  /// when [resetDeviceStorage] is set or when capturing an empty baseline.
  static Future<void> wipeAllPersistentStorage() async {
    final storage = StorageManager();
    await AppSessionSnapshot.clearPersistentStorage(storage);
  }

  /// Captures the pre-suite storage baseline once. When
  /// [resetDeviceStorage] is true, wipes first so the baseline is empty.
  static Future<void> ensurePreSuiteStorageSnapshot() async {
    if (_preSuiteStorageSnapshot != null) return;
    final capture = _preSuiteStorageSnapshotCapture ??=
        Future<AppSessionSnapshot>.microtask(() async {
      requirePhysicalDeviceStorageAcknowledgment();
      if (resetDeviceStorage) {
        await wipeAllPersistentStorage();
      }
      final snapshot = await AppSessionSnapshot.capture();
      _preSuiteStorageSnapshot = snapshot;
      return snapshot;
    });
    try {
      await capture;
    } finally {
      if (identical(_preSuiteStorageSnapshotCapture, capture)) {
        _preSuiteStorageSnapshotCapture = null;
      }
    }
  }

  /// Restores device storage to the pre-suite baseline so independent tests
  /// do not inherit keys written by earlier tests, while preserving whatever
  /// already existed on the device before the suite started.
  static Future<void> _clearPersistentTestState() async {
    await restorePreSuiteStorage();
  }

  /// Restores the cached pre-suite storage baseline (capturing it first if needed).
  static Future<void> restorePreSuiteStorage() async {
    return await RunnerBenchmark.async('lifecycle', 'restorePreSuiteStorage',
        () async {
      await ensurePreSuiteStorageSnapshot();
      await _preSuiteStorageSnapshot!.restore();
    });
  }

  /// Restores the pre-suite baseline at suite teardown (including after
  /// failures) so the device returns to its pre-run storage state.
  ///
  /// Invoked from the suite entry `finally` and again from package `tearDown`
  /// so both Dart exception exits and flutter_test teardown paths restore.
  /// Safe to call repeatedly: after the first attempt the baseline is cleared
  /// so a second call is a no-op (avoids double-restore across finally/tearDown).
  static Future<void> restorePreSuiteStorageAtSuiteEnd() async {
    var snapshot = _preSuiteStorageSnapshot;
    final pendingCapture = _preSuiteStorageSnapshotCapture;
    if (snapshot == null && pendingCapture != null) {
      await pendingCapture;
      snapshot = _preSuiteStorageSnapshot;
    }
    if (snapshot == null) return;
    // Clear before restore so a second call (tearDown after finally) is a
    // no-op even if restore throws — the first failure is the one reported.
    _preSuiteStorageSnapshot = null;
    await snapshot.restore();
  }

  /// Test hook: drop the cached baseline between unit tests.
  static void resetPreSuiteStorageSnapshotForTest() {
    _preSuiteStorageSnapshot = null;
    _preSuiteStorageSnapshotCapture = null;
  }

  /// Test hook exposing [restorePreSuiteStorage].
  static Future<void> restorePreSuiteStorageForTest() =>
      restorePreSuiteStorage();

  static void resetTestRuntime({NavigationFlowRecorder? navigationFlow}) {
    navigationFlow
      ?..clear()
      ..onScreenAdded = null;
    LiveAsyncCallSupport.reset();
    Ensemble.resetInitManagersForTest();
  }
}
