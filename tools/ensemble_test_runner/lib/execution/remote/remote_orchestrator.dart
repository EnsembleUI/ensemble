import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:ensemble_test_runner/cli/yaml_test_app_patcher.dart';
import 'package:ensemble_test_runner/execution/artifact_transport.dart';
import 'package:ensemble_test_runner/execution/remote/file_remote_run_store.dart';
import 'package:ensemble_test_runner/execution/remote/firebase_test_lab_provider.dart';
import 'package:ensemble_test_runner/execution/remote/ftl_client.dart';
import 'package:ensemble_test_runner/execution/remote/gcs_remote_run_store.dart';
import 'package:ensemble_test_runner/execution/remote/native_build_service.dart';
import 'package:ensemble_test_runner/execution/remote/remote_models.dart';
import 'package:ensemble_test_runner/execution/remote/remote_progress.dart';
import 'package:ensemble_test_runner/execution/remote/remote_provider.dart';
import 'package:ensemble_test_runner/execution/remote/remote_report_reconciler.dart';
import 'package:ensemble_test_runner/execution/remote/remote_run_store.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/reporters/atomic_file.dart';
import 'package:ensemble_test_runner/reporters/ensemble_test_history_store.dart';
import 'package:ensemble_test_runner/reporters/html_test_reporter.dart';
import 'package:path/path.dart' as p;

/// Host-side remote orchestration: intent → submit → ref → poll → collect.
class RemoteOrchestrator {
  final RemoteProvider provider;
  final RemoteRunStore store;
  final NativeBuildService buildService;
  final RemoteProgress? onProgress;

  RemoteOrchestrator({
    required this.provider,
    required this.store,
    NativeBuildService? buildService,
    this.onProgress,
  }) : buildService = buildService ?? NativeBuildService(onProgress: onProgress);

  void _log(String message) => onProgress?.call(message);

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

