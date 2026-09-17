import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:ensemble_test_runner/execution/remote/file_remote_run_store.dart';
import 'package:ensemble_test_runner/execution/remote/firebase_test_lab_provider.dart';
import 'package:ensemble_test_runner/execution/remote/ftl_client.dart';
import 'package:ensemble_test_runner/execution/remote/gcs_remote_run_store.dart';
import 'package:ensemble_test_runner/execution/remote/native_build_service.dart';
import 'package:ensemble_test_runner/execution/remote/remote_models.dart';
import 'package:ensemble_test_runner/execution/remote/remote_provider.dart';
import 'package:ensemble_test_runner/execution/remote/remote_report_reconciler.dart';
import 'package:ensemble_test_runner/execution/remote/remote_run_store.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/reporters/atomic_file.dart';
import 'package:path/path.dart' as p;

/// Host-side remote orchestration: intent → submit → ref → poll → collect.
class RemoteOrchestrator {
  final RemoteProvider provider;
  final RemoteRunStore store;
  final NativeBuildService buildService;

  RemoteOrchestrator({
    required this.provider,
    required this.store,
    NativeBuildService? buildService,
  }) : buildService = buildService ?? NativeBuildService();

  Future<AggregatedRemoteReport> runSuite({
    required String appDir,
    required EnsembleTestConfig config,
    required String platform,
    List<String> selectedTestIds = const [],
    String? runIdOverride,
    Directory? collectDirectory,
    bool waitForCompletion = true,
  }) async {
    final remote = config.remote;
    if (remote == null) {
      throw StateError('remote config required');
    }
    final devices = remoteDevicesForPlatform(remote, platform);
    if (devices.isEmpty) {
      throw StateError(
        'No remote.devices match --remote-platform=$platform. '
        'Add devices with platform: $platform (or omit platform to share).',
      );
    }
    if (devices.length > provider.limits.maxDevicesPerRun) {
      throw StateError(
        'Refusing matrix of ${devices.length} $platform devices '
        '(max ${provider.limits.maxDevicesPerRun}).',
      );
    }

    final identity = NativeBuildService.computeIdentity(
      mode: config.mode,
      target: ExecutionTarget.remote,
      platform: platform,
      variant: 'debug',
      selectedTestIds: selectedTestIds,
    );

    final artifacts = await buildService.buildOrReuse(
      identity: identity,
      appDir: appDir,
      config: config,
    );

    final runId = runIdOverride ??
        'run-${DateTime.now().toUtc().millisecondsSinceEpoch}-'
            '${Random.secure().nextInt(1 << 20).toRadixString(16)}';
    final clientToken = sha256
        .convert(utf8.encode('$runId|${identity.buildId}|$platform'))
        .toString()
        .substring(0, 32);
    final intentFingerprint = sha256
        .convert(
          utf8.encode(
            json.encode({
              'buildId': identity.buildId,
              'planHash': identity.planHash,
              'devices': devices.map((d) => d.toJson()).toList(),
              'platform': platform,
            }),
          ),
        )
        .toString();

    final manifest = RemoteRunManifest(
      runId: runId,
      buildId: identity.buildId,
      planHash: identity.planHash,
      intentFingerprint: intentFingerprint,
      clientToken: clientToken,
      platform: platform,
      devices: devices,
      status: 'intent',
      updatedAt: DateTime.now().toUtc(),
      version: 1,
    );

    final intent = RemoteRunIntent(
      manifest: manifest,
      appPackagePath: artifacts.appPackagePath,
      testPackagePath: artifacts.testPackagePath,
    );
    await store.putIntent(intent);

    final submitIntent = RemoteSubmitIntent(
      runId: runId,
      buildId: identity.buildId,
      planHash: identity.planHash,
      intentFingerprint: intentFingerprint,
      clientToken: clientToken,
      devices: devices,
      appPackagePath: artifacts.appPackagePath,
      testPackagePath: artifacts.testPackagePath,
      platform: platform,
    );

    RemoteProviderJobRef ref;
    try {
      ref = await provider.submit(submitIntent);
    } catch (error) {
      final existing = await provider.findByIntent(submitIntent);
      if (existing == null) rethrow;
      ref = existing;
    }

    await store.putProviderRef(
      runId: runId,
      ref: ref,
      expectedVersion: 1,
    );

    if (!waitForCompletion) {
      return AggregatedRemoteReport(
        runId: runId,
        devices: const [],
        overall: RemoteExecutionFailureClass.incomplete,
        exitCode: 0,
      );
    }

    return collectAndReconcile(
      runId: runId,
      collectDirectory: collectDirectory ??
          Directory(p.join(appDir, 'build/ensemble_test_runner/remote', runId)),
    );
  }

