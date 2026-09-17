import 'dart:convert';

import 'package:ensemble_test_runner/execution/remote/remote_models.dart';
import 'package:ensemble_test_runner/execution/remote/remote_provider.dart';

/// Durable manifest for a remote orchestration run.
class RemoteRunManifest {
  final String runId;
  final String buildId;
  final String planHash;
  final String intentFingerprint;
  final String clientToken;
  final String platform;
  final List<RemoteDeviceSpec> devices;
  final RemoteProviderJobRef? providerRef;
  final String status;
  final RemoteCancellationState cancellation;
  final int version;
  final DateTime updatedAt;
  final Map<String, dynamic> metadata;

  const RemoteRunManifest({
    required this.runId,
    required this.buildId,
    required this.planHash,
    required this.intentFingerprint,
    required this.clientToken,
    required this.platform,
    required this.devices,
    this.providerRef,
    required this.status,
    this.cancellation = RemoteCancellationState.none,
    this.version = 1,
    required this.updatedAt,
    this.metadata = const {},
  });

  RemoteRunManifest copyWith({
    RemoteProviderJobRef? providerRef,
    String? status,
    RemoteCancellationState? cancellation,
    int? version,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return RemoteRunManifest(
      runId: runId,
      buildId: buildId,
      planHash: planHash,
      intentFingerprint: intentFingerprint,
      clientToken: clientToken,
      platform: platform,
      devices: devices,
      providerRef: providerRef ?? this.providerRef,
      status: status ?? this.status,
      cancellation: cancellation ?? this.cancellation,
      version: version ?? this.version,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
        'runId': runId,
        'buildId': buildId,
        'planHash': planHash,
        'intentFingerprint': intentFingerprint,
        'clientToken': clientToken,
        'platform': platform,
        'devices': devices.map((d) => d.toJson()).toList(),
        if (providerRef != null) 'providerRef': providerRef!.toJson(),
        'status': status,
        'cancellation': cancellation.name,
        'version': version,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        if (metadata.isNotEmpty) 'metadata': metadata,
      };

  factory RemoteRunManifest.fromJson(Map<String, dynamic> json) {
    final devicesRaw = json['devices'];
    final refRaw = json['providerRef'];
    final cancellationRaw = json['cancellation']?.toString();
    return RemoteRunManifest(
      runId: json['runId']?.toString() ?? '',
      buildId: json['buildId']?.toString() ?? '',
      planHash: json['planHash']?.toString() ?? '',
      intentFingerprint: json['intentFingerprint']?.toString() ?? '',
      clientToken: json['clientToken']?.toString() ?? '',
      platform: json['platform']?.toString() ?? 'android',
      devices: devicesRaw is List
          ? devicesRaw
              .whereType<Map>()
              .map(
                (e) => RemoteDeviceSpec.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList()
          : const [],
      providerRef: refRaw is Map
          ? RemoteProviderJobRef.fromJson(Map<String, dynamic>.from(refRaw))
          : null,
      status: json['status']?.toString() ?? 'unknown',
      cancellation: RemoteCancellationState.values.firstWhere(
        (e) => e.name == cancellationRaw,
        orElse: () => RemoteCancellationState.none,
      ),
      version: json['version'] as int? ?? 1,
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const {},
    );
  }

  String encode() => json.encode(toJson());

  static RemoteRunManifest decode(String raw) =>
      RemoteRunManifest.fromJson(json.decode(raw) as Map<String, dynamic>);
}

/// Intent persisted before provider submit.
class RemoteRunIntent {
  final RemoteRunManifest manifest;
  final String appPackagePath;
  final String testPackagePath;

  const RemoteRunIntent({
    required this.manifest,
    required this.appPackagePath,
    required this.testPackagePath,
  });
}

/// Durable store for remote run manifests.
///
/// Provider-job reconciliation stays in the orchestrator, not here.
abstract class RemoteRunStore {
  Future<void> putIntent(RemoteRunIntent intent);

  Future<void> putProviderRef({
    required String runId,
    required RemoteProviderJobRef ref,
    required int expectedVersion,
  });

  Future<RemoteRunManifest?> get(String runId);

  /// Compare-and-swap using [expectedVersion]. Returns false on conflict.
  Future<bool> compareAndSwap({
    required RemoteRunManifest next,
    required int expectedVersion,
  });
}
