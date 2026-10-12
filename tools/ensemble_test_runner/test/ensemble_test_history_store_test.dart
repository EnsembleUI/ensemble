import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/reporters/ensemble_test_history_store.dart';
import 'package:ensemble_test_runner/reporters/report_json_optimizer.dart';
import 'package:ensemble_test_runner/src/core/operation.dart';
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
            failureOperation: 'interaction.tap',
            failureSource: const SourceLocation(
              'ensemble/apps/app/tests/settings.test.yaml',
              'steps[2]',
            ),
            message: 'Timed out waiting for id "save_button".\nextra details',
            attempts: 3,
            retry: 2,
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

    final runs = await db.query('test_results', where: "record_type = 'run'");
    expect(runs, hasLength(1));
    expect(runs.single['status'], 'failed');
    expect(runs.single['duration_ms'], 1234);
    final summary = jsonDecode(runs.single['summary_data'] as String);
    expect(summary['passed_tests'], 1);
    expect(summary['failed_tests'], 1);
    expect(summary['total_tests'], 2);
    expect(summary['mode'], 'integration');
    expect(summary['platform'], 'ios');
    expect(summary['device_name'], 'iPhone 15 Pro');
    final currentReport = ReportJsonOptimizer.expand(
      jsonDecode(
              utf8.decode(gzip.decode(runs.single['report_data'] as Uint8List)))
          as Map<String, dynamic>,
    );
    expect(currentReport['state'], 'complete');
    expect(currentReport['tests'], hasLength(2));

    final testResults = await db.rawQuery('''
SELECT r.*, c.test_id, c.file_name, c.device, c.scenario, c.profile
FROM test_results r JOIN test_catalog c ON c.id = r.test_ref
WHERE r.record_type = 'test' ORDER BY r.id ASC
''');
    expect(testResults, hasLength(2));
    expect(testResults.first['status'], 'passed');
    expect(testResults.first['duration_ms'], 300);
    expect(testResults.first['device'], 'android');
    expect(testResults.last['status'], 'failed');
    expect(testResults.last['device'], 'iphone');
    expect(testResults.last['scenario'], 'retry_case');
    expect(testResults.last['failed_step'], 'tap(save_button)');
    expect(testResults.last['attempts'], 3);
    expect(testResults.last['error_kind'], 'assertion');
    expect(
      testResults.last['error_summary'],
      'Timed out waiting for id "save_button".',
    );
    expect(testResults.last.keys, isNot(contains('feature')));
    expect(testResults.last.keys, isNot(contains('retry')));
    expect(testResults.last.keys, isNot(contains('failure_source_path')));
    expect(testResults.first['test_ref'], isNot(testResults.last['test_ref']));
    expect(
        (await db.rawQuery('SELECT COUNT(*) AS count FROM test_catalog'))
            .single['count'],
        2);
    expect(
      await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='failed_tests'",
      ),
      isEmpty,
    );
    expect(
      await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='runs'",
      ),
      isEmpty,
    );
  });

  test('starts a new database without importing the retired filename',
      () async {
    final reportDir = Directory(p.join(tempDir.path, 'report'))
      ..createSync(recursive: true);
    final retiredPath = p.join(reportDir.path, 'ensemble_test_history.db');
    final retiredDb = await databaseFactoryFfi.openDatabase(retiredPath);
    await retiredDb.execute('CREATE TABLE runs (id INTEGER PRIMARY KEY)');
    await retiredDb.close();

    await EnsembleTestHistoryStore.recordCompletedRun(
      appDir: tempDir.path,
      artifactRoot: tempDir.path,
      result: EnsembleTestRunResult(results: [
        EnsembleSingleTestResult.passed(testId: 'current', durationMs: 25),
      ]),
    );

    final currentPath = p.join(reportDir.path, 'ensemble_test.db');
    expect(File(currentPath).existsSync(), isTrue);
    expect(File(retiredPath).existsSync(), isTrue);
    final db = await databaseFactoryFfi.openDatabase(currentPath);
    addTearDown(db.close);
    expect(
      await db.query('test_results', where: "record_type = 'run'"),
      hasLength(1),
    );
    expect(
      await db.query('test_results', where: "record_type = 'test'"),
      hasLength(1),
    );
  });

  test('caps persisted failure summaries', () async {
    await EnsembleTestHistoryStore.recordCompletedRun(
      appDir: tempDir.path,
      artifactRoot: tempDir.path,
      result: EnsembleTestRunResult(results: [
        EnsembleSingleTestResult.failed(
          testId: 'large_error',
          durationMs: 1,
          message: List.filled(10000, 'x').join(),
        ),
      ]),
    );

    final db = await databaseFactoryFfi.openDatabase(
      p.join(tempDir.path, 'report', EnsembleTestHistoryStore.fileName),
    );
    addTearDown(db.close);
    final rows = await db.query('test_results', where: "record_type = 'test'");
    expect((rows.single['error_summary'] as String).length, 240);
  });

  test('keeps the latest 50 runs with all their case results', () async {
    EnsembleTestRunResult failedRun(int index) => EnsembleTestRunResult(
          results: [
            EnsembleSingleTestResult.failed(
              testId: 'repeat_case (ensemble/apps/app/tests/repeat.test.yaml)',
              durationMs: index,
              message: 'failure $index',
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
      for (var i = 0; i < 104; i++) {
        final runId = await txn.insert('test_results', {
          'record_type': 'run',
          'status': 'failed',
          'duration_ms': i,
          'summary_data': jsonEncode({
            'created_at': DateTime.utc(2026, 1, 1)
                .add(Duration(seconds: i))
                .toIso8601String(),
            'passed_tests': 0,
            'failed_tests': 1,
            'total_tests': 1,
          }),
        });
        const identity = '["repeat_case","repeat.test.yaml",null,null,null]';
        await txn.rawInsert(
          'INSERT OR IGNORE INTO test_catalog (identity_key, test_id, file_name) VALUES (?, ?, ?)',
          [identity, 'repeat_case', 'repeat.test.yaml'],
        );
        final testRef = (await txn.query('test_catalog',
                columns: ['id'],
                where: 'identity_key = ?',
                whereArgs: [identity]))
            .single['id'];
        await txn.insert('test_results', {
          'record_type': 'test',
          'run_id': runId,
          'test_ref': testRef,
          'status': 'failed',
          'duration_ms': i,
        });
      }
    });
    await db.close();

    await EnsembleTestHistoryStore.recordCompletedRun(
      appDir: tempDir.path,
      artifactRoot: tempDir.path,
      wallTimeMs: 104,
      result: failedRun(104),
    );

    final retainedDb = await databaseFactoryFfi.openDatabase(dbPath);
    addTearDown(retainedDb.close);

    final runs = await retainedDb.query('test_results',
        where: "record_type = 'run'", orderBy: 'id ASC');
    expect(runs, hasLength(EnsembleTestHistoryStore.maxRuns));
    expect(runs.first['duration_ms'], 55);
    expect(runs.last['duration_ms'], 104);

    final testResults =
        await retainedDb.query('test_results', where: "record_type = 'test'");
    expect(testResults, hasLength(EnsembleTestHistoryStore.maxRuns));
    final catalog =
        await retainedDb.rawQuery('SELECT COUNT(*) AS count FROM test_catalog');
    expect(catalog.single['count'], 1);
  });
}
