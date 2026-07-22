/// Declarative test document and run results.
library;

/// Request object describing an Ensemble YAML test run.
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

/// Environment overrides applied to a YAML test run.
class EnsembleTestEnvironment {
  final Map<String, dynamic> env;

  const EnsembleTestEnvironment({this.env = const {}});
}

/// Parsed definition of a single YAML test case.
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
        if (tags.isNotEmpty) 'tags': tags,
        if (description != null) 'description': description,
        if (owner != null) 'owner': owner,
        if (priority != null) 'priority': priority,
        if (retry > 0) 'retry': retry,
        if (deviceTarget != null) 'device': deviceTarget!.id,
      };
}

/// One scenario from a scenario-based test suite.
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

class EnsembleTestConfig {
  final List<TestServiceConfig> services;
  final List<String> mockFiles;
  final Map<String, dynamic> inlineMocks;
  final Map<String, dynamic> initialState;

  /// Suite device matrix (platform/model + optional locale). When non-empty,
  /// each test runs once per entry.
  final List<TestDeviceTarget> devices;
  final ScreenshotConfig screenshots;
  final PerformanceConfig performance;
  final DumpTreeConfig dumpTree;
  final LogApiCallsConfig logApiCalls;
  final LogStorageConfig logStorage;
  final TimerRewriteConfig timers;
  final WifiTestConfig wifi;

