/// Declarative test document and run results.
library;

import 'test_step.dart';

export 'package:ensemble_test_runner/models/test_failure_details.dart'
    show TestFailureDetails, TestFailureKind;
export 'test_step.dart';
export 'test_results.dart';

/// Request object describing an Ensemble test run.
class EnsembleTestRunRequest {
  final String? appPath;
  final String? appHome;
  final String? i18nPath;
  final List<EnsembleTestCase> tests;
  final EnsembleTestConfig config;
  final EnsembleTestEnvironment environment;

  const EnsembleTestRunRequest({
    this.appPath,
    this.appHome,
    this.i18nPath,
    required this.tests,
    this.config = const EnsembleTestConfig(),
    this.environment = const EnsembleTestEnvironment(),
  });
}

/// Environment overrides applied to a test run.
class EnsembleTestEnvironment {
  final Map<String, dynamic> env;

  const EnsembleTestEnvironment({this.env = const {}});
}

/// Parsed definition of a single declarative test case.
class EnsembleTestCase {
  final String id;
  final String? sourcePath;
  final String? type;
  final String? feature;
  final List<String> tags;
  final String? description;
  final String? owner;
  final String? priority;
  final bool parallel;
  final int retry;

  /// Cold-start screen.
  final String? startScreen;
  final Map<String, dynamic> startScreenInputs;

  /// Test [id] whose captured storage state is restored before [startScreen].
  final String? session;
  final String? profile;
  final List<String> profiles;
  final String? scenarioId;
  final String? scenarioDescription;
  final List<String> mockFiles;
  final Map<String, dynamic> inlineMocks;
  final List<TestScenario> scenarios;
  final Map<String, dynamic> initialState;

  /// Headless actions executed before the start screen is mounted.
  final List<TestStep> setupSteps;

  /// Runtime API mocks resolved from [mockFiles].
  final TestMocks mocks;
  final List<TestStep> steps;

  /// Set when suite `devices` expands this test for one device.
  final TestDeviceTarget? deviceTarget;

  /// Optional contact-sheet filename key (defaults to [id]).
  final String? screenshotSheetId;

  const EnsembleTestCase({
    required this.id,
    this.sourcePath,
    this.type,
    this.feature,
    this.tags = const [],
    this.description,
    this.owner,
    this.priority,
    this.parallel = true,
    this.retry = 0,
    this.startScreen,
    this.startScreenInputs = const {},
    this.session,
    this.profile,
    this.profiles = const [],
    this.scenarioId,
    this.scenarioDescription,
    this.mockFiles = const [],
    this.inlineMocks = const {},
    this.scenarios = const [],
    this.initialState = const {},
    this.setupSteps = const [],
    this.mocks = const TestMocks(),
    required this.steps,
    this.deviceTarget,
    this.screenshotSheetId,
  });

  bool get hasStartScreen => startScreen != null && startScreen!.isNotEmpty;

  bool get hasSession => session != null && session!.isNotEmpty;

  /// Contact sheet filename / aggregation key.
  String get resolvedScreenshotSheetId => screenshotSheetId ?? id;

  Map<String, dynamic> get metadataJson => {
        if (feature != null) 'feature': feature,
        if (profile != null) 'profile': profile,
        if (scenarioId != null) 'scenarioId': scenarioId,
        if (scenarioDescription != null)
          'scenarioDescription': scenarioDescription,
        if (tags.isNotEmpty) 'tags': tags,
        if (description != null) 'description': description,
        if (owner != null) 'owner': owner,
        if (priority != null) 'priority': priority,
        if (retry > 0) 'retry': retry,
        if (deviceTarget != null) 'device': deviceTarget!.toJson(),
      };
}

/// One scenario from a scenario-based test suite.
///
/// Scenarios share the test's steps while providing different variables and
/// mock inputs. The runner expands them into independent test results.
class TestScenario {
  final String id;
  final String? description;
  final Map<String, dynamic> vars;

  const TestScenario({
    required this.id,
    this.description,
    this.vars = const {},
  });
}

/// Suite-wide configuration loaded from `tests/config.yaml`.
///
/// The configuration is applied to every discovered test. Use test-level
/// fields only for data that genuinely belongs to one test case, such as its
/// description, steps, and scenario selection.
class EnsembleTestConfig {
  final ExecutionMode mode;
  final List<TestServiceConfig> services;
  final List<String> mockFiles;
  final Map<String, dynamic> inlineMocks;
  final Map<String, dynamic> initialState;
  final String? defaultProfile;
  final Map<String, TestProfile> profiles;
  final Map<String, List<String>> profileGroups;

