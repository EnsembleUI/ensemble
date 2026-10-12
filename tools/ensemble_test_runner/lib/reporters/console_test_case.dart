import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/reporters/result_projection.dart';
import 'package:ensemble_test_runner/reporters/step_outline_format.dart';
import 'package:ensemble_test_runner/runner/test_artifacts.dart';

/// Writes one test entry for the boxed reporter and the pure-Dart CLI.
///
/// This file intentionally has no Flutter or Ensemble runtime imports so the
/// executable can remain usable with `dart run`.
void writeConsoleTestCase(
  StringBuffer buffer,
  EnsembleSingleTestResult result, {
  bool includeFailureKind = true,
}) {
  final projection = TestResultProjection(result);
  final icon = projection.failed ? '✗' : '✓';
  buffer.writeln('│  $icon ${result.testId} (${projection.durationMs}ms)');
  if (projection.attempts > 1) {
    buffer.writeln(
      '│     attempts: ${projection.attempts}/${projection.retry + 1}',
    );
  }

  final report = result.report;
  if (report != null) {
    if (report.session != null)
      buffer.writeln('│     session: ${report.session}');
    if (report.startScreen != null) {
      buffer.writeln('│     start: ${report.startScreen}');
    }
    if (report.endScreen != null && report.endScreen != report.startScreen) {
      buffer.writeln('│     end:   ${report.endScreen}');
    }
    if (report.screensVisited.length > 1) {
      buffer.writeln('│     flow:  ${report.screensVisited.join(' → ')}');
    }
    if (report.stepsOutline.isNotEmpty) {
      buffer.writeln('│     steps (${report.stepsOutline.length}):');
      var index = 0;
      for (final line in stepOutlineDisplayLines(
        stepsOutline: report.stepsOutline,
        stepDurationsMs: report.stepDurationsMs,
        failedStepIndex:
            result.status == TestStatus.failed ? result.failedStepIndex : null,
      )) {
        final prefix = line.failed ? '>>' : '  ';
        buffer.writeln('│       $prefix ${index + 1}. ${line.text}');
        index++;
      }
    }
  }

  if (projection.failed) {
    buffer.writeln('│     error: ${projection.failureMessage}');
    if (projection.failureOperation != null) {
      buffer.writeln('│     operation: ${projection.failureOperation}');
    }
    if (includeFailureKind) {
      buffer.writeln('│     kind: ${projection.failureKind ?? 'internal'}');
    }
    if (result.failedStep != null) {
      buffer.writeln('│     failed: ${formatStepBrief(result.failedStep!)}');
    } else if (result.failedStepIndex != null) {
      buffer.writeln('│     at step: ${result.failedStepIndex! + 1}');
    }
  }

  final artifacts = durableArtifactLogs(result.logs).toList();
  if (artifacts.isNotEmpty) {
    buffer.writeln('│     artifacts:');
    for (final log in artifacts) buffer.writeln('│          $log');
  }
}
