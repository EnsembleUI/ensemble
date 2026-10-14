/// Helpers for wiring Ensemble tests into `flutter_test`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:ensemble_test_runner/entry/test_execution_mode.dart';
import 'package:ensemble_test_runner/discovery/ensemble_test_execution_planner.dart';
import 'package:ensemble_test_runner/discovery/flutter_test_execution_planner.dart';
import 'package:ensemble_test_runner/ensemble_test_runner.dart';
import 'package:ensemble_test_runner/reporters/ensemble_test_history_store.dart';
import 'package:ensemble_test_runner/reporters/screenshot_archive.dart';
import 'package:ensemble_test_runner/runner/test_artifacts.dart';
import 'package:ensemble_test_runner/entry/test_entry_environment.dart';
import 'package:ensemble_test_runner/entry/runner_runtime_configuration.dart';
import 'package:ensemble_test_runner/src/integrations/test_integration_registration.dart';
import 'package:ensemble_test_runner/runtime/serialized_plan_batch_loader.dart';
import 'package:ensemble_test_runner/runner/flutter_error_isolation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

int get _timeoutSeconds =>
    RunnerRuntimeConfiguration.current.integer('ensembleTestTimeoutSeconds');
const _historyDisplayPath =
    'build/ensemble_test_runner/report/${EnsembleTestHistoryStore.fileName}';

/// Options for [runEnsembleTests], typically set from `test/ensemble_tests.dart`.
class EnsembleTestOptions {
  /// App bootstrap, typically `() => EnsembleModules().init()` from
  /// `lib/generated/ensemble_modules.dart` (same as `main.dart`).
  final Future<void> Function()? bootstrap;

  /// Host-app methods passed to `EnsembleApp`, e.g. `captureCertificateForHost`.
  final Map<String, Function>? externalMethods;

  /// Execution environment. The regular public entry point uses widget mode.
  final ExecutionMode mode;

  const EnsembleTestOptions({
    this.bootstrap,
    this.externalMethods,
    this.mode = ExecutionMode.widget,
  });
}

/// Registers the shared test suite after an execution-specific binding exists.
///
/// Integration entry points initialize `IntegrationTestWidgetsFlutterBinding`
/// and call this function with [ExecutionMode.integration].
Future<void> registerEnsembleTestsInternal(
  EnsembleTestOptions options,
  Iterable<TestIntegrationRegistration> integrations,
) async {
  configureArtifactTransport(options.mode);
  EnsembleTestHarness.configureTestIntegrations(integrations);
  final runtimeAdapter = EnsembleTestHarness.runtimeAdapterFor(options.mode);
  runtimeAdapter.initialize();
  tearDown(() async {
    try {
      // Dual path with the suite `finally`. After the first attempt the harness
      // clears the baseline, so this is usually a no-op. If finally never ran,
      // a restore failure here fails the test (infrastructure error).
      await EnsembleTestHarness.restorePreSuiteStorageAtSuiteEnd();
      EnsembleTestHarness.resetTestRuntime();
    } finally {
      EnsembleTestHarness.disposeTestStorage();
    }
  });

  testWidgets(
    'Ensemble app test suite',
    (tester) async {
      if (!usesDeviceArtifactTransport) {
        ScreenshotArchive.clearPendingImages(ensembleTestArtifactRoot);
      }
      await withFlutterErrorIsolation(() async {
        var emittedMachineReport = false;
        void emitMachineReport(EnsembleTestRunResult result) {
          emitMachineTestReport(result);
          emittedMachineReport = true;
        }

        Object? suiteError;
        StackTrace? suiteStackTrace;
        Object? storageRestoreError;

        try {
          if (options.bootstrap == null) {
            fail(
              'Ensemble tests require module bootstrap. '
              'In test/ensemble_tests.dart call runEnsembleTests with '
              'bootstrap: () => EnsembleModules().init() '
              '(see ensemble_test_runner README).',
            );
          }
          await tester.runAsync(() async {
            await options.bootstrap!();
            runtimeAdapter.afterBootstrap();
            // Module constructors may schedule follow-up async init work.
            await Future<void>.delayed(Duration.zero);
          });
          if (options.mode == ExecutionMode.integration &&
              usesDeviceArtifactTransport) {
            emitEnsembleTestArtifactTransportBegin();
          }

          final target = await EnsembleTestDiscovery.loadAppTarget();
          final workerBatch = await workerBatchFromEnvironment();
          final plan = workerBatch?.plan ??
              await FlutterTestExecutionPlanner.build(
                target: target,
                selection: testSelectionFromEnvironment(),
                inputs: testInputsFromEnvironment(),
              );
          final harness = EnsembleTestHarness(
            appPath: target.appPath,
            appHome: target.appHome,
            i18nPath: target.i18nPath,
            externalMethods: options.externalMethods,
            executionMode: options.mode,
          );

          final runner = EnsembleTestRunner(harness: harness);
          final serializedPlans = workerBatch?.serializedPlans ?? const {};
          final planResult = await runner.runPlan(
            plan,
            tester,
            onTestStart: emitTestProgressStart,
            onTestComplete: _emitProgressEvent,
            serializedPlans: serializedPlans,
          );
          final resultsById = planResult.resultsById;
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
                failureOperation: result.failureOperation,
                failureSource: result.failureSource,
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
          var runResult = EnsembleTestRunResult(
            results: orderedResults,
            suiteLogs: suiteLogs,
            metadata: _runMetadata(options.mode),
          );
          if (options.mode == ExecutionMode.widget &&
              !isEnsembleTestParallelWorker() &&
              !usesDeviceArtifactTransport) {
            if (await _recordHistory(runResult)) {
              suiteLogs.add('history: $_historyDisplayPath');
              runResult = EnsembleTestRunResult(
                results: orderedResults,
                suiteLogs: suiteLogs,
                metadata: _runMetadata(options.mode),
              );
            }
          }
          if (options.mode == ExecutionMode.widget &&
              !isEnsembleTestParallelWorker() &&
              !usesDeviceArtifactTransport) {
            final htmlPath = HtmlTestReporter().writeShell(
              cleanIntermediates: true,
            );
            suiteLogs.add('htmlReport: $htmlPath');
            runResult = EnsembleTestRunResult(
              results: orderedResults,
              suiteLogs: suiteLogs,
              metadata: _runMetadata(options.mode),
            );
          }
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
          suiteError = error;
          suiteStackTrace = stackTrace;
          if (!emittedMachineReport) {
            final runResult = EnsembleTestRunResult(
              results: [
                EnsembleSingleTestResult.failed(
                  testId: 'test-process',
                  durationMs: 0,
                  message: error.toString(),
                  stackTrace: stackTrace.toString(),
                ),
              ],
              suiteLogs: const [],
              metadata: _runMetadata(options.mode),
            );
            emitMachineReport(runResult);
          }
        } finally {
          try {
            await EnsembleTestHarness.restorePreSuiteStorageAtSuiteEnd();
          } catch (error) {
            storageRestoreError = error;
            stderr.writeln(
              'Failed to restore pre-suite storage at suite end: $error',
            );
          }
          if (options.mode == ExecutionMode.integration &&
              usesDeviceArtifactTransport) {
            emitEnsembleTestArtifactTransportComplete();
          }
        }

        reportSuiteEndWithStorageRestore(
          suiteError: suiteError,
          suiteStackTrace: suiteStackTrace,
          storageRestoreError: storageRestoreError,
        );
      });
    },
    timeout: _timeoutSeconds > 0
        ? Timeout(Duration(seconds: _timeoutSeconds))
        : Timeout.none,
  );
}