  const EnsembleTestConfig({
    this.services = const [],
    this.mockFiles = const [],
    this.inlineMocks = const {},
    this.initialState = const {},
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

class PerformanceConfig {
  final bool enabled;

  const PerformanceConfig({
    this.enabled = false,
  });
}

class TimerRewriteConfig {
  final bool enabled;
  final int maxStartAfterSeconds;
  final int maxRepeatIntervalSeconds;

  const TimerRewriteConfig({
    this.enabled = false,
    this.maxStartAfterSeconds = 1,
    this.maxRepeatIntervalSeconds = 1,
  });
}

class DumpTreeConfig {
  final bool enabled;

  const DumpTreeConfig({
    this.enabled = false,
  });
}

class LogApiCallsConfig {
  final bool enabled;

  const LogApiCallsConfig({
    this.enabled = false,
  });
}

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

  Map<String, dynamic> toScreenshotArgs() => {
        'platform': platform,
        'model': model,
      };
}

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

/// Mock configuration attached to a test case.
class TestMocks {
  final Map<String, MockAPIResponse> apis;

  const TestMocks({this.apis = const {}});
}

/// Mock API response returned by the test HTTP provider.
class MockAPIResponse {
  final int statusCode;
  final dynamic body;
  final Map<String, dynamic>? headers;
  final int? delayMs;
  final List<MockAPIResponse> responses;

  const MockAPIResponse({
    this.statusCode = 200,
    this.body,
    this.headers,
    this.delayMs,
    this.responses = const [],
  });
}

/// Single executable step from a YAML test file.
class TestStep {
  /// YAML step key (e.g. `expectVisible`, `group`).
  final String type;
  final Map<String, dynamic> args;
  final TestMocks mocks;

  /// Nested steps for control-flow step types such as `group` and `repeat`.
  final List<TestStep> nestedSteps;

  const TestStep({
    required this.type,
    required this.args,
    this.mocks = const TestMocks(),
    this.nestedSteps = const [],
  });

  /// Canonical handler name after alias resolution.
  String get canonicalType => type;

  TestStep withCanonicalType(String canonical) => TestStep(
        type: canonical,
        args: args,
        mocks: mocks,
        nestedSteps: nestedSteps,
      );

  Map<String, dynamic> toJson() => {
        type: args,
        if (nestedSteps.isNotEmpty)
          'steps': nestedSteps.map((s) => s.toJson()).toList(),
      };
}

/// Aggregate result for a YAML test run.
class EnsembleTestRunResult {
  final List<EnsembleSingleTestResult> results;
  final List<String> suiteLogs;

  const EnsembleTestRunResult({
    required this.results,
    this.suiteLogs = const [],
  });

  int get passedCount =>
      results.where((r) => r.status == TestStatus.passed).length;
  int get failedCount =>
      results.where((r) => r.status == TestStatus.failed).length;

  String get summary =>
      '$passedCount passed, $failedCount failed (${results.length} total)';

  Map<String, dynamic> toJson() => {
        'status': failedCount > 0 ? 'failed' : 'passed',
        'total': results.length,
        'passed': passedCount,
        'failed': failedCount,
        'results': results.map((r) => r.toJson()).toList(),
        if (suiteLogs.isNotEmpty) 'suiteLogs': suiteLogs,
      };
}

/// Status of a test case (passed, failed, or pending mid-run).
enum TestStatus { passed, failed, pending }

/// Result for one executed YAML test case.
class EnsembleSingleTestResult {
  final String testId;
  final Map<String, dynamic> metadata;
  final TestStatus status;
  final int durationMs;
  final int attempts;
  final int retry;
  final int? failedStepIndex;
  final TestStep? failedStep;
  final String? message;
  final String? stackTrace;
  final List<String> logs;
  final EnsembleTestReportDetails? report;

  const EnsembleSingleTestResult({
    required this.testId,
    this.metadata = const {},
    required this.status,
    required this.durationMs,
    this.attempts = 1,
    this.retry = 0,
    this.failedStepIndex,
    this.failedStep,
    this.message,
    this.stackTrace,
    this.logs = const [],
    this.report,
  });

  factory EnsembleSingleTestResult.passed({
    required String testId,
    Map<String, dynamic> metadata = const {},
    required int durationMs,
    int attempts = 1,
    int retry = 0,
    List<String> logs = const [],
    EnsembleTestReportDetails? report,
  }) =>
      EnsembleSingleTestResult(
        testId: testId,
        metadata: metadata,
        status: TestStatus.passed,
        durationMs: durationMs,
        attempts: attempts,
        retry: retry,
        logs: logs,
        report: report,
      );

  factory EnsembleSingleTestResult.failed({
    required String testId,
    Map<String, dynamic> metadata = const {},
    required int durationMs,
    int attempts = 1,
    int retry = 0,
    int? failedStepIndex,
    TestStep? failedStep,
    String? error,
    String? stackTrace,
    List<String> logs = const [],
    EnsembleTestReportDetails? report,
  }) =>
      EnsembleSingleTestResult(
        testId: testId,
        metadata: metadata,
        status: TestStatus.failed,
        durationMs: durationMs,
        attempts: attempts,
        retry: retry,
        failedStepIndex: failedStepIndex,
        failedStep: failedStep,
        message: error,
        stackTrace: stackTrace,
        logs: logs,
        report: report,
      );

  Map<String, dynamic> toJson() => {
        'testId': testId,
        if (metadata.isNotEmpty) 'metadata': metadata,
        'status': status.name,
        'durationMs': durationMs,
        if (attempts > 1) 'attempts': attempts,
        if (retry > 0) 'retry': retry,
        if (failedStepIndex != null) 'failedStepIndex': failedStepIndex,
        if (failedStep != null) 'failedStep': failedStep!.toJson(),
        if (message != null) 'message': message,
        if (status == TestStatus.failed) 'failure': _failureJson(),
        if (stackTrace != null) 'stackTrace': stackTrace,
        'logs': logs,
        if (report != null) 'report': report!.toJson(),
      };

  Map<String, dynamic> _failureJson() {
    final text = message ?? '';
    final kind = _failureKind(text);
    return {
      'kind': kind,
      if (failedStep != null) 'step': failedStep!.type,
      if (failedStepIndex != null) 'stepIndex': failedStepIndex,
      if (failedStep?.args['id'] != null) 'expected': failedStep!.args['id'],
      'actual': text,
      'suggestions': _failureSuggestions(kind, failedStep),
      if (report != null)
        'context': {
          'currentScreen': report!.endScreen ?? report!.startScreen,
          'screensVisited': report!.screensVisited,
        },
    };
  }

  String _failureKind(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('timeout') || lower.contains('timed out')) {
      return 'timeout';
    }
    if (lower.contains('api')) return 'apiMismatch';
    if (lower.contains('navigation') ||
        lower.contains('navigated') ||
        lower.contains('screen')) {
      return 'navigationMismatch';
    }
    if (lower.contains('widget') ||
        lower.contains('visible') ||
        lower.contains('finder')) {
      return 'missingWidget';
    }
    if (lower.contains('yaml') ||
        lower.contains('parse') ||
        lower.contains('invalid')) {
      return 'parseError';
    }
    return 'assertionFailure';
  }

  List<String> _failureSuggestions(String kind, TestStep? step) {
    switch (kind) {
      case 'missingWidget':
        final id = step?.args['id'];
        return [
          if (id != null)
            'Verify "$id" exists as id/testId on the active screen.',
          'Run --inspect-app to list available widget ids.',
        ];
      case 'apiMismatch':
        return [
          'Check API name spelling against --inspect-app output.',
          'Use root mocks with .mock.json files for mocked API responses.',
        ];
      case 'navigationMismatch':
        return [
          'Check expected screen name against --inspect-app navigation targets.',
          'Add waitForNavigation after navigation-triggering actions.',
        ];
      case 'timeout':
        return [
          'Wait for a stable widget or API completion before asserting.',
          'Increase timeoutMs only after confirming the expected UI appears.',
        ];
      case 'parseError':
        return [
          'Run --validate-only to find schema issues.',
        ];
      default:
        return [
          'Inspect the failedStep and report context to repair the test.'
        ];
    }
  }
}

/// Human-readable run metadata for console reports (see [TestReporter]).
class EnsembleTestReportDetails {
  /// Display start screen (explicit or inherited from runtime).
  final String startScreen;
  final String? endScreen;
  final String? session;
  final List<String> screensVisited;
  final List<String> stepsOutline;

