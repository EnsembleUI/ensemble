/// Helpers for wiring Ensemble YAML tests into `flutter_test`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:ensemble_test_runner/discovery/ensemble_test_execution_planner.dart';
import 'package:ensemble_test_runner/ensemble_test_runner.dart';
import 'package:ensemble_test_runner/mocks/firebase_test_setup.dart';
import 'package:ensemble_test_runner/mocks/wifi_test_setup.dart';
import 'package:ensemble_test_runner/runner/yaml_test_session.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _timeoutSeconds = int.fromEnvironment(
  'ensembleTestTimeoutSeconds',
  defaultValue: 0,
);

/// Options for [runEnsembleYamlTests], typically set from `test/ensemble_tests.dart`.
class EnsembleYamlTestOptions {
  /// App bootstrap, typically `() => EnsembleModules().init()` from
  /// `lib/generated/ensemble_modules.dart` (same as `main.dart`).
  final Future<void> Function()? bootstrap;

  /// Host-app methods passed to [EnsembleApp], e.g. `captureCertificateForHost`.
  final Map<String, Function>? externalMethods;

  const EnsembleYamlTestOptions({
    this.bootstrap,
    this.externalMethods,
  });
}

/// Flutter test entry: discovers app-local `tests/*.test.yaml` and runs them.
///
/// Mirror `main.dart` from `test/ensemble_tests.dart`:
/// ```dart
/// import 'package:my_app/generated/ensemble_modules.dart';
///
/// Future<void> main() async {
///   await runEnsembleYamlTests(
///     bootstrap: () => EnsembleModules().init(),
///     externalMethods: {
///       'captureCertificateForHost': captureCertificateForHost,
///     },
///   );
/// }
/// ```
Future<void> runEnsembleYamlTests({
  Future<void> Function()? bootstrap,
  Map<String, Function>? externalMethods,
}) {
  return runEnsembleYamlTestsWithOptions(
    EnsembleYamlTestOptions(
      bootstrap: bootstrap,
      externalMethods: externalMethods,
    ),
  );
}

/// Same as [runEnsembleYamlTests] with an explicit options object.
Future<void> runEnsembleYamlTestsWithOptions(
  EnsembleYamlTestOptions options,
) async {
  LiveTestWidgetsFlutterBinding.ensureInitialized();
  EnsembleTestHarness.ensureTestPlugins();
  tearDown(() {
    EnsembleTestHarness.resetTestRuntime();
    YamlTestSession.dispose();
  });

  testWidgets(
    'Ensemble app *.test.yaml',
    (tester) async {
      var emittedMachineReport = false;
      void emitMachineReport(EnsembleTestRunResult result) {
        _emitMachineReport(result);
        emittedMachineReport = true;
      }

      try {
        if (options.bootstrap == null) {
          fail(
            'Ensemble YAML tests require module bootstrap. '
            'In test/ensemble_tests.dart call runEnsembleYamlTests with '
            'bootstrap: () => EnsembleModules().init() '
            '(see ensemble_test_runner README).',
          );
        }
        await tester.runAsync(() async {
          await options.bootstrap!();
          ensureWifiTestDoublesForTest();
          ensureLiveAuthActionsForTest();
          // Module constructors may schedule follow-up async init work.
          await Future<void>.delayed(Duration.zero);
        });

        final target = await EnsembleTestDiscovery.loadAppTarget();
        final plan = await EnsembleTestExecutionPlanner.build(
          target: target,
          selection: _selectionFromEnvironment(),
          inputs: _inputsFromEnvironment(),
        );
        final harness = EnsembleTestHarness(
          appPath: target.appPath,
          appHome: target.appHome,
          i18nPath: target.i18nPath,
          externalMethods: options.externalMethods,
        );

        final runner = EnsembleTestRunner(harness: harness);
        final planResult = await runner.runPlan(
          plan,
          tester,
          onTestComplete: _emitProgressEvent,
        );
        final resultsById = planResult.resultsById;
        await YamlTestSession.navigationFlow.flushPending();
        final pendingFrameworkExceptions = <Object?>[];
        await _pumpBestEffort(tester, pendingFrameworkExceptions);

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
              attempts: result.attempts,
              retry: result.retry,
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

        final suiteLogs = <String>[
          ...planResult.suiteLogs,
        ];
        if (!isEnsembleTestParallelWorker()) {
          final htmlPath = HtmlTestReporter().write(
            EnsembleTestRunResult(
              results: orderedResults,
              suiteLogs: suiteLogs,
            ),
          );
          suiteLogs.add('htmlReport: $htmlPath');
        }
        final runResult = EnsembleTestRunResult(
          results: orderedResults,
          suiteLogs: suiteLogs,
        );
        // Background app errors are recorded by TestErrorTracker and can be
        // asserted with expectNoRenderErrors/expectError. Explicitly unmount
        // the app and drain teardown exceptions so a suite with passing YAML
        // assertions does not fail after the summary is printed.
        pendingFrameworkExceptions.addAll(
          await _drainPendingExceptionsAndUnmount(tester),
        );

        final reporter = TestReporter();
        final suiteSummary = reporter.formatSummary(
          runResult,
          testFile: '${target.testsAssetPrefix}*.test.yaml',
        );
        print(suiteSummary);
        emitMachineReport(runResult);
        _ignorePostTestAnimationInvariant();

        if (failures.isNotEmpty) {
          fail(
            reporter.formatFailureSummary(
              runResult,
              failedPaths: failures,
              pendingFrameworkExceptions: pendingFrameworkExceptions,
            ),
          );
        }
      } catch (error, stackTrace) {
        if (!emittedMachineReport) {
          final runResult = EnsembleTestRunResult(
            results: [
              EnsembleSingleTestResult.failed(
                testId: 'test-process',
                durationMs: 0,
                error: error.toString(),
                stackTrace: stackTrace.toString(),
              ),
            ],
            suiteLogs: const [],
          );
          emitMachineReport(runResult);
        }
        rethrow;
      }
    },
    timeout: _timeoutSeconds > 0
        ? Timeout(Duration(seconds: _timeoutSeconds))
        : Timeout.none,
  );
}

