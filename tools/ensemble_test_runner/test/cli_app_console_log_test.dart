import 'dart:io';
import 'dart:convert';

import 'package:ensemble_test_runner/cli/cli_app_console_log.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/reporters/test_report_document.dart';
import 'package:ensemble_test_runner/runner/diagnostic_redaction.dart';
import 'package:ensemble_test_runner/runner/test_runtime_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses stable relative paths for the main and worker logs', () {
    expect(
      CliAppConsoleLog.relativePath(),
      'build/ensemble_test_runner/logs/app_console.log',
    );
    expect(
      CliAppConsoleLog.relativePath(workerIndex: 2),
      'build/ensemble_test_runner/logs/app_console_3.log',
    );
  });

  test('filters protocol lines while retaining application output', () {
    final directory = Directory.systemTemp.createTempSync('runner-console-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = CliAppConsoleLog.open('${directory.path}/app.log')!;

    CliAppConsoleLog.append(file, 'stdout', 'visible output');
    CliAppConsoleLog.append(
      file,
      'stdout',
      'ENSEMBLE_TEST_JSON_REPORT:{"results":[]}',
    );

    final content = file.readAsStringSync();
    expect(content, contains('[stdout] visible output'));
    expect(content, isNot(contains('ENSEMBLE_TEST_JSON_REPORT')));
  });

  test('redacts app log artifacts and report projection only', () {
    final directory = Directory.systemTemp.createTempSync('runner-console-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = CliAppConsoleLog.open('${directory.path}/app.log')!;
    const sourceLine = '{"firebase":{"access_token":"fixture-access"},'
        '"firebaseAccessToken":"fixture-firebase",'
        '"X-API-Key":"fixture-api-key",'
        '"message":"Authorization: Bearer fixture-bearer"}';
    final runtime = TestRuntimeState()..consoleLogs.add(sourceLine);

    CliAppConsoleLog.append(file, 'stdout', sourceLine);
    CliAppConsoleLog.append(
        file, 'stderr', 'request failed: Bearer fixture-stderr');

    final sidecar = file.readAsStringSync();
    expect(sidecar, isNot(contains('fixture-access')));
    expect(sidecar, isNot(contains('fixture-firebase')));
    expect(sidecar, isNot(contains('fixture-api-key')));
    expect(sidecar, isNot(contains('fixture-bearer')));
    expect(sidecar, isNot(contains('fixture-stderr')));
    final savedJsonLine = sidecar
        .split('\n')
        .singleWhere((line) => line.startsWith('[stdout] '))
        .substring('[stdout] '.length);
    final savedJson = json.decode(savedJsonLine) as Map<String, dynamic>;
    expect(
      savedJson,
      {
        'firebase': {'access_token': diagnosticRedactedValue},
        'firebaseAccessToken': diagnosticRedactedValue,
        'X-API-Key': diagnosticRedactedValue,
        'message': 'Authorization: Bearer $diagnosticRedactedValue',
      },
    );

    final report = TestReportDocument.buildComplete(
      EnsembleTestRunResult(
        results: [
          EnsembleSingleTestResult.passed(
            testId: 'console-redaction',
            durationMs: 1,
            logs: ['appLogs: ${file.path}'],
            report: const EnsembleTestReportDetails(
              stepsOutline: ['submit'],
            ),
          ),
        ],
      ),
      artifactRoot: directory.path,
      displayRoot: directory.path,
    );
    final tests = report['tests'] as List;
    final steps = (tests.single as Map)['steps'] as List;
    final projectedLogs = (steps.single as Map)['appLogs'] as List;
    final projection = projectedLogs.join('\n');
    expect(projection, contains(diagnosticRedactedValue));
    expect(projection, isNot(contains('fixture-access')));
    expect(projection, isNot(contains('fixture-firebase')));
    expect(projection, isNot(contains('fixture-api-key')));
    expect(projection, isNot(contains('fixture-bearer')));
    expect(projection, isNot(contains('fixture-stderr')));

    // Assertions consume the untouched runtime line; redaction belongs only
    // to the CLI artifact publication boundary.
    expect(runtime.consoleLogs.single, sourceLine);
  });

  test('does not write after the bounded artifact is truncated', () {
    final directory = Directory.systemTemp.createTempSync('runner-console-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = CliAppConsoleLog.open('${directory.path}/app.log')!;
    final oversizedLine = 'x' * CliAppConsoleLog.maxBytes;

    CliAppConsoleLog.append(file, 'stdout', oversizedLine);
    final afterTruncation = file.readAsStringSync();
    CliAppConsoleLog.append(file, 'stdout', 'after truncation');

    expect(afterTruncation, contains('app console log truncated'));
    expect(file.readAsStringSync(), afterTruncation);
  });
}