    _log(
      'Build identity ${identity.buildId.substring(0, 12)}… '
      '(platform=$platform, plan=${identity.planHash.substring(0, 12)}…)',
    );
    final buildStarted = DateTime.now().toUtc();
    final artifacts = await buildService.buildOrReuse(
      identity: identity,
      appDir: appDir,
      config: config,
    );
    final buildSecs =
        DateTime.now().toUtc().difference(buildStarted).inSeconds;
    final reused = artifacts.metadata['reused'] == 'true';
    final stub = artifacts.metadata['stub'] == 'true';
    _log(
      reused
          ? 'Reused cached native packages (${buildSecs}s)'
          : 'Native packages ready (${buildSecs}s)',
    );
    _log('  app:  ${artifacts.appPackagePath}');
    _log('  test: ${artifacts.testPackagePath}');
    if (stub) {
      throw StateError(
        'Native package is a stub (real $platform build failed): '
        '${artifacts.metadata['detail'] ?? 'unknown'}. '
        'Fix the local Flutter/$platform build before submitting to '
        'Firebase Test Lab — otherwise nothing useful appears in the console.',
      );
    }

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
    _log('Persisting run intent $runId ...');
    await store.putIntent(intent);
    _log('Run intent persisted');

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
      _log('Submitting to ${provider.id} ...');
      ref = await provider.submit(submitIntent);
    } catch (error) {
      _log('Submit error ($error); checking for existing matrix by intent ...');
      final existing = await provider.findByIntent(submitIntent);
      if (existing == null) rethrow;
      ref = existing;
      _log('Adopted existing matrix ${ref.matrixId ?? ref.jobId}');
    }

    // Provider already logged the console link on submit.

    await store.putProviderRef(
      runId: runId,
      ref: ref,
      expectedVersion: 1,
    );
    _log('Provider ref stored (matrix=${ref.matrixId ?? ref.jobId})');

    if (!waitForCompletion) {
      _log('waitForCompletion=false; returning without poll');
      return AggregatedRemoteReport(
        runId: runId,
        devices: const [],
        overall: RemoteExecutionFailureClass.incomplete,
        exitCode: 0,
      );
    }

    return collectAndReconcile(
      runId: runId,
      appDir: appDir,
      collectDirectory: collectDirectory ??
          Directory(p.join(appDir, 'build/ensemble_test_runner/remote', runId)),
    );
  }

  Future<AggregatedRemoteReport> collectAndReconcile({
    required String runId,
    required String appDir,
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

    _log('Collecting artifacts into ${collectDirectory.path} ...');
    collectDirectory.createSync(recursive: true);
    final collected = await provider.collectArtifacts(
      ref,
      destinationDirectory: collectDirectory.path,
    );

    final hostArtifactRoot =
        p.join(appDir, 'build', 'ensemble_test_runner');
    await _materializeDeviceArtifactsIntoHost(
      collectDirectory: collectDirectory,
      hostArtifactRoot: hostArtifactRoot,
    );

    final status = await provider.getStatus(ref);
    final devices = <ReconciledDeviceResult>[];
    if (status.devices.isEmpty) {
      final envelope = RemoteReportReconciler.loadEnvelope(collectDirectory);
      _canonicalizeEnvelope(collectDirectory, envelope);
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
        _canonicalizeEnvelope(deviceDir, envelope);
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

    if (report.overall == RemoteExecutionFailureClass.pass ||
        report.overall == RemoteExecutionFailureClass.testFailure) {
      await _writeHostReportsFromEnvelopes(
        appDir: appDir,
        hostArtifactRoot: hostArtifactRoot,
        devices: devices,
      );
    }

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
    _log(
      'Remote run finished: overall=${report.overall.name} '
      'exit=${report.exitCode}',
    );
    return report;
  }

  /// Copies pulled on-device files and materializes logcat artifact chunks into
  /// the host `build/ensemble_test_runner` tree used by HTML/history.
  Future<void> _materializeDeviceArtifactsIntoHost({
    required Directory collectDirectory,
    required String hostArtifactRoot,
  }) async {
    Directory(hostArtifactRoot).createSync(recursive: true);

    // Prefer an explicit pulled ensemble_test_remote tree when present.
    try {
      for (final entity in collectDirectory.listSync(recursive: true)) {
        if (entity is! Directory) continue;
        if (p.basename(entity.path) != 'ensemble_test_remote') continue;
        _copyDirectoryContents(entity, Directory(hostArtifactRoot));
        _log('Merged pulled on-device tree into $hostArtifactRoot');
        break;
      }
    } catch (_) {
      // Continue with logcat materialization.
    }

    final logcat = _readCollectedLogcat(collectDirectory);
    if (logcat.isEmpty) return;
    if (!logcat.contains(ensembleTestArtifactProtocolPrefix) &&
        !logcat.contains(ensembleTestRemoteEnvelopePrefix)) {
      return;
    }
    try {
      final transport = await materializeTransportedArtifacts(
        artifactRoot: hostArtifactRoot,
        output: logcat,
      );
      _log(
        transport.complete
            ? 'Materialized ${transport.receivedPaths.length} artifact(s) from logcat'
            : 'Partial logcat artifact materialize '
                '(${transport.receivedPaths.length} file(s)'
                '${transport.error != null ? '; ${transport.error}' : ''})',
      );
    } catch (error) {
      _log('Warning: logcat artifact materialize failed: $error');
    }
  }

  void _canonicalizeEnvelope(
    Directory directory,
    RemoteRunEnvelope? envelope,
  ) {
    if (envelope == null) return;
    try {
      final dest = File(p.join(directory.path, 'remote', 'envelope.json'));
      dest.parent.createSync(recursive: true);
      AtomicFile.writeStringSync(
        dest,
        const JsonEncoder.withIndent('  ').convert(envelope.toJson()),
      );
    } catch (_) {
      // Best-effort canonicalize for debugging / loadEnvelope preferred path.
    }
  }

  Future<void> _writeHostReportsFromEnvelopes({
    required String appDir,
    required String hostArtifactRoot,
    required List<ReconciledDeviceResult> devices,
  }) async {
    final combined = <EnsembleSingleTestResult>[];
    final suiteLogs = <String>[];
    for (final device in devices) {
      final results = device.envelope?.results;
      if (results == null) continue;
      combined.addAll(results.results);
      suiteLogs.addAll(results.suiteLogs);
      for (final err in device.envelope?.cleanupErrors ?? const <String>[]) {
        suiteLogs.add('cleanup[${device.deviceKey}]: $err');
      }
    }
    if (combined.isEmpty) {
      _log('No envelope.results to write HTML/history from');
      return;
    }

    final runResult = EnsembleTestRunResult(
      results: combined,
      suiteLogs: suiteLogs,
    );
    final displayRoot =
        p.join('build', 'ensemble_test_runner').replaceAll('\\', '/');
    try {
      await EnsembleTestHistoryStore.recordCompletedRun(
        appDir: appDir,
        artifactRoot: hostArtifactRoot,
        result: runResult,
      );
      suiteLogs.add(
        'history: ${p.join(displayRoot, 'report', EnsembleTestHistoryStore.fileName)}',
      );
    } catch (error) {
      _log('Warning: could not write history db: $error');
    }

    final withLogs = EnsembleTestRunResult(
      results: combined,
      suiteLogs: [
        ...suiteLogs,
        'htmlReport: ${p.join(displayRoot, 'report', 'index.html')}',
        'results: ${p.join(displayRoot, 'report', 'results.json.gz')}',
      ],
    );
    try {
      HtmlTestReporter().write(
        withLogs,
        artifactRoot: hostArtifactRoot,
        displayRoot: displayRoot,
      );
      _log(
        'Wrote HTML report under '
        '${p.join(hostArtifactRoot, 'report', 'index.html')}',
      );
    } catch (error) {
      _log('Warning: could not write HTML report: $error');
    }
  }

  static String _readCollectedLogcat(Directory directory) {
    if (!directory.existsSync()) return '';
    final buffer = StringBuffer();
    try {
      for (final entity in directory.listSync(recursive: true)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path).toLowerCase();
        final looksLikeLog = name.contains('logcat') ||
            name.endsWith('.txt') ||
            name.endsWith('.log');
        if (!looksLikeLog) continue;
        try {
          buffer.writeln(entity.readAsStringSync());
        } catch (_) {
          // Skip unreadable files.
        }
      }
    } catch (_) {
      return buffer.toString();
    }
    return buffer.toString();
  }

  static void _copyDirectoryContents(Directory source, Directory dest) {
    dest.createSync(recursive: true);
    for (final entity in source.listSync(recursive: true)) {
      final relative = p.relative(entity.path, from: source.path);
      final target = p.join(dest.path, relative);
      if (entity is Directory) {
        Directory(target).createSync(recursive: true);
      } else if (entity is File) {
        File(target).parent.createSync(recursive: true);
        entity.copySync(target);
      }
    }
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
    final started = DateTime.now().toUtc();
    var delay = limits.pollInterval;
    var lastLoggedState = '';
    var loggedResultsUrl = ref.metadata['resultsUrl'] != null;
    final projectId = ref.metadata['projectId']?.toString() ??
        Platform.environment['ENSEMBLE_TEST_FTL_PROJECT_ID'] ??
        '';
    final matrixId = ref.matrixId ?? ref.jobId;

    _log(
      'Polling FTL matrix $matrixId '
      '(interval=${limits.pollInterval.inSeconds}s, '
      'timeout=${limits.maxPollDuration.inMinutes}m)',
    );

    while (DateTime.now().isBefore(deadline)) {
      final status = await provider.getStatus(ref);
      if (!loggedResultsUrl &&
          status.resultsUrl != null &&
          status.resultsUrl!.isNotEmpty) {
        _log('Open results: ${status.resultsUrl}');
        loggedResultsUrl = true;
      } else if (!loggedResultsUrl &&
          status.historyId != null &&
          status.historyId!.isNotEmpty &&
          projectId.isNotEmpty) {
        // resultsUrl still missing; keep browsing fallback once.
        final links = FtlConsoleLinks(
          projectId: projectId,
          matrixId: matrixId,
          historyId: status.historyId,
        );
        _log(links.logLine);
        loggedResultsUrl = true;
      }
      final elapsed = DateTime.now().toUtc().difference(started);
      final elapsedLabel = elapsed.inMinutes >= 1
          ? '${elapsed.inMinutes}m ${elapsed.inSeconds % 60}s'
          : '${elapsed.inSeconds}s';
      final stateLabel = status.detail == null || status.detail!.isEmpty
          ? status.state.name
          : '${status.state.name} (${status.detail})';
      if (stateLabel != lastLoggedState) {
        _log('FTL status after $elapsedLabel: $stateLabel');
        lastLoggedState = stateLabel;
      } else {
        _log('Still waiting on FTL after $elapsedLabel: $stateLabel');
      }
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

RemoteProvider createRemoteProviderFromEnv(
  EnsembleTestConfig config, {
  RemoteProgress? onProgress,
}) {
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
    onProgress: onProgress,
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

  final progress = quiet ? null : stderrRemoteProgress();

  final patcher = YamlTestAppPatcher(appDir);
  try {
    progress?.call(
      'Patching app for integration_test ($platform) before remote build...',
    );
    patcher.enable(
      mode: ExecutionMode.integration,
      targetPlatform: platform,
      fixIosDeploymentTarget: platform == 'ios',
    );
    if (patcher.pubspecChanged) {
      progress?.call('flutter pub get (pubspec changed by patcher)...');
      final pubGet = await Process.run(
        'flutter',
        ['pub', 'get'],
        workingDirectory: appDir,
        runInShell: true,
      );
      if (pubGet.exitCode != 0) {
        stderr.writeln('flutter pub get failed: ${pubGet.stderr}');
        return 2;
      }
    }

    final store = createRemoteRunStoreFromEnv(appDir: appDir);
    final provider = createRemoteProviderFromEnv(
      suiteConfig,
      onProgress: progress,
    );
    final orch = RemoteOrchestrator(
      provider: provider,
      store: store,
      onProgress: progress,
      buildService: NativeBuildService(onProgress: progress),
    );
    progress?.call(
      'Starting remote execution via ${provider.id} '
      '($platform, ${devices.length} device(s))',
    );
    final report = await orch.runSuite(
      appDir: appDir,
      config: suiteConfig,
      platform: platform,
      selectedTestIds: _remoteOptionValues(arguments, '--id'),
    );
    if (verbose || !quiet) {
      remoteCliWrite(report.toPrettyJson(), toStderr: false);
    }
    return report.exitCode;
  } on FtlCredentialException catch (error) {
    remoteCliWrite(
      'Remote run unverified (missing FTL credentials): $error\n'
      'Packaging/validation completed locally where possible; '
      'cloud collect remains unverified.',
    );
    return 2;
  } catch (error) {
    remoteCliWrite(error);
    return 2;
  } finally {
    patcher.restore();
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
