import 'package:ensemble_test_runner/models/ensemble_test_models.dart';

/// Canonical values shared by every result reporter.
///
/// Reporters may format these values differently, but they must not invent
/// their own fallback rules. Keeping the policy here makes legacy results
/// (which may only have a free-form message) agree with structured results in
/// JSON, HTML, JUnit, console output, and history.
final class TestResultProjection {
  final EnsembleSingleTestResult result;

  const TestResultProjection(this.result);

  bool get failed => result.status == TestStatus.failed;
  String get status => result.status.name;
  int get durationMs => result.durationMs;
  int get attempts => result.attempts;
  int get retry => result.retry;
  int? get failedStepIndex => result.failedStepIndex;
  String? get failureOperation => result.failureOperation;
  Map<String, String>? get failureSource => result.failureSource == null
      ? null
      : {
          'path': result.failureSource!.path,
          'stepPath': result.failureSource!.stepPath,
        };
  String? get failureMessage => failed ? result.effectiveFailureMessage : null;
  TestFailureDetails? get failureDetails =>
      failed ? result.effectiveFailureDetails : null;
  String? get failureKind => failureDetails?.kind.name;

  /// Failure fields needed by rich report entries without materializing the
  /// full machine result and serializing logs/evidence twice.
  Map<String, dynamic>? get reportFailureJson => result.reportFailureJson;

  /// Returns usable diagnostic text for stack-aware reporters.
  ///
  /// Some legacy execution paths persisted an empty stack trace. Treating
  /// that as present made JUnit and HTML show a blank failure body while the
  /// console and history still showed the failure message. A projection must
  /// expose the same useful fallback to every consumer.
  String? get failureStackTrace {
    if (!failed) return null;
    return result.effectiveFailureStackTrace;
  }
}

/// Canonical aggregate values used by suite-level reporters.
///
/// The snapshot is intentional: one report should describe one stable view of
/// the run even if a caller mutates the source result list while another
/// reporter is being built. It also makes the aggregate counts and duration
/// one pass over the results instead of recomputing them for each field.
final class SuiteResultProjection {
  final EnsembleTestRunResult result;
  final _SuiteResultSnapshot _snapshot;

  SuiteResultProjection(this.result)
      : _snapshot = _SuiteResultSnapshot.from(result.results);

  int get total => _snapshot.total;
  int get passed => _snapshot.passed;
  int get failed => _snapshot.failed;

  /// Results in execution order, shared by every report projection.
  ///
  /// The machine JSON payload preserves this order. Other formats must not
  /// regroup failures because that makes cross-format inspection ambiguous.
  List<EnsembleSingleTestResult> get orderedResults => _snapshot.results;
  int get totalDurationMs => _snapshot.totalDurationMs;

  String get summary => '$passed passed, $failed failed ($total total)';
  String get status => failed > 0 ? 'failed' : 'passed';
}

final class _SuiteResultSnapshot {
  final List<EnsembleSingleTestResult> results;
  final int total;
  final int passed;
  final int failed;
  final int totalDurationMs;

  const _SuiteResultSnapshot({
    required this.results,
    required this.total,
    required this.passed,
    required this.failed,
    required this.totalDurationMs,
  });

  factory _SuiteResultSnapshot.from(
    List<EnsembleSingleTestResult> source,
  ) {
    final results = List<EnsembleSingleTestResult>.unmodifiable(source);
    var passed = 0;
    var failed = 0;
    var totalDurationMs = 0;
    for (final result in results) {
      if (result.status == TestStatus.passed) {
        passed++;
      } else if (result.status == TestStatus.failed) {
        failed++;
      }
      totalDurationMs += result.durationMs;
    }
    return _SuiteResultSnapshot(
      results: results,
      total: results.length,
      passed: passed,
      failed: failed,
      totalDurationMs: totalDurationMs,
    );
  }
}
