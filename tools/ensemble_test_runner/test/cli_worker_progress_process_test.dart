import 'dart:convert';
import 'dart:io';

import 'package:ensemble_test_runner/cli/cli_worker_progress_output.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CLI progress process prints outcomes but retains running events',
      () async {
    final directory = Directory.systemTemp.createTempSync('runner-progress-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final progressFile = File('${directory.path}/worker.jsonl')
      ..writeAsStringSync([
        jsonEncode({'status': 'running', 'testId': 'checkout'}),
        jsonEncode({
          'status': 'passed',
          'testId': 'checkout',
          'durationMs': 1250,
        }),
      ].join('\n'));

    final result = await Process.run(
      'dart',
      [
        'run',
        'test/support/cli_worker_progress_process.dart',
        progressFile.path
      ],
      workingDirectory: Directory.current.path,
    );

    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stdout, isEmpty);
    expect(result.stderr, '✓ checkout (1.3s)\n');
    expect(progressFile.readAsLinesSync(), hasLength(2));
    expect(progressFile.readAsStringSync(), contains('"status":"running"'));
  });

  test('preserves worker progress when a worker report is incomplete', () {
    final directory = Directory.systemTemp.createTempSync('runner-progress-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final progressFile = File('${directory.path}/worker1.jsonl')
      ..writeAsStringSync(
        '${jsonEncode({
              'status': 'running',
              'testId': 'slow_case',
              'assetPath': 'tests/slow.test.yaml',
              'startedAtEpochMs': 1000,
            })}\n',
      );
    final diagnostics = Directory('${directory.path}/diagnostics');

    final preserved = CliWorkerProgressOutput.preserveIncompleteProgress(
      [progressFile.path],
      diagnostics,
      timedOutWorkerIndexes: {0},
      capturedAt: DateTime.fromMillisecondsSinceEpoch(4250),
    );

    expect(preserved, hasLength(1));
    expect(preserved.single.path, endsWith('worker_1_progress.jsonl'));
    final lines = preserved.single.readAsLinesSync();
    expect(lines, hasLength(2));
    final timeout = jsonDecode(lines.last) as Map<String, dynamic>;
    expect(timeout['status'], 'timed_out');
    expect(timeout['testId'], 'slow_case');
    expect(timeout['durationMs'], 3250);
    expect(timeout['capturedAtEpochMs'], 4250);
  });

  test('treats a missing worker report as incomplete', () {
    final directory = Directory.systemTemp.createTempSync('runner-report-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final missingReport = '${directory.path}/worker.json';
    final emptyReport = File('${directory.path}/empty-worker.json')
      ..createSync();
    final completeReport = File('${directory.path}/complete-worker.json')
      ..writeAsStringSync('{}');

    expect(
      CliWorkerProgressOutput.hasMissingReports(
        [missingReport, emptyReport.path],
      ),
      isTrue,
    );
    expect(
      CliWorkerProgressOutput.hasMissingReports([completeReport.path]),
      isFalse,
    );
  });
}
