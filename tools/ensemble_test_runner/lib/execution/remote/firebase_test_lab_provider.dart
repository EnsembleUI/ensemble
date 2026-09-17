import 'package:ensemble_test_runner/execution/remote/ftl_client.dart';
import 'package:ensemble_test_runner/execution/remote/remote_models.dart';
import 'package:ensemble_test_runner/execution/remote/remote_provider.dart';
import 'package:path/path.dart' as p;

/// Firebase Test Lab [RemoteProvider] adapter.
class FirebaseTestLabProvider implements RemoteProvider {
  final FtlClient client;
  final String projectId;
  @override
  final RemoteProviderLimits limits;

  /// On-device export directory pulled via FTL directoriesToPull (Android).
  /// Hypothesis until verified on real devices — see acceptance ledger.
  static const androidExportPullPath =
      '/sdcard/Android/data/{applicationId}/files/ensemble_test_remote';

  FirebaseTestLabProvider({
    required this.client,
    required this.projectId,
    this.limits = const RemoteProviderLimits(),
  });

  @override
  String get id => 'firebaseTestLab';

  @override
  Future<RemoteProviderJobRef> submit(RemoteSubmitIntent intent) async {
    if (intent.devices.length > limits.maxDevicesPerRun) {
      throw StateError(
        'Device matrix size ${intent.devices.length} exceeds maxDevicesPerRun '
        '${limits.maxDevicesPerRun}. Refusing silent truncation.',
      );
    }

    final deviceMaps = [
      for (final d in intent.devices)
        {
          'model': d.model,
          if (d.version != null) 'version': d.version!,
          if (d.locale != null) 'locale': d.locale!,
          if (d.orientation != null) 'orientation': d.orientation!,
        },
    ];

    final appGcs = await client.uploadFile(
      projectId: projectId,
      localPath: intent.appPackagePath,
      objectName: '${intent.buildId}/${p.basename(intent.appPackagePath)}',
    );
    final testGcs = await client.uploadFile(
      projectId: projectId,
      localPath: intent.testPackagePath,
      objectName: '${intent.buildId}/${p.basename(intent.testPackagePath)}',
    );

    late final FtlSubmitResult result;
    if (intent.platform == 'ios') {
      result = await client.submitIosXcTest(
        projectId: projectId,
        testsZipGcs: appGcs,
        xctestrunGcs: testGcs,
        devices: deviceMaps,
        clientToken: intent.clientToken,
      );
    } else {
      result = await client.submitAndroidInstrumentation(
        projectId: projectId,
        appApkGcs: appGcs,
        testApkGcs: testGcs,
        devices: deviceMaps,
        clientToken: intent.clientToken,
        directoriesToPull: const [
          // Placeholder applicationId substituted by packager docs.
          '/sdcard/googletest/test_outputfiles',
        ],
      );
    }

    if (!result.accepted && !result.uncertain) {
      throw StateError('FTL rejected submit: ${result.detail}');
    }
    if (result.uncertain && result.matrixId.isEmpty) {
      final existing = await findByIntent(intent);
      if (existing != null) return existing;
      throw StateError(
        'FTL submit accept uncertain and no matching job found: '
        '${result.detail}',
      );
    }
    return RemoteProviderJobRef(
      jobId: result.matrixId,
      matrixId: result.matrixId,
      metadata: {
        'uncertain': result.uncertain,
        if (result.detail != null) 'detail': result.detail,
        'clientToken': intent.clientToken,
        'platform': intent.platform,
      },
    );
  }

  @override
  Future<RemoteProviderJobRef?> findByIntent(RemoteSubmitIntent intent) async {
    final list = await client.listRecentMatrices(
      projectId,
      clientTokenPrefix: intent.clientToken,
    );
    for (final snap in list) {
      if (snap.labels['clientToken'] == intent.clientToken) {
        return RemoteProviderJobRef(
          jobId: snap.matrixId,
          matrixId: snap.matrixId,
          metadata: {'adopted': true, 'clientToken': intent.clientToken},
        );
      }
    }
    return null;
  }

  @override
  Future<RemoteJobStatus> getStatus(RemoteProviderJobRef ref) async {
    final snap = await client.getTestMatrix(projectId, ref.matrixId ?? ref.jobId);
    return RemoteJobStatus(
      jobId: snap.matrixId,
      state: _mapState(snap.state),
      detail: snap.outcome,
      devices: {
        for (final d in const ['primary'])
          d: RemoteDeviceExecutionStatus(
            deviceKey: d,
            state: _mapState(snap.state),
            nativeOutcome: snap.outcome,
          ),
      },
    );
  }

  RemoteJobState _mapState(String raw) {
    switch (raw.toUpperCase()) {
      case 'VALIDATING':
      case 'PENDING':
      case 'QUEUED':
        return RemoteJobState.queued;
      case 'RUNNING':
        return RemoteJobState.running;
      case 'FINISHED':
      case 'COMPLETE':
        return RemoteJobState.finished;
      case 'ERROR':
      case 'UNSUPPORTED_ENVIRONMENT':
      case 'INCOMPATIBLE_ENVIRONMENT':
      case 'INCOMPATIBLE_ARCHITECTURE':
        return RemoteJobState.error;
      case 'CANCELLED':
        return RemoteJobState.cancelled;
      default:
        return RemoteJobState.unknown;
    }
  }

  @override
  Future<CollectedRemoteArtifacts> collectArtifacts(
    RemoteProviderJobRef ref, {
    required String destinationDirectory,
  }) async {
    final snap = await client.getTestMatrix(projectId, ref.matrixId ?? ref.jobId);
    final gcs = snap.resultStorageGcs;
    if (gcs == null || gcs.isEmpty) {
      return CollectedRemoteArtifacts(
        jobId: ref.jobId,
        localDirectory: destinationDirectory,
      );
    }
    await client.downloadGcsPrefix(
      gcsUri: gcs,
      localDirectory: destinationDirectory,
    );
    final entries = <RemoteArtifactEntry>[];
    // Host walks downloaded tree for envelope + known artifact paths.
    return CollectedRemoteArtifacts(
      jobId: ref.jobId,
      localDirectory: destinationDirectory,
      entries: entries,
      deviceDirectories: {'primary': destinationDirectory},
    );
  }

  @override
  Future<void> requestCancel(RemoteProviderJobRef ref) async {
    await client.cancelTestMatrix(projectId, ref.matrixId ?? ref.jobId);
  }
}
