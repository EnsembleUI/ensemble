import 'dart:convert';
import 'dart:io';

import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/reporters/atomic_file.dart';
import 'package:ensemble_test_runner/reporters/ensemble_test_history_store.dart';
import 'package:ensemble_test_runner/reporters/html_test_reporter.dart';
import 'package:ensemble_test_runner/reporters/junit_test_report.dart';
import 'package:path/path.dart' as p;

/// Coordinates the report artifacts written by the command line runner.
///
/// Keeping report lifecycle rules here makes the CLI orchestration responsible
/// for process execution only. The reporter still owns formatting and storage,
/// while this class owns when a suite is live, completed, or recorded in
/// history.
class CliReportCoordinator {
  CliReportCoordinator(String appDir)
      : _appDir = appDir,
        _artifactRoot = p.join(appDir, 'build', 'ensemble_test_runner');

  final String _appDir;
  final String _artifactRoot;

  /// Serializes a machine-readable result using the CLI's JSON/JUnit contract.
  String serializeMachineResult(
    EnsembleTestRunResult result, {
    required bool junit,
  }) =>
      junit ? JunitTestReport.build(result) : json.encode(result.toJson());

  /// Atomically writes a machine-readable result using the shared serializer.
  void writeMachineResult(
    EnsembleTestRunResult result, {
    required String path,
    required bool junit,
  }) {
    AtomicFile.writeStringSync(
      File(path),
      serializeMachineResult(result, junit: junit),
    );
  }

  Future<EnsembleTestRunResult> writeHtmlReport(
    EnsembleTestRunResult result, {
    int? wallTimeMs,
    bool isSuiteRunning = false,
  }) async {
    final reporter = HtmlTestReporter();
    final displayRoot =
        p.join('build', 'ensemble_test_runner').replaceAll('\\', '/');
    final htmlPath =
        p.join(displayRoot, 'report', 'index.html').replaceAll('\\', '/');
    final historyPath = p
        .join(displayRoot, 'report', EnsembleTestHistoryStore.fileName)
        .replaceAll('\\', '/');
    var historyRecorded = false;

    if (isSuiteRunning) {
      try {
        await EnsembleTestHistoryStore.markReportLoading(
          artifactRoot: _artifactRoot,
        );
      } catch (_) {
        stderr
            .writeln('Warning: could not reset the current report in SQLite.');
      }
      reporter.writeShell(
        artifactRoot: _artifactRoot,
        displayRoot: displayRoot,
      );
    } else {
      historyRecorded = await recordHistory(result, wallTimeMs: wallTimeMs);
      if (historyRecorded &&
          !result.suiteLogs.any((log) => log.startsWith('history:'))) {
        result = EnsembleTestRunResult(
          results: result.results,
          suiteLogs: [...result.suiteLogs, 'history: $historyPath'],
          metadata: result.metadata,
        );
      }
      reporter.writeShell(
        artifactRoot: _artifactRoot,
        displayRoot: displayRoot,
        cleanIntermediates: true,
      );
    }

    var suiteLogs = result.suiteLogs;
    if (!suiteLogs.any((log) => log.startsWith('htmlReport:'))) {
      suiteLogs = [...suiteLogs, 'htmlReport: $htmlPath'];
    }
    if (identical(suiteLogs, result.suiteLogs)) return result;
    return EnsembleTestRunResult(
      results: result.results,
      suiteLogs: suiteLogs,
      metadata: result.metadata,
    );
  }

  Future<bool> recordHistory(
    EnsembleTestRunResult result, {
    int? wallTimeMs,
  }) async {
    try {
      await EnsembleTestHistoryStore.recordCompletedRun(
        appDir: _appDir,
        artifactRoot: _artifactRoot,
        result: result,
        wallTimeMs: wallTimeMs,
      );
      return true;
    } catch (_) {
      stderr.writeln('Warning: could not write the test history database.');
      return false;
    }
  }
}