  Future<AggregatedRemoteReport> collectAndReconcile({
    required String runId,
    required Directory collectDirectory,
  }) async {
    final manifest = await store.get(runId);
    if (manifest == null) {
      throw StateError('Unknown run $runId');
    }
    final ref = manifest.providerRef;
    if (ref == null) {
      throw StateError('Run $runId has no provider ref yet');
    }

    await _pollUntilDone(ref);

    collectDirectory.createSync(recursive: true);
    final collected = await provider.collectArtifacts(
      ref,
      destinationDirectory: collectDirectory.path,
    );

    final status = await provider.getStatus(ref);
    final devices = <ReconciledDeviceResult>[];
    if (status.devices.isEmpty) {
      final envelope = RemoteReportReconciler.loadEnvelope(collectDirectory);
      devices.add(
        RemoteReportReconciler.reconcile(
          deviceKey: 'primary',
          nativeOutcome: status.detail ?? 'SUCCESS',
          envelope: envelope,
          artifactDirectory: collectDirectory,
        ),
      );
    } else {
      for (final entry in status.devices.entries) {
        final deviceDir = collected.deviceDirectories[entry.key] != null
            ? Directory(collected.deviceDirectories[entry.key]!)
            : collectDirectory;
        final envelope = RemoteReportReconciler.loadEnvelope(deviceDir);
        devices.add(
          RemoteReportReconciler.reconcile(
            deviceKey: entry.key,
            nativeOutcome: entry.value.nativeOutcome ?? status.detail,
            envelope: envelope,
            artifactDirectory: deviceDir,
          ),
        );
      }
    }

    final report = RemoteReportReconciler.aggregate(
      runId: runId,
      devices: devices,
    );

    final current = await store.get(runId);
    if (current != null) {
      await store.compareAndSwap(
        next: current.copyWith(
          status: report.overall.name,
          version: current.version + 1,
          updatedAt: DateTime.now().toUtc(),
          metadata: {
            ...current.metadata,
            'report': report.toJson(),
          },
        ),
        expectedVersion: current.version,
      );
    }

    final reportFile =
        File(p.join(collectDirectory.path, 'aggregated_report.json'));
    AtomicFile.writeStringSync(reportFile, report.toPrettyJson());
    return report;
  }

  Future<RemoteCancellationState> requestCancel(String runId) async {
    final manifest = await store.get(runId);
    if (manifest == null) throw StateError('Unknown run $runId');
    final ref = manifest.providerRef;
    if (ref == null) {
      await store.compareAndSwap(
        next: manifest.copyWith(
          cancellation: RemoteCancellationState.cancelled,
          status: 'cancelled',
          version: manifest.version + 1,
          updatedAt: DateTime.now().toUtc(),
        ),
        expectedVersion: manifest.version,
      );
      return RemoteCancellationState.cancelled;
    }

    await store.compareAndSwap(
      next: manifest.copyWith(
        cancellation: RemoteCancellationState.cancellationRequested,
        version: manifest.version + 1,
        updatedAt: DateTime.now().toUtc(),
      ),
      expectedVersion: manifest.version,
    );

    try {
      await provider.requestCancel(ref);
    } catch (_) {
      final latest = await store.get(runId);
      if (latest != null) {
        await store.compareAndSwap(
          next: latest.copyWith(
            cancellation: RemoteCancellationState.cancellationUncertain,
            version: latest.version + 1,
            updatedAt: DateTime.now().toUtc(),
          ),
          expectedVersion: latest.version,
        );
      }
      return RemoteCancellationState.cancellationUncertain;
    }

    final status = await provider.getStatus(ref);
    final state = status.state == RemoteJobState.cancelled
        ? RemoteCancellationState.cancelled
        : RemoteCancellationState.cancellationRequested;
    final latest = await store.get(runId);
    if (latest != null) {
      await store.compareAndSwap(
        next: latest.copyWith(
          cancellation: state,
          status: state == RemoteCancellationState.cancelled
              ? 'cancelled'
              : latest.status,
          version: latest.version + 1,
          updatedAt: DateTime.now().toUtc(),
        ),
        expectedVersion: latest.version,
      );
    }
    return state;
  }

