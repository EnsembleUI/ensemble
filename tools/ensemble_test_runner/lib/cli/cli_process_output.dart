import 'dart:convert';
import 'dart:collection';
import 'dart:io';

import 'package:ensemble_test_runner/runner/test_artifacts.dart';

/// Retains the order in which a child process's output streams were observed.
final class CliProcessTranscript {
  CliProcessTranscript({
    this.maxCharacters = 256 * 1024,
    this.maxLines = 2000,
  })  : assert(maxCharacters > 0),
        assert(maxLines > 0);

  /// Retain only a diagnostic tail. The child process already has separate
  /// stdout/stderr buffers for result parsing, so an unbounded third copy would
  /// add avoidable peak memory on large suites.
  final int maxCharacters;
  final int maxLines;
  final _events = ListQueue<({String stream, String line})>();
  var _characters = 0;
  var _truncated = false;

  void add(String stream, String line) {
    final boundedLine = line.length > maxCharacters
        ? line.substring(line.length - maxCharacters)
        : line;
    if (boundedLine.length != line.length) _truncated = true;
    _events.add((stream: stream, line: boundedLine));
    _characters += boundedLine.length;
    while (_events.length > maxLines || _characters > maxCharacters) {
      final removed = _events.removeFirst();
      _characters -= removed.line.length;
      _truncated = true;
    }
  }

  String get text {
    if (_events.isEmpty) return '';
    final prefix = _truncated ? '[earlier output omitted]\n' : '';
    return '$prefix${_events.map((event) => '[${event.stream}] ${event.line}').join('\n')}\n';
  }
}

/// Formatting and filtering for output produced by child Flutter processes.
final class CliProcessOutput {
  CliProcessOutput._();

  static bool isArtifactProtocolLine(String line) =>
      line.contains(ensembleTestArtifactProtocolPrefix);

  static bool isIntegrationProgressLine(String line) =>
      line.contains(ensembleTestProgressProtocolPrefix);

  static bool isIntegrationWorkloadStarted(String line) {
    final marker = line.indexOf(ensembleTestProgressProtocolPrefix);
    if (marker < 0) return false;
    try {
      final raw =
          line.substring(marker + ensembleTestProgressProtocolPrefix.length);
      final decoded = json.decode(_jsonRecordFromLine(raw));
      return decoded is Map && decoded['status'] == 'running';
    } catch (_) {
      return false;
    }
  }

  static String? formatIntegrationProgressLine(String line) {
    final marker = line.indexOf(ensembleTestProgressProtocolPrefix);
    if (marker < 0) return line;
    final raw =
        line.substring(marker + ensembleTestProgressProtocolPrefix.length);
    try {
      final dynamic decoded = json.decode(_jsonRecordFromLine(raw));
      if (decoded is Map) {
        final status = decoded['status']?.toString() ?? 'finished';
        if (status == 'running') return null;
        final id = decoded['testId']?.toString() ?? '(unknown)';
        final duration = decoded['durationMs'];
        return '[$status] $id${duration is int ? ' (${duration}ms)' : ''}';
      }
    } catch (_) {}
    return line;
  }

  static void writeStatus(
    String message, {
    required bool quiet,
    required bool machineReport,
  }) {
    if (quiet || machineReport) return;
    stderr.writeln(message);
  }

  static void writeProcessStreams(
    ProcessResult result, {
    bool toStderr = false,
  }) {
    final out = withoutArtifactProtocolLines(result.stdout?.toString() ?? '');
    final err = withoutArtifactProtocolLines(result.stderr?.toString() ?? '');
    if (out.isNotEmpty) {
      if (toStderr) {
        stderr.write(out);
      } else {
        stdout.write(out);
      }
    }
    if (err.isNotEmpty) stderr.write(err);
  }

  static String withoutArtifactProtocolLines(String output) {
    if (output.isEmpty) return output;
    final kept = const LineSplitter()
        .convert(output)
        .where((line) => !isArtifactProtocolLine(line))
        .toList();
    if (kept.isEmpty) return '';
    final buffer = StringBuffer(kept.join('\n'));
    if (output.endsWith('\n')) buffer.writeln();
    return buffer.toString();
  }

  static String _jsonRecordFromLine(String raw) {
    final end = raw.lastIndexOf('}');
    return end < 0 ? raw.trim() : raw.substring(0, end + 1);
  }
}