void _ignorePostTestAnimationInvariant() {
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    final exception = details.exception.toString();
    if (exception.contains(
      'An animation is still running even after the widget tree was disposed.',
    )) {
      return;
    }
    if (previousOnError != null) {
      previousOnError(details);
    } else {
      FlutterError.presentError(details);
    }
  };
}

Future<List<Object?>> _drainPendingExceptionsAndUnmount(
  WidgetTester tester,
) async {
  final exceptions = _drainPendingExceptions(tester);
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    exceptions.add(details.exception);
  };
  try {
    await _pumpWidgetBestEffort(tester, const SizedBox.shrink(), exceptions);
    exceptions.addAll(_drainPendingExceptions(tester));
    for (var i = 0; i < 10; i++) {
      await _pumpBestEffort(
        tester,
        exceptions,
        const Duration(milliseconds: 16),
      );
      exceptions.addAll(_drainPendingExceptions(tester));
      if (tester.binding.transientCallbackCount == 0) break;
    }
  } finally {
    FlutterError.onError = previousOnError;
  }
  return exceptions;
}

Future<void> _pumpBestEffort(
  WidgetTester tester,
  List<Object?> exceptions, [
  Duration? duration,
]) async {
  try {
    await tester.pump(duration);
  } catch (error) {
    exceptions.add(error);
  }
}

Future<void> _pumpWidgetBestEffort(
  WidgetTester tester,
  Widget widget,
  List<Object?> exceptions,
) async {
  try {
    await tester.pumpWidget(widget);
  } catch (error) {
    exceptions.add(error);
  }
}

void _emitProgressEvent(
  EnsembleTestDefinition definition,
  EnsembleSingleTestResult result,
) {
  const progressFile = String.fromEnvironment('ensembleTestProgressFile');
  if (progressFile.isEmpty) return;

  final file = File(progressFile);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(
    '${json.encode({
          'testId': result.testId,
          'assetPath': definition.assetPath,
          'status': result.status.name,
          'durationMs': result.durationMs,
          if (result.attempts > 1) 'attempts': result.attempts,
          if (result.retry > 0) 'retry': result.retry,
          if (result.message != null) 'message': result.message,
          if (result.failedStepIndex != null)
            'failedStepIndex': result.failedStepIndex,
        })}\n',
    mode: FileMode.append,
  );
}

List<Object?> _drainPendingExceptions(WidgetTester tester) {
  final exceptions = <Object?>[];
  Object? exception;
  while ((exception = tester.takeException()) != null) {
    exceptions.add(exception);
  }
  return exceptions;
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

Map<String, dynamic> _inputsFromEnvironment() {
  const encoded = String.fromEnvironment('ensembleTestInputs');
  if (encoded.isEmpty) return const {};
  try {
    final decoded = utf8.decode(base64Url.decode(encoded));
    final value = json.decode(decoded);
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
  } catch (_) {
    // Fall through to the explicit failure below.
  }
  throw EnsembleTestFailure('Invalid ensembleTestInputs dart-define payload.');
}

void _emitMachineReport(EnsembleTestRunResult result) {
  const reportMode = String.fromEnvironment('ensembleTestReport');
  const reportFile = String.fromEnvironment('ensembleTestReportFile');
  const emitJsonReport = bool.fromEnvironment('ensembleTestEmitJsonReport');
  final jsonReport = json.encode(result.toJson());
  final junitReport = _junitReport(result);

  if (reportFile.isNotEmpty) {
    final file = File(reportFile);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(reportMode == 'junit' ? junitReport : jsonReport);
  }

  if (reportMode == 'json' || emitJsonReport) {
    print('ENSEMBLE_TEST_JSON_REPORT:$jsonReport');
  }
  if (reportMode == 'junit') {
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
