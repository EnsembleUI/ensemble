import 'dart:io';

import 'package:ensemble_test_runner/cli/cli_process_output.dart';
import 'package:ensemble_test_runner/cli/ensemble_test_cli_output.dart';

/// Presents a completed Flutter process according to the selected CLI mode.
///
/// Process execution and report persistence stay in the runner; this boundary
/// owns only user-facing stdout/stderr selection.
final class CliTestOutputPresenter {
  const CliTestOutputPresenter._();

  static void present(
    ProcessResult result, {
    required bool jsonReport,
    required bool junitReport,
    required bool machineReport,
    required bool streamLiveOutput,
    required bool verbose,
  }) {
    if (verbose) return;
    final output = '${result.stdout ?? ''}\n${result.stderr ?? ''}';
    if (result.exitCode != 0) {
      final report = selectReport(
        output,
        jsonReport: jsonReport,
        junitReport: junitReport,
        machineReport: machineReport,
        streamLiveOutput: streamLiveOutput,
      );
      if (report != null && report.isNotEmpty) {
        if (jsonReport || junitReport) {
          stdout.writeln(report);
        } else {
          stdout.write(report);
          if (!report.endsWith('\n')) stdout.writeln();
        }
        return;
      }
      final knownFailure = extractKnownFailure(output);
      if (knownFailure.isNotEmpty) {
        stderr.writeln(knownFailure);
        return;
      }
      CliProcessOutput.writeProcessStreams(result);
      return;
    }

    final report = selectReport(
      result.stdout?.toString() ?? '',
      jsonReport: jsonReport,
      junitReport: junitReport,
      machineReport: machineReport,
      streamLiveOutput: streamLiveOutput,
    );
    if (report != null && report.isNotEmpty) {
      stdout.write(report);
      if (!report.endsWith('\n')) stdout.writeln();
    } else {
      CliProcessOutput.writeProcessStreams(result);
    }
    final error = result.stderr?.toString() ?? '';
    if (error.isNotEmpty && !isBenignFlutterTestStderr(error)) {
      stderr.write(error);
    }
  }

  /// Returns the report selected by the same precedence as the CLI presenter.
  static String? selectReport(
    String output, {
    required bool jsonReport,
    required bool junitReport,
    required bool machineReport,
    required bool streamLiveOutput,
  }) {
    final rawJson = extractJsonReport(output);
    final json = jsonReport ? rawJson : '';
    final junit = junitReport ? extractJunitReport(output) : '';
    if (junit.isNotEmpty) return junit;
    if (json.isNotEmpty) return json;
    if (machineReport) return null;
    final report = extractSuiteReport(
      output,
      includeScreenTracker: !streamLiveOutput,
    );
    return report.isEmpty ? null : report;
  }

  /// Formats a completed worker result for live output. Running events remain
  /// in the progress stream for internal state, but are not test results to
  /// print; each case gets one terminal line when it finishes.
  static String? progressLine(Map<String, dynamic> event) {
    final statusName = event['status']?.toString();
    if (statusName == 'running') return null;
    final status = statusName == 'passed' ? '✓' : '✗';

    final rawTestId = event['testId']?.toString() ?? '(unknown)';
    final suffixIndex = rawTestId.indexOf('  (');
    final testId =
        suffixIndex < 0 ? rawTestId : rawTestId.substring(0, suffixIndex);
    final durationMs =
        event['durationMs'] is int ? event['durationMs'] as int : 0;
    final attempts = event['attempts'] is int ? event['attempts'] as int : 1;
    final retry = event['retry'] is int ? event['retry'] as int : 0;
    final retryText = attempts > 1 ? ' · attempt $attempts/${retry + 1}' : '';
    final message = event['message']?.toString();
    final detail = message == null || message.isEmpty
        ? ''
        : ': ${_singleLine(message, maxLength: 120)}';
    final duration = durationMs < 1000
        ? '${durationMs}ms'
        : '${(durationMs / 1000).toStringAsFixed(1)}s';
    return '$status $testId ($duration)$retryText$detail';
  }
}

String _singleLine(String value, {required int maxLength}) {
  final single = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (single.length <= maxLength) return single;
  return '${single.substring(0, maxLength - 1)}…';
}
