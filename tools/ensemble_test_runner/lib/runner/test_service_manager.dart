import 'dart:async';
import 'dart:io';

import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/test_artifacts.dart';
import 'package:http/http.dart' as http;

class TestServiceManager {
  TestServiceManager(this.configs);

  final List<TestServiceConfig> configs;
  final List<_RunningTestService> _running = [];

  Future<void> startAll() async {
    try {
      for (final config in configs) {
        if (await _isReady(config.resolvedReadyUrl)) continue;
        final service = await _RunningTestService.start(config);
        _running.add(service);
        await service.waitUntilReady();
      }
    } catch (_) {
      await stopAll();
      rethrow;
    }
  }

  Future<void> stopAll() async {
    for (final service in _running.reversed) {
      await service.stop();
    }
    _running.clear();
  }

  static Future<bool> _isReady(String? url) async {
    if (url == null || url.isEmpty) return false;
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(milliseconds: 500));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}

class _RunningTestService {
  static const _artifactSuffix = String.fromEnvironment(
    'ensembleTestWorkerSuffix',
  );

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

  static Future<_RunningTestService> start(TestServiceConfig config) async {
    final logsDirectory = ensembleTestArtifactDirectory('logs');
    await logsDirectory.create(recursive: true);
    final safeName = config.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    final safeSuffix =
        _artifactSuffix.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    final suffixPart = safeSuffix.isEmpty ? '' : '_$safeSuffix';
    final logFile = ensembleTestArtifactFile(
      'logs',
      '${safeName}_service$suffixPart.log',
    );
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
  }

  Future<void> waitUntilReady() async {
    final readyUrl = config.resolvedReadyUrl;
    if (readyUrl == null || readyUrl.isEmpty) return;

    final deadline = DateTime.now().add(
      Duration(milliseconds: config.readyTimeoutMs),
    );
    Object? lastError;
    while (DateTime.now().isBefore(deadline)) {
      if (exitCode != null) {
        await logSink.flush();
        throw StateError(
          'Test service "${config.name}" exited with code $exitCode before '
          'becoming ready. See ${logFile.path}.',
        );
      }
      try {
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
  }

  Future<void> stop() async {
    if (exitCode == null) {
      process.kill(ProcessSignal.sigterm);
      try {
        await process.exitCode.timeout(const Duration(seconds: 3));
      } on TimeoutException {
        process.kill(ProcessSignal.sigkill);
        await process.exitCode;
      }
    }
    await stdoutSubscription.cancel();
    await stderrSubscription.cancel();
    await logSink.flush();
    await logSink.close();
  }
}
