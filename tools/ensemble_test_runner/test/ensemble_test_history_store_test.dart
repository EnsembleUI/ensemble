import 'dart:io';

import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/reporters/ensemble_test_history_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('ensemble_history_');
    sqfliteFfiInit();
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('records compact completed run history', () async {
    await EnsembleTestHistoryStore.recordCompletedRun(
      appDir: tempDir.path,
      artifactRoot: tempDir.path,
      wallTimeMs: 1234,
      result: EnsembleTestRunResult(
        metadata: const {
          'mode': 'integration',
          'platform': 'ios',
          'deviceName': 'iPhone 15 Pro',
        },
        results: [
          EnsembleSingleTestResult.passed(
            testId:
                'login_test[android] (ensemble/apps/app/tests/login.test.yaml)',
            durationMs: 300,
            metadata: const {
              'device': {'id': 'android'},
            },
          ),
          EnsembleSingleTestResult.failed(
            testId:
                'settings_flow[retry_case][iphone] (ensemble/apps/app/tests/settings.test.yaml)',
            durationMs: 700,
            failedStepIndex: 2,
            failedStep: const TestStep(
              type: 'tap',
              args: {'id': 'save_button'},
            ),
            error: 'Timed out waiting for id "save_button".\nextra details',
            metadata: const {
              'scenarioId': 'retry_case',
              'device': {'id': 'iphone'},
            },
          ),
        ],
      ),
    );

    final dbPath = p.join(
      tempDir.path,
      'report',
      EnsembleTestHistoryStore.fileName,
    );
    expect(File(dbPath).existsSync(), isTrue);
    final db = await databaseFactoryFfi.openDatabase(dbPath);
    addTearDown(db.close);

    final runs = await db.query('runs');
    expect(runs, hasLength(1));
    expect(runs.single['status'], 'failed');
    expect(runs.single['duration_ms'], 1234);
    expect(runs.single['passed_tests'], 1);
    expect(runs.single['failed_tests'], 1);
    expect(runs.single['total_tests'], 2);
    expect(runs.single['mode'], 'integration');
    expect(runs.single['platform'], 'ios');
    expect(runs.single['device_name'], 'iPhone 15 Pro');

    final testResults = await db.query('test_results', orderBy: 'id ASC');
    expect(testResults, hasLength(2));
    expect(testResults.first['status'], 'passed');
    expect(testResults.first['duration_ms'], 300);
    expect(testResults.last['status'], 'failed');
    expect(testResults.last['scenario'], 'retry_case');
    expect(testResults.last['failed_step'], 'tap(save_button)');
    expect(testResults.last['error_kind'], isNull);

    final failed = await db.query('failed_tests');
    expect(failed, hasLength(1));
    expect(failed.single['test_id'], 'settings_flow');
    expect(failed.single['base_id'], 'settings_flow');
    expect(failed.single['file_name'], 'settings.test.yaml');
    expect(failed.single['device'], 'iphone');
    expect(failed.single['scenario'], 'retry_case');
    expect(failed.single['failed_step_index'], 2);
    expect(failed.single['failed_step'], 'tap(save_button)');
    expect(
      failed.single['error_summary'],
      'Timed out waiting for id "save_button".',
    );
  });

  test('migrates failed step columns into an existing history database',
      () async {
    final reportDir = Directory(p.join(tempDir.path, 'report'))
      ..createSync(recursive: true);
    final dbPath = p.join(reportDir.path, EnsembleTestHistoryStore.fileName);
    final oldDb = await databaseFactoryFfi.openDatabase(dbPath);
    await oldDb.execute('''
CREATE TABLE runs (
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
  pr_number TEXT
)
''');
    await oldDb.execute('''
CREATE TABLE failed_tests (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  run_id INTEGER NOT NULL,
  test_id TEXT NOT NULL,
  base_id TEXT,
  file_name TEXT,
  device TEXT,
  scenario TEXT,
  error_summary TEXT,
  FOREIGN KEY(run_id) REFERENCES runs(id) ON DELETE CASCADE
)
''');
    await oldDb.close();

    await EnsembleTestHistoryStore.recordCompletedRun(
      appDir: tempDir.path,
      artifactRoot: tempDir.path,
      result: EnsembleTestRunResult(
        results: [
          EnsembleSingleTestResult.failed(
            testId: 'new_test (ensemble/apps/app/tests/new.test.yaml)',
            durationMs: 100,
            failedStepIndex: 0,
            failedStep: const TestStep(
              type: 'expectVisible',
              args: {'id': 'welcome_text'},
            ),
            error: 'not visible',
          ),
        ],
      ),
    );

    final db = await databaseFactoryFfi.openDatabase(dbPath);
    addTearDown(db.close);
    final columns = await db.rawQuery('PRAGMA table_info(failed_tests)');
    expect(
      columns.map((row) => row['name']),
      containsAll(['failed_step_index', 'failed_step']),
    );
    final failed = await db.query('failed_tests');
    expect(failed.single['failed_step_index'], 0);
    expect(failed.single['failed_step'], 'expectVisible(welcome_text)');
    expect(await db.query('test_results'), hasLength(1));
    final runColumns = await db.rawQuery('PRAGMA table_info(runs)');
    expect(
        runColumns.map((row) => row['name']),
        containsAll([
          'mode',
          'platform',
          'device_id',
          'device_name',
        ]));
  });

  test('keeps only the latest 500 history runs', () async {
    EnsembleTestRunResult failedRun(int index) => EnsembleTestRunResult(
          results: [
            EnsembleSingleTestResult.failed(
              testId:
                  'run_$index (ensemble/apps/app/tests/run_$index.test.yaml)',
              durationMs: index,
              error: 'failure $index',
            ),
          ],
        );

    // Create the schema through the public writer, then seed the history in a
    // single transaction. Only the final public write needs to exercise prune.
    await EnsembleTestHistoryStore.recordCompletedRun(
      appDir: tempDir.path,
      artifactRoot: tempDir.path,
      wallTimeMs: -1,
      result: failedRun(-1),
    );

    final dbPath = p.join(
      tempDir.path,
      'report',
      EnsembleTestHistoryStore.fileName,
    );
    final db = await databaseFactoryFfi.openDatabase(dbPath);
    await db.transaction((txn) async {
      for (var i = 0; i < 504; i++) {
        final runId = await txn.insert('runs', {
          'created_at': DateTime.utc(2026, 1, 1)
              .add(Duration(seconds: i))
              .toIso8601String(),
          'status': 'failed',
          'duration_ms': i,
          'passed_tests': 0,
          'failed_tests': 1,
          'total_tests': 1,
        });
        await txn.insert('failed_tests', {
          'run_id': runId,
          'test_id': 'run_$i',
          'base_id': 'run_$i',
          'file_name': 'run_$i.test.yaml',
          'error_summary': 'failure $i',
        });
        await txn.insert('test_results', {
          'run_id': runId,
          'test_id': 'run_$i',
          'file_name': 'run_$i.test.yaml',
          'status': 'failed',
          'duration_ms': i,
        });
      }
    });
    await db.close();

    await EnsembleTestHistoryStore.recordCompletedRun(
      appDir: tempDir.path,
      artifactRoot: tempDir.path,
      wallTimeMs: 504,
      result: failedRun(504),
    );

    final retainedDb = await databaseFactoryFfi.openDatabase(dbPath);
    addTearDown(retainedDb.close);

    final runs = await retainedDb.query('runs', orderBy: 'id ASC');
    expect(runs, hasLength(EnsembleTestHistoryStore.maxRuns));
    expect(runs.first['duration_ms'], 5);
    expect(runs.last['duration_ms'], 504);

    final failed =
        await retainedDb.query('failed_tests', orderBy: 'run_id ASC');
    expect(failed, hasLength(EnsembleTestHistoryStore.maxRuns));
    expect(failed.first['file_name'], 'run_5.test.yaml');
    expect(failed.last['file_name'], 'run_504.test.yaml');
    final testResults = await retainedDb.query('test_results');
    expect(testResults, hasLength(EnsembleTestHistoryStore.maxRuns));
  });

  test('migrates old history database with pending_tests column', () async {
    final reportDir = Directory(p.join(tempDir.path, 'report'))
      ..createSync(recursive: true);
    final dbPath = p.join(reportDir.path, EnsembleTestHistoryStore.fileName);
    final oldDb = await databaseFactoryFfi.openDatabase(dbPath);
    await oldDb.execute('''
CREATE TABLE runs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  created_at TEXT NOT NULL,
  status TEXT NOT NULL,
  duration_ms INTEGER NOT NULL,
  passed_tests INTEGER NOT NULL,
  failed_tests INTEGER NOT NULL,
  pending_tests INTEGER NOT NULL,
  total_tests INTEGER NOT NULL,
  commit_hash TEXT,
  branch TEXT,
  build_number TEXT,
  pr_number TEXT
)
''');
    await oldDb.execute('''
CREATE TABLE failed_tests (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  run_id INTEGER NOT NULL,
  test_id TEXT NOT NULL,
  base_id TEXT,
  file_name TEXT,
  device TEXT,
  scenario TEXT,
  error_summary TEXT,
  FOREIGN KEY(run_id) REFERENCES runs(id) ON DELETE CASCADE
)
''');
    final oldRunId = await oldDb.insert('runs', {
      'created_at': '2026-08-03T00:00:00.000Z',
      'status': 'pending',
      'duration_ms': 500,
      'passed_tests': 0,
      'failed_tests': 0,
      'pending_tests': 1,
      'total_tests': 1,
    });
    await oldDb.insert('failed_tests', {
      'run_id': oldRunId,
      'test_id': 'old_test (ensemble/apps/app/tests/old.test.yaml)',
      'base_id': 'old_test',
      'file_name': 'old.test.yaml',
      'device': 'iphone',
      'scenario': null,
      'error_summary': 'old failure',
    });
    await oldDb.close();

    await EnsembleTestHistoryStore.recordCompletedRun(
      appDir: tempDir.path,
      artifactRoot: tempDir.path,
      wallTimeMs: 1234,
      result: EnsembleTestRunResult(
        results: [
          EnsembleSingleTestResult.passed(
            testId: 'new_test (ensemble/apps/app/tests/new.test.yaml)',
            durationMs: 1234,
          ),
        ],
      ),
    );

    final db = await databaseFactoryFfi.openDatabase(dbPath);
    addTearDown(db.close);

    final columns = await db.rawQuery('PRAGMA table_info(runs)');
    expect(
      columns.map((row) => row['name']),
      isNot(contains('pending_tests')),
    );

    final runs = await db.query('runs', orderBy: 'id ASC');
    expect(runs, hasLength(2));
    expect(runs.first['status'], 'failed');
    expect(runs.last['status'], 'passed');

    final failed = await db.query('failed_tests');
    expect(failed, hasLength(1));
    expect(failed.single['test_id'], 'old_test');
    expect(failed.single['base_id'], 'old_test');
    expect(failed.single['file_name'], 'old.test.yaml');
  });
}
