import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:ensemble_test_runner/execution/remote/native_build_service.dart';
import 'package:ensemble_test_runner/execution/remote/remote_models.dart';
import 'package:path/path.dart' as p;

/// Host-side classification of a device execution after collect.
enum RemoteExecutionFailureClass {
  pass,
  testFailure,
  incomplete,
  infrastructureFailure,
  artifactFailure,
}

class ReconciledDeviceResult {
  final String deviceKey;
  final RemoteExecutionFailureClass failureClass;
  final String? nativeOutcome;
  final RemoteRunEnvelope? envelope;
  final List<String> messages;
  final int exitCode;

  const ReconciledDeviceResult({
    required this.deviceKey,
    required this.failureClass,
    this.nativeOutcome,
    this.envelope,
    this.messages = const [],
    required this.exitCode,
  });

  Map<String, dynamic> toJson() => {
        'deviceKey': deviceKey,
        'failureClass': failureClass.name,
        if (nativeOutcome != null) 'nativeOutcome': nativeOutcome,
        if (envelope != null) 'envelope': envelope!.toJson(),
        if (messages.isNotEmpty) 'messages': messages,
        'exitCode': exitCode,
      };
}

class AggregatedRemoteReport {
  final String runId;
  final List<ReconciledDeviceResult> devices;
  final RemoteExecutionFailureClass overall;
  final int exitCode;

  const AggregatedRemoteReport({
    required this.runId,
    required this.devices,
    required this.overall,
    required this.exitCode,
  });

  Map<String, dynamic> toJson() => {
        'runId': runId,
        'devices': devices.map((d) => d.toJson()).toList(),
        'overall': overall.name,
        'exitCode': exitCode,
      };

  String toPrettyJson() =>
      const JsonEncoder.withIndent('  ').convert(toJson());
}

/// Reconciles native framework outcome + envelope + artifact integrity.
abstract final class RemoteReportReconciler {
  RemoteReportReconciler._();

  static ReconciledDeviceResult reconcile({
    required String deviceKey,
    required String? nativeOutcome,
    required RemoteRunEnvelope? envelope,
    required Directory artifactDirectory,
    List<String> requiredArtifactRelativePaths = const ['remote/envelope.json'],
  }) {
    final messages = <String>[];

    if (nativeOutcome == null ||
        nativeOutcome.toUpperCase().contains('ERROR') ||
        nativeOutcome.toUpperCase().contains('INFRA')) {
      return ReconciledDeviceResult(
        deviceKey: deviceKey,
        failureClass: RemoteExecutionFailureClass.infrastructureFailure,
        nativeOutcome: nativeOutcome,
        envelope: envelope,
        messages: [
          'Native framework outcome missing or infrastructure failure '
              '(${nativeOutcome ?? 'null'}).',
        ],
        exitCode: 2,
      );
    }

    if (envelope == null || !envelope.complete) {
      final outcome = (nativeOutcome ?? '').toUpperCase();
      final ftlPassed = outcome.contains('SUCCESS') || outcome == 'PASSED';
      return ReconciledDeviceResult(
        deviceKey: deviceKey,
        failureClass: RemoteExecutionFailureClass.incomplete,
        nativeOutcome: nativeOutcome,
        envelope: envelope,
        messages: [
          'RemoteRunEnvelope missing or incomplete=false; never pass.',
          if (ftlPassed)
            'Firebase Test Lab reported $nativeOutcome for instrumentation, '
                'but the host could not collect a complete envelope '
                '(file under ${AndroidFtlPackager.onDeviceArtifactRoot} via '
                'directoriesToPull, or ENSEMBLE_TEST_REMOTE_ENVELOPE_V1 in '
                'logcat). HTML/history reports need envelope.results.',
        ],
        exitCode: 2,
      );
    }

    if (envelope.cleanupErrors.isNotEmpty) {
      messages.addAll(
        envelope.cleanupErrors.map((e) => 'cleanup: $e'),
      );
    }

    final artifactProblems = <String>[];
    // Envelope already loaded (possibly from an FTL-nested path). Skip the
    // fixed envelope path check; other caller-required paths still apply.
    for (final relative in requiredArtifactRelativePaths) {
      if (relative == 'remote/envelope.json' || relative == 'envelope.json') {
        continue;
      }
      final file = File(p.join(artifactDirectory.path, relative));
      if (!file.existsSync()) {
        artifactProblems.add('Missing required artifact: $relative');
        continue;
      }
      final normalized = p.normalize(relative);
      if (p.isAbsolute(normalized) ||
          normalized == '..' ||
          normalized.startsWith('../')) {
        artifactProblems.add('Unsafe artifact path: $relative');
      }
    }

    for (final entry in envelope.artifacts) {
      final normalized = p.posix.normalize(entry.path.replaceAll('\\', '/'));
      if (p.posix.isAbsolute(normalized) ||
          normalized == '..' ||
          normalized.startsWith('../')) {
        artifactProblems.add('Unsafe envelope artifact path: ${entry.path}');
        continue;
      }
      final file = File(p.join(artifactDirectory.path, normalized));
      if (!file.existsSync()) {
        artifactProblems.add('Envelope lists missing file: ${entry.path}');
        continue;
      }
      if (entry.sha256 != null) {
        final digest = sha256.convert(file.readAsBytesSync()).toString();
        if (digest != entry.sha256) {
          artifactProblems.add(
            'Checksum mismatch for ${entry.path}: expected ${entry.sha256}, '
            'got $digest',
          );
        }
      }
    }

    if (artifactProblems.isNotEmpty) {
      return ReconciledDeviceResult(
        deviceKey: deviceKey,
        failureClass: RemoteExecutionFailureClass.artifactFailure,
        nativeOutcome: nativeOutcome,
        envelope: envelope,
        messages: [...messages, ...artifactProblems],
        exitCode: 2,
      );
    }

    final failed = envelope.results?.failedCount ?? 0;
    final nativeFailed = nativeOutcome.toUpperCase().contains('FAILURE') ||
        nativeOutcome.toUpperCase() == 'FAILED';

    if (failed > 0 || nativeFailed) {
      return ReconciledDeviceResult(
        deviceKey: deviceKey,
        failureClass: RemoteExecutionFailureClass.testFailure,
        nativeOutcome: nativeOutcome,
        envelope: envelope,
        messages: [
          ...messages,
          'Test assertions failed (failedCount=$failed, native=$nativeOutcome).',
        ],
        exitCode: 1,
      );
    }

    return ReconciledDeviceResult(
      deviceKey: deviceKey,
      failureClass: RemoteExecutionFailureClass.pass,
      nativeOutcome: nativeOutcome,
      envelope: envelope,
      messages: messages,
      exitCode: 0,
    );
  }

