import 'package:ensemble_test_runner/execution/remote/remote_models.dart';

/// Opaque reference returned by a provider after accepting a job.
class RemoteProviderJobRef {
  final String jobId;
  final String? matrixId;
  final Map<String, dynamic> metadata;

  const RemoteProviderJobRef({
    required this.jobId,
    this.matrixId,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
        'jobId': jobId,
        if (matrixId != null) 'matrixId': matrixId,
        if (metadata.isNotEmpty) 'metadata': metadata,
      };

  factory RemoteProviderJobRef.fromJson(Map<String, dynamic> json) =>
      RemoteProviderJobRef(
        jobId: json['jobId']?.toString() ?? '',
        matrixId: json['matrixId']?.toString(),
        metadata: json['metadata'] is Map
            ? Map<String, dynamic>.from(json['metadata'] as Map)
            : const {},
      );
}

/// Submission intent fingerprint (never includes secrets).
class RemoteSubmitIntent {
  final String runId;
  final String buildId;
  final String planHash;
  final String intentFingerprint;
  final String clientToken;
  final List<RemoteDeviceSpec> devices;
  final String appPackagePath;
  final String testPackagePath;
  final String platform;
  final Map<String, String> labels;

  const RemoteSubmitIntent({
    required this.runId,
    required this.buildId,
    required this.planHash,
    required this.intentFingerprint,
    required this.clientToken,
    required this.devices,
    required this.appPackagePath,
    required this.testPackagePath,
    required this.platform,
    this.labels = const {},
  });
}

enum RemoteJobState {
  queued,
  running,
  finished,
  error,
  cancelled,
  unknown,
}

class RemoteJobStatus {
  final String jobId;
  final RemoteJobState state;
  final String? detail;
  final String? historyId;
  final Map<String, RemoteDeviceExecutionStatus> devices;

  const RemoteJobStatus({
    required this.jobId,
    required this.state,
    this.detail,
    this.historyId,
    this.devices = const {},
  });
}

class RemoteDeviceExecutionStatus {
  final String deviceKey;
  final RemoteJobState state;
  final String? nativeOutcome;
  final String? detail;

  const RemoteDeviceExecutionStatus({
    required this.deviceKey,
    required this.state,
    this.nativeOutcome,
    this.detail,
  });
}

class CollectedRemoteArtifacts {
  final String jobId;
  final String localDirectory;
  final List<RemoteArtifactEntry> entries;
  final Map<String, String> deviceDirectories;

  const CollectedRemoteArtifacts({
    required this.jobId,
    required this.localDirectory,
    this.entries = const [],
    this.deviceDirectories = const {},
  });
}

/// Operational limits applied by [RemoteProvider] adapters.
class RemoteProviderLimits {
  final Duration pollInterval;
  final Duration maxPollDuration;
  final Duration pollBackoffCap;
  final int maxSubmitRetries;
  final int maxConcurrentJobs;
  final int maxDevicesPerRun;
  final Duration artifactRetention;

  const RemoteProviderLimits({
    this.pollInterval = const Duration(seconds: 15),
    this.maxPollDuration = const Duration(hours: 2),
    this.pollBackoffCap = const Duration(minutes: 2),
    this.maxSubmitRetries = 2,
    this.maxConcurrentJobs = 4,
    this.maxDevicesPerRun = 8,
    this.artifactRetention = const Duration(days: 14),
  });
}

/// Cloud device-lab provider (Firebase Test Lab today).
abstract class RemoteProvider {
  String get id;
  RemoteProviderLimits get limits;

  Future<RemoteProviderJobRef> submit(RemoteSubmitIntent intent);

  /// Returns an existing job that matches [intent] when accept was uncertain.
  Future<RemoteProviderJobRef?> findByIntent(RemoteSubmitIntent intent);

  Future<RemoteJobStatus> getStatus(RemoteProviderJobRef ref);

  Future<CollectedRemoteArtifacts> collectArtifacts(
    RemoteProviderJobRef ref, {
    required String destinationDirectory,
  });

  /// Requests cancellation. Does not imply [RemoteJobState.cancelled].
  Future<void> requestCancel(RemoteProviderJobRef ref);
}
