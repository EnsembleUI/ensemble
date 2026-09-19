import 'dart:io';

import 'package:ensemble_test_runner/execution/artifact_transport.dart';
import 'package:ensemble_test_runner/execution/remote/remote_models.dart';
import 'package:ensemble_test_runner/execution/remote/remote_progress.dart';
import 'package:ensemble_test_runner/execution/remote/remote_report_reconciler.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/reporters/atomic_file.dart';
import 'package:ensemble_test_runner/reporters/ensemble_test_history_store.dart';
import 'package:ensemble_test_runner/reporters/html_test_reporter.dart';
import 'package:path/path.dart' as p;

/// Builds the same host report layout as local widget/integration runs from
/// FTL-collected on-device trees + optional device videos.
class RemoteHostReportBuilder {
  final RemoteProgress? onProgress;

  RemoteHostReportBuilder({this.onProgress});

  void _log(String message) => onProgress?.call(message);

  /// Display root used in artifact path labels (matches local CLI).
  static const displayRoot = 'build/ensemble_test_runner';

  /// Merges every pulled `ensemble_test_remote` tree into [hostArtifactRoot],
  /// then materializes any logcat artifact protocol as a backup.
  Future<void> materializeDeviceArtifactsIntoHost({
    required Directory collectDirectory,
    required String hostArtifactRoot,
  }) async {
    Directory(hostArtifactRoot).createSync(recursive: true);

    var merged = 0;
    try {
      for (final entity in collectDirectory.listSync(recursive: true)) {
        if (entity is! Directory) continue;
        if (p.basename(entity.path) != 'ensemble_test_remote') continue;
        _copyDirectoryContents(entity, Directory(hostArtifactRoot));
        merged++;
      }
    } catch (_) {
      // Continue with logcat materialization.
    }
    if (merged > 0) {
      _log(
        'Merged $merged pulled on-device tree(s) into $hostArtifactRoot',
      );
    }

    final logcat = readCollectedLogcat(collectDirectory);
    if (logcat.isEmpty) return;
    if (!logcat.contains(ensembleTestArtifactProtocolPrefix) &&
        !logcat.contains(ensembleTestRemoteEnvelopePrefix)) {
      return;
    }
    try {
      final transport = await materializeTransportedArtifacts(
        artifactRoot: hostArtifactRoot,
        output: logcat,
      );
      _log(
        transport.complete
            ? 'Materialized ${transport.receivedPaths.length} artifact(s) from logcat'
            : 'Partial logcat artifact materialize '
                '(${transport.receivedPaths.length} file(s)'
                '${transport.error != null ? '; ${transport.error}' : ''})',
      );
    } catch (error) {
      _log('Warning: logcat artifact materialize failed: $error');
    }
  }

  /// Writes `report/index.html` (+ results, history, screenshots) like local
  /// runs, copies FTL `video.mp4` into `report/`, and mirrors the package into
  /// [collectDirectory] so CI artifacts include a browseable HTML report.
  Future<String?> writeReports({
    required String appDir,
    required String hostArtifactRoot,
    required Directory collectDirectory,
    required List<ReconciledDeviceResult> devices,
  }) async {
    final combined = <EnsembleSingleTestResult>[];
    final suiteLogs = <String>[];
    for (final device in devices) {
      final results = device.envelope?.results;
      if (results == null) continue;
      combined.addAll(results.results);
      suiteLogs.addAll(results.suiteLogs);
      for (final err in device.envelope?.cleanupErrors ?? const <String>[]) {
        suiteLogs.add('cleanup[${device.deviceKey}]: $err');
      }
    }
    if (combined.isEmpty) {
      _log('No envelope.results to write HTML/history from');
      return null;
    }

    final videoLogs = _installFtlVideos(
      collectDirectory: collectDirectory,
      hostArtifactRoot: hostArtifactRoot,
    );
    suiteLogs.addAll(videoLogs);

    final runResult = EnsembleTestRunResult(
      results: combined,
      suiteLogs: suiteLogs,
    );
    try {
      await EnsembleTestHistoryStore.recordCompletedRun(
        appDir: appDir,
        artifactRoot: hostArtifactRoot,
        result: runResult,
      );
      suiteLogs.add(
        'history: ${p.join(displayRoot, 'report', EnsembleTestHistoryStore.fileName)}',
      );
    } catch (error) {
      _log('Warning: could not write history db: $error');
    }

    final withLogs = EnsembleTestRunResult(
      results: combined,
      suiteLogs: [
        ...suiteLogs,
        'htmlReport: ${p.join(displayRoot, 'report', 'index.html')}',
        'results: ${p.join(displayRoot, 'report', 'results.json.gz')}',
      ],
    );

    late final String htmlPath;
    try {
      htmlPath = HtmlTestReporter().write(
        withLogs,
        artifactRoot: hostArtifactRoot,
        displayRoot: displayRoot,
        forceRewriteShell: true,
      );
      _log(
        'Wrote HTML report under '
        '${p.join(hostArtifactRoot, 'report', 'index.html')}',
      );
    } catch (error) {
      _log('Warning: could not write HTML report: $error');
      return null;
    }

    _mirrorReportPackageIntoCollect(
      hostArtifactRoot: hostArtifactRoot,
      collectDirectory: collectDirectory,
    );
    return htmlPath;
  }