  /// Suite device matrix (platform/model + optional locale/theme).
  ///
  /// Widget mode expands each test once per entry and applies the viewport.
  /// Integration mode keeps entries whose [TestDeviceTarget.platform] matches
  /// the connected emulator/simulator so locale/theme still apply, and ignores
  /// viewport/model because the real display is used.
  final List<TestDeviceTarget> devices;
  final ScreenshotConfig screenshots;
  final PerformanceConfig performance;
  final DumpTreeConfig dumpTree;
  final LogApiCallsConfig logApiCalls;
  final LogStorageConfig logStorage;
  final TimerRewriteConfig timers;
  final WifiTestConfig wifi;

  const EnsembleTestConfig({
    this.mode = ExecutionMode.widget,
    this.services = const [],
    this.mockFiles = const [],
    this.inlineMocks = const {},
    this.initialState = const {},
    this.defaultProfile,
    this.profiles = const {},
    this.profileGroups = const {},
    this.devices = const [],
    this.screenshots = const ScreenshotConfig(),
    this.performance = const PerformanceConfig(),
    this.dumpTree = const DumpTreeConfig(),
    this.logApiCalls = const LogApiCallsConfig(),
    this.logStorage = const LogStorageConfig(),
    this.timers = const TimerRewriteConfig(),
    this.wifi = const WifiTestConfig(),
  });

  bool get hasDeviceMatrix => devices.isNotEmpty;

  EnsembleTestConfig copyWith({
    ExecutionMode? mode,
    List<TestServiceConfig>? services,
    List<String>? mockFiles,
    Map<String, dynamic>? inlineMocks,
    Map<String, dynamic>? initialState,
    String? defaultProfile,
    Map<String, TestProfile>? profiles,
    Map<String, List<String>>? profileGroups,
    List<TestDeviceTarget>? devices,
    ScreenshotConfig? screenshots,
    PerformanceConfig? performance,
    DumpTreeConfig? dumpTree,
    LogApiCallsConfig? logApiCalls,
    LogStorageConfig? logStorage,
    TimerRewriteConfig? timers,
    WifiTestConfig? wifi,
  }) {
    return EnsembleTestConfig(
      mode: mode ?? this.mode,
      services: services ?? this.services,
      mockFiles: mockFiles ?? this.mockFiles,
      inlineMocks: inlineMocks ?? this.inlineMocks,
      initialState: initialState ?? this.initialState,
      defaultProfile: defaultProfile ?? this.defaultProfile,
      profiles: profiles ?? this.profiles,
      profileGroups: profileGroups ?? this.profileGroups,
      devices: devices ?? this.devices,
      screenshots: screenshots ?? this.screenshots,
      performance: performance ?? this.performance,
      dumpTree: dumpTree ?? this.dumpTree,
      logApiCalls: logApiCalls ?? this.logApiCalls,
      logStorage: logStorage ?? this.logStorage,
      timers: timers ?? this.timers,
      wifi: wifi ?? this.wifi,
    );
  }
}

/// Host environment used to execute a declarative test suite.
enum ExecutionMode { widget, integration }

/// A named profile containing reusable mocks and initial state.
class TestProfile {
  final List<String> mockFiles;
  final Map<String, dynamic> inlineMocks;
  final Map<String, dynamic> initialState;

  const TestProfile({
    this.mockFiles = const [],
    this.inlineMocks = const {},
    this.initialState = const {},
  });
}

/// Suite Wi-Fi test double settings from `tests/config.yaml`.
///
/// Doubles are installed only when the app's wifi module is enabled
/// (`useWifi`, not a stub). Per-test behavior is controlled via
/// [modeStorageKey] in `initialState.storage` (`connect_fail`,
/// `verify_fail`; default is success).
class WifiTestConfig {
  static const successMode = 'success';
  static const connectFailMode = 'connect_fail';
  static const verifyFailMode = 'verify_fail';
  static const defaultModeStorageKey = 'wifiTestMode';
  static const supportedModes = {
    successMode,
    connectFailMode,
    verifyFailMode,
  };

  final String ssid;
  final String verifyFailSsid;
  final String modeStorageKey;

  const WifiTestConfig({
    this.ssid = '',
    this.verifyFailSsid = 'Wrong_Network',
    this.modeStorageKey = defaultModeStorageKey,
  });
}

/// A local process that the runner starts before executing tests.
class TestServiceConfig {
  final String name;
  final String command;
  final String? url;
  final List<String> arguments;
  final String? workingDirectory;
  final Map<String, String> environment;
  final String? readyUrl;
  final int readyTimeoutMs;

