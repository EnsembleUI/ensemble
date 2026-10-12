import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'dart:convert';
import 'dart:io';

import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/reporters/test_report_document.dart';
import 'package:ensemble_test_runner/reporters/screenshot_archive.dart';
import 'package:ensemble_test_runner/reporters/result_projection.dart';
import 'package:ensemble_test_runner/reporters/step_outline_format.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final class HistoricalTestDurations {
  final Map<String, int> files;
  final Map<String, int> tests;

  const HistoricalTestDurations({
    this.files = const {},
    this.tests = const {},
  });

  int? fileDuration(String path) => files[path];

  int? testDuration(String id) => tests[id];
}

/// Appends compact historical suite results for quick trend/debug lookup.
///
/// Stores compact run and per-test summaries. Full logs and screenshots stay
/// in the latest report artifacts.
class EnsembleTestHistoryStore {
  static const fileName = 'ensemble_test.db';
  // History is for recent trends and comparisons, not an execution archive.
  // Full run evidence lives in the report artifacts; keep only the latest 50
  // compact summaries in SQLite.
  static const maxRuns = 50;
  static const _schemaVersion = 8;
  static const _maxFailureSummaryLength = 240;
  // The live history database is deliberately small (50 suite runs), so 64
  // pages is too high a floor: it can leave a third of the file unused. Only
  // vacuum after pruning, and only when both fragmentation signals
  // are meaningful, to reclaim that space without adding a per-run cost.
  static const _vacuumFreePageThreshold = 16;

  static bool _initialized = false;

