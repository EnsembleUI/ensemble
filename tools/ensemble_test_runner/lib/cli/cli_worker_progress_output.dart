import 'dart:convert';
import 'dart:io';

import 'package:ensemble_test_runner/cli/cli_test_output_presenter.dart';

/// Prints completed worker outcomes while leaving in-flight events internal.
///
/// Progress files remain the source of internal run state; this adapter only
/// projects terminal outcomes to the CLI stream.
final class CliWorkerProgressOutput {
  const CliWorkerProgressOutput._();

  /// A worker can be terminated without a non-zero exit status before Flutter
  /// has written its report. In that case its progress stream is still the
  /// only record of the case that was in flight.
  static bool hasMissingReports(Iterable<String> reportFiles) =>
      reportFiles.any((path) {
        final report = File(path);
        return !report.existsSync() || report.lengthSync() == 0;
      });

  /// Preserves in-flight worker events when a process fails before writing its
  /// complete report. The terminal stream intentionally shows only completed
  /// case outcomes, so these events are the only durable pointer to a stuck
  /// case after its worker is terminated.
  static List<File> preserveIncompleteProgress(
    List<String> progressFiles,
    Directory diagnosticsDirectory, {
    Set<int> timedOutWorkerIndexes = const {},
    DateTime? capturedAt,
  }) {
    final preserved = <File>[];
    final capturedAtEpochMs =
        (capturedAt ?? DateTime.now()).millisecondsSinceEpoch;
    for (var i = 0; i < progressFiles.length; i++) {
      final source = File(progressFiles[i]);
      if (!source.existsSync() || source.lengthSync() == 0) continue;
      diagnosticsDirectory.createSync(recursive: true);
      final target = File(
        '${diagnosticsDirectory.path}/worker_${i + 1}_progress.jsonl',
      );
      final copy = source.copySync(target.path);
      final latest = <String, Map<String, dynamic>>{};
      for (final line in copy.readAsLinesSync()) {
        final event = _decodeEvent(line);
        final testId = event?['testId']?.toString();
        if (event != null && testId != null) latest[testId] = event;
      }
      final active =
          latest.values.where((event) => event['status'] == 'running');
      if (active.isNotEmpty) {
        final status =
            timedOutWorkerIndexes.contains(i) ? 'timed_out' : 'interrupted';
        final additions = active.map((event) {
          final startedAt = event['startedAtEpochMs'];
          final elapsedMs = startedAt is int
              ? (capturedAtEpochMs - startedAt).clamp(0, 0x7fffffff)
              : null;
          return json.encode({
            'testId': event['testId'],
            'assetPath': event['assetPath'],
            'status': status,
            if (elapsedMs != null) 'durationMs': elapsedMs,
            'capturedAtEpochMs': capturedAtEpochMs,
          });
        }).join('\n');
        copy.writeAsStringSync('$additions\n', mode: FileMode.append);
      }
      preserved.add(copy);
    }
    return preserved;
  }

  static void drainFiles(
    List<String> progressFiles,
    Map<String, int> seenLines, {
    void Function(String line)? writeLine,
  }) {
    final emit = writeLine ?? stderr.writeln;
    for (final path in progressFiles) {
      final file = File(path);
      if (!file.existsSync()) continue;
      final lines = file
          .readAsLinesSync()
          .where((line) => line.trim().isNotEmpty)
          .toList();
      final seen = seenLines[path] ?? 0;
      if (seen >= lines.length) continue;
      for (final line in lines.skip(seen)) {
        final event = _decodeEvent(line);
        if (event == null) continue;
        final outputLine = CliTestOutputPresenter.progressLine(event);
        if (outputLine != null) emit(outputLine);
      }
      seenLines[path] = lines.length;
    }
  }

  static Map<String, dynamic>? _decodeEvent(String line) {
    try {
      final decoded = json.decode(line);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }
}
