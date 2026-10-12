/// Result and report projections for a test run.
library;

import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'package:ensemble_test_runner/models/test_failure_details.dart';
import 'package:ensemble_test_runner/src/core/operation.dart';
import 'test_step.dart';

/// Aggregate result for a test run.
/// Aggregate result for one complete runner invocation.
class EnsembleTestRunResult {
  final List<EnsembleSingleTestResult> results;
  final List<String> suiteLogs;
  final Map<String, dynamic> metadata;

  const EnsembleTestRunResult({
    required this.results,
    this.suiteLogs = const [],
    this.metadata = const {},
  });

  int get passedCount =>
      results.where((r) => r.status == TestStatus.passed).length;
  int get failedCount =>
      results.where((r) => r.status == TestStatus.failed).length;

  String get summary =>
      '$passedCount passed, $failedCount failed (${results.length} total)';

  Map<String, dynamic> toJson() => RunnerBenchmark.sync(
        'report',
        'serializeRunResult',
        () {
          // Serialize each case once and derive the aggregate counts during
          // that same pass. Report generation calls this on every completed
          // run, so separate passed/failed scans needlessly revisit the full
          // result list before encoding it.
          final serialized = <Map<String, dynamic>>[];
          var passed = 0;
          var failed = 0;
          for (final result in results) {
            if (result.status == TestStatus.passed) {
              passed++;
            } else {
              failed++;
            }
            serialized.add(result.toJson());
          }
          return {
            'status': failed > 0 ? 'failed' : 'passed',
            'total': serialized.length,
            'passed': passed,
            'failed': failed,
            'results': serialized,
            if (suiteLogs.isNotEmpty) 'suiteLogs': suiteLogs,
            if (metadata.isNotEmpty) 'metadata': metadata,
          };
        },
      );
}

/// Status of a finished test case.
/// Final status of an executed test case.
enum TestStatus { passed, failed }