  static Future<void> recordCompletedRun({
    required String appDir,
    required String artifactRoot,
    required EnsembleTestRunResult result,
    int? wallTimeMs,
    Map<String, dynamic>? reportDocument,
  }) async {
    return await RunnerBenchmark.async('history', 'recordCompletedRun',
        () async {
      _ensureInitialized();

      final reportDir = Directory(p.join(artifactRoot, 'report'));
      reportDir.createSync(recursive: true);
      ScreenshotArchive.create(artifactRoot);
      final db = await _openDatabase(reportDir);
      try {
        final currentReport = reportDocument ??
            TestReportDocument.buildComplete(
              result,
              artifactRoot: artifactRoot,
              displayRoot: p.join('build', 'ensemble_test_runner'),
              wallTimeMs: wallTimeMs,
            );
        final compressedReport =
            TestReportDocument.encodeCompressed(currentReport);
        final prunedHistory = await db.transaction((txn) async {
          await txn.rawUpdate(
            "UPDATE test_results SET report_data = NULL WHERE record_type = 'run' AND report_data IS NOT NULL",
          );
          final suite = SuiteResultProjection(result);
          final failedCount = suite.failed;
          final passedCount = suite.passed;
          final status = suite.status;
          final durationMs = wallTimeMs ?? suite.totalDurationMs;

          final catalog = await _loadTestCatalog(txn);
          final createdAt = DateTime.now().toUtc().toIso8601String();
          final runId = await txn.insert('test_results', {
            'record_type': 'run',
            'status': status,
            'duration_ms': durationMs,
            'report_data': compressedReport,
            'summary_data': jsonEncode({
              'created_at': createdAt,
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
            }),
          });

          for (final test in result.results) {
            final projection = TestResultProjection(test);
            final testId = baseTestId(test.testId);
            final executionId = _executionId(test.testId);
            final fileName = p.basename(filePathOf(test.testId));
            final assetPath = filePathOf(test.testId).replaceAll('\\', '/');
            final device = _deviceLabel(test);
            final scenario = _stringValue(test.metadata['scenarioId']);
            final profile = _stringValue(test.metadata['profile']);
            final failedStep = _failedStepLabel(test);
            final error = _errorSummary(projection.failureMessage);
            final testRef = await _internTest(
              txn,
              catalog,
              testId: testId,
              executionId: executionId,
              durationMs: projection.durationMs,
              runId: runId,
              fileName: fileName,
              assetPath: assetPath,
              device: device,
              scenario: scenario,
              profile: profile,
            );
            await txn.insert('test_results', {
              'record_type': 'test',
              'run_id': runId,
              'test_ref': testRef,
              'status': projection.status,
              'duration_ms': projection.durationMs,
              'attempts': projection.attempts,
              'failed_step_index': test.failedStepIndex,
              'failed_step': failedStep,
              // Match the canonical JSON/HTML failure projection. Legacy
              // paths may only provide a free-form message, so use the same
              // inferred kind rather than leaving history inconsistent.
              'error_kind': projection.failureKind,
              'error_summary': error,
            });
          }

          final stateRows = await txn.query(
            'report_state',
            columns: ['started_at'],
            where: 'id = 1',
            limit: 1,
          );
          await txn.insert(
            'report_state',
            {
              'id': 1,
              'state': 'complete',
              'started_at': stateRows.isEmpty
                  ? createdAt
                  : stateRows.single['started_at'],
              'updated_at': createdAt,
              'run_id': runId,
              'total_tests': result.results.length,
              'passed_tests': passedCount,
              'failed_tests': failedCount,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );

          return await _pruneOldRuns(txn);
        });
        if (prunedHistory) await _compactIfNeeded(db);
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

  /// Prepares the screenshot workspace for a new run while retaining the last
  /// completed report and archive until the replacement report is committed.
  static Future<void> markReportLoading({required String artifactRoot}) async {
    _ensureInitialized();
    ScreenshotArchive.clearPendingImages(artifactRoot);
    final reportDir = Directory(p.join(artifactRoot, 'report'))
      ..createSync(recursive: true);
    final db = await _openDatabase(reportDir);
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await db.insert(
        'report_state',
        {
          'id': 1,
          'state': 'running',
          'started_at': now,
          'updated_at': now,
          'total_tests': 0,
          'passed_tests': 0,
          'failed_tests': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } finally {
      await db.close();
    }
    final oldDurationCache = File(p.join(
      artifactRoot,
      'test_durations.json',
    ));
    if (oldDurationCache.existsSync()) oldDurationCache.deleteSync();
  }

  static Future<Database> _openDatabase(Directory reportDir) {
    final dbPath = p.join(reportDir.path, fileName);
    return databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: _schemaVersion,
        onCreate: (db, version) => _createSchema(db),
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 7) await _upgradeToVersion7(db);
          if (oldVersion < 8) await _upgradeToVersion8(db);
        },
      ),
    );
  }

  static Future<void> _createSchema(DatabaseExecutor db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS test_catalog (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  identity_key TEXT NOT NULL UNIQUE,
  test_id TEXT NOT NULL,
  file_name TEXT,
  device TEXT,
  scenario TEXT,
  profile TEXT,
  asset_path TEXT,
  execution_id TEXT NOT NULL DEFAULT '',
  duration_ms INTEGER NOT NULL DEFAULT 0,
  last_run_id INTEGER
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS test_results (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  record_type TEXT NOT NULL CHECK(record_type IN ('run', 'test')),
  run_id INTEGER,
  test_ref INTEGER,
  status TEXT NOT NULL,
  duration_ms INTEGER NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 1,
  failed_step_index INTEGER,
  failed_step TEXT,
  error_kind TEXT,
  error_summary TEXT,
  summary_data TEXT,
  report_data BLOB,
  FOREIGN KEY(run_id) REFERENCES test_results(id) ON DELETE CASCADE,
  FOREIGN KEY(test_ref) REFERENCES test_catalog(id),
  CHECK((record_type = 'run' AND run_id IS NULL AND test_ref IS NULL) OR
        (record_type = 'test' AND run_id IS NOT NULL AND test_ref IS NOT NULL))
)
''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_test_results_run ON test_results(run_id)');
    await _createReportStateTable(db);
  }

  static Future<void> _upgradeToVersion7(DatabaseExecutor db) async {
    await db.execute(
      "ALTER TABLE test_catalog ADD COLUMN execution_id TEXT NOT NULL DEFAULT ''",
    );
    await db.execute(
      'ALTER TABLE test_catalog ADD COLUMN duration_ms INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute(
      'ALTER TABLE test_catalog ADD COLUMN last_run_id INTEGER',
    );
    await db.execute('''
UPDATE test_catalog
SET duration_ms = COALESCE((
  SELECT duration_ms FROM test_results
  WHERE record_type = 'test' AND test_ref = test_catalog.id
  ORDER BY run_id DESC LIMIT 1
), 0),
last_run_id = (
  SELECT run_id FROM test_results
  WHERE record_type = 'test' AND test_ref = test_catalog.id
  ORDER BY run_id DESC LIMIT 1
),
execution_id = test_id
''');
    await _createReportStateTable(db);
    final latestRuns = await db.query(
      'test_results',
      columns: ['id', 'summary_data'],
      where: "record_type = 'run'",
      orderBy: 'id DESC',
      limit: 1,
    );
    if (latestRuns.isNotEmpty) {
      final latest = latestRuns.single;
      final summary = jsonDecode(latest['summary_data'] as String? ?? '{}');
      final createdAt =
          summary is Map ? summary['created_at']?.toString() : null;
      if (createdAt != null && createdAt.isNotEmpty) {
        await db.insert(
          'report_state',
          {
            'id': 1,
            'state': 'complete',
            'started_at': createdAt,
            'updated_at': createdAt,
            'run_id': latest['id'],
            'total_tests': _summaryCount(summary, 'total_tests'),
            'passed_tests': _summaryCount(summary, 'passed_tests'),
            'failed_tests': _summaryCount(summary, 'failed_tests'),
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
  }

  static int _summaryCount(dynamic summary, String key) {
    final value = summary is Map ? summary[key] : null;
    return value is num && value >= 0 ? value.toInt() : 0;
  }

  static Future<void> _upgradeToVersion8(DatabaseExecutor db) async {
    await db.execute('ALTER TABLE test_catalog ADD COLUMN asset_path TEXT');
  }

  static Future<void> _createReportStateTable(DatabaseExecutor db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS report_state (
  id INTEGER PRIMARY KEY CHECK(id = 1),
  state TEXT NOT NULL CHECK(state IN ('running', 'complete')),
  started_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  run_id INTEGER,
  total_tests INTEGER NOT NULL DEFAULT 0,
  passed_tests INTEGER NOT NULL DEFAULT 0,
  failed_tests INTEGER NOT NULL DEFAULT 0
)
''');
  }

  static Future<Map<String, int>> _loadTestCatalog(DatabaseExecutor db) async {
    final rows =
        await db.query('test_catalog', columns: ['id', 'identity_key']);
    return {
      for (final row in rows)
        row['identity_key']! as String: (row['id']! as num).toInt(),
    };
  }

  static Future<int> _internTest(
    DatabaseExecutor db,
    Map<String, int> catalog, {
    required String testId,
    required String executionId,
    required int durationMs,
    required int runId,
    required String? fileName,
    required String? assetPath,
    required String? device,
    required String? scenario,
    required String? profile,
  }) async {
    final identity = jsonEncode([testId, fileName, device, scenario, profile]);
    final known = catalog[identity];
    if (known != null) {
      await db.update(
        'test_catalog',
        {
          'execution_id': executionId,
          'asset_path': assetPath,
          'duration_ms': durationMs,
          'last_run_id': runId,
        },
        where: 'id = ?',
        whereArgs: [known],
      );
      return known;
    }

    // The catalog was loaded at transaction start, so a missing in-memory key
    // is guaranteed to be a new row. The insert returns its ID directly and
    // avoids an extra SELECT for every distinct test variant.
    final id = await db.insert('test_catalog', {
      'identity_key': identity,
      'test_id': testId,
      'file_name': fileName,
      'asset_path': assetPath,
      'device': device,
      'scenario': scenario,
      'profile': profile,
      'execution_id': executionId,
      'duration_ms': durationMs,
      'last_run_id': runId,
    });
    catalog[identity] = id;
    return id;
  }

  static String _executionId(String testId) {
    final assetMarker = RegExp(r'\s+\(').firstMatch(testId)?.start;
    return (assetMarker == null ? testId : testId.substring(0, assetMarker))
        .trim();
  }

  /// Reads scheduler estimates from the same retained history database used by
  /// the report. Each test uses its latest recorded duration; file estimates
  /// sum the newest retained run that contains that file.
  static Future<HistoricalTestDurations> loadPlannerDurations(
    String appDir,
  ) async {
    final dbFile = File(p.join(
      appDir,
      'build',
      'ensemble_test_runner',
      'report',
      fileName,
    ));
    if (!dbFile.existsSync()) return const HistoricalTestDurations();
    _ensureInitialized();
    final db = await databaseFactoryFfi.openDatabase(dbFile.path);
    try {
      final catalogRows = await db.rawQuery('''
SELECT execution_id, duration_ms FROM test_catalog
WHERE execution_id != '' AND duration_ms > 0
ORDER BY last_run_id DESC
''');
      final tests = <String, int>{};
      for (final row in catalogRows) {
        tests.putIfAbsent(
          row['execution_id']! as String,
          () => (row['duration_ms'] as num).toInt(),
        );
      }

      final resultRows = await db.rawQuery('''
SELECT r.run_id, r.duration_ms, c.asset_path
FROM test_results r JOIN test_catalog c ON c.id = r.test_ref
WHERE r.record_type = 'test' AND r.duration_ms > 0
AND c.asset_path IS NOT NULL AND c.asset_path != ''
ORDER BY r.run_id DESC, c.asset_path ASC
''');
      final latestFileRuns = <String, int>{};
      final files = <String, int>{};
      for (final row in resultRows) {
        final assetPath = row['asset_path'] as String?;
        if (assetPath == null || assetPath.isEmpty) continue;
        final runId = (row['run_id'] as num).toInt();
        final latestRunId = latestFileRuns.putIfAbsent(assetPath, () => runId);
        if (latestRunId == runId) {
          files[assetPath] =
              (files[assetPath] ?? 0) + (row['duration_ms'] as num).toInt();
        }
      }
      return HistoricalTestDurations(files: files, tests: tests);
    } finally {
      await db.close();
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

  static Future<bool> _pruneOldRuns(Transaction txn) async {
    return await RunnerBenchmark.async('history', 'pruneOldRuns', () async {
      final oldRuns = await txn.rawQuery(
        '''
SELECT id FROM test_results
WHERE record_type = 'run' AND id NOT IN (
  SELECT id FROM test_results
  WHERE record_type = 'run'
  ORDER BY id DESC
  LIMIT ?
)
''',
        [maxRuns],
      );
      final oldIds = oldRuns.map((row) => row['id']).toList();
      if (oldIds.isEmpty) return false;

      final placeholders = List.filled(oldIds.length, '?').join(',');
      await txn.rawDelete(
        'DELETE FROM test_results WHERE id IN ($placeholders) OR run_id IN ($placeholders)',
        [...oldIds, ...oldIds],
      );
      await txn.rawDelete('''
DELETE FROM test_catalog
WHERE NOT EXISTS (
  SELECT 1 FROM test_results
  WHERE record_type = 'test' AND test_ref = test_catalog.id
)
''');
      return true;
    });
  }

  static Future<void> _compactIfNeeded(Database db) async {
    final rows = await db.rawQuery('PRAGMA freelist_count');
    final freePages = (rows.first['freelist_count'] as num?)?.toInt() ?? 0;
    if (freePages < _vacuumFreePageThreshold) return;

    final pageRows = await db.rawQuery('PRAGMA page_count');
    final pageCount = (pageRows.first['page_count'] as num?)?.toInt() ?? 0;
    if (pageCount == 0 || freePages * 4 < pageCount) return;

    // VACUUM must run outside the write transaction and only after pruning.
    await db.execute('VACUUM');
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
    final summary = text
        .split(RegExp(r'\r?\n'))
        .first
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (summary.length <= _maxFailureSummaryLength) return summary;
    return '${summary.substring(0, _maxFailureSummaryLength - 1)}…';
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
