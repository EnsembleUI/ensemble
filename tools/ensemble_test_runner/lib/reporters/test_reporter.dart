import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/reporters/step_outline_format.dart';
import 'package:ensemble_test_runner/reporters/result_projection.dart';
import 'package:ensemble_test_runner/reporters/console_test_case.dart';
import 'package:ensemble_test_runner/runner/test_artifacts.dart';
import 'package:ensemble_test_runner/runner/test_session.dart';

export 'package:ensemble_test_runner/reporters/step_outline_format.dart';

EnsembleTestReportDetails buildTestReportDetails(
  EnsembleTestCase testCase, {
  List<int> stepDurationsMs = const [],
  List<String> stepStartTimes = const [],
  Map<String, Map<String, dynamic>> screens = const {},
  required NavigationFlowRecorder navigationFlow,
}) {
  final flow = navigationFlow.flow;
  final effectiveStart =
      testCase.startScreen ?? (flow.isEmpty ? null : flow.first);
  final details = EnsembleTestReportDetails(
    startScreen: effectiveStart,
    endScreen: flow.isEmpty ? null : flow.last,
    session: testCase.session,
    screensVisited: effectiveStart == null
        ? flow
        : collectScreensVisited(effectiveStart, navigationFlow: navigationFlow),
    stepsOutline: outlineSteps(testCase.steps),
    stepDurationsMs: stepDurationsMs,
    stepStartTimes: stepStartTimes,
    screens: screens,
  );
  return details;
}

List<String> collectScreensVisited(
  String effectiveStart, {
  required NavigationFlowRecorder navigationFlow,
}) {
  final flow = List<String>.from(navigationFlow.flow);
  if (flow.isEmpty) {
    return [effectiveStart];
  }
  if (flow.first != effectiveStart) {
    return [effectiveStart, ...flow];
  }
  return flow;
}

List<String> outlineSteps(List<TestStep> steps) {
  final lines = <String>[];
  for (final step in steps) {
    lines.addAll(_outlineStep(step));
  }
  return lines;
}

List<String> _outlineStep(TestStep step) {
  if ((step.type == 'optional' || step.type == 'ifVisible') &&
      step.nestedSteps.length == 1) {
    return [formatStepBrief(step)];
  }
  if (step.nestedSteps.isNotEmpty) {
    final nested = outlineSteps(step.nestedSteps);
    return [
      '${step.type} (${nested.length} steps)',
      ...nested.map((line) => '  $line'),
    ];
  }
  return [formatStepBrief(step)];
}

class TestReporter {
  /// Formats a multi-test run report for console output.
  String formatSummary(
    EnsembleTestRunResult result, {
    String? testFile,
  }) {
    return RunnerBenchmark.sync('report', 'formatSummary', () {
      final buffer = StringBuffer();
      final suite = SuiteResultProjection(result);

      buffer.writeln('┌─ Ensemble tests ─────────────────────────────────');
      if (testFile != null) {
        buffer.writeln('│  $testFile');
        buffer.writeln('│');
      }

      final orderedResults = suite.orderedResults;
      for (var i = 0; i < orderedResults.length; i++) {
        if (i > 0) buffer.writeln('│');
        writeTestCase(buffer, orderedResults[i]);
      }

      final suiteArtifacts = durableArtifactLogs(result.suiteLogs).toList();
      if (suiteArtifacts.isNotEmpty) {
        buffer.writeln('│');
        buffer.writeln('│  suite artifacts:');
        for (final log in suiteArtifacts) {
          buffer.writeln('│       $log');
        }
      }

      buffer.writeln('│');
      buffer.writeln(
        '└─ ${suite.summary} · ${suite.totalDurationMs}ms total',
      );
      return buffer.toString();
    });
  }

  /// Formats the short failure passed to Flutter's test framework.
  ///
  /// The full boxed report is printed separately. Keeping this compact avoids
  /// Flutter echoing the entire report again with its framework stack trace.
  String formatFailureSummary(
    EnsembleTestRunResult result, {
    Iterable<String> failedPaths = const [],
    Iterable<Object?> pendingFrameworkExceptions = const [],
  }) {
    return RunnerBenchmark.sync('report', 'formatFailureSummary', () {
      final suite = SuiteResultProjection(result);
      final failed = suite.orderedResults
          .where((r) => r.status == TestStatus.failed)
          .toList(growable: false);
      final paths = failedPaths.toList(growable: false);
      final buffer = StringBuffer()
        ..writeln(
          'Failed tests (${suite.failed}/${suite.total}):',
        );

      for (var i = 0; i < failed.length; i++) {
        final r = failed[i];
        final path = i < paths.length ? paths[i] : null;
        final label = path == null || r.testId.contains(path)
            ? r.testId
            : '${r.testId} ($path)';
        final failedStep = r.failedStep != null
            ? ' (failed: ${formatStepBrief(r.failedStep!)})'
            : r.failedStepIndex != null
                ? ' (failed: step ${r.failedStepIndex! + 1})'
                : '';
        buffer.writeln('- $label: ${r.effectiveFailureMessage}$failedStep');
      }

      final pending = pendingFrameworkExceptions
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
      if (pending.isNotEmpty) {
        buffer.writeln();
        buffer.writeln('Pending Flutter framework exceptions:');
        for (final exception in pending) {
          buffer.writeln('- ${_firstLine(exception)}');
        }
      }

      buffer.writeln();
      buffer.write('See the Ensemble tests report above.');
      return buffer.toString();
    });
  }

  /// Writes one test entry using the canonical result projection.
  ///
  /// The CLI and the boxed reporter intentionally share this formatter so
  /// failure fallbacks, retry text, step highlighting, and artifact display
  /// cannot drift between entry points. The CLI omits the richer failure kind
  /// line to preserve its compact output contract.
  static void writeTestCase(
    StringBuffer buffer,
    EnsembleSingleTestResult r, {
    bool includeFailureKind = true,
  }) {
    writeConsoleTestCase(
      buffer,
      r,
      includeFailureKind: includeFailureKind,
    );
  }
}

String _firstLine(String value) {
  final index = value.indexOf('\n');
  return index == -1 ? value : value.substring(0, index);
}
