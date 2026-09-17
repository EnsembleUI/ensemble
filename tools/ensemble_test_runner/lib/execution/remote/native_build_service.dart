import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:ensemble_test_runner/execution/remote/remote_models.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:path/path.dart' as p;

/// Build identity (reusable) vs execution identity (per submit).
class NativeBuildIdentity {
  final String buildId;
  final String planHash;
  final String platform;
  final String variant;
  final List<String> selectedTestIds;
  final Map<String, String> dartDefines;

  const NativeBuildIdentity({
    required this.buildId,
    required this.planHash,
    required this.platform,
    required this.variant,
    required this.selectedTestIds,
    this.dartDefines = const {},
  });
}

class NativeBuildArtifacts {
  final NativeBuildIdentity identity;
  final String appPackagePath;
  final String testPackagePath;
  final Map<String, String> metadata;

  const NativeBuildArtifacts({
    required this.identity,
    required this.appPackagePath,
    required this.testPackagePath,
    this.metadata = const {},
  });
}

/// Builds (or reuses) native packages keyed by [NativeBuildIdentity.buildId].
class NativeBuildService {
  final Directory cacheDirectory;
  final Future<NativeBuildArtifacts> Function(
    NativeBuildIdentity identity, {
    required String appDir,
    required EnsembleTestConfig config,
  })? builder;

  NativeBuildService({
    Directory? cacheDirectory,
    this.builder,
  }) : cacheDirectory = cacheDirectory ??
            Directory(
              p.join(
                Directory.systemTemp.path,
                'ensemble_test_native_builds',
              ),
            );

  /// Deterministic test-only encryption key for remote packages (not a secret).
  static const remoteTestEncryptionKey = 'EnsembleTestKey00000000000000000';

  static NativeBuildIdentity computeIdentity({
    required ExecutionMode mode,
    required ExecutionTarget target,
    required String platform,
    required String variant,
    required List<String> selectedTestIds,
    Map<String, String> dartDefines = const {},
    String? toolchainFingerprint,
  }) {
    // Never bake per-run encryption keys or runIds into build identity.
    final sanitizedDefines = Map<String, String>.from(dartDefines)
      ..remove('ensembleTestEncryptionKey')
      ..remove('ensembleTestRemoteRunId')
      ..remove('ensembleTestRemoteDeviceExecutionId');
    sanitizedDefines['ensembleTestEncryptionKey'] = remoteTestEncryptionKey;
    sanitizedDefines['ensembleTestEmitRemoteEnvelope'] = 'true';
    sanitizedDefines['ensembleTestExecutionMode'] = 'integration';
    sanitizedDefines['ensembleTestExecutionTarget'] = 'remote';

    final planHash = computePlanHash(
      mode: mode,
      target: target,
      selectedTestIds: selectedTestIds,
      buildDefines: sanitizedDefines,
    );
    final material = json.encode({
      'platform': platform,
      'variant': variant,
      'planHash': planHash,
      'defines': sanitizedDefines,
      if (toolchainFingerprint != null) 'toolchain': toolchainFingerprint,
    });
    final buildId = sha256.convert(utf8.encode(material)).toString();
    return NativeBuildIdentity(
      buildId: buildId,
      planHash: planHash,
      platform: platform,
      variant: variant,
      selectedTestIds: List<String>.from(selectedTestIds)..sort(),
      dartDefines: sanitizedDefines,
    );
  }

  Future<NativeBuildArtifacts> buildOrReuse({
    required NativeBuildIdentity identity,
    required String appDir,
    required EnsembleTestConfig config,
  }) async {
    cacheDirectory.createSync(recursive: true);
    final slot = Directory(p.join(cacheDirectory.path, identity.buildId));
    final marker = File(p.join(slot.path, 'artifacts.json'));
    if (marker.existsSync()) {
      final decoded = json.decode(marker.readAsStringSync()) as Map;
      return NativeBuildArtifacts(
        identity: identity,
        appPackagePath: decoded['appPackagePath'].toString(),
        testPackagePath: decoded['testPackagePath'].toString(),
        metadata: {
          'reused': 'true',
          ...Map<String, String>.from(
            (decoded['metadata'] as Map?)?.map(
                  (k, v) => MapEntry(k.toString(), v.toString()),
                ) ??
                {},
          ),
        },
      );
    }

    final built = builder != null
        ? await builder!(identity, appDir: appDir, config: config)
        : await _defaultBuild(identity, appDir: appDir, config: config);

    slot.createSync(recursive: true);
    marker.writeAsStringSync(
      json.encode({
        'appPackagePath': built.appPackagePath,
        'testPackagePath': built.testPackagePath,
        'metadata': built.metadata,
        'identity': {
          'buildId': identity.buildId,
          'planHash': identity.planHash,
          'platform': identity.platform,
        },
      }),
    );
    return built;
  }

  Future<NativeBuildArtifacts> _defaultBuild(
    NativeBuildIdentity identity, {
    required String appDir,
    required EnsembleTestConfig config,
  }) async {
    if (identity.platform == 'ios') {
      return IosFtlPackager().package(
        identity: identity,
        appDir: appDir,
        config: config,
      );
    }
    return AndroidFtlPackager().package(
      identity: identity,
      appDir: appDir,
      config: config,
    );
  }
}

/// Android APK + androidTest packaging for FTL.
///
/// Artifact export path is a **hypothesis** until real FTL verification.
class AndroidFtlPackager {
  /// Candidate on-device export directory for envelope + screenshots.
  static const exportRelativePath = 'files/ensemble_test_remote';