  static AggregatedRemoteReport aggregate({
    required String runId,
    required List<ReconciledDeviceResult> devices,
  }) {
    RemoteExecutionFailureClass overall = RemoteExecutionFailureClass.pass;
    var exitCode = 0;
    for (final d in devices) {
      exitCode = exitCode > d.exitCode ? exitCode : d.exitCode;
      overall = _worse(overall, d.failureClass);
    }
    if (devices.isEmpty) {
      overall = RemoteExecutionFailureClass.incomplete;
      exitCode = 2;
    }
    return AggregatedRemoteReport(
      runId: runId,
      devices: devices,
      overall: overall,
      exitCode: exitCode,
    );
  }

  static RemoteExecutionFailureClass _worse(
    RemoteExecutionFailureClass a,
    RemoteExecutionFailureClass b,
  ) {
    int rank(RemoteExecutionFailureClass c) => switch (c) {
          RemoteExecutionFailureClass.pass => 0,
          RemoteExecutionFailureClass.testFailure => 1,
          RemoteExecutionFailureClass.artifactFailure => 2,
          RemoteExecutionFailureClass.incomplete => 3,
          RemoteExecutionFailureClass.infrastructureFailure => 4,
        };
    return rank(b) > rank(a) ? b : a;
  }

  static RemoteRunEnvelope? loadEnvelope(Directory directory) {
    if (!directory.existsSync()) return null;
    final preferred = [
      File(p.join(directory.path, 'remote', 'envelope.json')),
      File(p.join(directory.path, 'envelope.json')),
      // FTL nests pulled trees under device-specific prefixes.
      File(
        p.join(
          directory.path,
          'data',
          'local',
          'tmp',
          'ensemble_test_remote',
          'remote',
          'envelope.json',
        ),
      ),
      File(
        p.join(
          directory.path,
          'ensemble_test_remote',
          'remote',
          'envelope.json',
        ),
      ),
    ];
    for (final file in preferred) {
      final parsed = _tryParseEnvelope(file);
      if (parsed != null) return parsed;
    }
    // Any envelope.json under the download tree.
    try {
      for (final entity in directory.listSync(recursive: true)) {
        if (entity is! File) continue;
        if (p.basename(entity.path) != 'envelope.json') continue;
        final parsed = _tryParseEnvelope(entity);
        if (parsed != null) return parsed;
      }
    } catch (_) {
      // Ignore walk errors; treat as missing envelope.
    }
    // Secondary protocol: device prints ENSEMBLE_TEST_REMOTE_ENVELOPE_V1 to
    // stdout → captured in FTL logcat artifacts.
    return loadEnvelopeFromLogcat(directory);
  }

  /// Scans FTL-downloaded logcat / text logs for the envelope print protocol.
  static RemoteRunEnvelope? loadEnvelopeFromLogcat(Directory directory) {
    if (!directory.existsSync()) return null;
    try {
      for (final entity in directory.listSync(recursive: true)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path).toLowerCase();
        final looksLikeLog = name.contains('logcat') ||
            name.endsWith('.txt') ||
            name.endsWith('.log');
        if (!looksLikeLog) continue;
        String text;
        try {
          text = entity.readAsStringSync();
        } catch (_) {
          continue;
        }
        if (!text.contains(ensembleTestRemoteEnvelopePrefix)) continue;
        final parsed = parseRemoteRunEnvelopeFromOutput(text);
        if (parsed != null) return parsed;
      }
    } catch (_) {
      // Ignore walk errors.
    }
    return null;
  }

  static RemoteRunEnvelope? _tryParseEnvelope(File file) {
    if (!file.existsSync()) return null;
    try {
      final decoded = json.decode(file.readAsStringSync());
      if (decoded is Map) {
        return RemoteRunEnvelope.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      // Keep scanning.
    }
    return null;
  }
}
