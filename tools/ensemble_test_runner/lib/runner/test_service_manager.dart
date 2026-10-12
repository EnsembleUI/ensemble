// Dart 3.8 reports deprecated_member_use at RegExp construction sites even though
// the deprecation is specifically about implementing RegExp. Keep construction compatible
// with this SDK without suppressing diagnostics in unrelated files.
// ignore_for_file: deprecated_member_use
import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'dart:async';
import 'dart:io';

import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/test_artifacts.dart';
import 'package:ensemble_test_runner/entry/runner_runtime_configuration.dart';
import 'package:ensemble_test_runner/cli/process_lifecycle.dart';
import 'package:http/http.dart' as http;

class TestServiceManager {
  TestServiceManager(this.configs, {this.artifactRoot});

  final List<TestServiceConfig> configs;
  final String? artifactRoot;
  final List<_RunningTestService> _running = [];

  /// Whether this suite owns any external services.
  ///
  /// Application and device-hosted suites commonly have no service process to
  /// start. Exposing this small fact lets the lifecycle boundary avoid
  /// entering Flutter's asynchronous test zone for a no-op startup.
  bool get hasConfiguredServices => configs.isNotEmpty;
  // A stop can overlap startup when a suite is interrupted.  Keep a small
  // generation flag so a service created after stopAll began is never left
  // unmanaged.
  bool _stopRequested = false;

  Future<void> startAll() async {
    return await RunnerBenchmark.async('support_service', 'startAll', () async {
      _stopRequested = false;
      try {
        for (final config in configs) {
          if (await _isReady(config.resolvedReadyUrl)) continue;
          final service = await _RunningTestService.start(
            config,
            artifactRoot: artifactRoot,
          );
          if (_stopRequested) {
            await service.stop();
            return;
          }
          _running.add(service);
          await service.waitUntilReady(
            isCancelled: () => _stopRequested,
          );
        }
      } catch (_) {
        await stopAll();
        rethrow;
      }
    });
  }

  Future<void> stopAll() async {
    return await RunnerBenchmark.async('support_service', 'stopAll', () async {
      _stopRequested = true;
      Object? firstError;
      StackTrace? firstStackTrace;
      // Continue through every child when one process refuses cleanup. This
      // matters during suite timeout/interruption, where orphaned services can
      // affect the next run even though the first cleanup failure is reported.
      for (final service in _running.reversed.toList()) {
        try {
          await service.stop();
        } catch (error, stackTrace) {
          firstError ??= error;
          firstStackTrace ??= stackTrace;
        }
      }
      _running.clear();
      if (firstError != null) {
        Error.throwWithStackTrace(firstError, firstStackTrace!);
      }
    });
  }

  static Future<bool> _isReady(String? url) async {
    return await RunnerBenchmark.async('support_service', 'isReady', () async {
      if (url == null || url.isEmpty) return false;
      try {
        RunnerBenchmark.count('readinessProbes', 1);
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(milliseconds: 500));
        return response.statusCode >= 200 && response.statusCode < 300;
      } catch (_) {
        return false;
      }
    });
  }
}

class _RunningTestService {
  static final _artifactSuffix =
      RunnerRuntimeConfiguration.current.string('ensembleTestWorkerSuffix');

  _RunningTestService({
    required this.config,
    required this.process,
    required this.logFile,
    required this.logSink,
    required this.stdoutSubscription,
    required this.stderrSubscription,
  }) {
    process.exitCode.then((value) => exitCode = value);
  }

  final TestServiceConfig config;
  final Process process;
  final File logFile;
  final IOSink logSink;
  final StreamSubscription<List<int>> stdoutSubscription;
  final StreamSubscription<List<int>> stderrSubscription;
  int? exitCode;
  Future<void>? _stopFuture;

  static Future<_RunningTestService> start(
    TestServiceConfig config, {
    String? artifactRoot,
  }) async {
    return await RunnerBenchmark.async('support_service', 'start', () async {
      final logsDirectory = artifactRoot == null
          ? ensembleTestArtifactDirectory('logs')
          : Directory('$artifactRoot/logs');
      await logsDirectory.create(recursive: true);
      final safeName = config.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
      final safeSuffix =
          _artifactSuffix.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
      final suffixPart = safeSuffix.isEmpty ? '' : '_$safeSuffix';
      final logFile = artifactRoot == null
          ? ensembleTestArtifactFile(
              'logs',
              '${safeName}_service$suffixPart.log',
            )
          : File('${logsDirectory.path}/${safeName}_service$suffixPart.log');
      final logSink = logFile.openWrite();

      try {
        final process = await Process.start(
          config.command,
          config.arguments,
          workingDirectory: config.workingDirectory,
          environment: config.resolvedEnvironment.isEmpty
              ? null
              : config.resolvedEnvironment,
          includeParentEnvironment: true,
        );
        final stdoutSubscription = process.stdout.listen(logSink.add);
        final stderrSubscription = process.stderr.listen(logSink.add);
        return _RunningTestService(
          config: config,
          process: process,
          logFile: logFile,
          logSink: logSink,
          stdoutSubscription: stdoutSubscription,
          stderrSubscription: stderrSubscription,
        );
      } catch (_) {
        await logSink.close();
        rethrow;
      }
    });
  }

  Future<void> waitUntilReady({bool Function()? isCancelled}) async {
    return await RunnerBenchmark.async('support_service', 'waitUntilReady',
        () async {
      final readyUrl = config.resolvedReadyUrl;
      if (readyUrl == null || readyUrl.isEmpty) return;

      final deadline = DateTime.now().add(
        Duration(milliseconds: config.readyTimeoutMs),
      );
      Object? lastError;
      while (DateTime.now().isBefore(deadline)) {
        if (isCancelled?.call() ?? false) {
          throw StateError(
            'Test service "${config.name}" startup was cancelled.',
          );
        }
        if (exitCode != null) {
          await logSink.flush();
          throw StateError(
            'Test service "${config.name}" exited with code $exitCode before '
            'becoming ready. See ${logFile.path}.',
          );
        }
        try {
          RunnerBenchmark.count('readinessProbes', 1);
          final response = await http
              .get(Uri.parse(readyUrl))
              .timeout(const Duration(seconds: 1));
          if (response.statusCode >= 200 && response.statusCode < 300) return;
          lastError = 'HTTP ${response.statusCode}';
        } catch (error) {
          lastError = error;
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      throw StateError(
        'Timed out waiting for test service "${config.name}" at $readyUrl'
        '${lastError == null ? '' : ': $lastError'}. See ${logFile.path}.',
      );
    });
  }

  Future<void> stop() async {
    final existing = _stopFuture;
    if (existing != null) return existing;
    final stopFuture =
        RunnerBenchmark.async('support_service', 'stop', () async {
      if (exitCode == null) {
        // Services can launch helper processes. Reuse the worker lifecycle
        // path so timeout cleanup also reaps descendants before suite teardown
        // returns, while retaining the same bounded graceful/forced shutdown.
        await waitForManagedProcess(
          process,
          terminateOnStart: ProcessSignal.sigterm,
          terminationGracePeriod: const Duration(seconds: 3),
        );
      }
      await stdoutSubscription.cancel();
      await stderrSubscription.cancel();
      await logSink.flush();
      await logSink.close();
    });
    _stopFuture = stopFuture;
    return stopFuture;
  }
}
