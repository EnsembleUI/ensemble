import 'dart:io';

import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/reporters/ensemble_test_history_store.dart';
import 'package:ensemble_test_runner/reporters/test_report_document.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory appDir;

  setUp(() {
    appDir = Directory.systemTemp.createTempSync('duration_history_');
    sqfliteFfiInit();
  });

  tearDown(() {
    if (appDir.existsSync()) appDir.deleteSync(recursive: true);
  });

  test('planner reads per-test and relative-file durations from report DB',
      () async {
    final artifactRoot =
        Directory(p.join(appDir.path, 'build', 'ensemble_test_runner'))
          ..createSync(recursive: true);
    await EnsembleTestHistoryStore.recordCompletedRun(
      appDir: appDir.path,
      artifactRoot: artifactRoot.path,
      wallTimeMs: 1200,
      result: EnsembleTestRunResult(results: [
        EnsembleSingleTestResult.passed(
          testId: 'case[one] (tests/flow.test.yaml)',
          durationMs: 300,
          metadata: const {'scenarioId': 'one'},
        ),
        EnsembleSingleTestResult.passed(
          testId: 'case[two] (tests/flow.test.yaml)',
          durationMs: 900,
          metadata: const {'scenarioId': 'two'},
        ),
      ]),
    );

    final durations =
        await EnsembleTestHistoryStore.loadPlannerDurations(appDir.path);
    expect(durations.testDuration('case[one]'), 300);
    expect(durations.testDuration('case[two]'), 900);
    expect(durations.fileDuration('tests/flow.test.yaml'), 1200);
    expect(
      File(p.join(artifactRoot.path, 'test_durations.json')).existsSync(),
      isFalse,
    );
  });

  test('report state is stored in DB and legacy duration cache is removed',
      () async {
    final root = Directory(p.join(appDir.path, 'build', 'ensemble_test_runner'))
      ..createSync(recursive: true);
    File(p.join(root.path, 'test_durations.json')).writeAsStringSync('{}');

    await EnsembleTestHistoryStore.markReportLoading(artifactRoot: root.path);

    final db = await databaseFactoryFfi.openDatabase(p.join(
      root.path,
      'report',
      EnsembleTestHistoryStore.fileName,
    ));
    addTearDown(db.close);
    final state = (await db.query('report_state')).single;
    expect(state['state'], 'running');
    expect(state['total_tests'], 0);
    expect(
        File(p.join(root.path, 'test_durations.json')).existsSync(), isFalse);
  });

  test('transient cleanup removes legacy duration cache', () {
    final root = Directory(p.join(appDir.path, 'build', 'ensemble_test_runner'))
      ..createSync(recursive: true);
    final legacy = File(p.join(root.path, 'test_durations.json'))
      ..writeAsStringSync('{}');

    TestReportDocument.cleanTransientArtifacts(root.path);

    expect(legacy.existsSync(), isFalse);
  });
}
