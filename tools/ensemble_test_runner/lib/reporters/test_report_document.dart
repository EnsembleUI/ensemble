// Dart 3.8 reports deprecated_member_use at RegExp construction sites even though
// the deprecation is specifically about implementing RegExp. Keep construction compatible
// with this SDK without suppressing diagnostics in unrelated files.
// ignore_for_file: deprecated_member_use
import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/reporters/report_json_optimizer.dart';
import 'package:ensemble_test_runner/reporters/result_projection.dart';
import 'package:ensemble_test_runner/reporters/step_log_grouping.dart';
import 'package:path/path.dart' as p;

/// Builds the current suite report and encodes its compact database payload.
class TestReportDocument {
  /// Seed document while the suite is still running.
  static Map<String, dynamic> buildLoading({int? wallTimeMs}) {
    return {
      'state': 'loading',
      'generatedAt': DateTime.now().toIso8601String(),
      'summary': {
        'passed': 0,
        'failed': 0,
        'total': 0,
        'status': 'loading',
        'totalMs': 0,
        if (wallTimeMs != null) 'wallTimeMs': wallTimeMs,
      },
      'suiteArtifacts': <Map<String, dynamic>>[],
      'tests': <Map<String, dynamic>>[],
    };
  }

  /// Full document after the suite finishes.
  static Map<String, dynamic> buildComplete(
    EnsembleTestRunResult result, {
    required String artifactRoot,
    required String displayRoot,
    int? wallTimeMs,
  }) {
    return RunnerBenchmark.sync('report', 'buildComplete', () {
      final suite = SuiteResultProjection(result);

      return {
        'state': 'complete',
        'generatedAt': DateTime.now().toIso8601String(),
        'summary': {
          'passed': suite.passed,
          'failed': suite.failed,
          // Keep the report envelope aligned with the canonical run result.
          // Consumers that only read the summary should not reconstruct the
          // total or status from the test entries.
          'total': suite.total,
          'status': suite.status,
          'totalMs': suite.totalDurationMs,
          'wallTimeMs': wallTimeMs ?? suite.totalDurationMs,
        },
        if (result.metadata.isNotEmpty) 'metadata': result.metadata,
        'suiteArtifacts': _suiteArtifacts(
          result.suiteLogs,
          artifactRoot: artifactRoot,
          displayRoot: displayRoot,
        ),
        'tests': [
          for (final test in suite.orderedResults)
            _buildTestEntry(
              test,
              artifactRoot: artifactRoot,
              displayRoot: displayRoot,
            ),
        ],
      };
    });
  }

  /// Encodes a report payload for storage in the history database.
  static Uint8List encodeCompressed(Map<String, dynamic> document) {
    final optimized = ReportJsonOptimizer.optimize(document);
    return Uint8List.fromList(
      gzip.encode(utf8.encode(json.encode(optimized))),
    );
  }

  /// Decodes the report payload stored in the latest database row.
  static Map<String, dynamic> decodeCompressed(Uint8List bytes) {
    final decoded = json.decode(utf8.decode(gzip.decode(bytes)));
    if (decoded is! Map) {
      throw const FormatException('Report payload must be a JSON object.');
    }
    return ReportJsonOptimizer.expand(Map<String, dynamic>.from(decoded));
  }

  /// Removes runner intermediates that are no longer needed after results write.
  ///
  /// Keeps only the durable report files; timing history lives in SQLite.
  ///
  /// Screenshot images are packed into `report/screenshots.zip`; transient
  /// frame manifests under `frames/` are removed here.
  ///
  /// `worker_progress` / `worker_reports` are normally deleted earlier by the
  /// CLI when each finishes its job; listed here as a safety net.
  static void cleanTransientArtifacts(String artifactRoot) {
    return RunnerBenchmark.sync('report', 'cleanTransientArtifacts', () {
      for (final name in [
        'logs',
        'worker_progress',
        'worker_reports',
        'frames',
        // Loose screenshot files are now stored in report/screenshots.zip.
        p.join('report', 'screenshots'),
        // Legacy pre-rename location for `*_frames.json` manifests.
        'screenshots',
      ]) {
        final directory = Directory(p.join(artifactRoot, name));
        if (directory.existsSync()) {
          directory.deleteSync(recursive: true);
        }
      }
      final retiredDurations =
          File(p.join(artifactRoot, 'test_durations.json'));
      if (retiredDurations.existsSync()) retiredDurations.deleteSync();
    });
  }