/// Result for one executed declarative test case.
/// Result and diagnostics for one expanded test case run.
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

  /// Canonical operation responsible for the failure, when available.
  final String? failureOperation;
  final SourceLocation? failureSource;
  final List<String> logs;
  final EnsembleTestReportDetails? report;
  final TestFailureDetails? failure;
  final List<TestFailureDetails> secondaryFailures;
  final Map<String, bool> capabilityStatus;

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
    this.failureOperation,
    this.failureSource,
    this.logs = const [],
    this.report,
    this.failure,
    this.secondaryFailures = const [],
    this.capabilityStatus = const {},
  });

  /// Stable human-readable failure text shared by every report projection.
  ///
  /// Older execution paths populated [message], while newer paths can retain
  /// only structured [failure] details. Reporters must not choose different
  /// fallbacks for those two representations.
  String get effectiveFailureMessage {
    final legacy = message?.trim();
    if (legacy != null && legacy.isNotEmpty) return message!;
    final structured = failure?.message.trim();
    if (structured != null && structured.isNotEmpty) return failure!.message;
    return 'failed';
  }

  /// Stack text published to machine-readable and human-facing reports.
  ///
  /// A failed result without a useful stack still needs a non-empty diagnostic
  /// body. Keeping this fallback on the result model makes JSON, HTML, JUnit,
  /// and console projections agree instead of each deciding independently.
  String? get effectiveFailureStackTrace {
    if (status != TestStatus.failed) return stackTrace;
    final value = stackTrace?.trim();
    return value == null || value.isEmpty
        ? effectiveFailureMessage
        : stackTrace;
  }

  /// The failure details represented by the canonical JSON projection.
  ///
  /// Older execution paths only populated [message].  Keeping this fallback
  /// here means compact history and richer report formats expose the same
  /// inferred failure kind instead of disagreeing about whether a kind exists.
  TestFailureDetails? get effectiveFailureDetails {
    if (status != TestStatus.failed) return null;
    final details = failure;
    if (details != null && details.message.trim().isNotEmpty) return details;
    if (details != null) {
      return TestFailureDetails(
        kind: details.kind,
        message: effectiveFailureMessage,
        target: details.target,
        phase: details.phase,
      );
    }
    return TestFailureDetails.fromMessage(effectiveFailureMessage);
  }

  factory EnsembleSingleTestResult.passed({
    required String testId,
    Map<String, dynamic> metadata = const {},
    required int durationMs,
    int attempts = 1,
    int retry = 0,
    List<String> logs = const [],
    EnsembleTestReportDetails? report,
    Map<String, bool> capabilityStatus = const {},
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
        capabilityStatus: capabilityStatus,
      );

  factory EnsembleSingleTestResult.failed({
    required String testId,
    Map<String, dynamic> metadata = const {},
    required int durationMs,
    int attempts = 1,
    int retry = 0,
    int? failedStepIndex,
    TestStep? failedStep,
    String? message,
    String? stackTrace,
    String? failureOperation,
    SourceLocation? failureSource,
    List<String> logs = const [],
    EnsembleTestReportDetails? report,
    TestFailureDetails? failure,
    List<TestFailureDetails> secondaryFailures = const [],
    Map<String, bool> capabilityStatus = const {},
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
        message: message,
        stackTrace: stackTrace,
        failureOperation: failureOperation,
        failureSource: failureSource,
        logs: logs,
        report: report,
        failure: failure,
        secondaryFailures: secondaryFailures,
        capabilityStatus: capabilityStatus,
      );

  factory EnsembleSingleTestResult.fromJson(Map<String, dynamic> json) {
    final failureRaw = json['failure'];
    final secondaryRaw = json['secondaryFailures'];
    final capabilitiesRaw = json['capabilities'];
    return EnsembleSingleTestResult(
      testId: json['testId']?.toString() ?? '(unknown)',
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const {},
      status: json['status'] == TestStatus.passed.name
          ? TestStatus.passed
          : TestStatus.failed,
      durationMs: json['durationMs'] is int ? json['durationMs'] as int : 0,
      attempts: json['attempts'] is int ? json['attempts'] as int : 1,
      retry: json['retry'] is int ? json['retry'] as int : 0,
      failedStepIndex: json['failedStepIndex'] is int
          ? json['failedStepIndex'] as int
          : null,
      failedStep: json['failedStep'] is Map
          ? TestStep.fromJson(
              Map<String, dynamic>.from(json['failedStep'] as Map))
          : null,
      message: json['message']?.toString(),
      stackTrace: json['stackTrace']?.toString(),
      failureOperation: json['failureOperation']?.toString(),
      failureSource: json['failureSource'] is Map
          ? SourceLocation(
              (json['failureSource'] as Map)['path']?.toString() ?? '',
              (json['failureSource'] as Map)['stepPath']?.toString() ?? '',
            )
          : null,
      logs: (json['logs'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      report: json['report'] is Map
          ? EnsembleTestReportDetails.fromJson(
              Map<String, dynamic>.from(json['report'] as Map),
            )
          : null,
      failure: failureRaw is Map && failureRaw['message'] != null
          ? TestFailureDetails.fromJson(
              Map<String, dynamic>.from(failureRaw),
            )
          : null,
      secondaryFailures: secondaryRaw is List
          ? secondaryRaw
              .whereType<Map>()
              .map((value) => TestFailureDetails.fromJson(
                    Map<String, dynamic>.from(value),
                  ))
              .toList()
          : const [],
      capabilityStatus: capabilitiesRaw is Map
          ? capabilitiesRaw.map(
              (key, value) => MapEntry(key.toString(), value == true),
            )
          : const {},
    );
  }

  Map<String, dynamic> toJson() => {
        'testId': testId,
        if (metadata.isNotEmpty) 'metadata': metadata,
        'status': status.name,
        'durationMs': durationMs,
        if (attempts > 1) 'attempts': attempts,
        if (retry > 0) 'retry': retry,
        if (failedStepIndex != null) 'failedStepIndex': failedStepIndex,
        if (failedStep != null) 'failedStep': failedStep!.toJson(),
        // Failed results have one canonical message. Older execution paths
        // can leave a blank legacy message while structured failure details
        // contain the useful text; serializing the raw field would make JSON
        // disagree with the other report projections.
        if (status == TestStatus.failed)
          'message': effectiveFailureMessage
        else if (message != null)
          'message': message,
        if (status == TestStatus.failed) 'failure': _failureJson(),
        if (secondaryFailures.isNotEmpty)
          'secondaryFailures':
              secondaryFailures.map((failure) => failure.toJson()).toList(),
        if (capabilityStatus.isNotEmpty) 'capabilities': capabilityStatus,
        if (effectiveFailureStackTrace != null)
          'stackTrace': effectiveFailureStackTrace,
        if (failureOperation != null) 'failureOperation': failureOperation,
        if (failureSource != null)
          'failureSource': {
            'path': failureSource!.path,
            'stepPath': failureSource!.stepPath,
          },
        'logs': logs,
        if (report != null) 'report': report!.toJson(),
      };

  /// Failure payload used by report projections without serializing the
  /// complete result (logs, report screens, and step evidence) a second time.
  ///
  /// The full [toJson] shape remains the canonical machine result. This
  /// narrow accessor is intentionally limited to the fields that the HTML
  /// report copies into its test entry envelope.
  Map<String, dynamic>? get reportFailureJson =>
      status == TestStatus.failed ? _failureJson() : null;

  Map<String, dynamic> _failureJson() {
    final text = effectiveFailureMessage;
    final structured = effectiveFailureDetails!;
    final legacyKind = _legacyFailureKind(text);
    return {
      'kind': structured.kind.name,
      'legacyKind': legacyKind,
      if (structured.phase != null) 'phase': structured.phase,
      if (structured.target.isNotEmpty) 'target': structured.target,
      if (failedStep != null) 'step': failedStep!.type,
      if (failedStepIndex != null) 'stepIndex': failedStepIndex,
      if (failureOperation != null) 'operation': failureOperation,
      if (failureSource != null)
        'source': {
          'path': failureSource!.path,
          'stepPath': failureSource!.stepPath,
        },
      if (failedStep?.args['id'] != null) 'expected': failedStep!.args['id'],
      'actual': text,
      'message': structured.message,
      'suggestions': _failureSuggestions(legacyKind, failedStep),
      if (report != null)
        'context': {
          'currentScreen': report!.endScreen ?? report!.startScreen,
          'screensVisited': report!.screensVisited,
          'navigationKnown': report!.navigationKnown,
        },
    };
  }

  String _legacyFailureKind(String text) {
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
        lower.contains('finder') ||
        lower.contains('not found')) {
      return 'missingWidget';
    }
    if (lower.contains('yaml') ||
        lower.contains('parse') ||
        lower.contains('invalid')) {
      return 'parseError';
    }
    if (lower.contains('ambiguous')) return 'missingWidget';
    if (lower.contains('capability') || lower.contains('unavailable')) {
      return 'assertionFailure';
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
  final String? startScreen;
  final String? endScreen;
  final bool navigationKnown;
  final String? session;
  final List<String> screensVisited;
  final List<String> stepsOutline;

  /// Wall-clock ms for each top-level step (same order as [EnsembleTestCase.steps]).
  /// Shorter than the step list when the run failed mid-suite.
  final List<int> stepDurationsMs;
  final List<String> stepStartTimes;

  /// Map from screen name to its captured artifacts (debugTree, performance, etc.)
  final Map<String, Map<String, dynamic>> screens;

  const EnsembleTestReportDetails({
    this.startScreen,
    this.endScreen,
    this.navigationKnown = true,
    this.session,
    this.screensVisited = const [],
    this.stepsOutline = const [],
    this.stepDurationsMs = const [],
    this.stepStartTimes = const [],
    this.screens = const {},
  });

  factory EnsembleTestReportDetails.fromJson(Map<String, dynamic> json) {
    final screensMap = <String, Map<String, dynamic>>{};
    if (json['screens'] is Map) {
      (json['screens'] as Map).forEach((k, v) {
        if (v is Map) {
          screensMap[k.toString()] = Map<String, dynamic>.from(v);
        }
      });
    }
    return EnsembleTestReportDetails(
      startScreen: json['startScreen']?.toString(),
      endScreen: json['endScreen']?.toString(),
      navigationKnown: json['navigationKnown'] != false,
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
      screens: screensMap,
    );
  }

  Map<String, dynamic> toJson() => {
        if (startScreen != null) 'startScreen': startScreen,
        if (endScreen != null) 'endScreen': endScreen,
        'navigationKnown': navigationKnown,
        if (session != null) 'session': session,
        'screensVisited': screensVisited,
        'stepsOutline': stepsOutline,
        if (stepDurationsMs.isNotEmpty) 'stepDurationsMs': stepDurationsMs,
        if (stepStartTimes.isNotEmpty) 'stepStartTimes': stepStartTimes,
        if (screens.isNotEmpty) 'screens': screens,
      };
}

/// Thrown when a test step or assertion fails.
/// Exception used for user-facing test and assertion failures.
class EnsembleTestFailure implements Exception {
  final String message;

  EnsembleTestFailure(this.message);

  @override
  String toString() => message;
}
