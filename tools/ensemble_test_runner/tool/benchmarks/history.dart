import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'results.dart';

class BenchmarkHistory {
  BenchmarkHistory(this.root);
  final Directory root;
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    root.createSync(recursive: true);
    sqfliteFfiInit();
    return _db = await databaseFactoryFfi.openDatabase(
        p.join(root.path, 'history.sqlite'),
        options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, version) async {
              await db.execute(
                  'CREATE TABLE runs (id TEXT PRIMARY KEY, created_at TEXT NOT NULL, branch TEXT NOT NULL, compatibility TEXT NOT NULL, summary_json TEXT NOT NULL)');
              await db.execute(
                  'CREATE INDEX runs_context ON runs(branch, compatibility, created_at)');
              await db.execute(
                  'CREATE TABLE cases (run_id TEXT NOT NULL, case_id TEXT NOT NULL, status TEXT NOT NULL, summary_json TEXT NOT NULL, PRIMARY KEY(run_id, case_id))');
              await db.execute(
                  'CREATE TABLE samples (run_id TEXT NOT NULL, case_id TEXT NOT NULL, sample INTEGER NOT NULL, summary_json TEXT NOT NULL, PRIMARY KEY(run_id, case_id, sample))');
              await db.execute(
                  'CREATE TABLE operations (run_id TEXT NOT NULL, case_id TEXT NOT NULL, operation TEXT NOT NULL, summary_json TEXT NOT NULL, PRIMARY KEY(run_id, case_id, operation))');
              await db.execute(
                  'CREATE TABLE baselines (run_id TEXT PRIMARY KEY, baseline_id TEXT)');
            },
            onUpgrade: (db, old, next) async {
              throw StateError(
                  'Unsupported benchmark history migration $old → $next');
            }));
  }

  Future<bool> record(Map<String, dynamic> summary,
      {List<Map<String, dynamic>> samples = const []}) async {
    validateExport(summary);
    if (samples.isEmpty && summary['samples'] is List)
      samples = (summary['samples'] as List)
          .map((s) => Map<String, dynamic>.from(s as Map))
          .toList();
    final compactSummary = {...summary}..remove('samples');
    final db = await database;
    return db.transaction((txn) async {
      if ((await txn
              .query('runs', where: 'id = ?', whereArgs: [summary['runId']]))
          .isNotEmpty) return false;
      await txn.insert('runs', {
        'id': summary['runId'],
        'created_at': summary['timestamp'],
        'branch': summary['branch'],
        'compatibility': compatibilityKey(summary),
        'summary_json': jsonEncode(compactSummary)
      });
      for (final c in summary['cases'] as List) {
        await txn.insert('cases', {
          'run_id': summary['runId'],
          'case_id': c['id'],
          'status': c['status'],
          'summary_json': jsonEncode(c)
        });
        for (final op in c['operations'] as List? ?? []) {
          await txn.insert('operations', {
            'run_id': summary['runId'],
            'case_id': c['id'],
            'operation': op['key'],
            'summary_json': jsonEncode(op)
          });
        }
      }
      for (final s in samples) {
        final compact = {...s}..remove('spans');
        await txn.insert('samples', {
          'run_id': summary['runId'],
          'case_id': s['caseId'],
          'sample': s['index'],
          'summary_json': jsonEncode(compact)
        });
      }
      await txn.insert('baselines', {
        'run_id': summary['runId'],
        'baseline_id': summary['baselineRunId']
      });
      return true;
    });
  }

  Future<List<Map<String, dynamic>>> runs() async => [
        for (final row in await (await database)
            .query('runs', orderBy: 'created_at DESC, id DESC'))
          jsonDecode(row['summary_json'] as String) as Map<String, dynamic>
      ];

  Future<Map<String, dynamic>?> baseline(Map<String, dynamic> run,
      {String? id}) async {
    final db = await database;
    final rows = await db.query('runs',
        where: id != null
            ? 'id = ?'
            : 'branch = ? AND compatibility = ? AND id <> ?',
        whereArgs: id != null
            ? [id]
            : [run['branch'], compatibilityKey(run), run['runId']],
        orderBy: 'created_at DESC, id DESC',
        limit: 1);
    if (rows.isEmpty) {
      if (id != null) throw ArgumentError('Unknown baseline run: $id');
      return null;
    }
    final prior = jsonDecode(rows.single['summary_json'] as String)
        as Map<String, dynamic>;
    if (compatibilityKey(prior) != compatibilityKey(run)) {
      throw ArgumentError(
          'Baseline $id has an incompatible environment or workload');
    }
    return prior;
  }

  /// Compact summaries are retained; only this tool's expired per-run data goes.
  void pruneDetails({DateTime? now, int days = 30}) {
    final directory = Directory(p.join(root.path, 'runs'));
    if (!directory.existsSync()) return;
    final cutoff =
        (now ?? DateTime.now().toUtc()).subtract(Duration(days: days));
    for (final entry
        in directory.listSync(followLinks: false).whereType<Directory>()) {
      final manifest = File(p.join(entry.path, 'manifest.json'));
      if (!manifest.existsSync()) continue;
      try {
        final decoded = jsonDecode(manifest.readAsStringSync()) as Map;
        if (DateTime.parse(decoded['timestamp'] as String).isBefore(cutoff)) {
          for (final name in [
            'spans.jsonl.gz',
            'fixtures',
            'worker-output',
            'worker.log'
          ]) {
            final target = p.join(entry.path, name);
            if (FileSystemEntity.isDirectorySync(target)) {
              Directory(target).deleteSync(recursive: true);
            } else if (FileSystemEntity.isFileSync(target)) {
              File(target).deleteSync();
            }
          }
        }
      } on FormatException {/* Keep unknown data rather than deleting it. */}
    }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}

void validateExport(Map<String, dynamic> run) {
  if (run['schemaVersion'] != benchmarkSchemaVersion)
    throw FormatException('Unsupported benchmark export schema');
  if (run['runId'] is! String ||
      !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(run['runId'] as String))
    throw FormatException('Invalid benchmark run ID');
  DateTime.parse(run['timestamp'] as String);
  if (run['branch'] is! String ||
      run['environment'] is! Map ||
      run['cases'] is! List)
    throw FormatException('Incomplete benchmark export');
  final ids = <String>{};
  for (final c in run['cases'] as List) {
    if (c is! Map ||
        c['id'] is! String ||
        !ids.add(c['id'] as String) ||
        !['measured', 'skipped', 'invalid'].contains(c['status']))
      throw FormatException('Invalid benchmark case');
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
        !sampleIds.add('${raw['caseId']}:${raw['index']}'))
      throw FormatException('Invalid benchmark sample');
  }
}
