import 'dart:convert';
import 'dart:io';

import 'package:ensemble_test_runner/cli/cli_report_coordinator.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('writes the live report shell and canonical suite log paths', () async {
    final tempDir = Directory.systemTemp.createTempSync('ensemble_cli_report_');
    addTearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    final coordinator = CliReportCoordinator(tempDir.path);
    final reportDir =
        p.join(tempDir.path, 'build', 'ensemble_test_runner', 'report');
    Directory(reportDir).createSync(recursive: true);
    File(p.join(reportDir, 'index.html'))
        .writeAsStringSync("fetch('results.json.gz')");
    File(p.join(reportDir, 'results.json.gz')).writeAsBytesSync([1, 2, 3]);

    await coordinator.writeHtmlReport(
      EnsembleTestRunResult(results: [
        EnsembleSingleTestResult.passed(testId: 'previous', durationMs: 10),
      ]),
    );
    final dbPath = p.join(reportDir, 'ensemble_test.db');
    final generatedShell =
        File(p.join(reportDir, 'index.html')).readAsStringSync();
    expect(generatedShell, contains('ensemble_test.db'));
    expect(generatedShell, isNot(contains('results.json.gz')));
    expect(File(p.join(reportDir, 'results.json.gz')).existsSync(), isFalse);
    var db = await databaseFactoryFfi.openDatabase(dbPath);
    expect(
      (await db.rawQuery(
        "SELECT report_data FROM test_results WHERE record_type = 'run' ORDER BY id DESC LIMIT 1",
      ))
          .single['report_data'],
      isNotNull,
    );
    await db.close();

    final result = await coordinator.writeHtmlReport(
      const EnsembleTestRunResult(results: []),
      wallTimeMs: 0,
      isSuiteRunning: true,
    );

    expect(
      File(p.join(tempDir.path, 'build', 'ensemble_test_runner', 'report',
              'index.html'))
          .existsSync(),
      isTrue,
    );
    expect(result.suiteLogs, contains(startsWith('htmlReport:')));
    expect(result.suiteLogs, isNot(contains(startsWith('results:'))));
    expect(
      File(p.join(tempDir.path, 'build', 'ensemble_test_runner', 'report',
              'results.json.gz'))
          .existsSync(),
      isFalse,
    );
    expect(
      File(p.join(tempDir.path, 'build', 'ensemble_test_runner', 'report',
              'ensemble_test.db'))
          .existsSync(),
      isTrue,
    );
    db = await databaseFactoryFfi.openDatabase(dbPath);
    addTearDown(db.close);
    expect(
      await db.rawQuery(
        "SELECT id FROM test_results WHERE record_type = 'run' AND report_data IS NOT NULL",
      ),
      hasLength(1),
    );
  });

  test('uses one JSON/JUnit serializer for stdout and report files', () async {
    final tempDir = Directory.systemTemp.createTempSync('ensemble_cli_report_');
    addTearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });
    final coordinator = CliReportCoordinator(tempDir.path);
    const result = EnsembleTestRunResult(results: []);

    final jsonReport = coordinator.serializeMachineResult(
      result,
      junit: false,
    );
    expect(jsonDecode(jsonReport), result.toJson());
    final junitReport = coordinator.serializeMachineResult(
      result,
      junit: true,
    );
    expect(junitReport, contains('<testsuite name="ensemble_tests"'));

    final output = File('${tempDir.path}/report.json');
    coordinator.writeMachineResult(
      result,
      path: output.path,
      junit: false,
    );
    expect(jsonDecode(output.readAsStringSync()), result.toJson());
  });
}