/// Surfaces storage-restore failures as suite infrastructure failures.
///
/// Preserves [suiteError] when present and appends the restore failure so both
/// are visible; a restore-only failure fails the suite with a clear message.
void reportSuiteEndWithStorageRestore({
  Object? suiteError,
  StackTrace? suiteStackTrace,
  Object? storageRestoreError,
}) {
  if (storageRestoreError != null && suiteError != null) {
    fail(
      '${_formatSuiteError(suiteError)}\n\n'
      'Also failed to restore pre-suite device storage: $storageRestoreError',
    );
  }
  if (storageRestoreError != null) {
    fail(
      'Failed to restore pre-suite device storage after the suite: '
      '$storageRestoreError',
    );
  }
  if (suiteError != null) {
    if (suiteStackTrace != null) {
      Error.throwWithStackTrace(suiteError, suiteStackTrace);
    }
    throw suiteError;
  }
}

String _formatSuiteError(Object error) {
  if (error is TestFailure) {
    return error.message ?? error.toString();
  }
  return error.toString();
}

Map<String, dynamic> _runMetadata(ExecutionMode mode) {
  const deviceId = String.fromEnvironment('ensembleTestPhysicalDeviceId');
  const platform = String.fromEnvironment('ensembleTestPhysicalPlatform');
  const deviceName = String.fromEnvironment('ensembleTestPhysicalDeviceName');
  final resolvedMode = resolveExecutionMode(mode);
  return {
    'mode': resolvedMode.name,
    if (deviceId.isNotEmpty) 'deviceId': deviceId,
    if (platform.isNotEmpty) 'platform': platform,
    if (deviceName.isNotEmpty) 'deviceName': deviceName,
  };
}

Future<bool> _recordHistory(EnsembleTestRunResult result) async {
  try {
    await EnsembleTestHistoryStore.recordCompletedRun(
      appDir: Directory.current.path,
      artifactRoot: ensembleTestArtifactRoot,
      result: result,
    );
    return true;
  } catch (_) {
    // History is a convenience artifact; it must not affect test outcome.
    stderr.writeln('Warning: could not write the test history database.');
    return false;
  }
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
  final progressFile =
      RunnerRuntimeConfiguration.current.string('ensembleTestProgressFile');
  final event = json.encode({
    'testId': result.testId,
    'assetPath': definition.assetPath,
    'status': result.status.name,
    'durationMs': result.durationMs,
    if (result.attempts > 1) 'attempts': result.attempts,
    if (result.retry > 0) 'retry': result.retry,
    if (result.message != null) 'message': result.message,
    if (result.failedStepIndex != null)
      'failedStepIndex': result.failedStepIndex,
  });
  if (progressFile.isEmpty) {
    if (usesDeviceArtifactTransport) {
      print('$ensembleTestProgressProtocolPrefix$event');
    }
    return;
  }

  final file = File(progressFile);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(
    '$event\n',
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