  const TestServiceConfig({
    required this.name,
    required this.command,
    this.url,
    this.arguments = const [],
    this.workingDirectory,
    this.environment = const {},
    this.readyUrl,
    this.readyTimeoutMs = 10000,
  });

  String? get resolvedReadyUrl {
    final value = readyUrl;
    if (value == null ||
        value.isEmpty ||
        Uri.tryParse(value)?.isAbsolute == true) {
      return value;
    }
    final base = url;
    if (base == null || base.isEmpty) return value;
    return Uri.parse(base).resolve(value).toString();
  }

  Map<String, String> get resolvedEnvironment {
    final resolved = {...environment};
    final uri = url == null ? null : Uri.tryParse(url!);
    if (!resolved.containsKey('PORT') && uri != null && uri.hasPort) {
      resolved['PORT'] = '${uri.port}';
    }
    return resolved;
  }
}

/// Controls suite-level application performance logging.
class PerformanceConfig {
  final bool enabled;

  const PerformanceConfig({
    this.enabled = false,
  });
}

/// Controls timer normalization used by the Flutter test host.
class TimerRewriteConfig {
  final bool enabled;
  final int maxStartAfterSeconds;
  final int maxRepeatIntervalSeconds;

  /// When set, caps YAML `maxNumberOfTimes` on timers (keeps long poll loops
  /// like firmware disconnect waits from running for minutes under tests).
  final int? maxNumberOfTimes;

  /// Optional per-screen cap, keyed by the screen YAML filename without `.yaml`.
  final Map<String, int> maxNumberOfTimesByScreen;

  const TimerRewriteConfig({
    this.enabled = false,
    this.maxStartAfterSeconds = 1,
    this.maxRepeatIntervalSeconds = 1,
    this.maxNumberOfTimes,
    this.maxNumberOfTimesByScreen = const {},
  });
}

/// Controls writing the rendered widget tree to a diagnostic artifact.
class DumpTreeConfig {
  final bool enabled;

  const DumpTreeConfig({
    this.enabled = false,
  });
}

/// Controls writing the per-test API call log artifact.
///
/// The default remains enabled for compatibility with existing suites. Set
/// `logApiCalls.enabled: false` to avoid collecting and writing the sidecar.
class LogApiCallsConfig {
  final bool enabled;

  const LogApiCallsConfig({this.enabled = true});
}

/// Controls writing the final local storage snapshot to an artifact.
class LogStorageConfig {
  final bool enabled;
  final String? key;

  const LogStorageConfig({
    this.enabled = false,
    this.key,
  });
}

/// One device (+ optional locale/theme) in a suite run matrix.
class TestDeviceTarget {
  final String id;
  final String platform;
  final String model;
  final String? locale;

  /// Ensemble theme name or alias (`light` / `dark` → `Light` / `Dark`).
  final String? theme;

  const TestDeviceTarget({
    required this.id,
    required this.platform,
    required this.model,
    this.locale,
    this.theme,
  });

  String get displayLabel {
    final parts = <String>[model];
    final localeValue = locale?.trim();
    if (localeValue != null && localeValue.isNotEmpty) {
      parts.add(localeValue);
    }
    final themeValue = theme?.trim();
    if (themeValue != null && themeValue.isNotEmpty) {
      parts.add(themeValue);
    }
    return parts.join(' · ');
  }

  /// Canonical platform key used to match Flutter integration targets.
  ///
  /// `android*` → `android`; `ios` / `iphone` / `ipad` → `ios`.
  static String normalizePlatform(String raw) {
    final key = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (key.startsWith('android')) return 'android';
    if (key.startsWith('ios') ||
        key.startsWith('iphone') ||
        key.startsWith('ipad')) {
      return 'ios';
    }
    return key;
  }

  bool matchesPlatform(String other) =>
      normalizePlatform(platform) == normalizePlatform(other);

  Map<String, dynamic> toScreenshotArgs() => {
        'platform': platform,
        'model': model,
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'platform': platform,
        'model': model,
        if (locale != null && locale!.isNotEmpty) 'locale': locale,
        if (theme != null && theme!.isNotEmpty) 'theme': theme,
        'label': displayLabel,
      };
}

/// Controls automatic per-step screenshot capture and filtering.
class ScreenshotConfig {
  final bool enabled;
  final List<String> includeSteps;
  final List<String> excludeSteps;

  const ScreenshotConfig({
    this.enabled = false,
    this.includeSteps = const [],
    this.excludeSteps = const [],
  });

  bool shouldCaptureStep(String stepType) {
    if (!enabled) return false;
    if (excludeSteps.contains(stepType)) return false;
    if (includeSteps.isNotEmpty && !includeSteps.contains(stepType)) {
      return false;
    }
    return true;
  }
}