  /// Wall-clock ms for each top-level step (same order as [EnsembleTestCase.steps]).
  /// Shorter than the step list when the run failed mid-suite.
  final List<int> stepDurationsMs;
  final List<String> stepStartTimes;

  const EnsembleTestReportDetails({
    required this.startScreen,
    this.endScreen,
    this.session,
    this.screensVisited = const [],
    this.stepsOutline = const [],
    this.stepDurationsMs = const [],
    this.stepStartTimes = const [],
  });

  factory EnsembleTestReportDetails.fromJson(Map<String, dynamic> json) {
    return EnsembleTestReportDetails(
      startScreen: json['startScreen']?.toString() ?? '(unknown)',
      endScreen: json['endScreen']?.toString(),
      session: json['session']?.toString(),
      screensVisited: (json['screensVisited'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      stepsOutline: (json['stepsOutline'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      stepDurationsMs: (json['stepDurationsMs'] as List<dynamic>? ?? const [])
          .map((value) => value is int ? value : int.tryParse('$value') ?? 0)
          .toList(),
      stepStartTimes: (json['stepStartTimes'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'startScreen': startScreen,
        if (endScreen != null) 'endScreen': endScreen,
        if (session != null) 'session': session,
        'screensVisited': screensVisited,
        'stepsOutline': stepsOutline,
        if (stepDurationsMs.isNotEmpty) 'stepDurationsMs': stepDurationsMs,
        if (stepStartTimes.isNotEmpty) 'stepStartTimes': stepStartTimes,
      };
}

/// Thrown when a test step or assertion fails.
class EnsembleTestFailure implements Exception {
  final String message;

  EnsembleTestFailure(this.message);

  @override
  String toString() => message;
}
