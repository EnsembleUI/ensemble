import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'dart:io';

import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/reporters/test_report_document.dart';
import 'package:ensemble_test_runner/reporters/step_outline_format.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Appends compact historical suite results for quick trend/debug lookup.
///
/// Stores compact run and per-test summaries. Full logs and screenshots stay
/// in the latest report artifacts.
class EnsembleTestHistoryStore {
  static const fileName = 'ensemble_test_history.db';
  static const maxRuns = 500;

  static bool _initialized = false;

  static Future<void> recordCompletedRun({
    required String appDir,
    required String artifactRoot,
    required EnsembleTestRunResult result,
    int? wallTimeMs,
  }) async {
    return await RunnerBenchmark.async('history', 'recordCompletedRun',
        () async {
      _ensureInitialized();

      final reportDir = Directory(p.join(artifactRoot, 'report'));
      reportDir.createSync(recursive: true);
      final dbPath = p.join(reportDir.path, fileName);
      final db = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async => _createSchema(db),
          onOpen: _createSchema,
        ),
      );

      try {
        await db.transaction((txn) async {
          final failedCount = result.failedCount;
          final passedCount = result.passedCount;
          final status = failedCount > 0 ? 'failed' : 'passed';
          final durationMs = wallTimeMs ??
              result.results.fold<int>(
                0,
                (sum, test) => sum + test.durationMs,
              );

          final runId = await txn.insert('runs', {
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'status': status,
            'duration_ms': durationMs,
            'passed_tests': passedCount,
            'failed_tests': failedCount,
            'total_tests': result.results.length,
            'commit_hash': _envOrGit(
              appDir,
              envKeys: const ['BUILD_SOURCEVERSION'],
              gitArgs: const ['rev-parse', '--short', 'HEAD'],
              shorten: true,
            ),
            'branch': _envOrGit(
              appDir,
              envKeys: const [
                'SYSTEM_PULLREQUEST_SOURCEBRANCH',
                'BUILD_SOURCEBRANCHNAME',
                'BUILD_SOURCEBRANCH',
              ],
              gitArgs: const ['rev-parse', '--abbrev-ref', 'HEAD'],
            ),
            'build_number': _firstEnv(const ['BUILD_BUILDNUMBER']),
            'pr_number':
                _firstEnv(const ['SYSTEM_PULLREQUEST_PULLREQUESTNUMBER']),
            'mode': _stringValue(result.metadata['mode']),
            'platform': _stringValue(result.metadata['platform']) ??
                _singleMetadataValue(result.results, 'platform'),
            'device_id': _stringValue(result.metadata['deviceId']) ??
                _singleDeviceValue(result.results, id: true),
            'device_name': _stringValue(result.metadata['deviceName']) ??
                _singleDeviceValue(result.results),
          });

          for (final test in result.results) {
            final testId = baseTestId(test.testId);
            final fileName = p.basename(filePathOf(test.testId));
            final device = _deviceLabel(test);
            final scenario = _stringValue(test.metadata['scenarioId']);
            final profile = _stringValue(test.metadata['profile']);
            final feature = _stringValue(test.metadata['feature']);
            final error = _errorSummary(test.message);
            await txn.insert('test_results', {
              'run_id': runId,
              'test_id': testId,
              'file_name': fileName,
              'device': device,
              'scenario': scenario,
              'profile': profile,
              'feature': feature,
              'status': test.status.name,
              'duration_ms': test.durationMs,
              'attempts': test.attempts,
              'failed_step_index': test.failedStepIndex,
              'failed_step': _failedStepLabel(test),
              'error_kind': test.failure?.kind.name,
              'error_summary': error,
            });
            if (test.status == TestStatus.failed) {
              await txn.insert('failed_tests', {
                'run_id': runId,
                'test_id': testId,
                'base_id': testId,
                'file_name': fileName,
                'device': device,
                'scenario': scenario,
                'failed_step_index': test.failedStepIndex,
                'failed_step': _failedStepLabel(test),
                'error_summary': error,
              });
            }
          }

          await _pruneOldRuns(txn);
        });
      } finally {
        await db.close();
      }
    });
  }

  static void _ensureInitialized() {
    if (_initialized) return;
    sqfliteFfiInit();
    _initialized = true;
  }

  static Future<void> _createSchema(Database db, [int? _]) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS runs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  created_at TEXT NOT NULL,
  status TEXT NOT NULL,
  duration_ms INTEGER NOT NULL,
  passed_tests INTEGER NOT NULL,
  failed_tests INTEGER NOT NULL,
  total_tests INTEGER NOT NULL,
  commit_hash TEXT,
  branch TEXT,
  build_number TEXT,
  pr_number TEXT,
  mode TEXT,
  platform TEXT,
  device_id TEXT,
  device_name TEXT
)
''');
    await _migrateRunsSchema(db);
    await _ensureRunContextColumns(db);
    await db.execute('''