  Future<void> _pollUntilDone(RemoteProviderJobRef ref) async {
    final limits = provider.limits;
    final deadline = DateTime.now().add(limits.maxPollDuration);
    var delay = limits.pollInterval;
    while (DateTime.now().isBefore(deadline)) {
      final status = await provider.getStatus(ref);
      if (status.state == RemoteJobState.finished ||
          status.state == RemoteJobState.error ||
          status.state == RemoteJobState.cancelled) {
        return;
      }
      await Future<void>.delayed(delay);
      final nextMs = (delay.inMilliseconds * 1.5).round();
      delay = Duration(
        milliseconds: nextMs > limits.pollBackoffCap.inMilliseconds
            ? limits.pollBackoffCap.inMilliseconds
            : nextMs,
      );
    }
    throw TimeoutException(
      'Remote job ${ref.jobId} did not finish within ${limits.maxPollDuration}',
    );
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  @override
  String toString() => message;
}

RemoteRunStore createRemoteRunStoreFromEnv({String? appDir}) {
  final gcsBucket = Platform.environment['ENSEMBLE_TEST_REMOTE_STORE_GCS_BUCKET'];
  if (gcsBucket != null && gcsBucket.isNotEmpty) {
    return GcsRemoteRunStore(
      bucket: gcsBucket,
      prefix: Platform.environment['ENSEMBLE_TEST_REMOTE_STORE_PREFIX'] ??
          'ensemble-test-remote-runs',
    );
  }
  final root = Directory(
    p.join(
      appDir ?? Directory.current.path,
      'build/ensemble_test_runner/remote_runs',
    ),
  );
  return FileRemoteRunStore(root);
}

RemoteProvider createRemoteProviderFromEnv(EnsembleTestConfig config) {
  final projectId = config.remote?.projectId ??
      Platform.environment['ENSEMBLE_TEST_FTL_PROJECT_ID'] ??
      '';
  if (projectId.isEmpty) {
    throw StateError(
      'Firebase Test Lab project id required via remote.projectId or '
      'ENSEMBLE_TEST_FTL_PROJECT_ID.',
    );
  }
  return FirebaseTestLabProvider(
    client: HttpFtlClient(
      resultsBucket:
          Platform.environment['ENSEMBLE_TEST_FTL_RESULTS_BUCKET'] ?? '',
    ),
    projectId: projectId,
  );
}

/// CLI entry for `--target=remote`.
Future<int> runRemoteEnsembleYamlTestsCli(
  List<String> arguments, {
  required String appDir,
  required EnsembleTestConfig suiteConfig,
  required bool quiet,
  required bool verbose,
}) async {
  final platformValues = _remoteOptionValues(arguments, '--remote-platform');
  final platform = platformValues.isEmpty
      ? (Platform.isMacOS ? 'ios' : 'android')
      : platformValues.single;
  if (platform != 'android' && platform != 'ios') {
    stderr.writeln('Invalid --remote-platform=$platform (android|ios).');
    return 2;
  }

  // Multi-device orchestration (same platform) is gated on Android FTL verification.
  final allDevices = suiteConfig.remote?.devices ?? const <RemoteDeviceSpec>[];
  final devices = [
    for (final d in allDevices)
      if (d.matchesPlatform(platform)) d,
  ];
  if (devices.isEmpty) {
    stderr.writeln(
      'No remote.devices match --remote-platform=$platform. '
      'Add an entry with platform: $platform.',
    );
    return 2;
  }
  if (devices.length > 1) {
    final androidVerified =
        Platform.environment['ENSEMBLE_TEST_FTL_ANDROID_VERIFIED'] == '1';
    if (!androidVerified) {
      stderr.writeln(
        'Multi-device remote matrices require verified Android FTL '
        '(set ENSEMBLE_TEST_FTL_ANDROID_VERIFIED=1 after cloud proof). '
        'Refusing ${devices.length} $platform devices.',
      );
      return 2;
    }
  }

  try {
    final store = createRemoteRunStoreFromEnv(appDir: appDir);
    final provider = createRemoteProviderFromEnv(suiteConfig);
    final orch = RemoteOrchestrator(provider: provider, store: store);
    if (!quiet) {
      stdout.writeln(
        'Remote execution via ${provider.id} ($platform, '
        '${devices.length} device(s))...',
      );
    }
    final report = await orch.runSuite(
      appDir: appDir,
      config: suiteConfig,
      platform: platform,
      selectedTestIds: _remoteOptionValues(arguments, '--id'),
    );
    if (verbose || !quiet) {
      stdout.writeln(report.toPrettyJson());
    }
    return report.exitCode;
  } on FtlCredentialException catch (error) {
    stderr.writeln(
      'Remote run unverified (missing FTL credentials): $error\n'
      'Packaging/validation completed locally where possible; '
      'cloud collect remains unverified.',
    );
    return 2;
  } catch (error) {
    stderr.writeln(error);
    return 2;
  }
}

List<String> _remoteOptionValues(List<String> arguments, String name) {
  final values = <String>[];
  for (final arg in arguments) {
    if (arg == name) continue;
    if (arg.startsWith('$name=')) {
      values.add(arg.substring(name.length + 1));
    }
  }
  // Also support space-separated: --id foo (handled by main CLI elsewhere).
  for (var i = 0; i < arguments.length; i++) {
    if (arguments[i] == name && i + 1 < arguments.length) {
      final next = arguments[i + 1];
      if (!next.startsWith('--')) values.add(next);
    }
  }
  return values;
}