  static List<Map<String, dynamic>> _suiteArtifacts(
    List<String> suiteLogs, {
    required String artifactRoot,
    required String displayRoot,
  }) {
    final out = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final log in suiteLogs) {
      final ref = _parseArtifactLine(log);
      if (ref == null) continue;
      if (ref.label == 'htmlReport' ||
          ref.label == 'results' ||
          ref.label == 'appPerformance' ||
          ref.label == 'dumpTree' ||
          ref.label == 'history') {
        // htmlReport/results are top-level links; appPerformance/dumpTree are
        // screen-scoped inside each test report (legacy suite labels ignored);
        // history is the sqlite db file and is skipped from logs UI download list.
        continue;
      }

      final fsPath = filesystemPath(
        ref.path,
        artifactRoot: artifactRoot,
        displayRoot: displayRoot,
      );
      if (fsPath == null || !File(fsPath).existsSync()) continue;
      // Multiple lifecycle paths may attach the same durable artifact. Keep
      // one link in the report while preserving distinct labels for distinct
      // evidence files.
      final identity = '${ref.label}\u0000${ref.path}';
      if (!seen.add(identity)) continue;
      out.add({
        'label': ref.label,
        'path': ref.path,
        'href': _relativeHref(ref.path, displayRoot),
      });
    }
    return out;
  }

  static Map<String, dynamic> _buildTestEntry(
    EnsembleSingleTestResult test, {
    required String artifactRoot,
    required String displayRoot,
  }) {
    final artifacts = _parseArtifacts(test.logs);
    final console = _readConsole(artifacts, artifactRoot, displayRoot);
    final apiEvents = _readApiEvents(artifacts, artifactRoot, displayRoot);
    final storage = _readStorage(artifacts, artifactRoot, displayRoot);
    final frames = _readScreenshotFrames(artifacts, artifactRoot, displayRoot);
    final report = test.report;
    final device = _deviceMetadata(test);
    // Keep the HTML result's machine-readable failure details aligned with
    // the canonical result JSON projection. The report-specific fields below
    // remain tailored to the HTML viewer and preserve its existing schema.
    final projection = TestResultProjection(test);
    // The HTML entry only needs the failure fields below. Avoid calling the
    // full machine projection here: that would serialize logs, screenshots,
    // observer evidence, and the report screens before serializing the same
    // report payload again below.
    final machineFailure = projection.reportFailureJson;

    final steps = report == null
        ? <Map<String, dynamic>>[]
        : groupLogsByStep(
            stepsOutline: report.stepsOutline,
            stepDurationsMs: report.stepDurationsMs,
            stepStartTimes: report.stepStartTimes,
            apiEvents: apiEvents,
            rawConsoleLines: console,
            storageSteps: (storage['storageSteps'] as List?)
                    ?.whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList() ??
                const [],
            secureStorageSteps: (storage['secureStorageSteps'] as List?)
                    ?.whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList() ??
                const [],
            keychainSteps: (storage['keychainSteps'] as List?)
                    ?.whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList() ??
                const [],
            screenshotFrames: frames,
          );

    // Performance / dumpTree live under report.screens only.
    // Keep end-of-test storage keys snapshot only (diffs live in steps).
    return {
      'id': test.testId,
      'baseId': baseTestId(test.testId),
      'deviceBadge': device['id']?.toString() ?? deviceBadgeOf(test.testId),
      if (device.isNotEmpty) 'device': device,
      'filePath': filePathOf(test.testId),
      'status': projection.status,
      'durationMs': projection.durationMs,
      'attempts': projection.attempts,
      'retry': projection.retry,
      if (test.metadata.isNotEmpty) 'metadata': test.metadata,
      if (test.metadata['feature'] != null)
        'feature': test.metadata['feature'].toString(),
      if (test.metadata['profile'] != null)
        'profile': test.metadata['profile'].toString(),
      if (test.metadata['scenarioId'] != null)
        'scenarioId': test.metadata['scenarioId'].toString(),
      if (test.metadata['scenarioDescription'] != null)
        'scenarioDescription': test.metadata['scenarioDescription'].toString(),
      if (test.metadata['description'] != null)
        'description': test.metadata['description'].toString(),
      if (projection.failed) 'message': projection.failureMessage,
      if (machineFailure != null) 'failure': machineFailure,
      if (test.secondaryFailures.isNotEmpty)
        'secondaryFailures': [
          for (final failure in test.secondaryFailures) failure.toJson(),
        ],
      if (projection.failureStackTrace != null)
        'stackTrace': projection.failureStackTrace,
      if (test.failedStep != null) 'failedStep': test.failedStep!.toJson(),
      if (test.failureOperation != null)
        'failureOperation': test.failureOperation,
      if (projection.failureSource != null)
        'failureSource': projection.failureSource,
      if (test.capabilityStatus.isNotEmpty)
        'capabilities': test.capabilityStatus,
      if (test.failedStepIndex != null) 'failedStepIndex': test.failedStepIndex,
      if (report != null) 'report': report.toJson(),
      'storage': {
        'keys': storage['storageKeys'] is Map
            ? Map<String, dynamic>.from(storage['storageKeys'] as Map)
            : <String, dynamic>{},
        'secureStorageKeys': storage['secureStorageKeys'] is Map
            ? Map<String, dynamic>.from(storage['secureStorageKeys'] as Map)
            : <String, dynamic>{},
        'keychainKeys': storage['keychainKeys'] is Map
            ? Map<String, dynamic>.from(storage['keychainKeys'] as Map)
            : <String, dynamic>{},
      },
      'steps': steps,
    };
  }

  static Map<String, dynamic> _deviceMetadata(EnsembleSingleTestResult test) {
    final device = test.metadata['device'];
    if (device is Map) {
      return Map<String, dynamic>.from(device);
    }
    if (device != null && device.toString().trim().isNotEmpty) {
      return {'id': device.toString().trim()};
    }
    return const {};
  }

  static List<String> _readConsole(
    List<_ArtifactRef> artifacts,
    String artifactRoot,
    String displayRoot,
  ) {
    final lines = <String>[];
    for (final ref
        in artifacts.where((artifact) => artifact.label == 'appLogs')) {
      final fsPath = filesystemPath(ref.path,
          artifactRoot: artifactRoot, displayRoot: displayRoot);
      if (fsPath == null || !File(fsPath).existsSync()) continue;
      try {
        lines.addAll(File(fsPath).readAsLinesSync());
      } catch (_) {
        // A missing or unreadable attempt log should not hide other attempts.
      }
    }
    return lines;
  }

  static List<Map<String, dynamic>> _readApiEvents(
    List<_ArtifactRef> artifacts,
    String artifactRoot,
    String displayRoot,
  ) {
    final events = <Map<String, dynamic>>[];
    for (final ref
        in artifacts.where((artifact) => artifact.label == 'apiCalls')) {
      final fsPath = filesystemPath(ref.path,
          artifactRoot: artifactRoot, displayRoot: displayRoot);
      if (fsPath == null || !File(fsPath).existsSync()) continue;
      try {
        final decoded = json.decode(File(fsPath).readAsStringSync());
        if (decoded is! Map || decoded['events'] is! List) continue;
        events.addAll([
          for (final ev in decoded['events'])
            if (ev is Map) Map<String, dynamic>.from(ev),
        ]);
      } catch (_) {
        // Skip only the unreadable sidecar; retain events from other attempts.
      }
    }
    return events;
  }

  static Map<String, dynamic> _readStorage(
    List<_ArtifactRef> artifacts,
    String artifactRoot,
    String displayRoot,
  ) {
    final ref = _first(artifacts, 'storage');
    if (ref == null) return _emptyStorageReport();
    final fsPath = filesystemPath(ref.path,
        artifactRoot: artifactRoot, displayRoot: displayRoot);
    if (fsPath == null || !File(fsPath).existsSync()) {
      return _emptyStorageReport();
    }
    try {
      final decoded = json.decode(File(fsPath).readAsStringSync());
      if (decoded is Map) {
        if (decoded['storage'] is Map || decoded['secureStorage'] is Map) {
          final publicSection = _asMap(decoded['storage']);
          final secureSection = _asMap(decoded['secureStorage']);
          final keychainSection = _asMap(decoded['keychain']);
          return _storageReport(
            storageKeys: publicSection['keys'],
            secureStorageKeys: secureSection['keys'],
            keychainKeys: keychainSection['keys'],
            storageSteps: publicSection['steps'],
            secureStorageSteps: secureSection['steps'],
            keychainSteps: keychainSection['steps'],
          );
        }
      }
    } catch (_) {}
    return _emptyStorageReport();
  }

  static Map<String, dynamic> _storageReport({
    dynamic storageKeys,
    dynamic secureStorageKeys,
    dynamic keychainKeys,
    dynamic storageSteps,
    dynamic secureStorageSteps,
    dynamic keychainSteps,
  }) =>
      {
        'storageKeys': _asMap(storageKeys),
        'secureStorageKeys': _asMap(secureStorageKeys),
        'keychainKeys': _asMap(keychainKeys),
        'storageSteps': _asMapList(storageSteps),
        'secureStorageSteps': _asMapList(secureStorageSteps),
        'keychainSteps': _asMapList(keychainSteps),
      };

  static Map<String, dynamic> _emptyStorageReport() => _storageReport();

  static Map<String, dynamic> _asMap(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  static List<Map<String, dynamic>> _asMapList(dynamic value) => value is List
      ? [
          for (final item in value)
            if (item is Map) Map<String, dynamic>.from(item)
        ]
      : <Map<String, dynamic>>[];

  static List<Map<String, dynamic>> _readScreenshotFrames(
    List<_ArtifactRef> artifacts,
    String artifactRoot,
    String displayRoot,
  ) {
    String? framesDisplay;
    final framesRef = _first(artifacts, 'screenshotFrames');
    if (framesRef != null) framesDisplay = framesRef.path;
    if (framesDisplay == null || framesDisplay.isEmpty) return const [];

    final fsPath = filesystemPath(framesDisplay,
        artifactRoot: artifactRoot, displayRoot: displayRoot);
    if (fsPath == null || !File(fsPath).existsSync()) return const [];

    try {
      final decoded = json.decode(File(fsPath).readAsStringSync());
      if (decoded is! Map || decoded['frames'] is! List) return const [];
      final frames = <Map<String, dynamic>>[];
      for (final frame in decoded['frames']) {
        if (frame is! Map) continue;
        final entry = Map<String, dynamic>.from(frame);
        final fileName = entry['file']?.toString();
        if (fileName != null && fileName.isNotEmpty) {
          entry['href'] = 'screenshots.zip#screenshots/$fileName';
        }
        frames.add(entry);
      }
      return frames;
    } catch (_) {
      return const [];
    }
  }

  static _ArtifactRef? _first(List<_ArtifactRef> artifacts, String label) {
    for (final a in artifacts) {
      if (a.label == label) return a;
    }
    return null;
  }

  static List<_ArtifactRef> _parseArtifacts(List<String> logs) {
    final artifacts = <_ArtifactRef>[];
    final seen = <String>{};
    for (final log in logs) {
      final ref = _parseArtifactLine(log);
      if (ref != null && seen.add('${ref.label}\u0000${ref.path}')) {
        artifacts.add(ref);
      }
    }
    return artifacts;
  }

  static _ArtifactRef? _parseArtifactLine(String log) {
    final separator = log.indexOf(':');
    if (separator <= 0) return null;
    final label = log.substring(0, separator).trim();
    final path = log.substring(separator + 1).trim();
    if (label.isEmpty || path.isEmpty) return null;
    return _ArtifactRef(label: label, path: path);
  }

  static String _relativeHref(String artifactDisplayPath, String displayRoot) {
    final normalized = artifactDisplayPath.replaceAll('\\', '/');
    final reportDir = p.join(displayRoot, 'report').replaceAll('\\', '/');
    return p.relative(normalized, from: reportDir).replaceAll('\\', '/');
  }
}

