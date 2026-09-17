import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';

/// Where a suite runs relative to the developer machine / CI host.
///
/// Orthogonal to [ExecutionMode]: remote requires [ExecutionMode.integration].
enum ExecutionTarget { local, remote }

/// Provider job cancellation lifecycle (never jump to [cancelled] on request alone).
enum RemoteCancellationState {
  none,
  cancellationRequested,
  cancelled,
  cancellationUncertain,
}

/// Versioned on-device / collected result envelope for remote (and local proof).
class RemoteRunEnvelope {
  static const schemaVersion = 1;

  final int version;
  final String runId;
  final String? deviceExecutionId;
  final String? planHash;
  final String? buildId;
  final EnsembleTestRunResult? results;
  final List<RemoteArtifactEntry> artifacts;
  final List<String> infrastructureErrors;
  final List<String> cleanupErrors;
  final bool complete;
  final Map<String, dynamic> metadata;

  const RemoteRunEnvelope({
    this.version = schemaVersion,
    required this.runId,
    this.deviceExecutionId,
    this.planHash,
    this.buildId,
    this.results,
    this.artifacts = const [],
    this.infrastructureErrors = const [],
    this.cleanupErrors = const [],
    required this.complete,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'runId': runId,
        if (deviceExecutionId != null) 'deviceExecutionId': deviceExecutionId,
        if (planHash != null) 'planHash': planHash,
        if (buildId != null) 'buildId': buildId,
        if (results != null) 'results': results!.toJson(),
        if (artifacts.isNotEmpty)
          'artifacts': artifacts.map((a) => a.toJson()).toList(),
        if (infrastructureErrors.isNotEmpty)
          'infrastructureErrors': infrastructureErrors,
        if (cleanupErrors.isNotEmpty) 'cleanupErrors': cleanupErrors,
        'complete': complete,
        if (metadata.isNotEmpty) 'metadata': metadata,
      };

  factory RemoteRunEnvelope.fromJson(Map<String, dynamic> json) {
    final resultsRaw = json['results'];
    final artifactsRaw = json['artifacts'];
    final infraRaw = json['infrastructureErrors'];
    final cleanupRaw = json['cleanupErrors'];
    final metadataRaw = json['metadata'];
    return RemoteRunEnvelope(
      version: json['version'] as int? ?? schemaVersion,
      runId: json['runId']?.toString() ?? '',
      deviceExecutionId: json['deviceExecutionId']?.toString(),
      planHash: json['planHash']?.toString(),
      buildId: json['buildId']?.toString(),
      results: resultsRaw is Map
          ? EnsembleTestRunResult.fromJson(
              Map<String, dynamic>.from(resultsRaw),
            )
          : null,
      artifacts: artifactsRaw is List
          ? artifactsRaw
              .whereType<Map>()
              .map(
                (e) => RemoteArtifactEntry.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList()
          : const [],
      infrastructureErrors: infraRaw is List
          ? infraRaw.map((e) => e.toString()).toList()
          : const [],
      cleanupErrors: cleanupRaw is List
          ? cleanupRaw.map((e) => e.toString()).toList()
          : const [],
      complete: json['complete'] == true,
      metadata: metadataRaw is Map
          ? Map<String, dynamic>.from(metadataRaw)
          : const {},
    );
  }
}

class RemoteArtifactEntry {
  final String path;
  final String? mimeType;
  final int? byteLength;
  final String? sha256;

  const RemoteArtifactEntry({
    required this.path,
    this.mimeType,
    this.byteLength,
    this.sha256,
  });

  Map<String, dynamic> toJson() => {
        'path': path,
        if (mimeType != null) 'mimeType': mimeType,
        if (byteLength != null) 'byteLength': byteLength,
        if (sha256 != null) 'sha256': sha256,
      };

  factory RemoteArtifactEntry.fromJson(Map<String, dynamic> json) =>
      RemoteArtifactEntry(
        path: json['path']?.toString() ?? '',
        mimeType: json['mimeType']?.toString(),
        byteLength: json['byteLength'] as int?,
        sha256: json['sha256']?.toString(),
      );
}

/// Suite-level remote provider configuration (FTL catalog, not viewport matrix).
class RemoteExecutionConfig {
  final String provider;
  final String? projectId;
  final List<RemoteDeviceSpec> devices;
  final List<RemoteEndpointConfig> endpoints;

  const RemoteExecutionConfig({
    this.provider = 'firebaseTestLab',
    this.projectId,
    this.devices = const [],
    this.endpoints = const [],
  });

  Map<String, dynamic> toJson() => {
        'provider': provider,
        if (projectId != null) 'projectId': projectId,
        if (devices.isNotEmpty)
          'devices': devices.map((d) => d.toJson()).toList(),
        if (endpoints.isNotEmpty)
          'endpoints': endpoints.map((e) => e.toJson()).toList(),
      };

  factory RemoteExecutionConfig.fromJson(Map<String, dynamic> json) {
    final devicesRaw = json['devices'];
    final endpointsRaw = json['endpoints'];
    return RemoteExecutionConfig(
      provider: json['provider']?.toString() ?? 'firebaseTestLab',
      projectId: json['projectId']?.toString(),
      devices: devicesRaw is List
          ? devicesRaw
              .whereType<Map>()
              .map(
                (e) => RemoteDeviceSpec.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList()
          : const [],
      endpoints: endpointsRaw is List
          ? endpointsRaw
              .whereType<Map>()
              .map(
                (e) => RemoteEndpointConfig.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList()
          : const [],
    );
  }
}

class RemoteDeviceSpec {
  final String model;
  final String? version;
  final String? locale;
  final String? orientation;

  const RemoteDeviceSpec({
    required this.model,
    this.version,
    this.locale,
    this.orientation,
  });

  Map<String, dynamic> toJson() => {
        'model': model,
        if (version != null) 'version': version,
        if (locale != null) 'locale': locale,
        if (orientation != null) 'orientation': orientation,
      };

  factory RemoteDeviceSpec.fromJson(Map<String, dynamic> json) =>
      RemoteDeviceSpec(
        model: json['model']?.toString() ?? '',
        version: json['version']?.toString(),
        locale: json['locale']?.toString(),
        orientation: json['orientation']?.toString(),
      );
}

class RemoteEndpointConfig {
  final String name;
  final String url;

  const RemoteEndpointConfig({required this.name, required this.url});

  Map<String, dynamic> toJson() => {'name': name, 'url': url};

  factory RemoteEndpointConfig.fromJson(Map<String, dynamic> json) =>
      RemoteEndpointConfig(
        name: json['name']?.toString() ?? '',
        url: json['url']?.toString() ?? '',
      );
}

/// Stable hash over behavior-affecting remote plan inputs (not run/device ids).
String computePlanHash({
  required ExecutionMode mode,
  required ExecutionTarget target,
  required List<String> selectedTestIds,
  Map<String, dynamic> buildDefines = const {},
}) {
  final buffer = StringBuffer()
    ..write(mode.name)
    ..write('|')
    ..write(target.name)
    ..write('|')
    ..write((List<String>.from(selectedTestIds)..sort()).join(','))
    ..write('|')
    ..write(json.encode(buildDefines));
  return sha256.convert(utf8.encode(buffer.toString())).toString();
}

/// Protocol prefix for stdout/logcat envelope records (local proof + fallback).
const ensembleTestRemoteEnvelopePrefix = 'ENSEMBLE_TEST_REMOTE_ENVELOPE_V1:';

void emitRemoteRunEnvelope(RemoteRunEnvelope envelope) {
  // ignore: avoid_print
  print('$ensembleTestRemoteEnvelopePrefix${json.encode(envelope.toJson())}');
}

RemoteRunEnvelope? parseRemoteRunEnvelopeFromOutput(String output) {
  for (final line in output.split('\n')) {
    final trimmed = line.trim();
    final idx = trimmed.indexOf(ensembleTestRemoteEnvelopePrefix);
    if (idx < 0) continue;
    final payload =
        trimmed.substring(idx + ensembleTestRemoteEnvelopePrefix.length);
    try {
      final decoded = json.decode(payload);
      if (decoded is Map) {
        return RemoteRunEnvelope.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      // Keep scanning.
    }
  }
  return null;
}
