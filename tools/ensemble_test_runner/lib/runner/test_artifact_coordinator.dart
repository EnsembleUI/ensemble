import 'package:ensemble_test_runner/runner/debug_artifact_logs.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/storage_step_diff.dart';
import 'package:ensemble_test_runner/mocks/test_logger.dart';
import 'package:ensemble_test_runner/src/benchmark_measurement.dart';

/// Coordinates the diagnostic artifacts that are emitted for a test attempt.
///
/// Keeping artifact publication together makes failure cleanup independent of
/// step execution and gives the runner one small boundary for diagnostic
/// writers. Each writer remains best effort so a broken artifact cannot mask
/// the original test result.
final class TestArtifactCoordinator {
  const TestArtifactCoordinator();

  /// Writes the API and application console sidecars shared by all entry
  /// modes. Keeping these writers behind one boundary prevents hosted and
  /// standalone execution from drifting in error handling or artifact labels.
  Future<void> attachLogArtifacts(EnsembleTestContext context) {
    return RunnerBenchmark.async('workflow', 'attachLogArtifacts', () async {
      if (context.config.logApiCalls.enabled) {
        try {
          final path = await writeApiCallsLog(context);
          replaceArtifactLog(context.logger, 'apiCalls', path);
        } catch (error) {
          context.logger.log('apiCallsError: $error');
        }
      }

      try {
        final path = await writeAppConsoleLog(context);
        replaceArtifactLog(context.logger, 'appLogs', path);
      } catch (error) {
        context.logger.log('appLogsError: $error');
      }
    });
  }

  /// Publishes API and app-console sidecars once per attempt. Kernel terminal
  /// subscribers and compatibility cleanup converge on the same Future.
  Future<void> attachLogArtifactsOnce(EnsembleTestContext context) {
    return context.runtime.debugLogArtifactsWrite ??=
        attachLogArtifacts(context);
  }

  Future<void> attachPerTestDebugArtifacts(EnsembleTestContext context) {
    return RunnerBenchmark.async(
      'workflow',
      'attachPerTestDebugArtifacts',
      () async {
        if (context.config.logStorage.enabled) {
          try {
            final path = await writeStorageLog(context);
            replaceArtifactLog(context.logger, 'storage', path);
          } catch (error) {
            context.logger.log('storageError: $error');
          }
        }

        await attachLogArtifactsOnce(context);
      },
    );
  }

  /// Writes final attempt sidecars at most once for [context].
  ///
  /// Attempt cleanup can be reached through both the execution result and the
  /// outer failure boundary. Sharing the future avoids duplicate storage and
  /// log scans while preserving the best-effort behavior of the writers.
  Future<void> attachPerTestDebugArtifactsOnce(
    EnsembleTestContext context,
  ) {
    return context.runtime.debugArtifactsWrite ??= attachPerTestDebugArtifacts(
      context,
    );
  }

  Future<void> recordStorageStepDiff({
    required EnsembleTestContext context,
    required int stepIndex,
    required StorageStepSnapshot before,
  }) {
    return RunnerBenchmark.async('workflow', 'recordStorageStepDiff', () async {
      final changes = diffStorage(before.publicValues, capturePublicStorage());
      final secureChanges =
          diffStorage(before.secureValues, captureSecureStorage());
      final keychainChanges = diffStorage(
        before.keychainValues,
        await captureKeychainStorage(),
      );
      final timestamp = DateTime.now();
      if (changes.isNotEmpty) {
        context.runtime.storageStepDiffs.add(StorageStepDiff(
          stepIndex: stepIndex,
          timestamp: timestamp,
          changes: changes,
        ));
      }
      if (secureChanges.isNotEmpty) {
        context.runtime.secureStorageStepDiffs.add(StorageStepDiff(
          stepIndex: stepIndex,
          timestamp: timestamp,
          changes: secureChanges,
        ));
      }
      if (keychainChanges.isNotEmpty) {
        context.runtime.keychainStepDiffs.add(StorageStepDiff(
          stepIndex: stepIndex,
          timestamp: timestamp,
          changes: keychainChanges,
        ));
      }
    });
  }

  /// Replaces a prior artifact entry while retaining unrelated logs.
  static void replaceArtifactLog(TestLogger logger, String label, String path) {
    logger.logs.removeWhere((entry) {
      final separator = entry.indexOf(':');
      if (separator <= 0) return false;
      return entry.substring(0, separator).trim() == label;
    });
    logger.log('$label: $path');
  }
}
