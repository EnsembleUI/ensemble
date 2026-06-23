/// Declarative test document and run results.
library;

class EnsembleTestRunRequest {
  final String? appPath;
  final String? appHome;
  final String? i18nPath;
  final List<EnsembleTestCase> tests;
  final EnsembleTestEnvironment environment;

  const EnsembleTestRunRequest({
    this.appPath,
    this.appHome,
    this.i18nPath,
    required this.tests,
    this.environment = const EnsembleTestEnvironment(),
  });
}

class EnsembleTestEnvironment {
  final Map<String, dynamic> env;

  const EnsembleTestEnvironment({this.env = const {}});
}

class EnsembleTestCase {
  final String id;
  final String? type;

  /// Cold-start screen. Omit when [prerequisite] is set.
  final String? startScreen;

  /// Test [id] that must run before this one (same app session).
  final String? prerequisite;
  final Map<String, dynamic> initialState;
  final TestMocks mocks;
  final List<TestStep> steps;

  const EnsembleTestCase({
    required this.id,
    this.type,
    this.startScreen,
    this.prerequisite,
    this.initialState = const {},
    this.mocks = const TestMocks(),
    required this.steps,
  });

  bool get hasStartScreen => startScreen != null && startScreen!.isNotEmpty;

  bool get hasPrerequisite => prerequisite != null && prerequisite!.isNotEmpty;
}

class TestMocks {
  final Map<String, MockAPIResponse> apis;

  const TestMocks({this.apis = const {}});
}

class MockAPIResponse {
  final int statusCode;
  final dynamic body;
  final Map<String, dynamic>? headers;
  final int? delayMs;

  const MockAPIResponse({
    this.statusCode = 200,
    this.body,
    this.headers,
    this.delayMs,
  });
}

class TestStep {
  /// YAML step key (e.g. `expectVisible`, `group`).
  final String type;
  final Map<String, dynamic> args;

  /// Nested steps for [group], [repeat], [optional], [ifVisible].
  final List<TestStep> nestedSteps;

  const TestStep({
    required this.type,
    required this.args,
    this.nestedSteps = const [],
  });

  /// Canonical handler name after alias resolution.
  String get canonicalType => type;

  TestStep withCanonicalType(String canonical) => TestStep(
        type: canonical,
        args: args,
        nestedSteps: nestedSteps,
      );

  Map<String, dynamic> toJson() => {
        type: args,
        if (nestedSteps.isNotEmpty)
          'steps': nestedSteps.map((s) => s.toJson()).toList(),
      };
}

class EnsembleTestRunResult {
  final List<EnsembleSingleTestResult> results;

  const EnsembleTestRunResult({required this.results});

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
      };
}

enum TestStatus { passed, failed }

class EnsembleSingleTestResult {
  final String testId;
  final TestStatus status;
  final int durationMs;
  final int? failedStepIndex;
  final TestStep? failedStep;
  final String? message;
  final String? stackTrace;
  final List<String> logs;
  final EnsembleTestReportDetails? report;

  const EnsembleSingleTestResult({
    required this.testId,
    required this.status,
    required this.durationMs,
    this.failedStepIndex,
    this.failedStep,
    this.message,
    this.stackTrace,
    this.logs = const [],
    this.report,
  });

  factory EnsembleSingleTestResult.passed({
    required String testId,
    required int durationMs,
    List<String> logs = const [],
    EnsembleTestReportDetails? report,
  }) =>
      EnsembleSingleTestResult(
        testId: testId,
        status: TestStatus.passed,
        durationMs: durationMs,
        logs: logs,
        report: report,
      );

  factory EnsembleSingleTestResult.failed({
    required String testId,
    required int durationMs,
    int? failedStepIndex,
    TestStep? failedStep,
    String? error,
    String? stackTrace,
    List<String> logs = const [],
    EnsembleTestReportDetails? report,
  }) =>
      EnsembleSingleTestResult(
        testId: testId,
        status: TestStatus.failed,
        durationMs: durationMs,
        failedStepIndex: failedStepIndex,
        failedStep: failedStep,
        message: error,
        stackTrace: stackTrace,
        logs: logs,
        report: report,
      );

  Map<String, dynamic> toJson() => {
        'testId': testId,
        'status': status.name,
        'durationMs': durationMs,
        if (failedStepIndex != null) 'failedStepIndex': failedStepIndex,
        if (failedStep != null) 'failedStep': failedStep!.toJson(),
        if (message != null) 'message': message,
        if (stackTrace != null) 'stackTrace': stackTrace,
        'logs': logs,
        if (report != null) 'report': report!.toJson(),
      };
}

/// Human-readable run metadata for console reports (see [TestReporter]).
class EnsembleTestReportDetails {
  /// Display start screen (explicit or inherited from runtime).
  final String startScreen;
  final String? endScreen;
  final String? prerequisite;
  final List<String> screensVisited;
  final List<String> stepsOutline;

  const EnsembleTestReportDetails({
    required this.startScreen,
    this.endScreen,
    this.prerequisite,
    this.screensVisited = const [],
    this.stepsOutline = const [],
  });

  Map<String, dynamic> toJson() => {
        'startScreen': startScreen,
        if (endScreen != null) 'endScreen': endScreen,
        if (prerequisite != null) 'prerequisite': prerequisite,
        'screensVisited': screensVisited,
        'stepsOutline': stepsOutline,
      };
}

/// Thrown when a test step or assertion fails.
class EnsembleTestFailure implements Exception {
  final String message;

  EnsembleTestFailure(this.message);

  @override
  String toString() => message;
}