  /// Copies FTL device videos into `hostArtifactRoot/report/` and returns
  /// suite-log lines (`ftlVideo: …`) for the HTML reporter.
  List<String> _installFtlVideos({
    required Directory collectDirectory,
    required String hostArtifactRoot,
  }) {
    final reportDir =
        Directory(p.join(hostArtifactRoot, 'report'))..createSync(recursive: true);
    final logs = <String>[];
    final usedNames = <String>{};

    for (final video in findFtlVideos(collectDirectory)) {
      final deviceLabel = p.basename(p.dirname(video.path));
      var fileName = 'video.mp4';
      if (deviceLabel.isNotEmpty && deviceLabel != '.') {
        final safe = deviceLabel.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
        fileName = 'video_$safe.mp4';
      }
      if (!usedNames.add(fileName)) {
        fileName =
            'video_${usedNames.length}_${p.basenameWithoutExtension(fileName)}.mp4';
        usedNames.add(fileName);
      }
      final dest = File(p.join(reportDir.path, fileName));
      try {
        video.copySync(dest.path);
        logs.add('ftlVideo: ${p.join(displayRoot, 'report', fileName)}');
        _log('Installed FTL video → ${dest.path}');
      } catch (error) {
        _log('Warning: could not copy FTL video ${video.path}: $error');
      }
    }
    return logs;
  }

  void _mirrorReportPackageIntoCollect({
    required String hostArtifactRoot,
    required Directory collectDirectory,
  }) {
    final hostReport = Directory(p.join(hostArtifactRoot, 'report'));
    if (!hostReport.existsSync()) return;
    final destReport = Directory(p.join(collectDirectory.path, 'report'));
    try {
      if (destReport.existsSync()) {
        destReport.deleteSync(recursive: true);
      }
      _copyDirectoryContents(hostReport, destReport);
      _log(
        'Mirrored HTML report into '
        '${p.join(collectDirectory.path, 'report', 'index.html')}',
      );
    } catch (error) {
      _log('Warning: could not mirror report into collect dir: $error');
    }
  }

  /// Finds FTL `video.mp4` files under a collect / device tree.
  static List<File> findFtlVideos(Directory root) {
    if (!root.existsSync()) return const [];
    final out = <File>[];
    try {
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File) continue;
        if (p.basename(entity.path).toLowerCase() != 'video.mp4') continue;
        // Skip videos already under host report/ to avoid re-copy loops.
        final parts = p.split(entity.path);
        if (parts.contains('report') &&
            parts.indexOf('report') < parts.length - 1 &&
            p.basename(p.dirname(entity.path)) == 'report') {
          continue;
        }
        out.add(entity);
      }
    } catch (_) {
      return out;
    }
    return out;
  }

  static String readCollectedLogcat(Directory directory) {
    if (!directory.existsSync()) return '';
    final buffer = StringBuffer();
    try {
      for (final entity in directory.listSync(recursive: true)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path).toLowerCase();
        final looksLikeLog = name.contains('logcat') ||
            name.endsWith('.txt') ||
            name.endsWith('.log');
        if (!looksLikeLog) continue;
        try {
          buffer.writeln(entity.readAsStringSync());
        } catch (_) {
          // Skip unreadable files.
        }
      }
    } catch (_) {
      return buffer.toString();
    }
    return buffer.toString();
  }

  static void _copyDirectoryContents(Directory source, Directory dest) {
    dest.createSync(recursive: true);
    for (final entity in source.listSync(recursive: true)) {
      final relative = p.relative(entity.path, from: source.path);
      final target = p.join(dest.path, relative);
      if (entity is Directory) {
        Directory(target).createSync(recursive: true);
      } else if (entity is File) {
        File(target).parent.createSync(recursive: true);
        entity.copySync(target);
      }
    }
  }
}
