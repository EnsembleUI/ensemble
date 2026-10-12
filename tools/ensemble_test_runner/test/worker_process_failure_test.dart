import 'dart:io';

import 'package:ensemble_test_runner/cli/ensemble_test_cli.dart';
import 'package:ensemble_test_runner/cli/worker_process_failure.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reports a structured failure when a worker exits without test failures',
      () {
    final results = workerProcessFailureResults(
      ProcessResult(42, 137, '', 'worker stopped unexpectedly'),
      workerIndex: 1,
    );

    expect(results, hasLength(1));
    expect(results.single.testId, 'test-worker-2');
    expect(results.single.status, TestStatus.failed);
    expect(results.single.failure?.kind, TestFailureKind.crash);
    expect(results.single.failure?.phase, 'worker');
  });

  test('classifies a bounded timeout as incomplete execution', () {
    final result = workerProcessFailureResults(
      ProcessResult(42, 137, '', 'Ensemble test worker timed out after 1s.'),
      workerIndex: 0,
    );

    expect(result.single.failure?.kind, TestFailureKind.incompleteExecution);
  });

  test('classifies a parent-interrupted reportless worker as incomplete', () {
    final result = workerProcessFailureResults(
      ProcessResult(42, 143, '', 'Ensemble test worker interrupted by parent.'),
      workerIndex: 0,
    );

    expect(result.single.failure?.kind, TestFailureKind.incompleteExecution);
    expect(
        result.single.effectiveFailureMessage, 'Test worker 1 was interrupted');
  });

  test('does not duplicate a worker failure already represented by test cases',
      () {
    final result = workerProcessFailureResults(
      ProcessResult(42, 1, '', 'test failed'),
      workerIndex: 0,
      reportHasFailures: true,
    );

    expect(result, isEmpty);
  });

  test('does not promote a nonzero shutdown after a completed report', () {
    final result = workerProcessFailureResults(
      ProcessResult(42, 1, '', 'wrapper exited after report flush'),
      workerIndex: 0,
      reportHasResults: true,
    );

    expect(result, isEmpty);
  });

  test('reports an incomplete worker when an expected case is missing', () {
    final result = workerProcessFailureResults(
      ProcessResult(42, 0, '', ''),
      workerIndex: 0,
      reportHasResults: true,
      expectedTestIds: const ['login', 'settings'],
      reportedTestIds: const ['login'],
    );

    expect(result, hasLength(1));
    expect(result.single.failure?.kind, TestFailureKind.incompleteExecution);
    expect(result.single.testId, 'settings');
  });

  test('reports every assigned case when interruption leaves no report', () {
    final result = workerProcessFailureResults(
      ProcessResult(42, 143, '', 'worker stopped unexpectedly'),
      workerIndex: 0,
      expectedTestIds: const ['login[android]', 'settings[android]'],
    );

    expect(result.map((result) => result.testId),
        containsAll(['login[android]', 'settings[android]']));
    expect(result, hasLength(2));
    expect(
        result.every((result) =>
            result.failure?.kind == TestFailureKind.incompleteExecution),
        isTrue);
  });

  test('accepts a complete report even when the worker wrapper exits nonzero',
      () {
    final result = workerProcessFailureResults(
      ProcessResult(42, 1, '', 'wrapper shutdown'),
      workerIndex: 0,
      reportHasResults: true,
      expectedTestIds: const ['login'],
      reportedTestIds: const ['login'],
    );

    expect(result, isEmpty);
  });

  test('ignores the source suffix added to reported test ids', () {
    final result = workerProcessFailureResults(
      ProcessResult(42, 0, '', ''),
      workerIndex: 0,
      reportHasResults: true,
      expectedTestIds: const ['login[android]'],
      reportedTestIds: const [
        'login[android]  (tests/login.test.yaml)',
      ],
    );

    expect(result, isEmpty);
  });

  test('classifies an invalid report as incomplete execution', () {
    final result = workerReportDecodeFailureResults(
      workerIndex: 2,
      error: const FormatException('unexpected end of input'),
      outputFile: 'diagnostics/test_process_3_output.log',
    );

    expect(result.single.testId, 'test-worker-3');
    expect(result.single.failure?.kind, TestFailureKind.incompleteExecution);
    expect(result.single.failure?.phase, 'worker');
    expect(result.single.effectiveFailureMessage,
        contains('produced an invalid results report'));
    expect(result.single.effectiveFailureMessage,
        contains('test_process_3_output.log'));
  });

  test('merges malformed worker output into one failure per assigned case',
      () async {
    final directory = await Directory.systemTemp.createTemp('worker_report');
    final report = File('${directory.path}/worker.json')
      ..writeAsStringSync('{"results":[{"testId":"partial"');

    try {
      final merged = mergeWorkerReportsForTest(
        results: [ProcessResult(42, 1, '', 'truncated report')],
        reportFiles: [report.path],
        expectedWorkerTestIds: const [
          ['login[android]', 'settings[android]'],
        ],
        appDir: directory.path,
      );

      expect(
        merged.results.map((result) => result.testId),
        ['login[android]', 'settings[android]'],
      );
      expect(
        merged.results.every((result) =>
            result.status == TestStatus.failed &&
            result.failure?.kind == TestFailureKind.incompleteExecution &&
            result.failure?.phase == 'worker'),
        isTrue,
      );
      expect(merged.results.first.effectiveFailureMessage,
          contains('results report is invalid'));
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
