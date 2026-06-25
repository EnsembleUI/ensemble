import 'dart:convert';
import 'dart:io';

import 'package:ensemble_test_runner/discovery/ensemble_test_execution_planner.dart';
import 'package:ensemble_test_runner/ensemble_test_runner.dart';
import 'package:ensemble_test_runner/runner/test_runtime_state.dart';
import 'package:ensemble_test_runner/runner/yaml_test_session.dart';
import 'package:flutter_test/flutter_test.dart';

const _defaultTimeoutSeconds = 10 * 60;
const _timeoutSeconds = int.fromEnvironment(
  'ensembleTestTimeoutSeconds',
  defaultValue: _defaultTimeoutSeconds,
);

/// Flutter test entry: discovers app-local `tests/*.test.yaml` and runs them.
void runEnsembleYamlTests() {
  EnsembleTestHarness.ensureTestPlugins();
  tearDown(() {
    TestErrorTracker.reset();
    EnsembleTestHarness.resetTestRuntime();
    YamlTestSession.dispose();
  });

  testWidgets(
    'Ensemble app *.test.yaml',
    (tester) async {
      final target = await EnsembleTestDiscovery.loadAppTarget();
      final plan = await EnsembleTestExecutionPlanner.build(
        target: target,
        selection: _selectionFromEnvironment(),
      );
      final harness = EnsembleTestHarness(
        appPath: target.appPath,
        appHome: target.appHome,
        i18nPath: target.i18nPath,
      );

      final runner = EnsembleTestRunner(harness: harness);
      final resultsById = await runner.runPlan(plan, tester);

      final failures = <String>[];
      final orderedResults = <EnsembleSingleTestResult>[];

      for (final def in plan.ordered) {
        final result = resultsById[def.testCase.id]!;
        orderedResults.add(
          EnsembleSingleTestResult(
            testId: '${result.testId}  (${def.assetPath})',
            metadata: result.metadata,
            status: result.status,
            durationMs: result.durationMs,
            failedStepIndex: result.failedStepIndex,
            failedStep: result.failedStep,
            message: result.message,
            stackTrace: result.stackTrace,
            logs: result.logs,
            report: result.report,
          ),
        );

        if (result.status == TestStatus.failed) {
          failures.add(def.assetPath);
        }
      }

      final runResult = EnsembleTestRunResult(results: orderedResults);
      final suiteSummary = TestReporter().formatSummary(
        runResult,
        testFile: '${target.testsAssetPrefix}*.test.yaml',
      );
      print(suiteSummary);
      _emitMachineReport(runResult);

      if (failures.isNotEmpty) {
        fail(
          'Failed YAML tests:\n'
          '${failures.map((p) => '- $p').join('\n')}\n\n'
          '$suiteSummary',
        );
      }
    },
    timeout: Timeout(Duration(seconds: _timeoutSeconds)),
  );
}

EnsembleTestSelection _selectionFromEnvironment() {
  return EnsembleTestSelection(
    ids: _csvSet(const String.fromEnvironment('ensembleTestId')),
    features: _csvSet(const String.fromEnvironment('ensembleTestFeature')),
    tags: _csvSet(const String.fromEnvironment('ensembleTestTag')),
    paths: _csvSet(const String.fromEnvironment('ensembleTestPath')),
  );
}

Set<String> _csvSet(String value) {
  if (value.isEmpty) return const {};
  return value
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toSet();
}

void _emitMachineReport(EnsembleTestRunResult result) {
  const reportMode = String.fromEnvironment('ensembleTestReport');
  const reportFile = String.fromEnvironment('ensembleTestReportFile');
  final jsonReport = json.encode(result.toJson());
  final junitReport = _junitReport(result);

  if (reportFile.isNotEmpty) {
    final file = File(reportFile);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(reportMode == 'junit' ? junitReport : jsonReport);
  }

  if (reportMode == 'json') {
    print('ENSEMBLE_TEST_JSON_REPORT:$jsonReport');
  } else if (reportMode == 'junit') {
    print('ENSEMBLE_TEST_JUNIT_REPORT:${junitReport.replaceAll('\n', r'\n')}');
  }
}

String _junitReport(EnsembleTestRunResult result) {
  final totalMs = result.results.fold<int>(0, (sum, r) => sum + r.durationMs);
  final buffer = StringBuffer()
    ..writeln(
      '<testsuite name="ensemble_yaml_tests" tests="${result.results.length}" '
      'failures="${result.failedCount}" time="${(totalMs / 1000).toStringAsFixed(3)}">',
    );
  for (final r in result.results) {
    buffer.writeln(
      '  <testcase name="${_xmlEscape(r.testId)}" '
      'time="${(r.durationMs / 1000).toStringAsFixed(3)}">',
    );
    if (r.status == TestStatus.failed) {
      buffer
        ..writeln(
          '    <failure message="${_xmlEscape(r.message ?? 'failed')}">',
        )
        ..writeln(_xmlEscape(r.stackTrace ?? r.message ?? 'failed'))
        ..writeln('    </failure>');
    }
    buffer.writeln('  </testcase>');
  }
  buffer.writeln('</testsuite>');
  return buffer.toString();
}

String _xmlEscape(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}
