import 'dart:io';

import 'package:ensemble_test_runner/mocks/adobe_test_setup.dart';
import 'package:ensemble_test_runner/runner/test_app_metadata.dart';
import 'package:ensemble_test_runner/src/integrations/test_integration_registration.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';

/// Owns host setup for widget and integration execution environments.
///
/// This boundary keeps platform channels, optional integrations, and host
/// metadata out of the execution harness orchestration.
class TestHarnessHostRuntime {
  // Optional integrations are supplied by the selected entry point. Keeping
  // this default empty prevents application-owned and integration entry points
  // from pulling Firebase implementation libraries into their import graph.
  static TestIntegrationRegistry _testIntegrations =
      TestIntegrationRegistry(const []);
  // Keep the host storage directory lazy. Integration runs use the native
  // host and never need the widget-test channel backing this directory, so
  // creating it during class loading only adds startup work and a filesystem
  // side effect to those runs.
  static String? _testStoragePath;
  static bool _staleStoragePruned = false;

  static String get _storagePath => _testStoragePath ??=
      Directory.systemTemp.createTempSync('ensemble_test_runner_storage_').path;

  /// Exposes initialization state for the startup-boundary regression test.
  static bool get testStoragePathCreatedForTest => _testStoragePath != null;

  /// Removes the process-owned backing directory used by mocked path
  /// provider calls. It is recreated lazily for the next test process.
  static void disposeTestStorage() {
    final path = _testStoragePath;
    _testStoragePath = null;
    if (path != null) {
      final directory = Directory(path);
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    }
    _secureStorage.clear();
  }

  static final Map<String, String> _secureStorage = {};

  /// Widget tests mock MethodChannels because there is no host OS plugin.
  /// Integration runs inside a real Android/iOS binary; those plugins must
  /// stay registered. Host drivers call this in both modes.
  static void ensureTestPlugins() {
    TestWidgetsFlutterBinding.ensureInitialized();
    pruneStaleTestStorageDirectories();
    if (_usesNativeHostPlugins) {
      ensureIntegrationRuntime();
      return;
    }
    _testIntegrations.installAll();
    ensureAdobeAnalyticsMocksForTest();
    HttpOverrides.global = RealNetworkHttpOverrides();
    const pathProviderChannel =
        MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      switch (call.method) {
        case 'getApplicationDocumentsDirectory':
        case 'getTemporaryDirectory':
        case 'getApplicationSupportDirectory':
          return _storagePath;
        default:
          return null;
      }
    });

    const packageInfoChannel =
        MethodChannel('dev.fluttercommunity.plus/package_info');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(packageInfoChannel, (call) async {
      if (call.method == 'getAll') {
        return TestAppMetadata.packageInfo(Directory.current.path);
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
        return deviceInfoMockForTest();
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
  }

  /// Removes runner-owned temporary directories left by a process terminated
  /// before suite teardown. Normal runs remove their own storage and artifact
  /// transport directories; the age threshold protects active concurrent runs.
  @visibleForTesting
  static void pruneStaleTestStorageDirectories({
    Directory? temporaryRoot,
    DateTime? now,
    Duration staleAfter = const Duration(days: 1),
  }) {
    if (_staleStoragePruned && temporaryRoot == null) return;
    final root = temporaryRoot ?? Directory.systemTemp;
    final cutoff = (now ?? DateTime.now()).subtract(staleAfter);
    try {
      for (final entity in root.listSync(followLinks: false)) {
        if (entity is! Directory || !_isRunnerTemporaryDirectory(entity)) {
          continue;
        }
        try {
          if (entity.statSync().modified.isBefore(cutoff)) {
            entity.deleteSync(recursive: true);
          }
        } on FileSystemException {
          // A concurrent cleanup or filesystem error must not block setup.
        }
      }
      if (temporaryRoot == null) _staleStoragePruned = true;
    } on FileSystemException {
      // Temp cleanup is best effort; the current suite still owns its directory.
    }
  }

  static bool _isRunnerTemporaryDirectory(Directory entity) {
    final name = entity.path.split(Platform.pathSeparator).last;
    return name.startsWith('ensemble_test_runner_storage_') ||
        name.startsWith('ensemble_artifacts_');
  }

  /// Selects the optional integrations for the next test execution path.
  ///
  /// Paths that do not use an integration can pass an empty iterable and do
  /// not load or initialize that integration's setup.
  static void configureTestIntegrations(
    Iterable<TestIntegrationRegistration> registrations,
  ) {
    _testIntegrations = TestIntegrationRegistry(registrations);
  }

  /// Runs selected integration hooks that require the app to be bootstrapped.
  static void afterTestPluginBootstrap() {
    _testIntegrations.afterBootstrap();
  }

  /// Initializes only runner-owned Dart listeners for a real application.
  /// Native plugin channels remain registered by the Android/iOS host app.
  static void ensureIntegrationRuntime() {
    TestWidgetsFlutterBinding.ensureInitialized();
  }

  static bool get _usesNativeHostPlugins =>
      const String.fromEnvironment(
        'ensembleTestExecutionMode',
        defaultValue: 'widget',
      ) ==
      'integration';

  /// Platform-shaped `device_info_plus` map. A macOS payload on iOS makes
  /// `IosDeviceInfo.fromMap` throw `type 'Null' is not a subtype of type
  /// 'String'` because required fields such as `name` are missing.
  static Map<String, Object?> deviceInfoMockForTest() {
    if (Platform.isIOS) {
      return {
        'name': 'iPhone',
        'systemName': 'iOS',
        'systemVersion': '17.0',
        'model': 'iPhone',
        'modelName': 'iPhone',
        'localizedModel': 'iPhone',
        'identifierForVendor': 'ensemble-test-device',
        'isPhysicalDevice': false,
        'isiOSAppOnMac': false,
        'isiOSAppOnVision': false,
        'physicalRamSize': 4096,
        'availableRamSize': 2048,
        'freeDiskSize': 1024,
        'totalDiskSize': 2048,
        'utsname': {
          'sysname': 'Darwin',
          'nodename': 'ensemble-test',
          'release': '23.0.0',
          'version': 'test',
          'machine': 'iPhone15,2',
        },
      };
    }
    if (Platform.isAndroid) {
      return {
        'version': {
          'baseOS': '',
          'sdkInt': 34,
          'release': '14',
          'codename': 'REL',
          'incremental': '1',
          'previewSdkInt': 0,
          'securityPatch': '2024-01-01',
        },
        'board': 'goldfish',
        'bootloader': 'unknown',
        'brand': 'google',
        'device': 'generic',
        'display': 'test',
        'fingerprint': 'google/test',
        'hardware': 'ranchu',
        'host': 'ensemble-test',
        'id': 'TEST',
        'manufacturer': 'Google',
        'model': 'sdk',
        'product': 'sdk',
        'name': 'Ensemble Test',
        'supported32BitAbis': <String>[],
        'supported64BitAbis': <String>['arm64-v8a'],
        'supportedAbis': <String>['arm64-v8a'],
        'tags': 'test',
        'type': 'user',
        'isPhysicalDevice': false,
        'freeDiskSize': 1024,
        'totalDiskSize': 2048,
        'systemFeatures': <String>[],
        'isLowRamDevice': false,
        'physicalRamSize': 4096,
        'availableRamSize': 2048,
      };
    }
    return {
      'computerName': 'Ensemble Test',
      'hostName': 'ensemble-test',
      'arch': 'arm64',
      'model': 'Mac',
      'modelName': 'Mac',
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
}

class RealNetworkHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context);
}
