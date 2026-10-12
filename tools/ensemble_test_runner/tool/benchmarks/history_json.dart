// Dart 3.8 reports deprecated_member_use at RegExp construction sites even though
// the deprecation is specifically about implementing RegExp. Keep construction compatible
// with this SDK without suppressing diagnostics in unrelated files.
// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'results.dart';

void validateExport(Map<String, dynamic> run) {
  if (run['schemaVersion'] != benchmarkSchemaVersion) {
    throw FormatException('Unsupported benchmark export schema');
  }
  if (run['runId'] is! String ||
      !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(run['runId'] as String)) {
    throw FormatException('Invalid benchmark run ID');
  }
  DateTime.parse(run['timestamp'] as String);
  if (run['branch'] is! String ||
      run['environment'] is! Map ||
      run['cases'] is! List) {
    throw FormatException('Incomplete benchmark export');
  }
  final ids = <String>{};
  for (final c in run['cases'] as List) {
    if (c is! Map ||
        c['id'] is! String ||
        !ids.add(c['id'] as String) ||
        !['measured', 'skipped', 'invalid'].contains(c['status'])) {
      throw FormatException('Invalid benchmark case');
    }
  }
  final sampleIds = <String>{};
  for (final raw in run['samples'] as List? ?? []) {
    if (raw is! Map ||
        !ids.contains(raw['caseId']) ||
        raw['index'] is! int ||
        raw['index'] < 0 ||
        raw['iterations'] is! int ||
        raw['iterations'] < 0 ||
        (raw['valid'] == true && raw['iterations'] == 0) ||
        !sampleIds.add('${raw['caseId']}:${raw['index']}')) {
      throw FormatException('Invalid benchmark sample');
    }
  }
}

/// Small file backed benchmark history.
///
/// Benchmark history is metadata used by the CLI and its HTML trend report.
/// It does not need relational queries, so keeping it as one compact JSON
/// document avoids starting a native SQLite runtime in benchmark processes.
final class BenchmarkHistory {
  BenchmarkHistory(this.root);

  final Directory root;
  static const _fileName = 'history.json';
  List<Map<String, dynamic>>? _runs;

  File get _file => File(p.join(root.path, _fileName));

  Future<List<Map<String, dynamic>>> _load() async {
    if (_runs != null) return _runs!;
    if (!_file.existsSync()) return _runs = <Map<String, dynamic>>[];
    final decoded = jsonDecode(await _file.readAsString());
    if (decoded is! Map || decoded['runs'] is! List) {
      throw FormatException('Invalid benchmark history document');
    }
    return _runs = [
      for (final value in decoded['runs'] as List)
        if (value is Map) Map<String, dynamic>.from(value),
    ];
  }

  Future<void> _save() async {
    root.createSync(recursive: true);
    final runs = _runs ?? const <Map<String, dynamic>>[];
    final temporary = File('${_file.path}.tmp');
    await temporary.writeAsString(
      const JsonEncoder.withIndent('  ').convert(
          {'version': 1, 'runs': null}).replaceFirst('null', jsonEncode(runs)),
    );
    await temporary.rename(_file.path);
  }

  Future<bool> record(Map<String, dynamic> summary,
      {List<Map<String, dynamic>> samples = const []}) async {
    validateExport(summary);
    final runs = await _load();
    final runId = summary['runId'] as String;
    if (runs.any((run) => run['runId'] == runId)) return false;
    final compact = Map<String, dynamic>.from(summary)..remove('samples');
    if (samples.isNotEmpty) {
      // Keep the same compact contract as the database implementation while
      // avoiding raw spans in the trend index.
      compact['sampleCount'] = samples.length;
    }
    runs.add(compact);
    runs.sort(_newestFirst);
    await _save();
    return true;
  }

  Future<List<Map<String, dynamic>>> runs() async => [
        for (final run in await _load()) Map<String, dynamic>.from(run),
      ];

  Future<Map<String, dynamic>?> baseline(Map<String, dynamic> run,
      {String? id}) async {
    final candidates = (await _load()).where((candidate) {
      if (id != null) return candidate['runId'] == id;
      return candidate['branch'] == run['branch'] &&
          candidate['runId'] != run['runId'];
    });
    if (id != null &&
        !candidates.any((candidate) => candidate['runId'] == id)) {
      throw ArgumentError('Unknown baseline run: $id');
    }
    for (final candidate in candidates) {
      if (compatibilityKey(candidate) == compatibilityKey(run)) {
        return Map<String, dynamic>.from(candidate);
      }
      if (id != null) {
        throw ArgumentError(
            'Baseline $id has an incompatible environment or workload');
      }
    }
    return null;
  }

  int pruneDetails({
    DateTime? now,
    int days = 30,
    int keepMostRecentRuns = 10,
    int incompleteRetentionDays = 7,
  }) {
    final directory = Directory(p.join(root.path, 'runs'));
    if (!directory.existsSync()) return 0;
    final currentTime = now ?? DateTime.now().toUtc();
    final cutoff = currentTime.subtract(Duration(days: days));
    final incompleteCutoff =
        currentTime.subtract(Duration(days: incompleteRetentionDays));
    final runs = <({Directory directory, DateTime timestamp})>[];
    var prunedRuns = 0;
    for (final entry
        in directory.listSync(followLinks: false).whereType<Directory>()) {
      final manifest = File(p.join(entry.path, 'manifest.json'));
      if (!manifest.existsSync()) {
        // An interrupted benchmark has no compact history record. Keep its
        // diagnostics briefly, then remove only recognized run directories.
        final files = entry
            .listSync(recursive: true, followLinks: false)
            .whereType<File>();
        var lastWrite = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
        for (final file in files) {
          final modified = file.lastModifiedSync();
          if (modified.isAfter(lastWrite)) lastWrite = modified;
        }
        if (files.isEmpty) lastWrite = entry.statSync().modified;
        if (RegExp(r'^\d+_\d+$').hasMatch(p.basename(entry.path)) &&
            lastWrite.isBefore(incompleteCutoff)) {
          entry.deleteSync(recursive: true);
          prunedRuns++;
        }
        continue;
      }
      try {
        final decoded = jsonDecode(manifest.readAsStringSync()) as Map;
        runs.add((
          directory: entry,
          timestamp: DateTime.parse(decoded['timestamp'] as String),
        ));
      } on FormatException {
        // Preserve unknown detail directories rather than deleting them.
      }
    }
    runs.sort((left, right) => right.timestamp.compareTo(left.timestamp));
    for (var index = 0; index < runs.length; index++) {
      final run = runs[index];
      if (index < keepMostRecentRuns && !run.timestamp.isBefore(cutoff)) {
        continue;
      }
      var removedDetails = false;
      for (final name in [
        'spans.jsonl.gz',
        'fixtures',
        'worker-output',
        'worker.log'
      ]) {
        final target = p.join(run.directory.path, name);
        if (FileSystemEntity.isDirectorySync(target)) {
          Directory(target).deleteSync(recursive: true);
          removedDetails = true;
        } else if (FileSystemEntity.isFileSync(target)) {
          File(target).deleteSync();
          removedDetails = true;
        }
      }
      if (removedDetails) prunedRuns++;
    }
    return prunedRuns;
  }

  Future<void> close() async {}

  static int _newestFirst(Map<String, dynamic> a, Map<String, dynamic> b) {
    final left = DateTime.tryParse(a['timestamp']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final right = DateTime.tryParse(b['timestamp']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return right.compareTo(left);
  }
}