/// Resolves a display-root path to a filesystem path under [artifactRoot].
String? filesystemPath(
  String artifactDisplayPath, {
  required String artifactRoot,
  required String displayRoot,
}) {
  final normalized = artifactDisplayPath.replaceAll('\\', '/');
  final display = displayRoot.replaceAll('\\', '/');
  String relative;
  if (normalized == display || normalized.startsWith('$display/')) {
    relative = p.relative(normalized, from: display);
  } else if (p.isAbsolute(normalized)) {
    return normalized;
  } else {
    relative = normalized;
  }
  return p.normalize(p.join(artifactRoot, relative));
}

String baseTestId(String testId) {
  final match = RegExp(r'^(.*?)\[(.*?)\]').firstMatch(testId);
  if (match != null) return match.group(1)!.trim();
  final pathMatch = RegExp(r'^(.*?)\s*\(').firstMatch(testId);
  if (pathMatch != null) return pathMatch.group(1)!.trim();
  return testId.trim();
}

String deviceBadgeOf(String testId) {
  final match = RegExp(r'\[(.*?)\]').firstMatch(testId);
  return match?.group(1)?.trim() ?? '';
}

String filePathOf(String testId) {
  final match = RegExp(r'\((.*?)\)').firstMatch(testId);
  return match?.group(1)?.trim() ?? '';
}

String anchorId(String testId) =>
    testId.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');

class _ArtifactRef {
  final String label;
  final String path;

  const _ArtifactRef({required this.label, required this.path});
}