CREATE TABLE IF NOT EXISTS failed_tests (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  run_id INTEGER NOT NULL,
  test_id TEXT NOT NULL,
  base_id TEXT,
  file_name TEXT,
  device TEXT,
  scenario TEXT,
  failed_step_index INTEGER,
  failed_step TEXT,
  error_summary TEXT,
  FOREIGN KEY(run_id) REFERENCES runs(id) ON DELETE CASCADE
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS test_results (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  run_id INTEGER NOT NULL,
  test_id TEXT NOT NULL,
  file_name TEXT,
  device TEXT,
  scenario TEXT,
  profile TEXT,
  feature TEXT,
  status TEXT NOT NULL,
  duration_ms INTEGER NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 1,
  failed_step_index INTEGER,
  failed_step TEXT,
  error_kind TEXT,
  error_summary TEXT,
  FOREIGN KEY(run_id) REFERENCES runs(id) ON DELETE CASCADE
)
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_test_results_run ON test_results(run_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_test_results_test ON test_results(test_id, run_id)',
    );
    await _migrateFailedTestsSchema(db);
    await _normalizeFailedTestIds(db);
  }

  static Future<void> _migrateFailedTestsSchema(Database db) async {
    final tableInfo = await db.rawQuery('PRAGMA table_info(failed_tests)');
    final columns = tableInfo
        .map((row) => row['name']?.toString())
        .whereType<String>()
        .toSet();

    if (!columns.contains('failed_step_index')) {
      await db.execute(
        'ALTER TABLE failed_tests ADD COLUMN failed_step_index INTEGER',
      );
    }
    if (!columns.contains('failed_step')) {
      await db.execute(
        'ALTER TABLE failed_tests ADD COLUMN failed_step TEXT',
      );
    }
  }

  static String? _failedStepLabel(EnsembleSingleTestResult test) {
    final step = test.failedStep;
    if (step != null) return formatStepBrief(step);

    final index = test.failedStepIndex;
    final outline = test.report?.stepsOutline ?? const <String>[];
    if (index != null && index >= 0 && index < outline.length) {
      return outline[index];
    }
    return null;
  }

  static Future<void> _migrateRunsSchema(Database db) async {
    final tableInfo = await db.rawQuery('PRAGMA table_info(runs)');
    final columns = tableInfo
        .map((row) => row['name']?.toString())
        .whereType<String>()
        .toSet();

    if (!columns.contains('pending_tests')) {
      await db.rawUpdate(
        "UPDATE runs SET status = 'failed' "
        "WHERE status NOT IN ('passed', 'failed')",
      );
      return;
    }

    await db.execute('PRAGMA foreign_keys=OFF');
    try {
      await db.execute('DROP TABLE IF EXISTS runs_migrated');
      await db.execute('''
CREATE TABLE runs_migrated (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  created_at TEXT NOT NULL,
  status TEXT NOT NULL,
  duration_ms INTEGER NOT NULL,
  passed_tests INTEGER NOT NULL,
  failed_tests INTEGER NOT NULL,
  total_tests INTEGER NOT NULL,
  commit_hash TEXT,
  branch TEXT,
  build_number TEXT,
  pr_number TEXT,
  mode TEXT,
  platform TEXT,
  device_id TEXT,
  device_name TEXT
)
''');
      await db.execute('''
INSERT INTO runs_migrated (
  id,
  created_at,
  status,
  duration_ms,
  passed_tests,
  failed_tests,
  total_tests,
  commit_hash,
  branch,
  build_number,
  pr_number,
  mode,
  platform,
  device_id,
  device_name
)
SELECT
  id,
  created_at,
  CASE WHEN status = 'passed' THEN 'passed' ELSE 'failed' END,
  duration_ms,
  passed_tests,
  failed_tests,
  total_tests,
  commit_hash,
  branch,
  build_number,
  pr_number,
  NULL,
  NULL,
  NULL,
  NULL
FROM runs
''');
      await db.execute('DROP TABLE runs');
      await db.execute('ALTER TABLE runs_migrated RENAME TO runs');
    } finally {
      await db.execute('PRAGMA foreign_keys=ON');
    }
  }

  static Future<void> _ensureRunContextColumns(Database db) async {
    final tableInfo = await db.rawQuery('PRAGMA table_info(runs)');
    final columns = tableInfo
        .map((row) => row['name']?.toString())
        .whereType<String>()
        .toSet();
    for (final column in const [
      'mode',
      'platform',
      'device_id',
      'device_name',
    ]) {
      if (!columns.contains(column)) {
        await db.execute('ALTER TABLE runs ADD COLUMN $column TEXT');
      }
    }
  }

  static Future<void> _normalizeFailedTestIds(Database db) async {
    await db.rawUpdate('''
UPDATE failed_tests
SET test_id = base_id
WHERE base_id IS NOT NULL
  AND base_id != ''
  AND test_id != base_id
''');
  }

  static Future<void> _pruneOldRuns(Transaction txn) async {
    return await RunnerBenchmark.async('history', 'pruneOldRuns', () async {
      final oldRuns = await txn.rawQuery(
        '''
SELECT id FROM runs
WHERE id NOT IN (
  SELECT id FROM runs
  ORDER BY id DESC
  LIMIT ?
)
''',
        [maxRuns],
      );
      final oldIds = oldRuns.map((row) => row['id']).toList();
      if (oldIds.isEmpty) return;

      final placeholders = List.filled(oldIds.length, '?').join(',');
      await txn.rawDelete(
        'DELETE FROM failed_tests WHERE run_id IN ($placeholders)',
        oldIds,
      );
      await txn.rawDelete(
        'DELETE FROM test_results WHERE run_id IN ($placeholders)',
        oldIds,
      );
      await txn.rawDelete(
        'DELETE FROM runs WHERE id IN ($placeholders)',
        oldIds,
      );
    });
  }

  static String? _deviceLabel(EnsembleSingleTestResult test) {
    final device = test.metadata['device'];
    if (device is Map) {
      return _stringValue(device['displayLabel']) ??
          _stringValue(device['model']) ??
          _stringValue(device['name']) ??
          _stringValue(device['id']);
    }
    return _stringValue(device);
  }

  static String? _singleDeviceValue(
    List<EnsembleSingleTestResult> results, {
    bool id = false,
  }) {
    final values = results
        .map((test) {
          final device = test.metadata['device'];
          if (device is Map) {
            return _stringValue(device[id ? 'id' : 'model']) ??
                _stringValue(device['name']);
          }
          return _stringValue(device);
        })
        .whereType<String>()
        .toSet();
    return values.length == 1 ? values.single : null;
  }

  static String? _singleMetadataValue(
    List<EnsembleSingleTestResult> results,
    String key,
  ) {
    final values = results
        .map((test) {
          final device = test.metadata['device'];
          return device is Map ? _stringValue(device[key]) : null;
        })
        .whereType<String>()
        .toSet();
    return values.length == 1 ? values.single : null;
  }

  static String? _stringValue(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static String? _errorSummary(String? message) {
    final text = message?.trim();
    if (text == null || text.isEmpty) return null;
    return text
        .split(RegExp(r'\r?\n'))
        .first
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String? _firstEnv(List<String> keys) {
    for (final key in keys) {
      final value = Platform.environment[key]?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static String? _envOrGit(
    String appDir, {
    required List<String> envKeys,
    required List<String> gitArgs,
    bool shorten = false,
  }) {
    final env = _firstEnv(envKeys);
    if (env != null) {
      return shorten && env.length > 12 ? env.substring(0, 12) : env;
    }
    try {
      final result = Process.runSync(
        'git',
        gitArgs,
        workingDirectory: appDir,
      );
      if (result.exitCode != 0) return null;
      final value = result.stdout.toString().trim();
      if (value.isEmpty) return null;
      return shorten && value.length > 12 ? value.substring(0, 12) : value;
    } catch (_) {
      return null;
    }
  }
}
