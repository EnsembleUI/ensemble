import 'dart:io';

import 'package:ensemble_test_runner/execution/remote/ftl_client.dart';
import 'package:ensemble_test_runner/execution/remote/remote_models.dart';
import 'package:ensemble_test_runner/execution/remote/remote_progress.dart';
import 'package:ensemble_test_runner/execution/remote/remote_provider.dart';
import 'package:path/path.dart' as p;

/// Firebase Test Lab [RemoteProvider] adapter.
class FirebaseTestLabProvider implements RemoteProvider {
  final FtlClient client;
  final String projectId;
  final RemoteProgress? onProgress;
  @override
  final RemoteProviderLimits limits;

  /// On-device export directory pulled via FTL directoriesToPull (Android).
  ///
  /// Must stay under `/sdcard/` (or `/storage/emulated/0/`) — FTL will not pull
  /// `/data/local/tmp/...`. The googletest output tree is always collected.
  static const androidExportPullPath =
      '/sdcard/googletest/test_outputfiles/ensemble_test_remote';

  /// Parent of [androidExportPullPath] passed to Testing API directoriesToPull.
  static const androidDirectoriesToPull = [
    '/sdcard/googletest/test_outputfiles',
  ];

  FirebaseTestLabProvider({
    required this.client,
    required this.projectId,
    this.limits = const RemoteProviderLimits(),
    this.onProgress,
  });

  void _log(String message) => onProgress?.call(message);

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KiB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';
  }

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

    final appBytes = File(intent.appPackagePath).existsSync()
        ? File(intent.appPackagePath).lengthSync()
        : 0;
    final testBytes = File(intent.testPackagePath).existsSync()
        ? File(intent.testPackagePath).lengthSync()
        : 0;

    _log(
      'Uploading app package (${_formatBytes(appBytes)}): '
      '${p.basename(intent.appPackagePath)}',
    );
    final uploadStarted = DateTime.now().toUtc();
    final appGcs = await client.uploadFile(
      projectId: projectId,
      localPath: intent.appPackagePath,
      objectName: '${intent.buildId}/${p.basename(intent.appPackagePath)}',
    );
    _log(
      'Uploaded app → $appGcs '
      '(${DateTime.now().toUtc().difference(uploadStarted).inSeconds}s)',
    );

    _log(
      'Uploading test package (${_formatBytes(testBytes)}): '
      '${p.basename(intent.testPackagePath)}',
    );
    final testUploadStarted = DateTime.now().toUtc();
    final testGcs = await client.uploadFile(
      projectId: projectId,
      localPath: intent.testPackagePath,
      objectName: '${intent.buildId}/${p.basename(intent.testPackagePath)}',
    );
    _log(
      'Uploaded test → $testGcs '
      '(${DateTime.now().toUtc().difference(testUploadStarted).inSeconds}s)',
    );

    _log(
      'Submitting ${intent.platform} matrix to Firebase Test Lab '
      '(${intent.devices.length} device(s))...',
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
        directoriesToPull: androidDirectoriesToPull,
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

    var historyId = result.historyId;
    var resultsUrl = result.resultsUrl;
    // Create responses often omit resultsUrl/historyId until the matrix is readable.
    if ((historyId == null || historyId.isEmpty) ||
        (resultsUrl == null || resultsUrl.isEmpty)) {
      try {
        final snap = await client.getTestMatrix(projectId, result.matrixId);
        historyId ??= snap.historyId;
        resultsUrl ??= snap.resultsUrl;
      } catch (_) {
        // Keep browsing fallback; poll may discover resultsUrl later.
      }
    }

    final links = FtlConsoleLinks(
      projectId: projectId,
      matrixId: result.matrixId,
      historyId: historyId,
      resultsUrl: resultsUrl,
    );
    _log('FTL matrix accepted: ${result.matrixId}');
    _log(links.logLine);

    return RemoteProviderJobRef(
      jobId: result.matrixId,
      matrixId: result.matrixId,
      metadata: {
        'uncertain': result.uncertain,
        if (result.detail != null) 'detail': result.detail,
        'clientToken': intent.clientToken,
        'platform': intent.platform,
        'projectId': projectId,
        ...links.toMetadata(),
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
        final links = FtlConsoleLinks(
          projectId: projectId,
          matrixId: snap.matrixId,
          historyId: snap.historyId,
          resultsUrl: snap.resultsUrl,
        );
        return RemoteProviderJobRef(
          jobId: snap.matrixId,
          matrixId: snap.matrixId,
          metadata: {
            'adopted': true,
            'clientToken': intent.clientToken,
            ...links.toMetadata(),
          },
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
      detail: snap.outcome ?? snap.state,
      historyId: snap.historyId,
      resultsUrl: snap.resultsUrl,
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
      _log('No GCS result path on matrix ${ref.jobId}; skipping download');
      return CollectedRemoteArtifacts(
        jobId: ref.jobId,
        localDirectory: destinationDirectory,
      );
    }
    _log('Downloading FTL artifacts from $gcs ...');
    await client.downloadGcsPrefix(
      gcsUri: gcs,
      localDirectory: destinationDirectory,
    );
    _log('Artifacts downloaded to $destinationDirectory');
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
    _log('Requesting cancel for matrix ${ref.matrixId ?? ref.jobId}');
    await client.cancelTestMatrix(projectId, ref.matrixId ?? ref.jobId);
  }
}