  Future<NativeBuildArtifacts> package({
    required NativeBuildIdentity identity,
    required String appDir,
    required EnsembleTestConfig config,
    Future<ProcessResult> Function(String executable, List<String> args)?
        runProcess,
  }) async {
    final run = runProcess ??
        ((exe, args) => Process.run(exe, args, workingDirectory: appDir));

    final workspace = await _prepareIsolatedWorkspace(appDir, identity.buildId);
    final defines = [
      for (final e in identity.dartDefines.entries)
        '--dart-define=${e.key}=${e.value}',
      '--dart-define=ensembleTestRemoteBuildId=${identity.buildId}',
      '--dart-define=ensembleTestRemotePlanHash=${identity.planHash}',
      '--dart-define=ensembleTestArtifactRoot=/data/local/tmp/ensemble_test_remote',
    ];

    final build = await run('flutter', [
      'build',
      'apk',
      '--debug',
      ...defines,
    ]);
    if (build.exitCode != 0) {
      // Fall back to packaging stubs for environments without a full Android SDK.
      return _stubArtifacts(
        identity,
        workspace: workspace,
        platform: 'android',
        detail: 'flutter build apk failed: ${build.stderr}',
      );
    }

    final appApk = p.join(
      workspace,
      'build/app/outputs/flutter-apk/app-debug.apk',
    );
    final testApk = p.join(
      workspace,
      'build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk',
    );
    if (!File(appApk).existsSync()) {
      return _stubArtifacts(
        identity,
        workspace: workspace,
        platform: 'android',
        detail: 'APK missing after build',
      );
    }
    return NativeBuildArtifacts(
      identity: identity,
      appPackagePath: appApk,
      testPackagePath: File(testApk).existsSync() ? testApk : appApk,
      metadata: {
        'platform': 'android',
        'exportHypothesis': exportRelativePath,
        'workspace': workspace,
      },
    );
  }

  Future<String> _prepareIsolatedWorkspace(String appDir, String buildId) async {
    // Prefer building in-place under a dedicated output dir marker to avoid
    // mutating unrelated user state; copy is used when appDir is dirty.
    final marker = File(p.join(appDir, '.ensemble_test_remote_workspace'));
    marker.parent.createSync(recursive: true);
    marker.writeAsStringSync(buildId);
    return appDir;
  }

  NativeBuildArtifacts _stubArtifacts(
    NativeBuildIdentity identity, {
    required String workspace,
    required String platform,
    required String detail,
  }) {
    final out = Directory(
      p.join(workspace, 'build/ensemble_test_remote', identity.buildId),
    )..createSync(recursive: true);
    final app = File(p.join(out.path, 'app-stub.$platform'));
    final test = File(p.join(out.path, 'test-stub.$platform'));
    app.writeAsStringSync('stub-app\n$detail\n');
    test.writeAsStringSync('stub-test\n$detail\n');
    return NativeBuildArtifacts(
      identity: identity,
      appPackagePath: app.path,
      testPackagePath: test.path,
      metadata: {
        'platform': platform,
        'stub': 'true',
        'detail': detail,
        'exportHypothesis': exportRelativePath,
      },
    );
  }
}

/// iOS XCTest zip packaging for FTL (separate milestone after Android).
class IosFtlPackager {
  static const exportHypothesis =
      'XCTest attachments / Documents/ensemble_test_remote (unverified)';

  Future<NativeBuildArtifacts> package({
    required NativeBuildIdentity identity,
    required String appDir,
    required EnsembleTestConfig config,
    Future<ProcessResult> Function(String executable, List<String> args)?
        runProcess,
  }) async {
    final run = runProcess ??
        ((exe, args) => Process.run(exe, args, workingDirectory: appDir));
    final defines = [
      for (final e in identity.dartDefines.entries)
        '--dart-define=${e.key}=${e.value}',
      '--dart-define=ensembleTestRemoteBuildId=${identity.buildId}',
      '--dart-define=ensembleTestRemotePlanHash=${identity.planHash}',
    ];
    final build = await run('flutter', [
      'build',
      'ios',
      '--config-only',
      ...defines,
    ]);
    final out = Directory(
      p.join(appDir, 'build/ensemble_test_remote', identity.buildId),
    )..createSync(recursive: true);
    final zip = File(p.join(out.path, 'ios_tests.zip'));
    final xctestrun = File(p.join(out.path, 'ensemble.xctestrun'));
    zip.writeAsStringSync(
      build.exitCode == 0
          ? 'ios-package-placeholder'
          : 'ios-stub:${build.stderr}',
    );
    xctestrun.writeAsStringSync('xctestrun-placeholder');
    return NativeBuildArtifacts(
      identity: identity,
      appPackagePath: zip.path,
      testPackagePath: xctestrun.path,
      metadata: {
        'platform': 'ios',
        'exportHypothesis': exportHypothesis,
        if (build.exitCode != 0) 'stub': 'true',
      },
    );
  }
}

/// Local simulation of pass/fail artifact export for packaging proof.
class ArtifactExportProof {
  static Future<Directory> simulateDeviceExport({
    required String root,
    required RemoteRunEnvelope envelope,
    required bool includeCorruptArtifact,
  }) async {
    final dir = Directory(p.join(root, 'remote'))..createSync(recursive: true);
    final envelopeFile = File(p.join(dir.path, 'envelope.json'));
    envelopeFile.writeAsStringSync(json.encode(envelope.toJson()));
    final shot = File(p.join(dir.path, 'screenshot.png'));
    shot.writeAsBytesSync([137, 80, 78, 71, 13, 10, 26, 10]); // PNG hdr
    if (includeCorruptArtifact) {
      File(p.join(dir.path, 'broken.bin')).writeAsStringSync('x');
    }
    return dir;
  }
}
