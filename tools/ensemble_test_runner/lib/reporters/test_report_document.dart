import 'dart:convert';
import 'dart:io';

import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/reporters/step_log_grouping.dart';
import 'package:ensemble_test_runner/runner/test_artifacts.dart';
import 'package:path/path.dart' as p;

/// Builds and writes the suite report document (`results.json`).
class TestReportDocument {
  /// Seed document while the suite is still running.
  static Map<String, dynamic> buildLoading({int? wallTimeMs}) {
    return {
      'state': 'loading',
      'generatedAt': DateTime.now().toIso8601String(),
      'summary': {
        'passed': 0,
        'failed': 0,
        'pending': 0,
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
    final ordered = [
      ...result.results.where((r) => r.status == TestStatus.failed),
      ...result.results.where((r) => r.status != TestStatus.failed),
    ];
    final totalMs = result.results.fold<int>(0, (sum, r) => sum + r.durationMs);
    final pendingCount =
        result.results.where((r) => r.status == TestStatus.pending).length;

    return {
      'state': 'complete',
      'generatedAt': DateTime.now().toIso8601String(),
      'summary': {
        'passed': result.passedCount,
        'failed': result.failedCount,
        'pending': pendingCount,
        'totalMs': totalMs,
        'wallTimeMs': wallTimeMs ?? totalMs,
      },
      'suiteArtifacts': _suiteArtifacts(result.suiteLogs, displayRoot),
      'tests': [
        for (final test in ordered)
          _buildTestEntry(
            test,
            artifactRoot: artifactRoot,
            displayRoot: displayRoot,
          ),
      ],
    };
  }

  /// Writes [document] as compact `results.json` under [reportDir].
  static void writeResults(Directory reportDir, Map<String, dynamic> document) {
    reportDir.createSync(recursive: true);
    // Compact JSON — indentation roughly doubles size for large suites.
    final jsonText = json.encode(document);
    File(p.join(reportDir.path, 'results.json')).writeAsStringSync(jsonText);
    // Drop legacy results.js from earlier dual-file reports.
    final legacyJs = File(p.join(reportDir.path, 'results.js'));
    if (legacyJs.existsSync()) {
      legacyJs.deleteSync();
    }
  }

  /// Removes runner intermediates that are no longer needed after results.json.
  ///
  /// Keeps `report/`, screenshot PNGs, and `test_durations.json`.
  static void cleanTransientArtifacts(String artifactRoot) {
    for (final name in const [
      'logs',
      'worker_progress',
      'worker_reports',
    ]) {
      final directory = Directory(p.join(artifactRoot, name));
      if (directory.existsSync()) {
        directory.deleteSync(recursive: true);
      }
    }
    final screenshots = Directory(p.join(artifactRoot, 'screenshots'));
    if (!screenshots.existsSync()) return;
    for (final entity in screenshots.listSync()) {
      if (entity is! File) continue;
      if (entity.path.replaceAll('\\', '/').endsWith('_frames.json')) {
        entity.deleteSync();
      }
    }
  }

  static List<Map<String, dynamic>> _suiteArtifacts(
    List<String> suiteLogs,
    String displayRoot,
  ) {
    final out = <Map<String, dynamic>>[];
    for (final log in suiteLogs) {
      final ref = _parseArtifactLine(log);
      if (ref == null) continue;
      if (ref.label == 'htmlReport' || ref.label == 'results') continue;
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

    final steps = report == null
        ? <Map<String, dynamic>>[]
        : groupLogsByStep(
            stepsOutline: report.stepsOutline,
            stepDurationsMs: report.stepDurationsMs,
            stepStartTimes: report.stepStartTimes,
            apiEvents: apiEvents,
            rawConsoleLines: console,
            storageSteps: (storage['steps'] as List?)
                    ?.whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList() ??
                const [],
            screenshotFrames: frames,
          );

    // Store payloads once under `steps` (Step Details + flatten for end-of-test
    // panels). Avoid duplicating api/console/screenshots at the test root.
    // Keep end-of-test storage keys snapshot only (diffs live in steps).
    return {
      'id': test.testId,
      'baseId': baseTestId(test.testId),
      'deviceBadge': deviceBadgeOf(test.testId),
      'filePath': filePathOf(test.testId),
      'status': test.status.name,
      'durationMs': test.durationMs,
      'attempts': test.attempts,
      'retry': test.retry,
      if (test.message != null) 'message': test.message,
      if (test.failedStepIndex != null) 'failedStepIndex': test.failedStepIndex,
      if (report != null) 'report': report.toJson(),
      'storage': {
        'keys': storage['keys'] is Map
            ? Map<String, dynamic>.from(storage['keys'] as Map)
            : <String, dynamic>{},
      },
      'steps': steps,
    };
  }

  static List<String> _readConsole(
    List<_ArtifactRef> artifacts,
    String artifactRoot,
    String displayRoot,
  ) {
    final ref = _first(artifacts, 'appLogs');
    if (ref == null) return const [];
    final fsPath = filesystemPath(ref.path,
        artifactRoot: artifactRoot, displayRoot: displayRoot);
    if (fsPath == null || !File(fsPath).existsSync()) return const [];
    return File(fsPath).readAsLinesSync();
  }

  static List<Map<String, dynamic>> _readApiEvents(
    List<_ArtifactRef> artifacts,
    String artifactRoot,
    String displayRoot,
  ) {
    final ref = _first(artifacts, 'apiCalls');
    if (ref == null) return const [];
    final fsPath = filesystemPath(ref.path,
        artifactRoot: artifactRoot, displayRoot: displayRoot);
    if (fsPath == null || !File(fsPath).existsSync()) return const [];
    try {
      final decoded = json.decode(File(fsPath).readAsStringSync());
      if (decoded is! Map || decoded['events'] is! List) return const [];
      return [
        for (final ev in decoded['events'])
          if (ev is Map) Map<String, dynamic>.from(ev),
      ];
    } catch (_) {
      return const [];
    }
  }

  static Map<String, dynamic> _readStorage(
    List<_ArtifactRef> artifacts,
    String artifactRoot,
    String displayRoot,
  ) {
    final ref = _first(artifacts, 'storage');
    if (ref == null) return {'keys': <String, dynamic>{}, 'steps': []};
    final fsPath = filesystemPath(ref.path,
        artifactRoot: artifactRoot, displayRoot: displayRoot);
    if (fsPath == null || !File(fsPath).existsSync()) {
      return {'keys': <String, dynamic>{}, 'steps': []};
    }
    try {
      final decoded = json.decode(File(fsPath).readAsStringSync());
      if (decoded is Map) {
        if (decoded['keys'] is Map || decoded['steps'] is List) {
          return {
            'keys': decoded['keys'] is Map
                ? Map<String, dynamic>.from(decoded['keys'] as Map)
                : <String, dynamic>{},
            'steps': [
              for (final step in (decoded['steps'] as List? ?? const []))
                if (step is Map) Map<String, dynamic>.from(step),
            ],
          };
        }
        // Legacy flat storage snapshot.
        return {
          'keys': Map<String, dynamic>.from(decoded),
          'steps': <Map<String, dynamic>>[],
        };
      }
    } catch (_) {}
    return {'keys': <String, dynamic>{}, 'steps': []};
  }

  static List<Map<String, dynamic>> _readScreenshotFrames(
    List<_ArtifactRef> artifacts,
    String artifactRoot,
    String displayRoot,
  ) {
    String? framesDisplay;
    final framesRef = _first(artifacts, 'screenshotFrames');
    final shotsRef = _first(artifacts, 'screenshots');
    if (framesRef != null) {
      framesDisplay = framesRef.path;
    } else if (shotsRef != null) {
      framesDisplay = screenshotFramesManifestDisplayPath(shotsRef.path);
    }
    if (framesDisplay == null || framesDisplay.isEmpty) return const [];

    final fsPath = filesystemPath(framesDisplay,
        artifactRoot: artifactRoot, displayRoot: displayRoot);
    if (fsPath == null || !File(fsPath).existsSync()) return const [];

    try {
      final decoded = json.decode(File(fsPath).readAsStringSync());
      if (decoded is! Map || decoded['frames'] is! List) return const [];
      final sheetDir = p.dirname(framesDisplay);
      final frames = <Map<String, dynamic>>[];
      for (final frame in decoded['frames']) {
        if (frame is! Map) continue;
        final entry = Map<String, dynamic>.from(frame);
        final fileName = entry['file']?.toString();
        if (fileName != null && fileName.isNotEmpty) {
          final displayPath = p.join(sheetDir, fileName).replaceAll('\\', '/');
          entry['href'] = _relativeHref(displayPath, displayRoot);
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
    for (final log in logs) {
      final ref = _parseArtifactLine(log);
      if (ref != null) artifacts.add(ref);
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
